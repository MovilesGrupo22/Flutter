import 'package:foodandes_app/data/services/lru_cache.dart';
import 'package:foodandes_app/data/services/quick_picks_isolate.dart';
import 'package:foodandes_app/models/restaurant.dart';

class _QuickPicksCacheEntry {
  final List<QuickPickResult> results;
  final DateTime storedAt;

  const _QuickPicksCacheEntry({
    required this.results,
    required this.storedAt,
  });
}

class QuickPicksCacheService {
  QuickPicksCacheService._();

  static final QuickPicksCacheService instance = QuickPicksCacheService._();

  // Small in-memory LRU cache for derived quick-pick rankings. It avoids
  // re-running the isolate when the same restaurant snapshot is ranked again.
  final LruCache<String, _QuickPicksCacheEntry> _cache = LruCache(maxSize: 8);
  static const Duration ttl = Duration(minutes: 10);

  List<QuickPickResult>? get(String key) {
    final entry = _cache.get(key);
    if (entry == null) return null;

    if (DateTime.now().difference(entry.storedAt) > ttl) {
      _cache.remove(key);
      return null;
    }

    return List<QuickPickResult>.unmodifiable(entry.results);
  }

  void put(String key, List<QuickPickResult> results) {
    _cache.put(
      key,
      _QuickPicksCacheEntry(
        results: List<QuickPickResult>.unmodifiable(results),
        storedAt: DateTime.now(),
      ),
    );
  }

  String buildKey({
    required List<Restaurant> restaurants,
    required int hour,
  }) {
    final hourBucket = hour ~/ 2;
    final fingerprint = restaurants
        .map(
          (restaurant) => [
            restaurant.id,
            restaurant.rating.toStringAsFixed(2),
            restaurant.reviewCount,
            restaurant.isOpen ? 1 : 0,
            restaurant.isFavorite ? 1 : 0,
            restaurant.priceRange,
            restaurant.category,
            restaurant.tags.join(','),
          ].join(':'),
        )
        .join('|')
        .hashCode;

    return 'quick-picks::$hourBucket::${restaurants.length}::$fingerprint';
  }

  void clear() => _cache.clear();

  int get size => _cache.size;
}
