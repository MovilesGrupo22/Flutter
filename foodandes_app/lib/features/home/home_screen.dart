import 'package:flutter/material.dart';
import 'package:foodandes_app/data/repositories/restaurant_repository.dart';
import 'package:foodandes_app/features/profile/profile_screen.dart';
import 'package:foodandes_app/features/restaurant/restaurant_detail_screen.dart';
import 'package:foodandes_app/features/search/search_empty_screen.dart';
import 'package:foodandes_app/models/restaurant.dart';
import 'package:foodandes_app/shared/widgets/category_chip.dart';
import 'package:foodandes_app/shared/widgets/custom_bottom_navbar.dart';
import 'package:foodandes_app/shared/widgets/restaurant_card.dart';
import 'package:foodandes_app/data/services/analytics_service.dart';
import 'package:foodandes_app/data/services/popular_filters_service.dart';
import 'package:foodandes_app/data/services/cas_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:foodandes_app/data/services/trending_restaurants_service.dart';
import 'package:foodandes_app/features/home/widgets/cas_dining_banner.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  static const String routeName = '/home';

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final RestaurantRepository _repository = RestaurantRepository();

  late Future<List<Restaurant>> _restaurantsFuture;

  List<Restaurant> _allRestaurants = [];
  List<Restaurant> _filteredRestaurants = [];

  List<Restaurant> _trendingRestaurants = [];
  bool _isTrendingLoading = true;

  String _selectedCategory = 'All';
  bool _onlyOpen = false;
  bool _onlyTopRated = false;
  String _selectedPriceRange = 'All';

  // --- NUEVO: filtros populares ---
  List<String> _topCategories = [];
  List<String> _topPriceRanges = [];
  List<String> _topQuickChips = [];

  // --- CAS: contexto por hora del dispositivo ---
  String _casContextMessage = '';
  bool _casAutoOpenEnabled = false;
  Timer? _casTimer;

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
    _loadPopularFilters(); // NUEVO
    _loadTrendingRestaurants(); // NUEVO
    _initCas();           // CAS

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = FirebaseAuth.instance.currentUser?.uid;

      AnalyticsService.instance.logSectionView(
        section: AppSection.home,
        userId: userId,
      );

      AnalyticsService.instance.logFlutterSmokeTest();
    });
  }

  Future<void> _loadTrendingRestaurants() async {
    try {
      final trending = await TrendingRestaurantsService.instance
          .getTrendingRestaurants(topN: 5);

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

  // --- CAS: inicializa el contexto por hora y actualiza cada minuto ---
  void _initCas() {
    _updateCasContext();
    // Refresh every minute so the banner and filter stay in sync with the clock
    _casTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _updateCasContext();
    });
  }

  void _updateCasContext() {
    final mood = CasService.instance.getDiningMood();
    final message = '${mood.emoji} ${mood.title} — ${mood.subtitle}';

    if (!mounted) return;

    var shouldRefilter = false;

    setState(() {
      _casContextMessage = message;
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
      _applyFilters();
    }
  }

  @override
  void dispose() {
    _casTimer?.cancel();
    super.dispose();
  }

  void _loadRestaurants() {
    _restaurantsFuture = _repository.fetchRestaurants();
  }

  // --- NUEVO: carga los filtros más usados desde Firestore ---
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

  void _applyFilters() {
    final mood = CasService.instance.getDiningMood();

    setState(() {
      final filtered = _repository.filterRestaurants(
        restaurants: _allRestaurants,
        selectedCategory: _selectedCategory,
        onlyOpen: _onlyOpen,
        onlyTopRated: _onlyTopRated,
        selectedPriceRange: _selectedPriceRange,
      );

      _filteredRestaurants = CasService.instance.rankByMoodRelevance(
        filtered,
        mood: mood,
      );
    });
  }

  Future<void> _refreshRestaurants() async {
    final restaurants = await _repository.fetchRestaurants();

    if (!mounted) return;

    final mood = CasService.instance.getDiningMood();

    setState(() {
      _allRestaurants = restaurants;
      final filtered = _repository.filterRestaurants(
        restaurants: _allRestaurants,
        selectedCategory: _selectedCategory,
        onlyOpen: _onlyOpen,
        onlyTopRated: _onlyTopRated,
        selectedPriceRange: _selectedPriceRange,
      );
      _filteredRestaurants = CasService.instance.rankByMoodRelevance(
        filtered,
        mood: mood,
      );
    });

    await _loadTrendingRestaurants();
  }

  Future<void> _toggleFavorite(Restaurant restaurant) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final willBeFavorite = !restaurant.isFavorite;

    await _repository.toggleFavorite(restaurant.id);

    if (userId != null) {
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

    await _refreshRestaurants();
  }

  // --- MODIFICADO: ahora también incrementa el contador en Firestore ---
  Future<void> _logFilter({
    required String filterType,
    required String filterValue,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    // Analytics (ya existía)
    await AnalyticsService.instance.logFilterUsed(
      filterType: '$filterType:$filterValue',
      userId: userId,
    );

    // Contador en Firestore (NUEVO)
    await PopularFiltersService.instance.incrementFilter(
      filterType: filterType,
      filterValue: filterValue,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurandes'),
        actions: [
          IconButton(
            onPressed: () async {
              await Navigator.pushNamed(context, SearchEmptyScreen.routeName);
              await _refreshRestaurants();
            },
            icon: const Icon(Icons.search),
          ),
          IconButton(
            onPressed: () async {
              await Navigator.pushNamed(context, ProfileScreen.routeName);
              await _refreshRestaurants();
            },
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      bottomNavigationBar: const CustomBottomNavbar(currentIndex: 0),
      body: FutureBuilder<List<Restaurant>>(
        future: _restaurantsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _allRestaurants.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError && _allRestaurants.isEmpty) {
            return Center(
              child: Text('Error loading restaurants: ${snapshot.error}'),
            );
          }

          if (_allRestaurants.isEmpty && snapshot.hasData) {
            final mood = CasService.instance.getDiningMood();
            _allRestaurants = snapshot.data ?? [];
            final filtered = _repository.filterRestaurants(
              restaurants: _allRestaurants,
              selectedCategory: _selectedCategory,
              onlyOpen: _onlyOpen,
              onlyTopRated: _onlyTopRated,
              selectedPriceRange: _selectedPriceRange,
            );
            _filteredRestaurants = CasService.instance.rankByMoodRelevance(
              filtered,
              mood: mood,
            );
          }

          final categoryOptions =
              _repository.extractCategories(_allRestaurants);
          final priceOptions =
              _repository.extractPriceRanges(_allRestaurants);

          if (_filteredRestaurants.isEmpty && _allRestaurants.isEmpty) {
            return const Center(
              child: Text('No restaurants available'),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshRestaurants,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                CasDiningBanner(
                  onCategoryTap: (category) async {
                    _selectedCategory = category;
                    _applyFilters();
                    await _logFilter(
                      filterType: 'category',
                      filterValue: category,
                    );
                  },
                ),
                if (_isTrendingLoading) ...[
                  const SizedBox(height: 8),
                  const Center(child: CircularProgressIndicator()),
                ] else if (_trendingRestaurants.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '🔥 Trending now on campus',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 300,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _trendingRestaurants.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final restaurant = _trendingRestaurants[index];

                        return SizedBox(
                          width: 280,
                          child: RestaurantCard(
                            restaurant: restaurant,
                            showFavoriteIcon: true,
                            favoriteFilled: restaurant.isFavorite,
                            onFavoriteTap: () => _toggleFavorite(restaurant),
                            onTap: () async {
                              await Navigator.pushNamed(
                                context,
                                RestaurantDetailScreen.routeName,
                                arguments: restaurant.id,
                              );

                              await _refreshRestaurants();
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                // --- NUEVO: sección de filtros más usados ---
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
                    children: [
                      // Quick chips populares (Open, Top Rated)
                      ..._topQuickChips.map((chip) => ActionChip(
                            label: Text(chip),
                            avatar: const Icon(
                              Icons.local_fire_department,
                              size: 14,
                              color: Colors.deepOrange,
                            ),
                            onPressed: () async {
                              if (chip == 'Open') {
                                _onlyOpen = true;
                              } else if (chip == 'Top Rated') {
                                _onlyTopRated = true;
                              }
                              _applyFilters();
                              await _logFilter(
                                filterType: 'quick_chip',
                                filterValue: chip,
                              );
                            },
                          )),
                      // Categorías populares
                      ..._topCategories.map((cat) => ActionChip(
                            label: Text(cat),
                            avatar: const Icon(
                              Icons.restaurant,
                              size: 14,
                              color: Colors.deepOrange,
                            ),
                            onPressed: () async {
                              _selectedCategory = cat;
                              _applyFilters();
                              await _logFilter(
                                filterType: 'category',
                                filterValue: cat,
                              );
                            },
                          )),
                      // Rangos de precio populares
                      ..._topPriceRanges.map((price) => ActionChip(
                            label: Text(price),
                            avatar: const Icon(
                              Icons.attach_money,
                              size: 14,
                              color: Colors.green,
                            ),
                            onPressed: () async {
                              _selectedPriceRange = price;
                              _applyFilters();
                              await _logFilter(
                                filterType: 'price_range',
                                filterValue: price,
                              );
                            },
                          )),
                    ],
                  ),
                  const Divider(height: 20),
                ],
                // --- FIN sección filtros más usados ---

                const SizedBox(height: 12),

                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      CategoryChip(
                        label: 'All',
                        selected: !_onlyOpen &&
                            !_onlyTopRated &&
                            _selectedCategory == 'All',
                        onTap: () async {
                          _selectedCategory = 'All';
                          _onlyOpen = false;
                          _onlyTopRated = false;
                          _applyFilters();

                          await _logFilter(
                            filterType: 'quick_chip',
                            filterValue: 'All',
                          );
                        },
                      ),
                      CategoryChip(
                        label: 'Open',
                        selected: _onlyOpen,
                        onTap: () async {
                          _onlyOpen = !_onlyOpen;
                          _applyFilters();
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
                          _applyFilters();
                          await _logFilter(
                            filterType: 'quick_chip',
                            filterValue:
                                _onlyTopRated ? 'Top Rated' : 'Top Rated_Off',
                          );
                        },
                      ),
                      ...categoryOptions
                          .where((category) => category != 'All')
                          .map(
                            (category) => CategoryChip(
                              label: category,
                              selected: _selectedCategory == category,
                              onTap: () async {
                                _selectedCategory =
                                    _selectedCategory == category
                                        ? 'All'
                                        : category;
                                _applyFilters();
                                await _logFilter(
                                  filterType: 'category',
                                  filterValue: _selectedCategory,
                                );
                              },
                            ),
                          ),
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
                  items: priceOptions.map((price) {
                    return DropdownMenuItem<String>(
                      value: price,
                      child: Text(price),
                    );
                  }).toList(),
                  onChanged: (value) async {
                    if (value == null) return;
                    _selectedPriceRange = value;
                    _applyFilters();

                    await _logFilter(
                      filterType: 'price_range',
                      filterValue: value,
                    );
                  },
                ),

                const SizedBox(height: 16),

                if (_filteredRestaurants.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text('No restaurants match the selected filters'),
                    ),
                  )
                else
                  ..._filteredRestaurants.map(
                    (restaurant) => Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: RestaurantCard(
                        restaurant: restaurant,
                        showFavoriteIcon: true,
                        favoriteFilled: restaurant.isFavorite,
                        onFavoriteTap: () => _toggleFavorite(restaurant),
                        onTap: () async {
                          await Navigator.pushNamed(
                            context,
                            RestaurantDetailScreen.routeName,
                            arguments: restaurant.id,
                          );

                          await _refreshRestaurants();
                        },
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}