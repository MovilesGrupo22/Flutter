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
    String query = '',
    String selectedCategory = 'All',
    bool onlyOpen = false,
    bool onlyTopRated = false,
    String selectedPriceRange = 'All',
  }) {
    final normalizedQuery = query.trim().toLowerCase();

    return restaurants.where((restaurant) {
      final matchesQuery = normalizedQuery.isEmpty ||
          restaurant.name.toLowerCase().contains(normalizedQuery) ||
          restaurant.category.toLowerCase().contains(normalizedQuery) ||
          restaurant.address.toLowerCase().contains(normalizedQuery) ||
          restaurant.tags.any(
            (tag) => tag.toLowerCase().contains(normalizedQuery),
          );

      final matchesCategory = selectedCategory == 'All' ||
          restaurant.category.toLowerCase() ==
              selectedCategory.toLowerCase();

      final matchesOpen = !onlyOpen || restaurant.isOpen;

      final matchesTopRated = !onlyTopRated || restaurant.rating >= 4.5;

      final matchesPrice = selectedPriceRange == 'All' ||
          restaurant.priceRange == selectedPriceRange;

      return matchesQuery &&
          matchesCategory &&
          matchesOpen &&
          matchesTopRated &&
          matchesPrice;
    }).toList();
  }

  List<String> extractCategories(List<Restaurant> restaurants) {
    final categories = restaurants
        .map((restaurant) => restaurant.category.trim())
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList();

    categories.sort();
    return ['All', ...categories];
  }

  List<String> extractPriceRanges(List<Restaurant> restaurants) {
    final prices = restaurants
        .map((restaurant) => restaurant.priceRange.trim())
        .where((price) => price.isNotEmpty)
        .toSet()
        .toList();

    prices.sort((a, b) => a.length.compareTo(b.length));
    return ['All', ...prices];
  }
}