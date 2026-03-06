import 'package:flutter/material.dart';
import 'package:foodandes_app/core/utils/helpers.dart';
import 'package:foodandes_app/data/dummy/dummy_restaurants.dart';
import 'package:foodandes_app/shared/widgets/open_badge.dart';

class RestaurantDetailScreen extends StatelessWidget {
  static const String routeName = '/restaurant-detail';

  const RestaurantDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final restaurant = dummyRestaurants.first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant Detail'),
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
                    child: Text(
                      item,
                      style: const TextStyle(fontSize: 16),
                    ),
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