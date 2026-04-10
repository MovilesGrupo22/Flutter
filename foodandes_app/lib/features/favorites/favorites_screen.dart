import 'package:flutter/material.dart';
import 'package:foodandes_app/data/repositories/restaurant_repository.dart';
import 'package:foodandes_app/features/favorites/favorites_empty_screen.dart';
import 'package:foodandes_app/features/restaurant/restaurant_detail_screen.dart';
import 'package:foodandes_app/models/restaurant.dart';
import 'package:foodandes_app/shared/widgets/custom_bottom_navbar.dart';
import 'package:foodandes_app/shared/widgets/restaurant_card.dart';
import 'package:foodandes_app/data/services/analytics_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoritesScreen extends StatefulWidget {
  static const String routeName = '/favorites';

  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final RestaurantRepository _repository = RestaurantRepository();

  late Future<List<Restaurant>> _favoritesFuture;

  @override
  void initState() {
    super.initState();
    _loadFavorites();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = FirebaseAuth.instance.currentUser?.uid;

      AnalyticsService.instance.logSectionView(
        section: AppSection.favorites,
        userId: userId,
      );
    });
  }

  void _loadFavorites() {
    _favoritesFuture = _repository.fetchFavoriteRestaurants();
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
          favoriteSource: 'favorites_screen',
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

        if (favorites.isEmpty) {
          return const FavoritesEmptyScreen();
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('My Favorites'),
          ),
          bottomNavigationBar: const CustomBottomNavbar(currentIndex: 3),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
                      await Navigator.pushNamed(
                        context,
                        RestaurantDetailScreen.routeName,
                        arguments: restaurant.id,
                      );

                      setState(() {
                        _loadFavorites();
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}