import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foodandes_app/data/repositories/restaurant_repository.dart';
import 'package:foodandes_app/data/services/analytics_service.dart';
import 'package:foodandes_app/data/services/connectivity_service.dart';
import 'package:foodandes_app/features/restaurant/restaurant_detail_screen.dart';
import 'package:foodandes_app/models/restaurant.dart';
import 'package:foodandes_app/shared/widgets/category_chip.dart';
import 'package:foodandes_app/shared/widgets/custom_bottom_navbar.dart';
import 'package:foodandes_app/shared/widgets/offline_protected_notice.dart';
import 'package:foodandes_app/shared/widgets/restaurant_card.dart';

class HomeFilteredScreen extends StatefulWidget {
  static const String routeName = '/home-filtered';

  const HomeFilteredScreen({super.key});

  @override
  State<HomeFilteredScreen> createState() => _HomeFilteredScreenState();
}

class _HomeFilteredScreenState extends State<HomeFilteredScreen> {
  final RestaurantRepository _repository = RestaurantRepository();

  late Future<List<Restaurant>> _restaurantsFuture;
  bool _isOffline = false;
  StreamSubscription<bool>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    final online = await ConnectivityService.instance.isOnline;
    if (!mounted) return;
    setState(() => _isOffline = !online);

    _connectivitySubscription =
        ConnectivityService.instance.isOnlineStream.listen((isOnline) {
      if (!mounted) return;
      setState(() => _isOffline = !isOnline);
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _loadRestaurants() {
    _restaurantsFuture = _repository.fetchRestaurants();
  }

  Future<void> _toggleFavorite(Restaurant restaurant) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final willBeFavorite = !restaurant.isFavorite;

    try {
      await _repository.toggleFavorite(restaurant.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update favorite: $error')),
      );
      return;
    }

    if (_isOffline && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Favorite change saved offline and will sync later.'),
        ),
      );
    }

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

    setState(_loadRestaurants);
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
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_isOffline)
                  const OfflineProtectedNotice(
                    message: 'Offline mode · showing saved restaurant data',
                  ),
                const SizedBox(height: 48),
                const Center(
                  child: Text('No Americana restaurants available'),
                ),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_isOffline) ...[
                const OfflineProtectedNotice(
                  message: 'Offline mode · showing saved restaurant data',
                ),
                const SizedBox(height: 16),
              ],
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

                      setState(_loadRestaurants);
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
