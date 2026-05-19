import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:foodandes_app/data/services/local_database_service.dart';
import 'package:foodandes_app/data/services/lru_cache.dart';
import 'package:foodandes_app/data/services/restaurant_service.dart';
import 'package:foodandes_app/models/user_profile.dart';

// FIX #2 + #3:
// toggleFavoriteRestaurant usaba userRef.update() que lanza si el doc no
// existe (ej. usuario Google cuyo doc aún no se había escrito). Cambiado a
// set+merge para ser idempotente.
// También se invalida la caché de RestaurantService al cambiar favoritos para
// que el próximo fetchRestaurants() refleje el cambio inmediatamente.

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // LRU cache for user profiles keyed by userId.
  // maxSize 10: supports up to 10 distinct users per session (e.g., viewing
  // other users' profiles in a social feature). User profiles rarely change,
  // so a cache hit avoids a Firestore read on every ProfileScreen open.
  final LruCache<String, UserProfile> _profileCache = LruCache(maxSize: 10);

  String? get _uid => _auth.currentUser?.uid;

  Future<UserProfile?> getCurrentUserProfile() async {
    final uid = _uid;
    if (uid == null) return null;

    // 1. Check LRU cache first — avoids Firestore read if already loaded.
    final cached = _profileCache.get(uid);
    if (cached != null) return cached;

    // 2. Fetch from Firestore and store in LRU before returning.
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 8));

      if (!doc.exists || doc.data() == null) return null;
      final profile = UserProfile.fromFirestore(doc.id, doc.data()!);
      _profileCache.put(uid, profile);
      return profile;
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> getFavoriteRestaurantIds() async {
    final uid = _uid;
    if (uid == null) return [];

    // Reuse the profile cache — favorites are part of the UserProfile document,
    // so if the profile is already cached we avoid a second Firestore read.
    final cached = _profileCache.get(uid);
    if (cached != null) return cached.favoriteRestaurants;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 8));

      final data = doc.data();
      if (data == null) return [];

      // Cache the full profile so subsequent calls to getCurrentUserProfile()
      // also benefit from this read.
      final profile = UserProfile.fromFirestore(doc.id, data);
      _profileCache.put(uid, profile);

      return profile.favoriteRestaurants;
    } catch (_) {
      return [];
    }
  }

  Future<void> toggleFavoriteRestaurant(String restaurantId) async {
    final uid = _uid;
    if (uid == null) throw Exception('No authenticated user');

    final userRef = _firestore.collection('users').doc(uid);
    final snapshot = await userRef.get();
    final data = snapshot.data() ?? {};

    final favorites = List<String>.from(data['favoriteRestaurants'] ?? []);

    if (favorites.contains(restaurantId)) {
      favorites.remove(restaurantId);
    } else {
      favorites.add(restaurantId);
    }

    // FIX: set+merge en lugar de update() para no fallar si el doc no existe
    await userRef.set(
      {'favoriteRestaurants': favorites},
      SetOptions(merge: true),
    );

    // Invalidate both caches so the next read reflects the updated favorites.
    _profileCache.remove(uid);
    RestaurantService.instance.invalidateCache();

    // Sync to local SQLite so FavoritesScreen can show saved favorites offline.
    try {
      final db = LocalDatabaseService.instance;
      if (favorites.contains(restaurantId)) {
        await db.insertFavorite(uid, restaurantId);
      } else {
        await db.removeFavorite(uid, restaurantId);
      }
    } catch (_) {}
  }

  /// Removes the cached profile for the current user.
  /// Call this after any profile update (name, photo, dietary preferences).
  void invalidateProfileCache() {
    final uid = _uid;
    if (uid != null) _profileCache.remove(uid);
  }
}