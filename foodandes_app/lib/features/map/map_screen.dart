import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:foodandes_app/core/constants/app_colors.dart';
import 'package:foodandes_app/data/repositories/restaurant_repository.dart';
import 'package:foodandes_app/features/restaurant/restaurant_detail_screen.dart';
import 'package:foodandes_app/models/restaurant.dart';
import 'package:foodandes_app/shared/widgets/custom_bottom_navbar.dart';
import 'package:foodandes_app/shared/widgets/open_badge.dart';
import 'package:foodandes_app/data/services/analytics_service.dart';

class MapScreen extends StatefulWidget {
  static const String routeName = '/map';

  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final RestaurantRepository _repository = RestaurantRepository();
  final LatLng _initialPosition = const LatLng(4.6026, -74.0652);

  GoogleMapController? _mapController;
  Restaurant? _selectedRestaurant;

  bool _isLoading = true;
  String? _error;
  List<Restaurant> _restaurants = [];

  @override
  void initState() {
    super.initState();
    _loadRestaurants();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AnalyticsService.instance.logSectionOpened('map');
    });
  }

  Future<void> _loadRestaurants() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final restaurants = await _repository.fetchRestaurants();

      if (!mounted) return;

      setState(() {
        _restaurants = restaurants.where(_hasValidCoordinates).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Error loading restaurants: $e';
        _isLoading = false;
      });
    }
  }

  bool _hasValidCoordinates(Restaurant restaurant) {
    final lat = restaurant.latitude;
    final lng = restaurant.longitude;

    return lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180 &&
        !(lat == 0.0 && lng == 0.0);
  }

  Set<Marker> _buildMarkers() {
    return _restaurants.map((restaurant) {
      final isSelected = _selectedRestaurant?.id == restaurant.id;

      return Marker(
        markerId: MarkerId(restaurant.id),
        position: LatLng(restaurant.latitude, restaurant.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isSelected
              ? BitmapDescriptor.hueAzure
              : BitmapDescriptor.hueRed,
        ),
        onTap: () async {
          setState(() {
            _selectedRestaurant = restaurant;
          });

          await _mapController?.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(restaurant.latitude, restaurant.longitude),
                zoom: 17,
              ),
            ),
          );
        },
        infoWindow: InfoWindow(
          title: restaurant.name,
          snippet: '${restaurant.category} • ${restaurant.priceRange}',
        ),
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final selectedRestaurant = _selectedRestaurant;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
      ),
      bottomNavigationBar: const CustomBottomNavbar(currentIndex: 1),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _restaurants.isEmpty
                  ? const Center(
                      child: Text('No restaurants available on the map'),
                    )
                  : Stack(
                      children: [
                        Positioned.fill(
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: _initialPosition,
                              zoom: 16,
                            ),
                            zoomControlsEnabled: false,
                            myLocationButtonEnabled: false,
                            mapToolbarEnabled: false,
                            markers: _buildMarkers(),
                            padding: EdgeInsets.only(
                              bottom: selectedRestaurant != null ? 220 : 90,
                            ),
                            onMapCreated: (controller) {
                              _mapController = controller;
                            },
                          ),
                        ),
                        if (selectedRestaurant != null)
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 94,
                            child: _MapRestaurantInfoCard(
                              restaurant: selectedRestaurant,
                              onClose: () {
                                setState(() {
                                  _selectedRestaurant = null;
                                });
                              },
                              onDetailsTap: () async {
                                await Navigator.pushNamed(
                                  context,
                                  RestaurantDetailScreen.routeName,
                                  arguments: selectedRestaurant.id,
                                );

                                if (!mounted) return;

                                await _loadRestaurants();
                              },
                            ),
                          ),
                      ],
                    ),
    );
  }
}

class _MapRestaurantInfoCard extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onClose;
  final VoidCallback onDetailsTap;

  const _MapRestaurantInfoCard({
    required this.restaurant,
    required this.onClose,
    required this.onDetailsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    restaurant.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    restaurant.imageURL,
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 90,
                      height: 90,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.image_not_supported),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${restaurant.category} • ${restaurant.priceRange}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '⭐ ${restaurant.rating.toStringAsFixed(1)} • ${restaurant.reviewCount} reviews',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OpenBadge(isOpen: restaurant.isOpen),
                      const SizedBox(height: 8),
                      Text(
                        restaurant.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onDetailsTap,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('View details'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}