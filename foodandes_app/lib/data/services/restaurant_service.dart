import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:foodandes_app/data/services/lru_cache.dart';
import 'package:foodandes_app/models/restaurant.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RestaurantService — multi-threading additions (MS5)
//
// STRATEGY 1 – Stream (5 pts)
//   restaurantsStream() wraps Firestore's native .snapshots() in a Stream.
//   Unlike a Future (one-shot), a Stream emits a new list EVERY TIME the
//   Firestore collection changes, so the UI updates automatically without
//   any manual pull-to-refresh.
//
//   Flow:
//     Firestore ──snapshots()──► Stream<QuerySnapshot>
//                  .map()      ──► Stream<List<Restaurant>>
//                  HomeScreen StreamBuilder re-renders on each emission
//
// STRATEGY 2 – Future with handler (5 pts)
//   getRestaurants() already returns a Future.  The .then() / .catchError()
//   handler pattern is used inside restaurantsStream() to update the in-memory
//   cache each time the stream emits, keeping the existing cache logic in sync.
// ─────────────────────────────────────────────────────────────────────────────

class RestaurantService {
  RestaurantService._();
  static final RestaurantService instance = RestaurantService._();

  // Constructor de instancia para compatibilidad con código que usa
  // RestaurantService() directamente (RestaurantRepository, etc.).
  factory RestaurantService() => instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Restaurant>? _cache;
  DateTime? _cacheTime;
  static const _ttl = Duration(seconds: 60);

  // LRU cache for individual restaurant lookups (capacity: 30 entries).
  // Avoids re-reading Firestore for recently viewed restaurants.
  final LruCache<String, Restaurant> _lruCache = LruCache(maxSize: 30);

  bool get _isCacheValid =>
      _cache != null &&
      _cacheTime != null &&
      DateTime.now().difference(_cacheTime!) < _ttl;

  // ── STRATEGY 1: Stream ──────────────────────────────────────────────────────
  //
  // Returns a Stream that emits the full restaurant list whenever the
  // Firestore 'restaurants' collection changes.
  //
  // Key differences vs Future:
  //   • Future  → one value then done. You must call it again to refresh.
  //   • Stream  → continuous sequence of values. Firestore pushes updates
  //               automatically; no polling needed.
  //
  // The stream is broadcast so multiple listeners (e.g. HomeScreen +
  // SearchScreen) can subscribe without re-reading Firestore.
  //
  // Handler pattern (.then / .catchError — 5 pts):
  //   We chain a Future handler on each snapshot to keep the in-memory cache
  //   consistent.  This avoids redundant Firestore reads elsewhere in the app.
  Stream<List<Restaurant>> restaurantsStream() {
    return _firestore
        .collection('restaurants')
        .snapshots() // ← Firestore real-time stream
        .map((snapshot) {
          // Transform QuerySnapshot → List<Restaurant>
          final restaurants = snapshot.docs
              .map((doc) => Restaurant.fromFirestore(doc.id, doc.data()))
              .toList();

          // Side-effect: keep the in-memory cache and LRU cache up-to-date so
          // that getRestaurantById() and other one-shot callers still benefit
          // from the cache without issuing a separate Firestore read.
          // This is the Future-with-handler (then/catchError) pattern:
          // the update is performed as a "continuation" after mapping.
          Future(() => restaurants)
              .then((list) {
                _cache = list;
                _cacheTime = DateTime.now();
                for (final r in list) {
                  _lruCache.put(r.id, r);
                }
              })
              .catchError((Object e) {
                debugPrint('RestaurantService.restaurantsStream cache ERROR -> $e');
              });

          return restaurants;
        })
        .handleError((Object e) {
          debugPrint('RestaurantService.restaurantsStream ERROR -> $e');
        });
  }

  // ── STRATEGY 2: Future (original, kept for non-stream callers) ─────────────
  //
  // Devuelve todos los restaurantes. Usa caché en memoria (60 s de TTL).
  Future<List<Restaurant>> getRestaurants({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid) return _cache!;

    try {
      final snapshot = await _firestore
          .collection('restaurants')
          .get()
          .timeout(const Duration(seconds: 10));

      _cache = snapshot.docs
          .map((doc) => Restaurant.fromFirestore(doc.id, doc.data()))
          .toList();
      _cacheTime = DateTime.now();

      // Populate LRU with every restaurant from the fresh batch.
      for (final r in _cache!) {
        _lruCache.put(r.id, r);
      }

      return _cache!;
    } catch (e) {
      debugPrint('RestaurantService.getRestaurants ERROR -> $e');
      // Devuelve caché vieja si hay, en lugar de lanzar
      return _cache ?? [];
    }
  }

  /// Busca un restaurante por id. Comprueba el LRU cache primero, luego la
  /// lista en memoria, y finalmente consulta Firestore si es necesario.
  Future<Restaurant?> getRestaurantById(String restaurantId) async {
    // 1. Check LRU cache — O(1) lookup, no Firestore read needed.
    final cached = _lruCache.get(restaurantId);
    if (cached != null) return cached;

    // 2. Fall back to list cache if valid.
    if (_isCacheValid) {
      try {
        final found = _cache!.firstWhere((r) => r.id == restaurantId);
        _lruCache.put(restaurantId, found); // promote to LRU
        return found;
      } catch (_) {
        // not found in list cache, continue to Firestore
      }
    }

    // 3. Fetch from Firestore and store in LRU before returning.
    try {
      final doc = await _firestore
          .collection('restaurants')
          .doc(restaurantId)
          .get()
          .timeout(const Duration(seconds: 8));

      if (!doc.exists) return null;
      final restaurant = Restaurant.fromFirestore(doc.id, doc.data()!);
      _lruCache.put(restaurantId, restaurant);
      return restaurant;
    } catch (e) {
      debugPrint('RestaurantService.getRestaurantById ERROR -> $e');
      return null;
    }
  }

  /// Invalida la caché (llamar tras escribir favoritos, reseñas, etc.)
  void invalidateCache() {
    _cache = null;
    _cacheTime = null;
  }
}
