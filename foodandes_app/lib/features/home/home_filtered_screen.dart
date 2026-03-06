import 'package:flutter/material.dart';
import 'package:foodandes_app/data/dummy/dummy_restaurants.dart';
import 'package:foodandes_app/features/restaurant/restaurant_detail_screen.dart';
import 'package:foodandes_app/shared/widgets/category_chip.dart';
import 'package:foodandes_app/shared/widgets/custom_bottom_navbar.dart';
import 'package:foodandes_app/shared/widgets/restaurant_card.dart';

class HomeFilteredScreen extends StatelessWidget {
  static const String routeName = '/home-filtered';

  const HomeFilteredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final restaurants = dummyRestaurants
        .where((restaurant) => restaurant.category == 'Americana')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurandes'),
      ),
      bottomNavigationBar: const CustomBottomNavbar(currentIndex: 0),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                CategoryChip(label: 'All'),
                CategoryChip(label: 'Open'),
                CategoryChip(label: 'TopRated'),
                CategoryChip(label: 'Americana', selected: true),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...restaurants.map(
            (restaurant) => Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: RestaurantCard(
                restaurant: restaurant,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    RestaurantDetailScreen.routeName,
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