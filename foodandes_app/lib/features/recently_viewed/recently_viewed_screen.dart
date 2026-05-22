import 'dart:async';

import 'package:flutter/material.dart';
import 'package:foodandes_app/core/constants/app_colors.dart';
import 'package:foodandes_app/data/services/connectivity_service.dart';
import 'package:foodandes_app/data/services/local_database_service.dart';
import 'package:foodandes_app/features/restaurant/restaurant_detail_screen.dart';
import 'package:foodandes_app/models/restaurant.dart';
import 'package:foodandes_app/shared/widgets/empty_state_widget.dart';
import 'package:foodandes_app/shared/widgets/offline_protected_notice.dart';
import 'package:foodandes_app/shared/widgets/restaurant_card.dart';

class RecentlyViewedScreen extends StatefulWidget {
  static const String routeName = '/recently-viewed';

  const RecentlyViewedScreen({super.key});

  @override
  State<RecentlyViewedScreen> createState() => _RecentlyViewedScreenState();
}

class _RecentlyViewedScreenState extends State<RecentlyViewedScreen> {
  late Future<List<Restaurant>> _recentlyViewedFuture;
  bool _isOffline = false;
  StreamSubscription<bool>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _loadRecentlyViewed();
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

  void _loadRecentlyViewed() {
    _recentlyViewedFuture =
        LocalDatabaseService.instance.getRecentlyViewedRestaurants();
  }

  Future<void> _clearHistory() async {
    await LocalDatabaseService.instance.clearRecentlyViewed();
    if (!mounted) return;
    setState(_loadRecentlyViewed);
  }

  Future<void> _openRestaurant(Restaurant restaurant) async {
    await Navigator.pushNamed(
      context,
      RestaurantDetailScreen.routeName,
      arguments: restaurant.id,
    );

    if (!mounted) return;
    setState(_loadRecentlyViewed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recently Viewed'),
        actions: [
          IconButton(
            tooltip: 'Clear history',
            onPressed: _clearHistory,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: FutureBuilder<List<Restaurant>>(
        future: _recentlyViewedFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading recent restaurants: ${snapshot.error}'),
            );
          }

          final restaurants = snapshot.data ?? [];

          if (restaurants.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_isOffline)
                  const OfflineProtectedNotice(
                    message: 'Offline mode · recent restaurants are saved locally',
                  ),
                const SizedBox(height: 48),
                const EmptyStateWidget(
                  icon: Icons.history,
                  title: 'No recent restaurants',
                  subtitle: 'Restaurants you open will appear here.',
                ),
              ],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: restaurants.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isOffline)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: OfflineProtectedNotice(
                          message: 'Offline mode · recent restaurants are saved locally',
                        ),
                      ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Saved locally on this device',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                );
              }

              final restaurant = restaurants[index - 1];
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: RestaurantCard(
                  restaurant: restaurant,
                  onTap: () => _openRestaurant(restaurant),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
