import 'dart:convert';

import 'package:foodandes_app/models/restaurant.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalSnapshotService {
  LocalSnapshotService._();

  static final LocalSnapshotService instance = LocalSnapshotService._();

  static const String _restaurantsSnapshotKey = 'restaurants_snapshot_v3';
  static const String _restaurantsLastSyncKey = 'restaurants_last_sync_v3';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  String _favoriteIdsKey(String uid) => 'favorite_restaurant_ids_$uid';
  String _favoritesLastSyncKey(String uid) => 'favorite_restaurant_last_sync_$uid';
  String _pendingFavoriteActionsKey(String uid) =>
      'pending_favorite_actions_$uid';
  String _pendingReviewsKey(String uid) => 'pending_reviews_$uid';
  String _reviewsLastSyncKey(String uid) => 'reviews_last_sync_$uid';
  String _reviewDraftKey(String uid, String restaurantId) =>
      'review_draft_${uid}_$restaurantId';

  Future<void> saveRestaurantsSnapshot(List<Restaurant> restaurants) async {
    final prefs = await _prefs;
    final encoded = jsonEncode(restaurants.map((r) => r.toJson()).toList());
    await prefs.setString(_restaurantsSnapshotKey, encoded);
  }

  Future<List<Restaurant>> loadRestaurantsSnapshot() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_restaurantsSnapshotKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map((item) => Restaurant.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveRestaurantsLastSync(DateTime value) async {
    final prefs = await _prefs;
    await prefs.setInt(_restaurantsLastSyncKey, value.millisecondsSinceEpoch);
  }

  Future<DateTime?> loadRestaurantsLastSync() async {
    final prefs = await _prefs;
    final value = prefs.getInt(_restaurantsLastSyncKey);
    if (value == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  Future<void> saveFavoriteRestaurantIds({
    required String uid,
    required List<String> favoriteIds,
  }) async {
    final prefs = await _prefs;
    await prefs.setStringList(_favoriteIdsKey(uid), favoriteIds);
  }

  Future<List<String>> loadFavoriteRestaurantIds(String uid) async {
    final prefs = await _prefs;
    return prefs.getStringList(_favoriteIdsKey(uid)) ?? <String>[];
  }

  Future<void> saveFavoritesLastSync(String uid, DateTime value) async {
    final prefs = await _prefs;
    await prefs.setInt(_favoritesLastSyncKey(uid), value.millisecondsSinceEpoch);
  }

  Future<DateTime?> loadFavoritesLastSync(String uid) async {
    final prefs = await _prefs;
    final value = prefs.getInt(_favoritesLastSyncKey(uid));
    if (value == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  Future<List<Map<String, dynamic>>> loadPendingFavoriteActions(String uid) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_pendingFavoriteActionsKey(uid));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> savePendingFavoriteActions(
    String uid,
    List<Map<String, dynamic>> actions,
  ) async {
    final prefs = await _prefs;
    await prefs.setString(_pendingFavoriteActionsKey(uid), jsonEncode(actions));
  }

  Future<void> enqueuePendingFavoriteAction({
    required String uid,
    required String restaurantId,
    required bool desiredState,
  }) async {
    final current = await loadPendingFavoriteActions(uid);
    current.add({
      'restaurantId': restaurantId,
      'desiredState': desiredState,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    await savePendingFavoriteActions(uid, current);
  }

  Future<void> clearPendingFavoriteActions(String uid) async {
    final prefs = await _prefs;
    await prefs.remove(_pendingFavoriteActionsKey(uid));
  }

  Future<List<Map<String, dynamic>>> loadPendingReviews(String uid) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_pendingReviewsKey(uid));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> savePendingReviews(
    String uid,
    List<Map<String, dynamic>> reviews,
  ) async {
    final prefs = await _prefs;
    await prefs.setString(_pendingReviewsKey(uid), jsonEncode(reviews));
  }

  Future<void> enqueuePendingReview({
    required String uid,
    required Map<String, dynamic> reviewData,
  }) async {
    final current = await loadPendingReviews(uid);
    current.add(reviewData);
    await savePendingReviews(uid, current);
  }

  Future<void> clearPendingReviews(String uid) async {
    final prefs = await _prefs;
    await prefs.remove(_pendingReviewsKey(uid));
  }

  Future<void> saveReviewsLastSync(String uid, DateTime value) async {
    final prefs = await _prefs;
    await prefs.setInt(_reviewsLastSyncKey(uid), value.millisecondsSinceEpoch);
  }

  Future<DateTime?> loadReviewsLastSync(String uid) async {
    final prefs = await _prefs;
    final value = prefs.getInt(_reviewsLastSyncKey(uid));
    if (value == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  Future<void> saveReviewDraft({
    required String uid,
    required String restaurantId,
    required String comment,
    required int rating,
  }) async {
    final prefs = await _prefs;
    await prefs.setString(
      _reviewDraftKey(uid, restaurantId),
      jsonEncode({
        'comment': comment,
        'rating': rating,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  Future<Map<String, dynamic>?> loadReviewDraft({
    required String uid,
    required String restaurantId,
  }) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_reviewDraftKey(uid, restaurantId));
    if (raw == null || raw.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearReviewDraft({
    required String uid,
    required String restaurantId,
  }) async {
    final prefs = await _prefs;
    await prefs.remove(_reviewDraftKey(uid, restaurantId));
  }
}
