import 'package:flutter/material.dart';
import 'package:foodandes_app/core/constants/app_colors.dart';
import 'package:foodandes_app/core/utils/map_launcher_helper.dart';
import 'package:foodandes_app/data/repositories/restaurant_repository.dart';
import 'package:foodandes_app/features/restaurant/compare_restaurants_screen.dart';
import 'package:foodandes_app/features/restaurant/reviews_screen.dart';
import 'package:foodandes_app/models/restaurant.dart';
import 'package:foodandes_app/shared/widgets/open_badge.dart';
import 'package:foodandes_app/data/services/analytics_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RestaurantDetailScreen extends StatefulWidget {
  static const String routeName = '/restaurant-detail';

  const RestaurantDetailScreen({super.key});

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  final RestaurantRepository _repository = RestaurantRepository();

  String? _restaurantId;
  Future<Restaurant?>? _restaurantFuture;
  bool _hasLoggedRestaurantView = false;
  String? _lastLoggedRestaurantId;

  Future<Restaurant?> _fetchRestaurant(String restaurantId) async {
    return _repository.fetchRestaurantById(restaurantId);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final restaurantId = ModalRoute.of(context)?.settings.arguments as String?;

  if (restaurantId != null && restaurantId != _restaurantId) {
    _restaurantId = restaurantId;
    _hasLoggedRestaurantView = false;
    _loadRestaurant();
}
  }

  void _loadRestaurant() {
    if (_restaurantId != null) {
      _restaurantFuture = _fetchRestaurant(_restaurantId!);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_restaurantId == null) return;

    final restaurant = await _repository.fetchRestaurantById(_restaurantId!);
    if (restaurant == null) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    final willBeFavorite = !restaurant.isFavorite;

    await _repository.toggleFavorite(_restaurantId!);

    if (userId != null) {
      if (willBeFavorite) {
        await AnalyticsService.instance.logRestaurantFavorited(
          restaurantId: restaurant.id,
          restaurantName: restaurant.name,
          userId: userId,
        );
      } else {
        await AnalyticsService.instance.logRestaurantUnfavorited(
          restaurantId: restaurant.id,
          userId: userId,
        );
      }
    }

    setState(() {
      _loadRestaurant();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
      ),
      body: FutureBuilder<Restaurant?>(
        future: _restaurantFuture,
        builder: (context, snapshot) {
          if (_restaurantFuture == null) {
            return const Center(
              child: Text('No restaurant selected'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading restaurant: ${snapshot.error}'),
            );
          }

          final restaurant = snapshot.data;

          if (restaurant != null && _lastLoggedRestaurantId != restaurant.id) {
            _lastLoggedRestaurantId = restaurant.id;
            final userId = FirebaseAuth.instance.currentUser?.uid;

            AnalyticsService.instance.logRestaurantView(
              restaurantId: restaurant.id,
              restaurantName: restaurant.name,
              userId: userId,
            );
          }
          
          if (restaurant == null) {
            return const Center(
              child: Text('Restaurant not found'),
            );
          }

          return ListView(
            children: [
              Stack(
                children: [
                  Image.network(
                    restaurant.imageURL,
                    height: 260,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 260,
                      color: Colors.grey.shade300,
                      child: const Center(
                        child: Icon(Icons.image_not_supported, size: 50),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: GestureDetector(
                      onTap: _toggleFavorite,
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white,
                        child: Icon(
                          restaurant.isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
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
                      '${restaurant.category} • ${restaurant.priceRange} • ⭐ ${restaurant.rating} (${restaurant.reviewCount})',
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OpenBadge(isOpen: restaurant.isOpen),
                    const SizedBox(height: 12),
                    if (restaurant.isFavorite)
                      const Text(
                        'Saved in favorites',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 18),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      restaurant.description,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 18),
                    if (restaurant.tags.isNotEmpty) ...[
                      const Divider(),
                      const SizedBox(height: 12),
                      const Text(
                        'Features',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: restaurant.tags.map((tag) {
                          return Chip(
                            label: Text(tag),
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: AppColors.border),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 18),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text(
                      'Contact Information',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            restaurant.address,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.phone, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            restaurant.phone,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.access_time, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            restaurant.openingHours,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          try {
                            final userId = FirebaseAuth.instance.currentUser?.uid;

                            await AnalyticsService.instance.logDirectionsRequested(
                              restaurantId: restaurant.id,
                              restaurantName: restaurant.name,
                              userId: userId,
                            );

                            await MapLauncherHelper.openDirections(
                              latitude: restaurant.latitude,
                              longitude: restaurant.longitude,
                            );
                          } catch (_) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Could not open Google Maps'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.near_me),
                        label: const Text('Get Directions'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await Navigator.pushNamed(
                                context,
                                ReviewsScreen.routeName,
                                arguments: {
                                  'restaurantId': restaurant.id,
                                  'restaurantName': restaurant.name,
                                },
                              );

                              if (!mounted) return;

                              setState(() {
                                _loadRestaurant();
                              });
                            },
                            icon: const Icon(
                              Icons.rate_review,
                              color: AppColors.primary,
                            ),
                            label: const Text(
                              'Reviews',
                              style: TextStyle(color: AppColors.primary),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await Navigator.pushNamed(
                                context,
                                CompareRestaurantsScreen.routeName,
                                arguments: restaurant.id,
                              );

                              if (!context.mounted) return;

                              setState(() {
                                _loadRestaurant();
                              });
                            },
                            icon: const Icon(
                              Icons.compare_arrows,
                              color: AppColors.primary,
                            ),
                            label: const Text(
                              'Compare',
                              style: TextStyle(color: AppColors.primary),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}