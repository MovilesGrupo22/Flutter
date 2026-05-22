import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foodandes_app/data/repositories/restaurant_repository.dart';
import 'package:foodandes_app/data/services/analytics_service.dart';
import 'package:foodandes_app/data/services/cas_service.dart';
import 'package:foodandes_app/data/services/connectivity_service.dart';
import 'package:foodandes_app/data/services/local_database_service.dart';
import 'package:foodandes_app/data/services/popular_filters_service.dart';
import 'package:foodandes_app/data/services/preferences_service.dart';
import 'package:foodandes_app/data/services/restaurant_filter_isolate.dart';
import 'package:foodandes_app/data/services/trending_restaurants_service.dart';
import 'package:foodandes_app/features/home/widgets/cas_dining_banner.dart';
import 'package:foodandes_app/features/profile/profile_screen.dart';
import 'package:foodandes_app/features/recently_viewed/recently_viewed_screen.dart';
import 'package:foodandes_app/features/restaurant/restaurant_detail_screen.dart';
import 'package:foodandes_app/features/search/search_empty_screen.dart';
import 'package:foodandes_app/models/restaurant.dart';
import 'package:foodandes_app/shared/widgets/category_chip.dart';
import 'package:foodandes_app/shared/widgets/connectivity_status_dot.dart';
import 'package:foodandes_app/shared/widgets/custom_bottom_navbar.dart';
import 'package:foodandes_app/shared/widgets/offline_banner.dart';
import 'package:foodandes_app/shared/widgets/restaurant_card.dart';

class HomeScreen extends StatefulWidget {
  static const String routeName = '/home';
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ── STRATEGY 1: Stream ─────────────────────────────────────────────────────
  // One open Stream for the widget's lifetime. Cancelled in dispose().
  late final Stream<List<Restaurant>> _restaurantsStream;
  StreamSubscription<List<Restaurant>>? _streamSubscription;
  StreamSubscription<bool>? _connectivitySubscription;

  final RestaurantRepository _repository = RestaurantRepository();

  List<Restaurant> _allRestaurants = [];
  Object? _restaurantLoadError;
  bool _isInitialRestaurantsLoading = true;

  // ── STRATEGY 2: Isolate — results written here after compute() returns ──────
  List<Restaurant> _filteredRestaurants = [];
  bool _isFiltering = false; // shows a tiny spinner in AppBar while isolate runs
  int _filterRunId = 0;

  List<Restaurant> _trendingRestaurants = [];
  bool _isTrendingLoading = true;

  String _selectedCategory = 'All';
  bool _onlyOpen = false;
  bool _onlyTopRated = false;
  String _selectedPriceRange = 'All';
  List<String> _categoryOptions = const ['All'];
  List<String> _priceOptions = const ['All'];

  List<String> _topCategories = [];
  List<String> _topPriceRanges = [];
  List<String> _topQuickChips = [];

  bool _casAutoOpenEnabled = false;
  Timer? _casTimer;

  bool _isOffline = false;

