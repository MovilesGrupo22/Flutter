import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:foodandes_app/models/restaurant.dart';
import 'package:foodandes_app/data/services/restaurant_service.dart';

class TrendingRestaurantsService {
  TrendingRestaurantsService._();
  static final TrendingRestaurantsService instance =
      TrendingRestaurantsService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RestaurantService _restaurantService = RestaurantService();

  final String _collection = 'restaurant_usage_events';

  Future<void> recordRestaurantView({
    required String restaurantId,
    required String restaurantName,
  }) async {
    await _firestore.collection(_collection).add({
      'restaurant_id': restaurantId,
      'restaurant_name': restaurantName,
      'event_type': 'restaurant_view',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> recordRestaurantFavorited({
    required String restaurantId,
    required String restaurantName,
  }) async {
    await _firestore.collection(_collection).add({
      'restaurant_id': restaurantId,
      'restaurant_name': restaurantName,
      'event_type': 'restaurant_favorited',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Restaurant>> getTrendingRestaurants({
    int topN = 5,
    Duration window = const Duration(hours: 24),
  }) async {
    final cutoff = Timestamp.fromDate(DateTime.now().subtract(window));

    final snapshot = await _firestore
        .collection(_collection)
        .where('timestamp', isGreaterThanOrEqualTo: cutoff)
        .get();

    if (snapshot.docs.isEmpty) return [];

    final Map<String, double> scores = {};
    final Map<String, String> names = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final restaurantId = data['restaurant_id'] as String?;
      final restaurantName = data['restaurant_name'] as String? ?? '';
      final eventType = data['event_type'] as String?;

      if (restaurantId == null || eventType == null) continue;

      names[restaurantId] = restaurantName;

      // Peso: favorito vale más que vista
      if (eventType == 'restaurant_view') {
        scores[restaurantId] = (scores[restaurantId] ?? 0) + 1.0;
      } else if (eventType == 'restaurant_favorited') {
        scores[restaurantId] = (scores[restaurantId] ?? 0) + 3.0;
      }
    }

    final sortedIds = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topIds = sortedIds.take(topN).map((e) => e.key).toSet();

    final restaurants = await _restaurantService.getRestaurants();

    final filtered = restaurants
        .where((restaurant) => topIds.contains(restaurant.id))
        .toList();

    filtered.sort((a, b) {
      final scoreA = scores[a.id] ?? 0;
      final scoreB = scores[b.id] ?? 0;
      return scoreB.compareTo(scoreA);
    });

    return filtered;
  }
}