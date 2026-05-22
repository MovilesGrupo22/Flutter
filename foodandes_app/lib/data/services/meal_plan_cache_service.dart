import 'package:foodandes_app/data/services/lru_cache.dart';
import 'package:foodandes_app/models/meal_plan.dart';
import 'package:foodandes_app/models/restaurant.dart';

class _MealPlanCacheEntry {
  final MealPlanResult result;
  final DateTime storedAt;

  const _MealPlanCacheEntry({
    required this.result,
    required this.storedAt,
  });
}

class MealPlanCacheService {
  MealPlanCacheService._();

  static final MealPlanCacheService instance = MealPlanCacheService._();

  // Small bounded LRU cache because meal-plan results are derived data.
  // Each entry stores a complete generated plan for a goal + constraints +
  // restaurant snapshot. The TTL keeps food availability reasonably fresh.
  final LruCache<String, _MealPlanCacheEntry> _cache = LruCache(maxSize: 12);
  static const Duration ttl = Duration(minutes: 15);

  MealPlanResult? get(String key) {
    final entry = _cache.get(key);
    if (entry == null) return null;

    final age = DateTime.now().difference(entry.storedAt);
    if (age > ttl) {
      _cache.remove(key);
      return null;
    }

    return entry.result.copyWith(
      fromCache: true,
      cacheKey: key,
      cachedAt: entry.storedAt,
    );
  }

  void put(String key, MealPlanResult result) {
    final now = DateTime.now();
    _cache.put(
      key,
      _MealPlanCacheEntry(
        result: result.copyWith(
          fromCache: false,
          cacheKey: key,
          cachedAt: now,
        ),
        storedAt: now,
      ),
    );
  }

  void invalidate(String key) => _cache.remove(key);

  void clear() => _cache.clear();

  int get size => _cache.size;

  String buildKey({
    required MealPlanGoal goal,
    required bool onlyOpen,
    required String selectedPriceRange,
    required List<String> selectedTags,
    required List<Restaurant> restaurants,
    DateTime? now,
  }) {
    final time = now ?? DateTime.now();
    final hourBucket = time.hour ~/ 4;
    final restaurantFingerprint = restaurants
        .map(
          (r) => [
            r.id,
            r.rating.toStringAsFixed(2),
            r.reviewCount,
            r.isOpen ? 1 : 0,
            r.priceRange,
            r.category,
            ...r.tags,
          ].join(':'),
        )
        .join('|')
        .hashCode;

    final tagFingerprint = selectedTags
        .map((tag) => tag.trim().toLowerCase())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return [
      goal.name,
      onlyOpen ? 'open' : 'all',
      selectedPriceRange,
      tagFingerprint.join(','),
      hourBucket,
      restaurants.length,
      restaurantFingerprint,
    ].join('::');
  }
}
