import 'dart:collection';

import 'package:foodandes_app/models/review.dart';

class ReviewsLruCacheService {
  ReviewsLruCacheService._();

  static final ReviewsLruCacheService instance = ReviewsLruCacheService._();

  static const int _maxEntries = 10;

  final LinkedHashMap<String, List<Review>> _cache =
      LinkedHashMap<String, List<Review>>();

  List<Review>? getReviews(String restaurantId) {
    if (!_cache.containsKey(restaurantId)) return null;

    final reviews = _cache.remove(restaurantId)!;

    // Reinsert to mark as most recently used.
    _cache[restaurantId] = reviews;

    return List<Review>.from(reviews);
  }

  void saveReviews({
    required String restaurantId,
    required List<Review> reviews,
  }) {
    if (_cache.containsKey(restaurantId)) {
      _cache.remove(restaurantId);
    }

    _cache[restaurantId] = List<Review>.from(reviews);

    if (_cache.length > _maxEntries) {
      _cache.remove(_cache.keys.first);
    }
  }

  void clearRestaurant(String restaurantId) {
    _cache.remove(restaurantId);
  }

  void clearAll() {
    _cache.clear();
  }

  bool contains(String restaurantId) {
    return _cache.containsKey(restaurantId);
  }

  int get size => _cache.length;
}