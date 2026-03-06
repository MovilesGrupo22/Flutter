import 'package:flutter/material.dart';
import 'package:foodandes_app/data/dummy/dummy_restaurants.dart';
import 'package:foodandes_app/features/favorites/favorites_empty_screen.dart';
import 'package:foodandes_app/features/restaurant/restaurant_detail_favorite_screen.dart';
import 'package:foodandes_app/shared/widgets/custom_bottom_navbar.dart';
import 'package:foodandes_app/shared/widgets/restaurant_card.dart';

class FavoritesScreen extends StatelessWidget {
  static const String routeName = '/favorites';

  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favoriteRestaurants =
        dummyRestaurants.where((restaurant) => restaurant.isFavorite).toList();

    if (favoriteRestaurants.isEmpty) {
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
            '${favoriteRestaurants.length} saved restaurants',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ...favoriteRestaurants.map(
            (restaurant) => Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: RestaurantCard(
                restaurant: restaurant,
                showFavoriteIcon: true,
                favoriteFilled: true,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    RestaurantDetailFavoriteScreen.routeName,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}