import 'package:foodandes_app/data/services/restaurant_service.dart';
import 'package:foodandes_app/data/services/user_service.dart';
import 'package:foodandes_app/models/restaurant.dart';

class RestaurantRepository {
  final RestaurantService _restaurantService = RestaurantService();
  final UserService _userService = UserService();

  Future<List<Restaurant>> fetchRestaurants() async {
    final restaurants = await _restaurantService.getRestaurants();

    List<String> favoriteIds = [];
    try {
      favoriteIds = await _userService.getFavoriteRestaurantIds();
    } catch (_) {
      favoriteIds = [];
    }

    return restaurants.map((restaurant) {
      return restaurant.copyWith(
        isFavorite: favoriteIds.contains(restaurant.id),
      );
    }).toList();
  }

  Future<Restaurant?> fetchRestaurantById(String restaurantId) async {
    final restaurant = await _restaurantService.getRestaurantById(restaurantId);

    if (restaurant == null) return null;

    List<String> favoriteIds = [];
    try {
      favoriteIds = await _userService.getFavoriteRestaurantIds();
    } catch (_) {
      favoriteIds = [];
    }

    return restaurant.copyWith(
      isFavorite: favoriteIds.contains(restaurant.id),
    );
  }

  Future<void> toggleFavorite(String restaurantId) async {
    await _userService.toggleFavoriteRestaurant(restaurantId);
  }

  Future<List<Restaurant>> fetchFavoriteRestaurants() async {
    final restaurants = await _restaurantService.getRestaurants();
    final favoriteIds = await _userService.getFavoriteRestaurantIds();

    return restaurants
        .where((restaurant) => favoriteIds.contains(restaurant.id))
        .map((restaurant) => restaurant.copyWith(isFavorite: true))
        .toList();
  }

  List<Restaurant> filterRestaurants({
    required List<Restaurant> restaurants,
    required String query,
  }) {
    final normalizedQuery = query.trim().toLowerCase();

    if (normalizedQuery.isEmpty) return [];

    return restaurants.where((restaurant) {
      final name = restaurant.name.toLowerCase();
      final category = restaurant.category.toLowerCase();
      final address = restaurant.address.toLowerCase();
      final tags = restaurant.tags.map((tag) => tag.toLowerCase()).join(' ');

      return name.contains(normalizedQuery) ||
          category.contains(normalizedQuery) ||
          address.contains(normalizedQuery) ||
          tags.contains(normalizedQuery);
    }).toList();
  }
}