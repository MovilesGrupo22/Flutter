import 'package:flutter/foundation.dart';
import 'package:foodandes_app/data/services/connectivity_service.dart';
import 'package:foodandes_app/data/services/local_database_service.dart';
import 'package:foodandes_app/data/services/restaurant_service.dart';
import 'package:foodandes_app/data/services/user_service.dart';
import 'package:foodandes_app/models/restaurant.dart';

class RestaurantRepository {
  final RestaurantService _restaurantService = RestaurantService();
  final UserService _userService = UserService();
  final LocalDatabaseService _localDb = LocalDatabaseService.instance;

  // ── STRATEGY 1: Stream ──────────────────────────────────────────────────────
  // Returns a Stream<List<Restaurant>> where each emission is the current full
  // restaurant list with up-to-date isFavorite flags. The stream also refreshes
  // SQLite so protected screens keep a usable offline copy.
  Stream<List<Restaurant>> restaurantsStream() {
    return _restaurantService.restaurantsStream().asyncMap((restaurants) async {
      await _localDb.insertRestaurants(restaurants).catchError((Object error) {
        debugPrint('RestaurantRepository local cache save ERROR -> $error');
      });
      return _withFavoriteState(restaurants);
    }).handleError((Object error) {
      debugPrint('RestaurantRepository.restaurantsStream ERROR -> $error');
    });
  }

  // ── STRATEGY 2: Future + async/await with offline fallback ─────────────────
  Future<List<Restaurant>> fetchRestaurants() async {
    final online = await ConnectivityService.instance.isOnline;
    if (!online) {
      return _fetchRestaurantsFromLocal();
    }

    try {
      final results = await Future.wait<dynamic>([
        _restaurantService.getRestaurants(forceRefresh: true),
        _userService.getFavoriteRestaurantIds().catchError((_) => <String>[]),
      ]);

      final restaurants = results[0] as List<Restaurant>;
      final favoriteIds = results[1] as List<String>;
      await _localDb.insertRestaurants(restaurants);

      return _applyFavoriteIds(restaurants, favoriteIds);
    } catch (error) {
      debugPrint('RestaurantRepository.fetchRestaurants ERROR -> $error');
      return _fetchRestaurantsFromLocal();
    }
  }

  Future<Restaurant?> fetchRestaurantById(String restaurantId) async {
    final online = await ConnectivityService.instance.isOnline;
    if (!online) {
      return _fetchRestaurantFromLocal(restaurantId);
    }

    try {
      final results = await Future.wait<dynamic>([
        _restaurantService.getRestaurantById(restaurantId),
        _userService.getFavoriteRestaurantIds().catchError((_) => <String>[]),
      ]);

      final restaurant = results[0] as Restaurant?;
      final favoriteIds = results[1] as List<String>;

      if (restaurant == null) {
        return _fetchRestaurantFromLocal(restaurantId);
      }

      await _localDb.insertRestaurants([restaurant]);
      return restaurant.copyWith(isFavorite: favoriteIds.contains(restaurant.id));
    } catch (error) {
      debugPrint('RestaurantRepository.fetchRestaurantById ERROR -> $error');
      return _fetchRestaurantFromLocal(restaurantId);
    }
  }

  Future<void> toggleFavorite(String restaurantId) async {
    await _userService.toggleFavoriteRestaurant(restaurantId);
  }

  Future<List<Restaurant>> fetchFavoriteRestaurants() async {
    final online = await ConnectivityService.instance.isOnline;
    if (!online) {
      return _fetchFavoritesFromLocal();
    }

    try {
      final results = await Future.wait<dynamic>([
        _restaurantService.getRestaurants(forceRefresh: true),
        _userService.getFavoriteRestaurantIds().catchError((_) => <String>[]),
      ]);

      final restaurants = results[0] as List<Restaurant>;
      final favoriteIds = results[1] as List<String>;
      await _localDb.insertRestaurants(restaurants);

      return restaurants
          .where((r) => favoriteIds.contains(r.id))
          .map((r) => r.copyWith(isFavorite: true))
          .toList();
    } catch (error) {
      debugPrint('RestaurantRepository.fetchFavoriteRestaurants ERROR -> $error');
      return _fetchFavoritesFromLocal();
    }
  }

  Future<List<Restaurant>> _withFavoriteState(List<Restaurant> restaurants) async {
    final favoriteIds = await _userService
        .getFavoriteRestaurantIds()
        .catchError((_) => <String>[]);
    return _applyFavoriteIds(restaurants, favoriteIds);
  }

  List<Restaurant> _applyFavoriteIds(
    List<Restaurant> restaurants,
    List<String> favoriteIds,
  ) {
    return restaurants
        .map((r) => r.copyWith(isFavorite: favoriteIds.contains(r.id)))
        .toList();
  }

  Future<List<Restaurant>> _fetchRestaurantsFromLocal() async {
    final restaurants = await _localDb.getRestaurants();
    final favoriteIds = await _userService
        .getFavoriteRestaurantIds()
        .catchError((_) => <String>[]);
    return _applyFavoriteIds(restaurants, favoriteIds);
  }

  Future<Restaurant?> _fetchRestaurantFromLocal(String restaurantId) async {
    final restaurant = await _localDb.getRestaurantById(restaurantId);
    if (restaurant == null) return null;

    final favoriteIds = await _userService
        .getFavoriteRestaurantIds()
        .catchError((_) => <String>[]);
    return restaurant.copyWith(isFavorite: favoriteIds.contains(restaurant.id));
  }

  Future<List<Restaurant>> _fetchFavoritesFromLocal() async {
    final restaurants = await _fetchRestaurantsFromLocal();
    return restaurants.where((r) => r.isFavorite).toList();
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
      final matchesPrice =
          selectedPriceRange == 'All' || r.priceRange == selectedPriceRange;

      return matchesQuery &&
          matchesCategory &&
          matchesOpen &&
          matchesPrice;
    }).toList()
      ..sort((a, b) {
        if (!onlyTopRated) return 0;
        final ratingCompare = b.rating.compareTo(a.rating);
        if (ratingCompare != 0) return ratingCompare;
        final reviewsCompare = b.reviewCount.compareTo(a.reviewCount);
        if (reviewsCompare != 0) return reviewsCompare;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
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
