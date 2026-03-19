import 'package:flutter/material.dart';
import 'package:foodandes_app/data/repositories/restaurant_repository.dart';
import 'package:foodandes_app/features/home/home_filtered_screen.dart';
import 'package:foodandes_app/features/profile/profile_screen.dart';
import 'package:foodandes_app/features/restaurant/restaurant_detail_screen.dart';
import 'package:foodandes_app/models/restaurant.dart';
import 'package:foodandes_app/shared/widgets/category_chip.dart';
import 'package:foodandes_app/shared/widgets/custom_bottom_navbar.dart';
import 'package:foodandes_app/shared/widgets/restaurant_card.dart';
import 'package:foodandes_app/features/search/search_empty_screen.dart';

class HomeScreen extends StatefulWidget {
  static const String routeName = '/home';

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final RestaurantRepository _repository = RestaurantRepository();

  late Future<List<Restaurant>> _restaurantsFuture;

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  void _loadRestaurants() {
    _restaurantsFuture = _repository.fetchRestaurants();
  }

  Future<void> _toggleFavorite(String restaurantId) async {
    await _repository.toggleFavorite(restaurantId);
    setState(() {
      _loadRestaurants();
    });
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

              setState(() {
                _loadRestaurants();
              });
            },
            icon: const Icon(Icons.search),
          ),
          IconButton(
            onPressed: () async {
              await Navigator.pushNamed(context, ProfileScreen.routeName);

              setState(() {
                _loadRestaurants();
              });
            },
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      bottomNavigationBar: const CustomBottomNavbar(currentIndex: 0),
      body: FutureBuilder<List<Restaurant>>(
        future: _restaurantsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading restaurants: ${snapshot.error}'),
            );
          }

          final restaurants = snapshot.data ?? [];

          if (restaurants.isEmpty) {
            return const Center(
              child: Text('No restaurants available'),
            );
          }

          return ListView(
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
                        Navigator.pushNamed(
                          context,
                          HomeFilteredScreen.routeName,
                        );
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
                    showFavoriteIcon: true,
                    favoriteFilled: restaurant.isFavorite,
                    onFavoriteTap: () => _toggleFavorite(restaurant.id),
                    onTap: () async {
                      await Navigator.pushNamed(
                        context,
                        RestaurantDetailScreen.routeName,
                        arguments: restaurant.id,
                      );

                      setState(() {
                        _loadRestaurants();
                      });
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}