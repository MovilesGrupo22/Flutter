import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:foodandes_app/models/user_profile.dart';
import 'package:foodandes_app/data/services/restaurant_service.dart';

// FIX #2 + #3:
// toggleFavoriteRestaurant usaba userRef.update() que lanza si el doc no
// existe (ej. usuario Google cuyo doc aún no se había escrito). Cambiado a
// set+merge para ser idempotente.
// También se invalida la caché de RestaurantService al cambiar favoritos para
// que el próximo fetchRestaurants() refleje el cambio inmediatamente.

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  Future<UserProfile?> getCurrentUserProfile() async {
    if (_uid == null) return null;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(_uid)
          .get()
          .timeout(const Duration(seconds: 8));

      if (!doc.exists || doc.data() == null) return null;
      return UserProfile.fromFirestore(doc.id, doc.data()!);
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> getFavoriteRestaurantIds() async {
    if (_uid == null) return [];

    try {
      final doc = await _firestore
          .collection('users')
          .doc(_uid)
          .get()
          .timeout(const Duration(seconds: 8));

      final data = doc.data();
      if (data == null) return [];
      return List<String>.from(data['favoriteRestaurants'] ?? []);
    } catch (_) {
      return [];
    }
  }

  Future<void> toggleFavoriteRestaurant(String restaurantId) async {
    if (_uid == null) throw Exception('No authenticated user');

    final userRef = _firestore.collection('users').doc(_uid);
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

    // Invalida caché para que el cambio se vea inmediatamente
    RestaurantService.instance.invalidateCache();
  }
}
