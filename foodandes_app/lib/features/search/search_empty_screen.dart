import 'dart:async';

import 'package:flutter/material.dart';
import 'package:foodandes_app/data/repositories/restaurant_repository.dart';
import 'package:foodandes_app/features/restaurant/restaurant_detail_screen.dart';
import 'package:foodandes_app/models/restaurant.dart';
import 'package:foodandes_app/shared/widgets/custom_bottom_navbar.dart';
import 'package:foodandes_app/shared/widgets/custom_search_bar.dart';
import 'package:foodandes_app/shared/widgets/empty_state_widget.dart';
import 'package:foodandes_app/shared/widgets/restaurant_card.dart';
import 'package:foodandes_app/data/services/analytics_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SearchEmptyScreen extends StatefulWidget {
  static const String routeName = '/search-empty';

  const SearchEmptyScreen({super.key});

  @override
  State<SearchEmptyScreen> createState() => _SearchEmptyScreenState();
}

class _SearchEmptyScreenState extends State<SearchEmptyScreen> {
  final RestaurantRepository _repository = RestaurantRepository();
  final TextEditingController _searchController = TextEditingController();

  late Future<List<Restaurant>> _allRestaurantsFuture;

  List<Restaurant> _allRestaurants = [];
  List<Restaurant> _filteredRestaurants = [];
  bool _isLoadingRestaurants = true;
  Timer? _searchAnalyticsDebounce;
  String _lastTrackedQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRestaurants();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = FirebaseAuth.instance.currentUser?.uid;

      AnalyticsService.instance.logSectionView(
        section: AppSection.search,
        userId: userId,
      );
    });
  }

  Future<void> _logSearchInteraction(
    String action, {
    Map<String, Object>? additionalParameters,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    await AnalyticsService.instance.logSectionInteraction(
      section: AppSection.search,
      action: action,
      userId: userId,
      additionalParameters: additionalParameters,
    );
  }

  Future<void> _loadRestaurants() async {
    setState(() {
      _isLoadingRestaurants = true;
    });

    _allRestaurantsFuture = _repository.fetchRestaurants();

    final restaurants = await _allRestaurantsFuture;

    if (!mounted) return;

    setState(() {
      _allRestaurants = restaurants;
      _filteredRestaurants = [];
      _isLoadingRestaurants = false;
    });
  }

  void _onSearchChanged(String value) {
    final trimmedValue = value.trim();
    final results = _repository.filterRestaurants(
      restaurants: _allRestaurants,
      query: value,
    );

    setState(() {
      _filteredRestaurants = results;
    });

    _searchAnalyticsDebounce?.cancel();

    if (trimmedValue.isEmpty) {
      _lastTrackedQuery = '';
      return;
    }

    _searchAnalyticsDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted || trimmedValue == _lastTrackedQuery) return;

      _lastTrackedQuery = trimmedValue;
      final userId = FirebaseAuth.instance.currentUser?.uid;

      AnalyticsService.instance.logSearch(
        query: trimmedValue,
        resultsCount: results.length,
        userId: userId,
      );

      _logSearchInteraction(
        'search_executed',
        additionalParameters: {
          'results_count': results.length,
        },
      );
    });
  }

  Future<void> _toggleFavorite(Restaurant restaurant) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final willBeFavorite = !restaurant.isFavorite;

    await _repository.toggleFavorite(restaurant.id);

    await _logSearchInteraction(
      willBeFavorite ? 'favorite_added' : 'favorite_removed',
      additionalParameters: {
        'restaurant_id': restaurant.id,
      },
    );

    if (userId != null) {
      if (willBeFavorite) {
        await AnalyticsService.instance.logRestaurantFavorited(
          restaurantId: restaurant.id,
          restaurantName: restaurant.name,
          userId: userId,
          favoriteSource: 'search_screen',
        );
      } else {
        await AnalyticsService.instance.logRestaurantUnfavorited(
          restaurantId: restaurant.id,
          userId: userId,
        );
      }
    }
    await _loadRestaurants();

    _onSearchChanged(_searchController.text);
  }

  @override
  void dispose() {
    _searchAnalyticsDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    final hasQuery = query.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
      bottomNavigationBar: const CustomBottomNavbar(currentIndex: 2),
      body: _isLoadingRestaurants
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CustomSearchBar(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: !hasQuery
                        ? const EmptyStateWidget(
                            icon: Icons.search,
                            title: 'Start typing to search',
                            subtitle:
                                'Find restaurants by name, category, tag, or address',
                          )
                        : _filteredRestaurants.isEmpty
                            ? const EmptyStateWidget(
                                icon: Icons.search_off,
                                title: 'No results found',
                                subtitle:
                                    'Try a different keyword or category',
                              )
                            : RefreshIndicator(
                                onRefresh: _loadRestaurants,
                                child: ListView.builder(
                                  itemCount: _filteredRestaurants.length,
                                  itemBuilder: (context, index) {
                                    final restaurant =
                                        _filteredRestaurants[index];

                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 18),
                                      child: RestaurantCard(
                                        restaurant: restaurant,
                                        showFavoriteIcon: true,
                                        favoriteFilled:
                                            restaurant.isFavorite,
                                        onFavoriteTap: () =>
                                            _toggleFavorite(restaurant),
                                        onTap: () async {
                                          await _logSearchInteraction(
                                            'open_search_result',
                                            additionalParameters: {
                                              'restaurant_id': restaurant.id,
                                            },
                                          );
                                          await Navigator.pushNamed(
                                            context,
                                            RestaurantDetailScreen.routeName,
                                            arguments: restaurant.id,
                                          );

                                          await _loadRestaurants();
                                          _onSearchChanged(
                                            _searchController.text,
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                  ),
                ],
              ),
            ),
    );
  }
}
