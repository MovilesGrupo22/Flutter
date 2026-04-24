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
import 'package:foodandes_app/features/restaurant/restaurant_detail_screen.dart';
import 'package:foodandes_app/features/search/search_empty_screen.dart';
import 'package:foodandes_app/models/restaurant.dart';
import 'package:foodandes_app/shared/widgets/category_chip.dart';
import 'package:foodandes_app/shared/widgets/custom_bottom_navbar.dart';
import 'package:foodandes_app/shared/widgets/offline_banner.dart';
import 'package:foodandes_app/shared/widgets/restaurant_card.dart';

// =============================================================================
// HomeScreen — Multi-threading / Concurrency strategies (MS5)
//
// STRATEGY 1 – Stream (5 pts)
//   _restaurantsStream is a Stream<List<Restaurant>> from Firestore via
//   RestaurantRepository.restaurantsStream(). A StreamBuilder in build()
//   reacts to every new emission automatically — no manual refresh needed.
//
// STRATEGY 2 – Isolate via compute() (10 pts)
//   _applyFiltersAsync() sends FilterParams to RestaurantFilterIsolate.run(),
//   which calls Flutter's compute() to execute the filter + CAS-ranking loop
//   on a background Dart Isolate. The UI thread stays free during computation.
//
// STRATEGY 3 – Future + async/await (10 pts — already present)
//   _logHomeInteraction, _loadPopularFilters, _toggleFavorite etc. use async/
//   await. Future.wait parallelism is used in RestaurantRepository.
// =============================================================================

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

  // ── STRATEGY 2: Isolate — results written here after compute() returns ──────
  List<Restaurant> _filteredRestaurants = [];
  bool _isFiltering = false; // shows a tiny spinner in AppBar while isolate runs

  List<Restaurant> _trendingRestaurants = [];
  bool _isTrendingLoading = true;

  String _selectedCategory = 'All';
  bool _onlyOpen = false;
  bool _onlyTopRated = false;
  String _selectedPriceRange = 'All';

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

    // Manual subscription so we can react to new data (trigger Isolate filter,
    // refresh trending list, persist to SQLite) in addition to the StreamBuilder.
    _streamSubscription = _restaurantsStream.listen(
      (restaurants) {
        if (!mounted) return;
        setState(() => _allRestaurants = restaurants);
        _applyFiltersAsync();                                     // Isolate
        _loadTrendingRestaurants(sourceRestaurants: restaurants); // Future
        // Keep SQLite in sync so offline access always has fresh data.
        LocalDatabaseService.instance.insertRestaurants(restaurants);
      },
      onError: (Object e) {
        debugPrint('HomeScreen stream ERROR -> $e');
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
      setState(() => _allRestaurants = cached);
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

    setState(() => _isFiltering = true);

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

    // Runs on a background Isolate — main thread stays responsive
    final result = await RestaurantFilterIsolate.run(params);

    if (!mounted) return;
    setState(() {
      _filteredRestaurants = result;
      _isFiltering = false;
    });
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
    await _repository.toggleFavorite(restaurant.id);
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
              await Navigator.pushNamed(context, SearchEmptyScreen.routeName);
            },
            icon: const Icon(Icons.search),
          ),
          IconButton(
            onPressed: () async {
              await _logHomeInteraction('open_profile_from_home');
              await Navigator.pushNamed(context, ProfileScreen.routeName);
            },
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      bottomNavigationBar: const CustomBottomNavbar(currentIndex: 0),

      // OfflineBanner sits above the stream content and collapses when online.
      body: Column(
        children: [
          OfflineBanner(isOffline: _isOffline),
          Expanded(
            child: StreamBuilder<List<Restaurant>>(
              stream: _restaurantsStream,
              // =================================================================
              // STRATEGY 1 — StreamBuilder
              //
              // Replaces the old FutureBuilder. Key differences:
              //   FutureBuilder  → builds once, then done.
              //   StreamBuilder  → rebuilds on EVERY stream event (Firestore push).
              //
              // connectionState for a Stream:
              //   waiting → stream open, no event yet  → show spinner
              //   active  → at least one event received → show content
              //   done    → stream closed (unusual for Firestore .snapshots())
              // =================================================================
              builder: (context, snapshot) {
                // First load only
                if (snapshot.connectionState == ConnectionState.waiting &&
                    _allRestaurants.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError && _allRestaurants.isEmpty) {
                  return Center(
                    child: Text('Error loading restaurants: ${snapshot.error}'),
                  );
                }

                final categoryOptions = _repository.extractCategories(_allRestaurants);
                final priceOptions = _repository.extractPriceRanges(_allRestaurants);

                if (_filteredRestaurants.isEmpty && _allRestaurants.isEmpty) {
                  return const Center(child: Text('No restaurants available'));
                }

                return RefreshIndicator(
                  onRefresh: () async => _applyFiltersAsync(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      CasDiningBanner(
                        onCategoryTap: (category) async {
                          _selectedCategory = category;
                          _applyFiltersAsync(); // Isolate
                          PreferencesService.instance.saveSelectedCategory(category);
                          await _logFilter(filterType: 'category', filterValue: category);
                        },
                      ),

                      // ── Trending ────────────────────────────────────────────
                      if (_isTrendingLoading) ...[
                        const SizedBox(height: 8),
                        const Center(child: CircularProgressIndicator()),
                      ] else if (_trendingRestaurants.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          '🔥 Trending now on campus',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 340,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _trendingRestaurants.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final r = _trendingRestaurants[index];
                              return SizedBox(
                                width: 280,
                                child: RestaurantCard(
                                  restaurant: r,
                                  compact: true,
                                  showFavoriteIcon: true,
                                  favoriteFilled: r.isFavorite,
                                  onFavoriteTap: () => _toggleFavorite(r),
                                  onTap: () async {
                                    await _logHomeInteraction(
                                      'open_trending_restaurant',
                                      additionalParameters: {'restaurant_id': r.id},
                                    );
                                    await Navigator.pushNamed(
                                      context,
                                      RestaurantDetailScreen.routeName,
                                      arguments: r.id,
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Filters ─────────────────────────────────────────────
                      const Text(
                        'Filters',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),

                      if (_topCategories.isNotEmpty ||
                          _topPriceRanges.isNotEmpty ||
                          _topQuickChips.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Text(
                          '🔥 Most used',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: () {
                            final chips = <Widget>[];
                            for (final chip in _topQuickChips) {
                              if (chips.length >= 3) break;
                              chips.add(ActionChip(
                                label: Text(chip),
                                avatar: const Icon(Icons.local_fire_department,
                                    size: 14, color: Colors.deepOrange),
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
                            for (final cat in _topCategories) {
                              if (chips.length >= 3) break;
                              chips.add(ActionChip(
                                label: Text(cat),
                                avatar: const Icon(Icons.restaurant,
                                    size: 14, color: Colors.deepOrange),
                                onPressed: () async {
                                  _selectedCategory = cat;
                                  _applyFiltersAsync();
                                  PreferencesService.instance.saveSelectedCategory(cat);
                                  await _logFilter(filterType: 'category', filterValue: cat);
                                },
                              ));
                            }
                            for (final price in _topPriceRanges) {
                              if (chips.length >= 3) break;
                              chips.add(ActionChip(
                                label: Text(price),
                                avatar: const Icon(Icons.attach_money,
                                    size: 14, color: Colors.green),
                                onPressed: () async {
                                  _selectedPriceRange = price;
                                  _applyFiltersAsync();
                                  PreferencesService.instance.saveSelectedPriceRange(price);
                                  await _logFilter(filterType: 'price_range', filterValue: price);
                                },
                              ));
                            }
                            return chips;
                          }(),
                        ),
                        const Divider(height: 20),
                      ],

                      const SizedBox(height: 12),

                      SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            CategoryChip(
                              label: 'All',
                              selected: !_onlyOpen && !_onlyTopRated && _selectedCategory == 'All',
                              onTap: () async {
                                _selectedCategory = 'All';
                                _onlyOpen = false;
                                _onlyTopRated = false;
                                _applyFiltersAsync(); // Isolate
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
                                _applyFiltersAsync(); // Isolate
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
                                _applyFiltersAsync(); // Isolate
                                PreferencesService.instance.saveOnlyTopRated(_onlyTopRated);
                                await _logFilter(
                                  filterType: 'quick_chip',
                                  filterValue: _onlyTopRated ? 'Top Rated' : 'Top Rated_Off',
                                );
                              },
                            ),
                            ...categoryOptions.where((c) => c != 'All').map((cat) =>
                                CategoryChip(
                                  label: cat,
                                  selected: _selectedCategory == cat,
                                  onTap: () async {
                                    _selectedCategory =
                                        _selectedCategory == cat ? 'All' : cat;
                                    _applyFiltersAsync(); // Isolate
                                    PreferencesService.instance.saveSelectedCategory(_selectedCategory);
                                    await _logFilter(
                                        filterType: 'category',
                                        filterValue: _selectedCategory);
                                  },
                                )),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        initialValue: _selectedPriceRange,
                        decoration: const InputDecoration(
                          labelText: 'Price range',
                          border: OutlineInputBorder(),
                        ),
                        items: priceOptions
                            .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                            .toList(),
                        onChanged: (value) async {
                          if (value == null) return;
                          _selectedPriceRange = value;
                          _applyFiltersAsync(); // Isolate
                          PreferencesService.instance.saveSelectedPriceRange(value);
                          await _logFilter(filterType: 'price_range', filterValue: value);
                        },
                      ),

                      const SizedBox(height: 16),

                      // ── Restaurant list driven by Isolate results ───────────
                      if (_filteredRestaurants.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: Center(
                            child: Text('No restaurants match the selected filters'),
                          ),
                        )
                      else
                        ..._filteredRestaurants.map(
                          (r) => Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: RestaurantCard(
                              restaurant: r,
                              showFavoriteIcon: true,
                              favoriteFilled: r.isFavorite,
                              onFavoriteTap: () => _toggleFavorite(r),
                              onTap: () async {
                                await _logHomeInteraction(
                                  'open_restaurant_from_home',
                                  additionalParameters: {'restaurant_id': r.id},
                                );
                                if (!context.mounted) return;
                                await Navigator.pushNamed(
                                  context,
                                  RestaurantDetailScreen.routeName,
                                  arguments: r.id,
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
