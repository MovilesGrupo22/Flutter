import 'package:flutter/material.dart';
import 'package:foodandes_app/core/constants/app_colors.dart';
import 'package:foodandes_app/core/utils/map_launcher_helper.dart';
import 'package:foodandes_app/data/repositories/restaurant_repository.dart';
import 'package:foodandes_app/data/services/local_database_service.dart';
import 'package:foodandes_app/features/restaurant/compare_restaurants_screen.dart';
import 'package:foodandes_app/features/restaurant/reviews_screen.dart';
import 'package:foodandes_app/models/restaurant.dart';
import 'package:foodandes_app/shared/widgets/app_cached_image.dart';
import 'package:foodandes_app/shared/widgets/open_badge.dart';
import 'package:foodandes_app/data/services/analytics_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:foodandes_app/data/services/trending_restaurants_service.dart';
import 'package:foodandes_app/data/services/demand_analytics_service.dart';
import 'package:foodandes_app/shared/widgets/offline_protected_notice.dart';
import 'package:foodandes_app/shared/widgets/offline_unavailable_screen.dart';

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
  String? _lastLoggedRestaurantId;
  bool _servedFromLocal = false;

  Future<Restaurant?> _fetchRestaurant(String restaurantId) async {
    _servedFromLocal = false;

    // Try primary path: LRU cache → list cache → Firestore.
    final restaurant = await _repository.fetchRestaurantById(restaurantId);
    if (restaurant != null) return restaurant;

    // Fall back to SQLite when offline or Firestore is unreachable.
    final local =
        await LocalDatabaseService.instance.getRestaurantById(restaurantId);
    if (local != null) {
      _servedFromLocal = true;
      return local;
    }

    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final restaurantId = ModalRoute.of(context)?.settings.arguments as String?;

    if (restaurantId != null && restaurantId != _restaurantId) {
      _restaurantId = restaurantId;
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
          favoriteSource: 'detail_screen',
        );

        await TrendingRestaurantsService.instance.recordRestaurantFavorited(
          restaurantId: restaurant.id,
          restaurantName: restaurant.name,
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
            final errorText = snapshot.error.toString().toLowerCase();
            final looksOffline = errorText.contains('unavailable') ||
                errorText.contains('network') ||
                errorText.contains('offline') ||
                errorText.contains('failed-precondition');

            if (looksOffline) {
              return const OfflineUnavailableScreen(
                title: 'Restaurant detail unavailable offline',
                message:
                    'This restaurant is not stored locally yet. Please reconnect to load it for the first time.',
              );
            }

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

            TrendingRestaurantsService.instance.recordRestaurantView(
              restaurantId: restaurant.id,
              restaurantName: restaurant.name,
            );

            DemandAnalyticsService.instance.recordDemandEvent(
              restaurant: restaurant,
              eventType: 'restaurant_view',
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
              if (_servedFromLocal)
                const OfflineProtectedNotice(
                  message: 'Offline mode · showing last saved version',
                ),
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: AppCachedImage(
                      imageUrl: restaurant.imageURL,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: Container(
                        color: Colors.grey.shade300,
                        child: const Center(
                          child: Icon(Icons.image_not_supported, size: 50),
                        ),
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
                      '${restaurant.category} • ${restaurant.priceRange} • ⭐ ${restaurant.rating.toStringAsFixed(2)} (${restaurant.reviewCount})',
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

                                    await AnalyticsService.instance.logSectionInteraction(
                              section: AppSection.detail,
                              action: 'request_directions',
                              userId: userId,
                              additionalParameters: {
                                'restaurant_id': restaurant.id,
                              },
                            );

                            await AnalyticsService.instance.logDirectionsRequested(
                              restaurantId: restaurant.id,
                              restaurantName: restaurant.name,
                              userId: userId,
                            );

                            await DemandAnalyticsService.instance.recordDemandEvent(
                              restaurant: restaurant,
                              eventType: 'directions_requested',
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
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 360;

                        final reviewButton = OutlinedButton.icon(
                          onPressed: () async {
                            await AnalyticsService.instance.logSectionInteraction(
                              section: AppSection.detail,
                              action: 'open_reviews',
                              userId: FirebaseAuth.instance.currentUser?.uid,
                              additionalParameters: {
                                'restaurant_id': restaurant.id,
                              },
                            );
                            if (!context.mounted) return;
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
                        );

                        final compareButton = OutlinedButton.icon(
                          onPressed: () async {
                            await AnalyticsService.instance.logSectionInteraction(
                              section: AppSection.detail,
                              action: 'open_compare',
                              userId: FirebaseAuth.instance.currentUser?.uid,
                              additionalParameters: {
                                'restaurant_id': restaurant.id,
                              },
                            );
                            if (!context.mounted) return;
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
                        );

                        if (isCompact) {
                          return Column(
                            children: [
                              SizedBox(width: double.infinity, child: reviewButton),
                              const SizedBox(height: 12),
                              SizedBox(width: double.infinity, child: compareButton),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: reviewButton),
                            const SizedBox(width: 12),
                            Expanded(child: compareButton),
                          ],
                        );
                      },
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