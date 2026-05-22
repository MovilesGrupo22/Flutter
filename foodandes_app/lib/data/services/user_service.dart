import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:foodandes_app/data/services/connectivity_service.dart';
import 'package:foodandes_app/data/services/local_database_service.dart';
import 'package:foodandes_app/data/services/local_snapshot_service.dart';
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

      if (!doc.exists || doc.data() == null) return _profileFromAuthUser();
      final profile = UserProfile.fromFirestore(doc.id, doc.data()!);
      _profileCache.put(uid, profile);
      return profile;
    } catch (_) {
      // Offline protected fallback: FirebaseAuth usually keeps the last signed
      // user locally, so the Profile screen can still render a safe summary.
      return _profileFromAuthUser();
    }
  }

  UserProfile? _profileFromAuthUser() {
    final user = _auth.currentUser;
    if (user == null) return null;

    final fallbackName = user.displayName?.trim();
    final email = user.email ?? '';

    return UserProfile(
      uid: user.uid,
      name: (fallbackName != null && fallbackName.isNotEmpty)
          ? fallbackName
          : (email.isNotEmpty ? email.split('@').first : 'User'),
      email: email,
      photoURL: user.photoURL ?? '',
      favoriteRestaurants: const [],
      dietaryPreferences: const [],
    );
  }

  Future<List<String>> getFavoriteRestaurantIds() async {
    final uid = _uid;
    if (uid == null) return [];

    final online = await ConnectivityService.instance.isOnline;
    if (!online) {
      return _loadFavoriteIdsFromLocal(uid);
    }

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
      if (data == null) return _loadFavoriteIdsFromLocal(uid);

      // Cache the full profile so subsequent calls to getCurrentUserProfile()
      // also benefit from this read.
      final profile = UserProfile.fromFirestore(doc.id, data);
      _profileCache.put(uid, profile);

      await _persistFavoriteIdsLocally(uid, profile.favoriteRestaurants);
      return profile.favoriteRestaurants;
    } catch (_) {
      return _loadFavoriteIdsFromLocal(uid);
    }
  }

  Future<List<String>> _loadFavoriteIdsFromLocal(String uid) async {
    final dbIds = await LocalDatabaseService.instance.getFavoriteIds(uid);
    if (dbIds.isNotEmpty) return dbIds;
    return LocalSnapshotService.instance.loadFavoriteRestaurantIds(uid);
  }

  Future<void> _persistFavoriteIdsLocally(
    String uid,
    List<String> favoriteIds,
  ) async {
    await Future.wait([
      LocalDatabaseService.instance.replaceFavoriteIds(uid, favoriteIds),
      LocalSnapshotService.instance.saveFavoriteRestaurantIds(
        uid: uid,
        favoriteIds: favoriteIds,
      ),
      LocalSnapshotService.instance.saveFavoritesLastSync(uid, DateTime.now()),
    ]);
  }

  Future<void> toggleFavoriteRestaurant(String restaurantId) async {
    final uid = _uid;
    if (uid == null) throw Exception('No authenticated user');

    final online = await ConnectivityService.instance.isOnline;

    // Offline-first branch: update local SQLite immediately and enqueue the
    // desired final state. PendingSyncService will send it to Firestore when
    // connectivity returns.
    if (!online) {
      final favoriteIds = List<String>.from(await _loadFavoriteIdsFromLocal(uid));
      final willBeFavorite = !favoriteIds.contains(restaurantId);

      if (willBeFavorite) {
        favoriteIds.add(restaurantId);
        await LocalDatabaseService.instance.insertFavorite(uid, restaurantId);
      } else {
        favoriteIds.remove(restaurantId);
        await LocalDatabaseService.instance.removeFavorite(uid, restaurantId);
      }

      await LocalSnapshotService.instance.saveFavoriteRestaurantIds(
        uid: uid,
        favoriteIds: favoriteIds,
      );
      await LocalSnapshotService.instance.enqueuePendingFavoriteAction(
        uid: uid,
        restaurantId: restaurantId,
        desiredState: willBeFavorite,
      );

      _profileCache.remove(uid);
      RestaurantService.instance.invalidateCache();
      return;
    }

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

    await _persistFavoriteIdsLocally(uid, favorites);
  }


  Future<void> syncPendingFavoriteActions() async {
    final uid = _uid;
    if (uid == null) return;

    final pendingActions =
        await LocalSnapshotService.instance.loadPendingFavoriteActions(uid);
    if (pendingActions.isEmpty) return;

    final userRef = _firestore.collection('users').doc(uid);
    final snapshot = await userRef.get();
    final data = snapshot.data() ?? {};
    final favorites = List<String>.from(data['favoriteRestaurants'] ?? []);

    for (final action in pendingActions) {
      final restaurantId = action['restaurantId'] as String?;
      final desiredState = action['desiredState'] as bool?;
      if (restaurantId == null || desiredState == null) continue;

      if (desiredState && !favorites.contains(restaurantId)) {
        favorites.add(restaurantId);
      } else if (!desiredState) {
        favorites.remove(restaurantId);
      }
    }

    await userRef.set(
      {'favoriteRestaurants': favorites},
      SetOptions(merge: true),
    );

    await _persistFavoriteIdsLocally(uid, favorites);
    await LocalSnapshotService.instance.clearPendingFavoriteActions(uid);
    _profileCache.remove(uid);
    RestaurantService.instance.invalidateCache();
  }

  /// Removes the cached profile for the current user.
  /// Call this after any profile update (name, photo, dietary preferences).
  void invalidateProfileCache() {
    final uid = _uid;
    if (uid != null) _profileCache.remove(uid);
  }
}