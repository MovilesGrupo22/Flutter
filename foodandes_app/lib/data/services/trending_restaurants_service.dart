import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:foodandes_app/models/restaurant.dart';
import 'package:foodandes_app/data/services/restaurant_service.dart';

// FIX #2 (app muy lenta):
// La versión anterior llamaba getRestaurants() de forma separada dentro de
// getTrendingRestaurants(), duplicando la lectura Firestore justo cuando
// HomeScreen ya hacía su propia carga. Ahora usa el singleton RestaurantService
// que tiene caché, así la segunda llamada es instantánea (desde memoria).

class TrendingRestaurantsService {
  TrendingRestaurantsService._();
  static final TrendingRestaurantsService instance =
      TrendingRestaurantsService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'restaurant_usage_events';

  Future<void> recordRestaurantView({
    required String restaurantId,
    required String restaurantName,
  }) async {
    try {
      await _firestore.collection(_collection).add({
        'restaurant_id': restaurantId,
        'restaurant_name': restaurantName,
        'event_type': 'restaurant_view',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('TrendingService.recordView ERROR -> $e');
    }
  }

  Future<void> recordRestaurantFavorited({
    required String restaurantId,
    required String restaurantName,
  }) async {
    try {
      await _firestore.collection(_collection).add({
        'restaurant_id': restaurantId,
        'restaurant_name': restaurantName,
        'event_type': 'restaurant_favorited',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('TrendingService.recordFavorited ERROR -> $e');
    }
  }

  Future<List<Restaurant>> getTrendingRestaurants({
    int topN = 5,
    Duration window = const Duration(hours: 24),
  }) async {
    try {
      final cutoff = Timestamp.fromDate(DateTime.now().subtract(window));

      final snapshot = await _firestore
          .collection(_collection)
          .where('timestamp', isGreaterThanOrEqualTo: cutoff)
          .get()
          .timeout(const Duration(seconds: 8));

      if (snapshot.docs.isEmpty) return [];

      final Map<String, double> scores = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final restaurantId = data['restaurant_id'] as String?;
        final eventType = data['event_type'] as String?;
        if (restaurantId == null || eventType == null) continue;

        if (eventType == 'restaurant_view') {
          scores[restaurantId] = (scores[restaurantId] ?? 0) + 1.0;
        } else if (eventType == 'restaurant_favorited') {
          scores[restaurantId] = (scores[restaurantId] ?? 0) + 3.0;
        }
      }

      if (scores.isEmpty) return [];

      final topIds = (scores.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .take(topN)
          .map((e) => e.key)
          .toSet();

      // FIX: usa el singleton con caché → no hace una nueva lectura Firestore
      // si HomeScreen ya cargó los restaurantes en los últimos 60 segundos.
      final restaurants = await RestaurantService.instance.getRestaurants();

      final filtered =
          restaurants.where((r) => topIds.contains(r.id)).toList()
            ..sort((a, b) =>
                (scores[b.id] ?? 0).compareTo(scores[a.id] ?? 0));

      return filtered;
    } catch (e) {
      debugPrint('TrendingService.getTrending ERROR -> $e');
      return [];
    }
  }
}
