import 'package:flutter/material.dart';
import 'package:foodandes_app/data/dummy/dummy_restaurants.dart';
import 'package:foodandes_app/features/restaurant/restaurant_detail_screen.dart';
import 'package:foodandes_app/shared/widgets/custom_bottom_navbar.dart';
import 'package:foodandes_app/shared/widgets/custom_search_bar.dart';
import 'package:foodandes_app/shared/widgets/restaurant_card.dart';

class SearchActiveScreen extends StatelessWidget {
  static const String routeName = '/search-active';

  const SearchActiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final results = dummyRestaurants
        .where((restaurant) => restaurant.name.toLowerCase().contains('a'))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
      bottomNavigationBar: const CustomBottomNavbar(currentIndex: 2),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const CustomSearchBar(initialValue: 'a'),
          const SizedBox(height: 16),
          ...results.map(
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