import 'package:flutter/material.dart';
import 'package:foodandes_app/core/constants/app_colors.dart';
import 'package:foodandes_app/core/utils/helpers.dart';
import 'package:foodandes_app/data/dummy/dummy_restaurants.dart';
import 'package:foodandes_app/shared/widgets/open_badge.dart';

class RestaurantDetailFavoriteScreen extends StatelessWidget {
  static const String routeName = '/restaurant-detail-favorite';

  const RestaurantDetailFavoriteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final restaurant = dummyRestaurants[1];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant Detail'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.favorite, color: AppColors.primary),
          ),
        ],
      ),
      body: ListView(
        children: [
          Image.network(
            restaurant.imageUrl,
            height: 260,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  restaurant.name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${restaurant.category} • ⭐ ${restaurant.rating} • ${formatPriceLevel(restaurant.priceLevel)}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                OpenBadge(isOpen: restaurant.isOpen),
                const SizedBox(height: 12),
                const Text(
                  'Saved in favorites',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  restaurant.description,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Menu',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                ...restaurant.menuItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(item, style: const TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}