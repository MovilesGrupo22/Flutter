import 'dart:async';

import 'package:flutter/material.dart';
import 'package:foodandes_app/data/repositories/restaurant_repository.dart';
import 'package:foodandes_app/data/services/connectivity_service.dart';
import 'package:foodandes_app/data/services/local_database_service.dart';
import 'package:foodandes_app/features/favorites/favorites_empty_screen.dart';
import 'package:foodandes_app/features/restaurant/restaurant_detail_screen.dart';
import 'package:foodandes_app/models/restaurant.dart';
import 'package:foodandes_app/shared/widgets/custom_bottom_navbar.dart';
import 'package:foodandes_app/shared/widgets/offline_protected_notice.dart';
import 'package:foodandes_app/shared/widgets/restaurant_card.dart';
import 'package:foodandes_app/data/services/analytics_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:foodandes_app/data/services/trending_restaurants_service.dart';

class FavoritesScreen extends StatefulWidget {
  static const String routeName = '/favorites';

  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final RestaurantRepository _repository = RestaurantRepository();

  late Future<List<Restaurant>> _favoritesFuture;
  bool _isOffline = false;
  StreamSubscription<bool>? _connectivitySubscription;

  Future<void> _logFavoritesInteraction(
    String action, {
    Map<String, Object>? additionalParameters,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    await AnalyticsService.instance.logSectionInteraction(
      section: AppSection.favorites,
      action: action,
      userId: userId,
      additionalParameters: additionalParameters,
    );
  }

  @override
  void initState() {
    super.initState();
    // Optimistic default: assume online until connectivity check completes.
    _favoritesFuture = _repository.fetchFavoriteRestaurants();
    _initConnectivity();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      AnalyticsService.instance.logSectionView(
        section: AppSection.favorites,
        userId: userId,
      );
    });
  }

  Future<void> _initConnectivity() async {
    final online = await ConnectivityService.instance.isOnline;
    if (!mounted) return;
    setState(() {
      _isOffline = !online;
      _loadFavorites();
    });

    _connectivitySubscription =
        ConnectivityService.instance.isOnlineStream.listen((isOnline) {
      if (!mounted) return;
      setState(() {
        _isOffline = !isOnline;
        _loadFavorites();
      });
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _loadFavorites() {
    _favoritesFuture = _isOffline
        ? _loadFavoritesFromLocal()
        : _repository.fetchFavoriteRestaurants();
  }

  Future<List<Restaurant>> _loadFavoritesFromLocal() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return [];

    final results = await Future.wait<dynamic>([
      LocalDatabaseService.instance.getRestaurants(),
      LocalDatabaseService.instance.getFavoriteIds(userId),
    ]);

    final allRestaurants = results[0] as List<Restaurant>;
    final favoriteIds = results[1] as List<String>;

    return allRestaurants
        .where((r) => favoriteIds.contains(r.id))
        .map((r) => r.copyWith(isFavorite: true))
        .toList();
  }

  Future<void> _toggleFavorite(Restaurant restaurant) async {
    if (_isOffline) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot change favorites while offline')),
      );
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    final willBeFavorite = !restaurant.isFavorite;

    await _repository.toggleFavorite(restaurant.id);

    await _logFavoritesInteraction(
      willBeFavorite ? 'favorite_added' : 'favorite_removed',
      additionalParameters: {'restaurant_id': restaurant.id},
    );

    if (userId != null) {
      if (willBeFavorite) {
        await AnalyticsService.instance.logRestaurantFavorited(
          restaurantId: restaurant.id,
          restaurantName: restaurant.name,
          userId: userId,
          favoriteSource: 'favorites_screen',
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

    setState(() {
      _loadFavorites();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Restaurant>>(
      future: _favoritesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('My Favorites')),
            bottomNavigationBar: const CustomBottomNavbar(currentIndex: 3),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('My Favorites')),
            bottomNavigationBar: const CustomBottomNavbar(currentIndex: 3),
            body: Center(
              child: Text('Error loading favorites: ${snapshot.error}'),
            ),
          );
        }

        final favorites = snapshot.data ?? [];

        if (favorites.isEmpty && !_isOffline) {
          return const FavoritesEmptyScreen();
        }

        return Scaffold(
          appBar: AppBar(title: const Text('My Favorites')),
          bottomNavigationBar: const CustomBottomNavbar(currentIndex: 3),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_isOffline)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: OfflineProtectedNotice(
                    message: 'Offline mode · showing saved favorites',
                  ),
                ),
              if (favorites.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Text(
                      'No saved favorites found locally',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                )
              else ...[
                Text(
                  '${favorites.length} saved restaurants',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                ...favorites.map(
                  (restaurant) => Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: RestaurantCard(
                      restaurant: restaurant,
                      showFavoriteIcon: true,
                      favoriteFilled: true,
                      onFavoriteTap: () => _toggleFavorite(restaurant),
                      onTap: () async {
                        await _logFavoritesInteraction(
                          'open_favorite_restaurant',
                          additionalParameters: {
                            'restaurant_id': restaurant.id,
                          },
                        );
                        if (!context.mounted) return;
                        await Navigator.pushNamed(
                          context,
                          RestaurantDetailScreen.routeName,
                          arguments: restaurant.id,
                        );

                        if (!mounted) return;
                        setState(() {
                          _loadFavorites();
                        });
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}