  @override
  void initState() {
    super.initState();

    // ── STRATEGY 1: open the Firestore-backed Stream ─────────────────────────
    _restaurantsStream = _repository.restaurantsStream();

    // Manual subscription so Home has a single source of state. This avoids
    // rebuilding once from StreamBuilder and again from setState.
    _streamSubscription = _restaurantsStream.listen(
      (restaurants) {
        if (!mounted) return;
        _setRestaurants(restaurants);
        _applyFiltersAsync();                                     // Isolate
        _loadTrendingRestaurants(sourceRestaurants: restaurants); // Future
        // Keep SQLite in sync so offline access always has fresh data.
        unawaited(LocalDatabaseService.instance.insertRestaurants(restaurants));
      },
      onError: (Object e) {
        debugPrint('HomeScreen stream ERROR -> $e');
        if (mounted) {
          setState(() {
            _restaurantLoadError = e;
            _isInitialRestaurantsLoading = false;
          });
        }
        _loadFromLocalIfOffline();
      },
    );

    _loadPopularFilters();    // Future + async/await
    _loadSavedPreferences();  // SharedPreferences restore
    _initCas();
    _initConnectivity();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      AnalyticsService.instance.logSectionView(
        section: AppSection.home,
        userId: userId,
      );
      AnalyticsService.instance.logFlutterSmokeTest();
    });
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();    // avoid memory leaks from open Stream
    _connectivitySubscription?.cancel();
    _casTimer?.cancel();
    super.dispose();
  }

  // ── Connectivity ────────────────────────────────────────────────────────────

  void _setRestaurants(List<Restaurant> restaurants) {
    setState(() {
      _allRestaurants = restaurants;
      _categoryOptions = _repository.extractCategories(restaurants);
      _priceOptions = _repository.extractPriceRanges(restaurants);
      _restaurantLoadError = null;
      _isInitialRestaurantsLoading = false;
    });
  }

  void _initConnectivity() {
    _connectivitySubscription = ConnectivityService.instance.isOnlineStream.listen(
      (isOnline) {
        if (!mounted) return;
        setState(() => _isOffline = !isOnline);
        if (!isOnline && _allRestaurants.isEmpty) {
          _loadFromLocalIfOffline();
        }
      },
    );
    // Perform an initial connectivity + SQLite load check.
    _loadFromLocalIfOffline();
  }

  // If currently offline and no restaurants are loaded, fall back to SQLite.
  Future<void> _loadFromLocalIfOffline() async {
    final online = await ConnectivityService.instance.isOnline;
    if (!mounted) return;
    setState(() => _isOffline = !online);
    if (!online && _allRestaurants.isEmpty) {
      final cached = await LocalDatabaseService.instance.getRestaurants();
      if (!mounted) return;
      _setRestaurants(cached);
      _applyFiltersAsync();
    }
  }

  // ── Saved preferences ───────────────────────────────────────────────────────

  Future<void> _loadSavedPreferences() async {
    final category = await PreferencesService.instance.getSelectedCategory();
    final onlyOpen = await PreferencesService.instance.getOnlyOpen();
    final onlyTopRated = await PreferencesService.instance.getOnlyTopRated();
    final priceRange = await PreferencesService.instance.getSelectedPriceRange();
    if (!mounted) return;
    setState(() {
      _selectedCategory = category;
      _onlyOpen = onlyOpen;
      _onlyTopRated = onlyTopRated;
      _selectedPriceRange = priceRange;
    });
    _applyFiltersAsync();
  }

  // ── STRATEGY 2: Isolate filter ─────────────────────────────────────────────
  //
  // Every filter interaction calls this instead of the old synchronous
  // _applyFilters(). compute() spawns a Dart Isolate, copies FilterParams into
  // it (no shared memory), runs the heavy loop, and returns a Future with the
  // result. The main thread is unblocked the whole time.
  Future<void> _applyFiltersAsync() async {
    if (_allRestaurants.isEmpty) return;

    final runId = ++_filterRunId;
    if (!_isFiltering) {
      setState(() => _isFiltering = true);
    }

    final mood = CasService.instance.getDiningMood();

    // FilterParams must be a plain Dart object (no platform types) so it can
    // cross the Isolate boundary via message passing.
    final params = FilterParams(
      restaurants: _allRestaurants,
      selectedCategory: _selectedCategory,
      onlyOpen: _onlyOpen,
      onlyTopRated: _onlyTopRated,
      selectedPriceRange: _selectedPriceRange,
      moodCategories: mood.recommendedCategories,
      moodTags: mood.recommendedTags,
    );

    try {
      // Runs on a background Isolate — main thread stays responsive.
      final result = await RestaurantFilterIsolate.run(params);

      if (!mounted || runId != _filterRunId) return;
      setState(() {
        _filteredRestaurants = result;
        _isFiltering = false;
      });
    } catch (error) {
      debugPrint('HomeScreen filter isolate ERROR -> $error');
      if (!mounted || runId != _filterRunId) return;
      setState(() {
        _filteredRestaurants = _repository.filterRestaurants(
          restaurants: _allRestaurants,
          selectedCategory: _selectedCategory,
          onlyOpen: _onlyOpen,
          onlyTopRated: _onlyTopRated,
          selectedPriceRange: _selectedPriceRange,
        );
        _isFiltering = false;
      });
    }
  }

  // ── STRATEGY 3: Future + async/await ───────────────────────────────────────

  Future<void> _logHomeInteraction(
    String action, {
    Map<String, Object>? additionalParameters,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    await AnalyticsService.instance.logSectionInteraction(
      section: AppSection.home,
      action: action,
      userId: userId,
      additionalParameters: additionalParameters,
    );
  }

  Future<void> _loadTrendingRestaurants({
    List<Restaurant>? sourceRestaurants,
  }) async {
    try {
      final trending = await TrendingRestaurantsService.instance
          .getTrendingRestaurants(topN: 5, sourceRestaurants: sourceRestaurants);
      if (!mounted) return;
      setState(() {
        _trendingRestaurants = trending;
        _isTrendingLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _trendingRestaurants = [];
        _isTrendingLoading = false;
      });
    }
  }

  void _initCas() {
    _updateCasContext();
    _casTimer = Timer.periodic(const Duration(minutes: 1), (_) => _updateCasContext());
  }

  void _updateCasContext() {
    final mood = CasService.instance.getDiningMood();
    if (!mounted) return;
    var shouldRefilter = false;
    setState(() {
      if (mood.autoFilterOpen && !_casAutoOpenEnabled) {
        _casAutoOpenEnabled = true;
        _onlyOpen = true;
        shouldRefilter = true;
      } else if (!mood.autoFilterOpen && _casAutoOpenEnabled) {
        _casAutoOpenEnabled = false;
        _onlyOpen = false;
        shouldRefilter = true;
      }
    });
    if (shouldRefilter) {
      PreferencesService.instance.saveOnlyOpen(_onlyOpen);
      _applyFiltersAsync(); // Isolate
    }
  }

  Future<void> _loadPopularFilters() async {
    final categories = await PopularFiltersService.instance
        .getTopFilters(filterType: 'category');
    final prices = await PopularFiltersService.instance
        .getTopFilters(filterType: 'price_range');
    final chips = await PopularFiltersService.instance
        .getTopFilters(filterType: 'quick_chip');
    if (!mounted) return;
    setState(() {
      _topCategories = categories;
      _topPriceRanges = prices;
      _topQuickChips = chips.where((c) => !c.endsWith('_Off')).toList();
    });
  }

  void _applyFavoriteStateLocally(String restaurantId, bool isFavorite) {
    Restaurant upd(Restaurant r) =>
        r.id == restaurantId ? r.copyWith(isFavorite: isFavorite) : r;
    setState(() {
      _allRestaurants = _allRestaurants.map(upd).toList();
      _filteredRestaurants = _filteredRestaurants.map(upd).toList();
      _trendingRestaurants = _trendingRestaurants.map(upd).toList();
    });
  }

  Future<void> _toggleFavorite(Restaurant restaurant) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final willBeFavorite = !restaurant.isFavorite;
    _applyFavoriteStateLocally(restaurant.id, willBeFavorite);
    try {
      await _repository.toggleFavorite(restaurant.id);
    } catch (error) {
      _applyFavoriteStateLocally(restaurant.id, !willBeFavorite);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update favorite: $error')),
      );
      return;
    }

    if (_isOffline && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Favorite change saved offline and will sync later.'),
        ),
      );
    }

    if (userId != null) {
      await _logHomeInteraction(
        willBeFavorite ? 'favorite_added' : 'favorite_removed',
        additionalParameters: {'restaurant_id': restaurant.id},
      );
      if (willBeFavorite) {
        await AnalyticsService.instance.logRestaurantFavorited(
          restaurantId: restaurant.id,
          restaurantName: restaurant.name,
          userId: userId,
          favoriteSource: 'home_screen',
        );
        await TrendingRestaurantsService.instance.recordRestaurantFavorited(
          restaurantId: restaurant.id,
          restaurantName: restaurant.name,
        );
      } else {
        await AnalyticsService.instance.logRestaurantUnfavorited(
          restaurantId: restaurant.id,
          userId: userId,
        );
      }
    }
    // Stream will push an updated snapshot automatically.
  }

  Future<void> _logFilter({
    required String filterType,
    required String filterValue,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    await AnalyticsService.instance.logFilterUsed(
      filterType: '$filterType:$filterValue',
      userId: userId,
    );
    await _logHomeInteraction(
      'filter_used',
      additionalParameters: {
        'filter_type': filterType,
        'filter_value': filterValue,
      },
    );
    await PopularFiltersService.instance.incrementFilter(
      filterType: filterType,
      filterValue: filterValue,
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  Widget _buildHomeContent() {
    if (_isInitialRestaurantsLoading && _allRestaurants.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_restaurantLoadError != null && _allRestaurants.isEmpty) {
      return Center(
        child: Text('Error loading restaurants: $_restaurantLoadError'),
      );
    }

    if (_filteredRestaurants.isEmpty && _allRestaurants.isEmpty) {
      return const Center(child: Text('No restaurants available'));
    }

    final headerWidgets = _buildHeaderWidgets();
    final itemCount = headerWidgets.length +
        (_filteredRestaurants.isEmpty ? 1 : _filteredRestaurants.length);

    return RefreshIndicator(
      onRefresh: () async => _applyFiltersAsync(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index < headerWidgets.length) {
            return headerWidgets[index];
          }

          if (_filteredRestaurants.isEmpty) {
            return const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(
                child: Text('No restaurants match the selected filters'),
              ),
            );
          }

          final restaurant = _filteredRestaurants[index - headerWidgets.length];
          return _buildRestaurantListItem(context, restaurant);
        },
      ),
    );
  }

  List<Widget> _buildHeaderWidgets() {
    return [
      CasDiningBanner(
        onCategoryTap: (category) async {
          _selectedCategory = category;
          _applyFiltersAsync();
          PreferencesService.instance.saveSelectedCategory(category);
          await _logFilter(filterType: 'category', filterValue: category);
        },
      ),
      ..._buildTrendingWidgets(),
      const Text(
        'Filters',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      ..._buildPopularFilterWidgets(),
      const SizedBox(height: 12),
      _buildCategoryFilters(),
      const SizedBox(height: 16),
      _buildPriceFilter(),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _buildTrendingWidgets() {
    if (_isTrendingLoading) {
      return const [
        SizedBox(height: 8),
        Center(child: CircularProgressIndicator()),
      ];
    }

    if (_trendingRestaurants.isEmpty) return const [];

    return [
      const SizedBox(height: 8),
      const Text(
        'Trending now on campus',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 340,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _trendingRestaurants.length,
          separatorBuilder: (context, index) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final restaurant = _trendingRestaurants[index];
            return SizedBox(
              width: 280,
              child: RepaintBoundary(
                child: RestaurantCard(
                  restaurant: restaurant,
                  compact: true,
                  showFavoriteIcon: true,
                  favoriteFilled: restaurant.isFavorite,
                  onFavoriteTap: () => _toggleFavorite(restaurant),
                  onTap: () async {
                    await _logHomeInteraction(
                      'open_trending_restaurant',
                      additionalParameters: {'restaurant_id': restaurant.id},
                    );
                    if (!context.mounted) return;
                    await Navigator.pushNamed(
                      context,
                      RestaurantDetailScreen.routeName,
                      arguments: restaurant.id,
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _buildPopularFilterWidgets() {
    if (_topCategories.isEmpty &&
        _topPriceRanges.isEmpty &&
        _topQuickChips.isEmpty) {
      return const [];
    }

    final chips = <Widget>[];
    for (final chip in _topQuickChips) {
      if (chips.length >= 3) break;
      chips.add(ActionChip(
        label: Text(chip),
        avatar: const Icon(
          Icons.local_fire_department,
          size: 14,
          color: Colors.deepOrange,
        ),
        onPressed: () async {
          if (chip == 'Open') {
            _onlyOpen = true;
            PreferencesService.instance.saveOnlyOpen(true);
          }
          if (chip == 'Top Rated') {
            _onlyTopRated = true;
            PreferencesService.instance.saveOnlyTopRated(true);
          }
          _applyFiltersAsync();
          await _logFilter(filterType: 'quick_chip', filterValue: chip);
        },
      ));
    }
    for (final category in _topCategories) {
      if (chips.length >= 3) break;
      chips.add(ActionChip(
        label: Text(category),
        avatar: const Icon(
          Icons.restaurant,
          size: 14,
          color: Colors.deepOrange,
        ),
        onPressed: () async {
          _selectedCategory = category;
          _applyFiltersAsync();
          PreferencesService.instance.saveSelectedCategory(category);
          await _logFilter(filterType: 'category', filterValue: category);
        },
      ));
    }
    for (final price in _topPriceRanges) {
      if (chips.length >= 3) break;
      chips.add(ActionChip(
        label: Text(price),
        avatar: const Icon(
          Icons.attach_money,
          size: 14,
          color: Colors.green,
        ),
        onPressed: () async {
          _selectedPriceRange = price;
          _applyFiltersAsync();
          PreferencesService.instance.saveSelectedPriceRange(price);
          await _logFilter(filterType: 'price_range', filterValue: price);
        },
      ));
    }

    return [
      const SizedBox(height: 10),
      const Text(
        'Most used',
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 4, children: chips),
      const Divider(height: 20),
    ];
  }

  Widget _buildCategoryFilters() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          CategoryChip(
            label: 'All',
            selected:
                !_onlyOpen && !_onlyTopRated && _selectedCategory == 'All',
            onTap: () async {
              _selectedCategory = 'All';
              _onlyOpen = false;
              _onlyTopRated = false;
              _applyFiltersAsync();
              PreferencesService.instance.saveSelectedCategory('All');
              PreferencesService.instance.saveOnlyOpen(false);
              PreferencesService.instance.saveOnlyTopRated(false);
              await _logFilter(filterType: 'quick_chip', filterValue: 'All');
            },
          ),
          CategoryChip(
            label: 'Open',
            selected: _onlyOpen,
            onTap: () async {
              _onlyOpen = !_onlyOpen;
              _applyFiltersAsync();
              PreferencesService.instance.saveOnlyOpen(_onlyOpen);
              await _logFilter(
                filterType: 'quick_chip',
                filterValue: _onlyOpen ? 'Open' : 'Open_Off',
              );
            },
          ),
          CategoryChip(
            label: 'Top Rated',
            selected: _onlyTopRated,
            onTap: () async {
              _onlyTopRated = !_onlyTopRated;
              _applyFiltersAsync();
              PreferencesService.instance.saveOnlyTopRated(_onlyTopRated);
              await _logFilter(
                filterType: 'quick_chip',
                filterValue: _onlyTopRated ? 'Top Rated' : 'Top Rated_Off',
              );
            },
          ),
          ..._categoryOptions.where((c) => c != 'All').map(
                (category) => CategoryChip(
                  label: category,
                  selected: _selectedCategory == category,
                  onTap: () async {
                    _selectedCategory =
                        _selectedCategory == category ? 'All' : category;
                    _applyFiltersAsync();
                    PreferencesService.instance
                        .saveSelectedCategory(_selectedCategory);
                    await _logFilter(
                      filterType: 'category',
                      filterValue: _selectedCategory,
                    );
                  },
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildPriceFilter() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedPriceRange,
      decoration: const InputDecoration(
        labelText: 'Price range',
        border: OutlineInputBorder(),
      ),
      items: _priceOptions
          .map((price) => DropdownMenuItem(value: price, child: Text(price)))
          .toList(),
      onChanged: (value) async {
        if (value == null) return;
        _selectedPriceRange = value;
        _applyFiltersAsync();
        PreferencesService.instance.saveSelectedPriceRange(value);
        await _logFilter(filterType: 'price_range', filterValue: value);
      },
    );
  }

  Widget _buildRestaurantListItem(
    BuildContext context,
    Restaurant restaurant,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: RepaintBoundary(
        child: RestaurantCard(
          key: ValueKey(restaurant.id),
          restaurant: restaurant,
          showFavoriteIcon: true,
          favoriteFilled: restaurant.isFavorite,
          onFavoriteTap: () => _toggleFavorite(restaurant),
          onTap: () async {
            await _logHomeInteraction(
              'open_restaurant_from_home',
              additionalParameters: {'restaurant_id': restaurant.id},
            );
            if (!context.mounted) return;
            await Navigator.pushNamed(
              context,
              RestaurantDetailScreen.routeName,
              arguments: restaurant.id,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurandes'),
        actions: [
          // Tiny spinner while the background Isolate is running
          if (_isFiltering)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          IconButton(
            onPressed: () async {
              await _logHomeInteraction('open_search_from_home');
              if (!context.mounted) return;
              await Navigator.pushNamed(context, SearchEmptyScreen.routeName);
            },
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'Recently viewed',
            onPressed: () async {
              await _logHomeInteraction('open_recently_viewed_from_home');
              if (!context.mounted) return;
              await Navigator.pushNamed(context, RecentlyViewedScreen.routeName);
            },
            icon: const Icon(Icons.history),
          ),
          IconButton(
            onPressed: () async {
              await _logHomeInteraction('open_profile_from_home');
              if (!context.mounted) return;
              await Navigator.pushNamed(context, ProfileScreen.routeName);
            },
            icon: const ConnectivityAwareProfileIcon(),
          ),
        ],
      ),
      bottomNavigationBar: const CustomBottomNavbar(currentIndex: 0),

      // OfflineBanner sits above the stream content and collapses when online.
      body: Column(
        children: [
          OfflineBanner(isOffline: _isOffline),
          Expanded(child: _buildHomeContent()),
        ],
      ),
    );
  }
}
