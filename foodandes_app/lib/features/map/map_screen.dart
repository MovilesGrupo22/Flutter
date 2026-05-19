import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:foodandes_app/core/constants/app_colors.dart';
import 'package:foodandes_app/data/repositories/restaurant_repository.dart';
import 'package:foodandes_app/features/restaurant/restaurant_detail_screen.dart';
import 'package:foodandes_app/models/restaurant.dart';
import 'package:foodandes_app/shared/widgets/custom_bottom_navbar.dart';
import 'package:foodandes_app/shared/widgets/open_badge.dart';
import 'package:foodandes_app/data/services/analytics_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<CompassEvent>? _headingSubscription;

  Restaurant? _selectedRestaurant;
  Position? _currentPosition;
  double _currentHeading = 0;

  bool _isLoading = true;
  bool _isRequestingLocation = false;
  bool _hasLocationPermission = false;
  String? _error;
  String? _locationStatusMessage;
  List<Restaurant> _restaurants = [];

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
    _initializeUserLocation();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = FirebaseAuth.instance.currentUser?.uid;

      AnalyticsService.instance.logSectionView(
        section: AppSection.map,
        userId: userId,
      );
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _headingSubscription?.cancel();
    super.dispose();
  }

  Future<void> _logMapInteraction(
    String action, {
    Map<String, Object>? additionalParameters,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    await AnalyticsService.instance.logSectionInteraction(
      section: AppSection.map,
      action: action,
      userId: userId,
      additionalParameters: additionalParameters,
    );
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

  Future<void> _initializeUserLocation() async {
    if (_isRequestingLocation) return;

    setState(() {
      _isRequestingLocation = true;
      _locationStatusMessage = null;
    });

    try {
      final hasPermission = await _ensureLocationPermission();
      if (!hasPermission) {
        if (!mounted) return;
        setState(() {
          _isRequestingLocation = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        _hasLocationPermission = true;
        _currentPosition = position;
        _isRequestingLocation = false;
      });

      await _moveCameraToUser(zoom: 17.5);
      await _logMapInteraction('user_location_enabled');
      _startLocationTracking();
      _startHeadingTracking();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isRequestingLocation = false;
        _locationStatusMessage =
            'We could not get your current location right now.';
      });
    }
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          _locationStatusMessage =
              'Turn on location services to show your position on the map.';
        });
      }
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      if (mounted) {
        setState(() {
          _locationStatusMessage =
              'Location permission is needed to show where you are.';
        });
      }
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _locationStatusMessage =
              'Location permission is permanently denied on this device.';
        });
      }
      return false;
    }

    return true;
  }

  void _startLocationTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen((position) {
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
      });
    });
  }

  void _startHeadingTracking() {
    _headingSubscription?.cancel();
    _headingSubscription = FlutterCompass.events?.listen((event) {
      final heading = event.heading;
      if (heading == null || !mounted) return;

      setState(() {
        _currentHeading = heading;
      });
    });
  }

  Future<void> _moveCameraToUser({double zoom = 17}) async {
    final position = _currentPosition;
    if (position == null) return;

    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: zoom,
        ),
      ),
    );
  }

  Future<void> _recenterOnUser() async {
    if (_currentPosition == null) {
      await _initializeUserLocation();
      return;
    }

    await _moveCameraToUser(zoom: 17.5);
    await _logMapInteraction('recenter_on_user');
  }

  String _headingLabel(double heading) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final normalized = (heading % 360 + 360) % 360;
    final index = ((normalized + 22.5) ~/ 45) % directions.length;
    return directions[index];
  }

  Set<Marker> _buildMarkers() {
    final markers = _restaurants.map((restaurant) {
      final isSelected = _selectedRestaurant?.id == restaurant.id;

      return Marker(
        markerId: MarkerId(restaurant.id),
        position: LatLng(restaurant.latitude, restaurant.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isSelected ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueRed,
        ),
        onTap: () async {
          setState(() {
            _selectedRestaurant = restaurant;
          });

          await _logMapInteraction(
            'marker_selected',
            additionalParameters: {
              'restaurant_id': restaurant.id,
            },
          );

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

    final position = _currentPosition;
    if (position != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: LatLng(position.latitude, position.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          anchor: const Offset(0.5, 0.5),
          flat: true,
          rotation: _currentHeading,
          zIndex: 3,
          infoWindow: InfoWindow(
            title: 'You are here',
            snippet: 'Facing ${_headingLabel(_currentHeading)}',
          ),
        ),
      );
    }

    return markers;
  }

  Set<Circle> _buildCircles() {
    final position = _currentPosition;
    if (position == null) return <Circle>{};

    return {
      Circle(
        circleId: const CircleId('user_accuracy'),
        center: LatLng(position.latitude, position.longitude),
        radius: 16,
        fillColor: AppColors.primary.withOpacity(0.18),
        strokeColor: AppColors.primary.withOpacity(0.45),
        strokeWidth: 2,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final selectedRestaurant = _selectedRestaurant;
    final showLocationBanner =
        _currentPosition != null || _locationStatusMessage != null;

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
                            myLocationEnabled: _hasLocationPermission,
                            myLocationButtonEnabled: false,
                            compassEnabled: true,
                            rotateGesturesEnabled: true,
                            mapToolbarEnabled: false,
                            markers: _buildMarkers(),
                            circles: _buildCircles(),
                            padding: EdgeInsets.only(
                              top: showLocationBanner ? 90 : 16,
                              bottom: selectedRestaurant != null ? 220 : 90,
                              right: 16,
                              left: 16,
                            ),
                            onMapCreated: (controller) {
                              _mapController = controller;
                              if (_currentPosition != null) {
                                unawaited(_moveCameraToUser(zoom: 17.5));
                              }
                            },
                          ),
                        ),
                        if (showLocationBanner)
                          Positioned(
                            top: 16,
                            left: 16,
                            right: 16,
                            child: _MapStatusBanner(
                              icon: _currentPosition != null
                                  ? Icons.navigation
                                  : Icons.location_off_outlined,
                              text: _currentPosition != null
                                  ? 'You are here • facing ${_headingLabel(_currentHeading)} (${_currentHeading.toStringAsFixed(0)}°)'
                                  : _locationStatusMessage!,
                            ),
                          ),
                        Positioned(
                          right: 16,
                          bottom: selectedRestaurant != null ? 316 : 110,
                          child: FloatingActionButton.small(
                            heroTag: 'recenter_map_button',
                            onPressed: _recenterOnUser,
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            child: _isRequestingLocation
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.my_location),
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
                                await _logMapInteraction(
                                  'open_restaurant_from_map',
                                  additionalParameters: {
                                    'restaurant_id': selectedRestaurant.id,
                                  },
                                );
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

class _MapStatusBanner extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MapStatusBanner({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 360;
            final imageSize = isCompact ? 72.0 : 90.0;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        restaurant.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
                isCompact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _MapCardImage(
                            restaurant: restaurant,
                            size: imageSize,
                          ),
                          const SizedBox(height: 12),
                          _MapCardDetails(restaurant: restaurant),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _MapCardImage(
                            restaurant: restaurant,
                            size: imageSize,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MapCardDetails(restaurant: restaurant),
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
            );
          },
        ),
      ),
    );
  }
}

class _MapCardImage extends StatelessWidget {
  final Restaurant restaurant;
  final double size;

  const _MapCardImage({
    required this.restaurant,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        restaurant.imageURL,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: Colors.grey.shade300,
          child: const Icon(Icons.image_not_supported),
        ),
      ),
    );
  }
}

class _MapCardDetails extends StatelessWidget {
  final Restaurant restaurant;

  const _MapCardDetails({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${restaurant.category} • ${restaurant.priceRange}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '⭐ ${restaurant.rating.toStringAsFixed(2)} • ${restaurant.reviewCount} reviews',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
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
    );
  }
}
