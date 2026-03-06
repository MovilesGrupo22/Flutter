import 'package:flutter/material.dart';
import 'package:foodandes_app/data/dummy/dummy_restaurants.dart';
import 'package:foodandes_app/features/home/home_filtered_screen.dart';
import 'package:foodandes_app/features/profile/profile_screen.dart';
import 'package:foodandes_app/features/restaurant/restaurant_detail_screen.dart';
import 'package:foodandes_app/shared/widgets/category_chip.dart';
import 'package:foodandes_app/shared/widgets/custom_bottom_navbar.dart';
import 'package:foodandes_app/shared/widgets/restaurant_card.dart';

class HomeScreen extends StatelessWidget {
  static const String routeName = '/home';

  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final restaurants = dummyRestaurants;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurandes'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search),
          ),
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, ProfileScreen.routeName);
            },
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      bottomNavigationBar: const CustomBottomNavbar(currentIndex: 0),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                const CategoryChip(label: 'All', selected: true),
                const CategoryChip(label: 'Open'),
                const CategoryChip(label: 'TopRated'),
                CategoryChip(
                  label: 'Americana',
                  onTap: () {
                    Navigator.pushNamed(context, HomeFilteredScreen.routeName);
                  },
                ),
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