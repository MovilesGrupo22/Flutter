import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:foodandes_app/data/repositories/restaurant_repository.dart';
import 'package:foodandes_app/features/restaurant/restaurant_detail_screen.dart';
import 'package:foodandes_app/models/restaurant.dart';
import 'package:foodandes_app/shared/widgets/custom_bottom_navbar.dart';

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
  List<Restaurant> _restaurants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  Future<void> _loadRestaurants() async {
    try {
      final restaurants = await _repository.fetchRestaurants();

      if (!mounted) return;

      setState(() {
        _restaurants = restaurants;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error loading map restaurants')),
      );
    }
  }

  Set<Marker> _buildMarkers() {
    return _restaurants.map((restaurant) {
      return Marker(
        markerId: MarkerId(restaurant.id),
        position: LatLng(restaurant.latitude, restaurant.longitude),
        infoWindow: InfoWindow(
          title: restaurant.name,
          snippet: '${restaurant.category} • ${restaurant.priceRange}',
          onTap: () async {
            await Navigator.pushNamed(
              context,
              RestaurantDetailScreen.routeName,
              arguments: restaurant.id,
            );

            await _loadRestaurants();
          },
        ),
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
      ),
      bottomNavigationBar: const CustomBottomNavbar(currentIndex: 1),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _initialPosition,
                zoom: 16,
              ),
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              markers: _buildMarkers(),
              onMapCreated: (controller) {
                _mapController = controller;
              },
            ),
    );
  }
}