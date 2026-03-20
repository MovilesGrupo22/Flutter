import 'package:flutter/material.dart';
import 'package:foodandes_app/data/repositories/restaurant_repository.dart';
import 'package:foodandes_app/features/profile/profile_screen.dart';
import 'package:foodandes_app/features/restaurant/restaurant_detail_screen.dart';
import 'package:foodandes_app/features/search/search_empty_screen.dart';
import 'package:foodandes_app/models/restaurant.dart';
import 'package:foodandes_app/shared/widgets/category_chip.dart';
import 'package:foodandes_app/shared/widgets/custom_bottom_navbar.dart';
import 'package:foodandes_app/shared/widgets/restaurant_card.dart';

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

  String _selectedCategory = 'All';
  bool _onlyOpen = false;
  bool _onlyTopRated = false;
  String _selectedPriceRange = 'All';

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  void _loadRestaurants() {
    _restaurantsFuture = _repository.fetchRestaurants();
  }

  void _applyFilters() {
    setState(() {
      _filteredRestaurants = _repository.filterRestaurants(
        restaurants: _allRestaurants,
        selectedCategory: _selectedCategory,
        onlyOpen: _onlyOpen,
        onlyTopRated: _onlyTopRated,
        selectedPriceRange: _selectedPriceRange,
      );
    });
  }

  Future<void> _refreshRestaurants() async {
    final restaurants = await _repository.fetchRestaurants();

    if (!mounted) return;

    setState(() {
      _allRestaurants = restaurants;
      _filteredRestaurants = _repository.filterRestaurants(
        restaurants: _allRestaurants,
        selectedCategory: _selectedCategory,
        onlyOpen: _onlyOpen,
        onlyTopRated: _onlyTopRated,
        selectedPriceRange: _selectedPriceRange,
      );
    });
  }

  Future<void> _toggleFavorite(String restaurantId) async {
    await _repository.toggleFavorite(restaurantId);
    await _refreshRestaurants();
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
            _allRestaurants = snapshot.data ?? [];
            _filteredRestaurants = _repository.filterRestaurants(
              restaurants: _allRestaurants,
              selectedCategory: _selectedCategory,
              onlyOpen: _onlyOpen,
              onlyTopRated: _onlyTopRated,
              selectedPriceRange: _selectedPriceRange,
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
                const Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
                        onTap: () {
                          _selectedCategory = 'All';
                          _onlyOpen = false;
                          _onlyTopRated = false;
                          _applyFilters();
                        },
                      ),
                      CategoryChip(
                        label: 'Open',
                        selected: _onlyOpen,
                        onTap: () {
                          _onlyOpen = !_onlyOpen;
                          _applyFilters();
                        },
                      ),
                      CategoryChip(
                        label: 'Top Rated',
                        selected: _onlyTopRated,
                        onTap: () {
                          _onlyTopRated = !_onlyTopRated;
                          _applyFilters();
                        },
                      ),
                      ...categoryOptions
                          .where((category) => category != 'All')
                          .map(
                            (category) => CategoryChip(
                              label: category,
                              selected: _selectedCategory == category,
                              onTap: () {
                                _selectedCategory =
                                    _selectedCategory == category
                                        ? 'All'
                                        : category;
                                _applyFilters();
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
                  onChanged: (value) {
                    if (value == null) return;
                    _selectedPriceRange = value;
                    _applyFilters();
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
                        onFavoriteTap: () => _toggleFavorite(restaurant.id),
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