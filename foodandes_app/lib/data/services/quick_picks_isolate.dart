import 'package:flutter/foundation.dart';
import 'package:foodandes_app/models/restaurant.dart';

class QuickPickResult {
  final Restaurant restaurant;
  final double score;
  final List<String> reasons;

  const QuickPickResult({
    required this.restaurant,
    required this.score,
    required this.reasons,
  });
}

class QuickPicksParams {
  final List<Map<String, dynamic>> restaurantsJson;
  final int hour;

  const QuickPicksParams({
    required this.restaurantsJson,
    required this.hour,
  });
}

class _RawQuickPickResult {
  final Map<String, dynamic> restaurantJson;
  final double score;
  final List<String> reasons;

  const _RawQuickPickResult({
    required this.restaurantJson,
    required this.score,
    required this.reasons,
  });

  Map<String, dynamic> toJson() {
    return {
      'restaurantJson': restaurantJson,
      'score': score,
      'reasons': reasons,
    };
  }

  factory _RawQuickPickResult.fromJson(Map<String, dynamic> json) {
    return _RawQuickPickResult(
      restaurantJson: Map<String, dynamic>.from(json['restaurantJson'] as Map),
      score: (json['score'] as num).toDouble(),
      reasons: List<String>.from(json['reasons'] as List),
    );
  }
}

/// Top-level function required by compute().
/// This runs outside the main UI isolate.
List<Map<String, dynamic>> _calculateQuickPicksInIsolate(
  QuickPicksParams params,
) {
  final scored = params.restaurantsJson.map((restaurantJson) {
    final restaurant = Restaurant.fromJson(restaurantJson);
    final score = _scoreRestaurant(restaurant, params.hour);
    final reasons = _buildReasons(restaurant, params.hour);

    return _RawQuickPickResult(
      restaurantJson: restaurantJson,
      score: score,
      reasons: reasons,
    );
  }).toList();

  scored.sort((a, b) => b.score.compareTo(a.score));

  return scored.take(8).map((result) => result.toJson()).toList();
}

double _scoreRestaurant(Restaurant restaurant, int hour) {
  double score = 0;

  // 1. Open restaurants are strongly preferred.
  if (restaurant.isOpen) score += 30;

  // 2. Rating is a strong quality signal.
  score += (restaurant.rating / 5.0) * 25;

  // 3. Review count adds reliability, capped to avoid domination.
  final reviewScore = restaurant.reviewCount.clamp(0, 100) / 100.0;
  score += reviewScore * 15;

  // 4. Lower price gets a small bonus for students.
  score += _priceScore(restaurant.priceRange);

  // 5. Time-aware category/tag match.
  score += _timeContextScore(restaurant, hour);

  // 6. Favorite restaurants get a small personalization bonus.
  if (restaurant.isFavorite) score += 5;

  return score.clamp(0, 100);
}

double _priceScore(String priceRange) {
  switch (priceRange.trim()) {
    case r'$':
      return 12;
    case r'$$':
      return 9;
    case r'$$$':
      return 5;
    case r'$$$$':
      return 2;
    default:
      return 6;
  }
}

double _timeContextScore(Restaurant restaurant, int hour) {
  final category = restaurant.category.toLowerCase();
  final tags = restaurant.tags.map((tag) => tag.toLowerCase()).join(' ');
  final haystack = '$category $tags';

  if (hour >= 6 && hour < 11) {
    if (_containsAny(haystack, ['coffee', 'café', 'bakery', 'breakfast', 'brunch'])) {
      return 18;
    }
    return 4;
  }

  if (hour >= 11 && hour < 15) {
    if (_containsAny(haystack, [
      'lunch',
      'almuerzo',
      'casero',
      'colombian',
      'corrientazo',
      'parrilla',
      'fast food',
      'burger',
    ])) {
      return 18;
    }
    return 6;
  }

  if (hour >= 15 && hour < 18) {
    if (_containsAny(haystack, ['coffee', 'café', 'snack', 'bakery', 'dessert'])) {
      return 18;
    }
    return 5;
  }

  if (hour >= 18 && hour < 22) {
    if (_containsAny(haystack, ['dinner', 'bar', 'parrilla', 'pizza', 'italian'])) {
      return 18;
    }
    return 6;
  }

  return restaurant.isOpen ? 6 : 0;
}

bool _containsAny(String text, List<String> tokens) {
  return tokens.any((token) => text.contains(token));
}

List<String> _buildReasons(Restaurant restaurant, int hour) {
  final reasons = <String>[];

  if (restaurant.isOpen) {
    reasons.add('Open now');
  }

  if (restaurant.rating >= 4.5) {
    reasons.add('Highly rated');
  }

  if (restaurant.reviewCount >= 10) {
    reasons.add('Reliable reviews');
  }

  if (restaurant.priceRange == r'$' || restaurant.priceRange == r'$$') {
    reasons.add('Student-friendly price');
  }

  final timeReason = _timeReason(restaurant, hour);
  if (timeReason != null) {
    reasons.add(timeReason);
  }

  if (restaurant.isFavorite) {
    reasons.add('Already in your favorites');
  }

  if (reasons.isEmpty) {
    reasons.add('Balanced option');
  }

  return reasons.take(3).toList();
}

String? _timeReason(Restaurant restaurant, int hour) {
  final category = restaurant.category.toLowerCase();
  final tags = restaurant.tags.map((tag) => tag.toLowerCase()).join(' ');
  final haystack = '$category $tags';

  if (hour >= 6 && hour < 11) {
    if (_containsAny(haystack, ['coffee', 'café', 'bakery', 'breakfast', 'brunch'])) {
      return 'Good for breakfast';
    }
  }

  if (hour >= 11 && hour < 15) {
    if (_containsAny(haystack, [
      'lunch',
      'almuerzo',
      'casero',
      'colombian',
      'corrientazo',
      'parrilla',
      'fast food',
      'burger',
    ])) {
      return 'Good for lunch';
    }
  }

  if (hour >= 15 && hour < 18) {
    if (_containsAny(haystack, ['coffee', 'café', 'snack', 'bakery', 'dessert'])) {
      return 'Good for a break';
    }
  }

  if (hour >= 18 && hour < 22) {
    if (_containsAny(haystack, ['dinner', 'bar', 'parrilla', 'pizza', 'italian'])) {
      return 'Good for dinner';
    }
  }

  return null;
}

class QuickPicksIsolate {
  QuickPicksIsolate._();

  static Future<List<QuickPickResult>> run({
    required List<Restaurant> restaurants,
    required int hour,
  }) async {
    final params = QuickPicksParams(
      restaurantsJson: restaurants.map((restaurant) => restaurant.toJson()).toList(),
      hour: hour,
    );

    final rawResults = await compute(_calculateQuickPicksInIsolate, params);

    return rawResults.map((raw) {
      final parsed = _RawQuickPickResult.fromJson(raw);
      return QuickPickResult(
        restaurant: Restaurant.fromJson(parsed.restaurantJson),
        score: parsed.score,
        reasons: parsed.reasons,
      );
    }).toList();
  }
}