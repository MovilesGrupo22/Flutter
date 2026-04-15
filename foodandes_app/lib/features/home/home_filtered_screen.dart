import 'package:flutter/material.dart';
import 'package:foodandes_app/data/repositories/restaurant_repository.dart';
import 'package:foodandes_app/features/restaurant/restaurant_detail_screen.dart';
import 'package:foodandes_app/models/restaurant.dart';
import 'package:foodandes_app/shared/widgets/category_chip.dart';
import 'package:foodandes_app/shared/widgets/custom_bottom_navbar.dart';
import 'package:foodandes_app/shared/widgets/restaurant_card.dart';
import 'package:foodandes_app/data/services/analytics_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeFilteredScreen extends StatefulWidget {
  static const String routeName = '/home-filtered';

  const HomeFilteredScreen({super.key});

  @override
  State<HomeFilteredScreen> createState() => _HomeFilteredScreenState();
}

class _HomeFilteredScreenState extends State<HomeFilteredScreen> {
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
          favoriteSource: 'home_filtered_screen',
        );
      } else {
        await AnalyticsService.instance.logRestaurantUnfavorited(
          restaurantId: restaurant.id,
          userId: userId,
        );
      }
    }

    setState(() {
      _loadRestaurants();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurandes'),
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

          final allRestaurants = snapshot.data ?? [];

          final restaurants = allRestaurants
              .where((restaurant) => restaurant.category == 'Americana')
              .toList();

          if (restaurants.isEmpty) {
            return const Center(
              child: Text('No Americana restaurants available'),
            );
          }

          return ListView(
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
                    showFavoriteIcon: true,
                    favoriteFilled: restaurant.isFavorite,
                    onFavoriteTap: () => _toggleFavorite(restaurant),
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