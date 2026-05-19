import 'package:flutter/foundation.dart';
import 'package:foodandes_app/models/restaurant.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RestaurantFilterIsolate
//
// Moves the filter + CAS-ranking computation off the main (UI) thread using
// Flutter's compute() helper, which spawns a real Dart Isolate internally.
//
// Why an Isolate here?
//   filterRestaurants() + rankByMoodRelevance() iterate over every restaurant
//   on every user interaction (chip tap, dropdown change, refresh). With a
//   large dataset this can cause frame drops (jank) on the main thread.
//   By offloading to a separate Isolate the UI stays responsive at 60 fps
//   while the heavy list processing happens in parallel.
//
// Key constraint of Isolates: they share NO memory with the main isolate.
//   All data must be passed as plain, serialisable objects (no BuildContext,
//   no Streams, no platform channels). That is why we bundle every parameter
//   needed for the computation into the plain [FilterParams] class below.
// ─────────────────────────────────────────────────────────────────────────────

/// Plain data class that bundles every parameter the filter computation needs.
/// Must be fully serialisable (no Flutter/platform types) so it can cross
/// Isolate boundaries safely.
class FilterParams {
  final List<Restaurant> restaurants;
  final String query;
  final String selectedCategory;
  final bool onlyOpen;
  final bool onlyTopRated;
  final String selectedPriceRange;

  /// Categories and tags that the CAS mood considers relevant right now.
  /// Passed explicitly so the Isolate does not need to call CasService
  /// (which would require a platform channel — not allowed in Isolates).
  final List<String> moodCategories;
  final List<String> moodTags;

  const FilterParams({
    required this.restaurants,
    this.query = '',
    this.selectedCategory = 'All',
    this.onlyOpen = false,
    this.onlyTopRated = false,
    this.selectedPriceRange = 'All',
    this.moodCategories = const [],
    this.moodTags = const [],
  });
}

/// Top-level function required by compute().
/// Must be a top-level (or static) function — closures cannot be sent across
/// Isolate boundaries.
List<Restaurant> _filterAndRankInIsolate(FilterParams params) {
  // ── Step 1: filter ──────────────────────────────────────────────────────────
  final q = params.query.trim().toLowerCase();

  final filtered = params.restaurants.where((r) {
    final matchesQuery = q.isEmpty ||
        r.name.toLowerCase().contains(q) ||
        r.category.toLowerCase().contains(q) ||
        r.address.toLowerCase().contains(q) ||
        r.tags.any((tag) => tag.toLowerCase().contains(q));

    final matchesCategory = params.selectedCategory == 'All' ||
        r.category.toLowerCase() == params.selectedCategory.toLowerCase();

    final matchesOpen = !params.onlyOpen || r.isOpen;
    final matchesPrice = params.selectedPriceRange == 'All' ||
        r.priceRange == params.selectedPriceRange;

    return matchesQuery &&
        matchesCategory &&
        matchesOpen &&
        matchesPrice;
  }).toList();

  if (params.onlyTopRated) {
    filtered.sort((a, b) {
      final ratingCompare = b.rating.compareTo(a.rating);
      if (ratingCompare != 0) return ratingCompare;
      final reviewsCompare = b.reviewCount.compareTo(a.reviewCount);
      if (reviewsCompare != 0) return reviewsCompare;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return filtered;
  }

  // ── Step 2: CAS mood ranking (replaces CasService.rankByMoodRelevance) ──────
  // We replicate the ranking logic here because we cannot call CasService
  // from inside the Isolate (it is a singleton that lives in the main isolate).
  if (params.moodCategories.isEmpty && params.moodTags.isEmpty) {
    return filtered;
  }

  int moodScore(Restaurant r) {
    int score = 0;
    if (params.moodCategories
        .any((c) => r.category.toLowerCase() == c.toLowerCase())) {
      score += 2;
    }
    if (params.moodTags
        .any((t) => r.tags.any((rt) => rt.toLowerCase() == t.toLowerCase()))) {
      score += 1;
    }
    return score;
  }

  filtered.sort((a, b) => moodScore(b).compareTo(moodScore(a)));
  return filtered;
}

/// Public API — called from HomeScreen instead of running the filter inline.
///
/// Usage:
/// ```dart
/// final results = await RestaurantFilterIsolate.run(FilterParams(...));
/// ```
///
/// compute() transparently:
///   1. Spawns a new Dart Isolate
///   2. Sends [params] to it (deep-copy via message passing)
///   3. Executes [_filterAndRankInIsolate] in that Isolate
///   4. Returns the result back to the main isolate
///   5. Terminates the worker Isolate
class RestaurantFilterIsolate {
  RestaurantFilterIsolate._();

  /// Runs [_filterAndRankInIsolate] on a background Isolate via compute().
  static Future<List<Restaurant>> run(FilterParams params) {
    return compute(_filterAndRankInIsolate, params);
  }
}
