import 'package:foodandes_app/data/services/restaurant_service.dart';
import 'package:foodandes_app/data/services/user_service.dart';
import 'package:foodandes_app/models/restaurant.dart';

// FIX #2 (app muy lenta):
// La versión anterior ejecutaba getRestaurants() y getFavoriteIds() en
// secuencia (dos round-trips Firestore). Ahora se lanzan en paralelo con
// Future.wait, reduciendo la latencia a la del más lento de los dos.

class RestaurantRepository {
  final RestaurantService _restaurantService = RestaurantService();
  final UserService _userService = UserService();

  Future<List<Restaurant>> fetchRestaurants() async {
    // Lanzar ambas lecturas en paralelo
    final results = await Future.wait([
      _restaurantService.getRestaurants(),
      _userService.getFavoriteRestaurantIds().catchError((_) => <String>[]),
    ]);

    final restaurants = results[0] as List<Restaurant>;
    final favoriteIds = results[1] as List<String>;

    return restaurants.map((r) {
      return r.copyWith(isFavorite: favoriteIds.contains(r.id));
    }).toList();
  }

  Future<Restaurant?> fetchRestaurantById(String restaurantId) async {
    // Lanzar ambas lecturas en paralelo
    final results = await Future.wait([
      _restaurantService.getRestaurantById(restaurantId),
      _userService.getFavoriteRestaurantIds().catchError((_) => <String>[]),
    ]);

    final restaurant = results[0] as Restaurant?;
    final favoriteIds = results[1] as List<String>;

    if (restaurant == null) return null;
    return restaurant.copyWith(isFavorite: favoriteIds.contains(restaurant.id));
  }

  Future<void> toggleFavorite(String restaurantId) async {
    await _userService.toggleFavoriteRestaurant(restaurantId);
  }

  Future<List<Restaurant>> fetchFavoriteRestaurants() async {
    final results = await Future.wait([
      _restaurantService.getRestaurants(),
      _userService.getFavoriteRestaurantIds().catchError((_) => <String>[]),
    ]);

    final restaurants = results[0] as List<Restaurant>;
    final favoriteIds = results[1] as List<String>;

    return restaurants
        .where((r) => favoriteIds.contains(r.id))
        .map((r) => r.copyWith(isFavorite: true))
        .toList();
  }

  // ─── Helpers de filtrado (sin toques de red) ────────────────────────────────

  List<Restaurant> filterRestaurants({
    required List<Restaurant> restaurants,
    String query = '',
    String selectedCategory = 'All',
    bool onlyOpen = false,
    bool onlyTopRated = false,
    String selectedPriceRange = 'All',
  }) {
    final q = query.trim().toLowerCase();

    return restaurants.where((r) {
      final matchesQuery = q.isEmpty ||
          r.name.toLowerCase().contains(q) ||
          r.category.toLowerCase().contains(q) ||
          r.address.toLowerCase().contains(q) ||
          r.tags.any((tag) => tag.toLowerCase().contains(q));

      final matchesCategory =
          selectedCategory == 'All' ||
          r.category.toLowerCase() == selectedCategory.toLowerCase();

      final matchesOpen = !onlyOpen || r.isOpen;
      final matchesTopRated = !onlyTopRated || r.rating >= 4.5;
      final matchesPrice =
          selectedPriceRange == 'All' || r.priceRange == selectedPriceRange;

      return matchesQuery &&
          matchesCategory &&
          matchesOpen &&
          matchesTopRated &&
          matchesPrice;
    }).toList();
  }

  List<String> extractCategories(List<Restaurant> restaurants) {
    final categories = restaurants
        .map((r) => r.category.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...categories];
  }

  List<String> extractPriceRanges(List<Restaurant> restaurants) {
    final prices = restaurants
        .map((r) => r.priceRange.trim())
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.length.compareTo(b.length));
    return ['All', ...prices];
  }
}
