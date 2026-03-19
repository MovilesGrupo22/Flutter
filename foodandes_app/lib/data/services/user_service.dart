import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:foodandes_app/models/user_profile.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  Future<UserProfile?> getCurrentUserProfile() async {
    if (_uid == null) return null;

    final doc = await _firestore.collection('users').doc(_uid).get();

    if (!doc.exists || doc.data() == null) return null;

    return UserProfile.fromFirestore(doc.id, doc.data()!);
  }

  Future<List<String>> getFavoriteRestaurantIds() async {
    if (_uid == null) return [];

    final doc = await _firestore.collection('users').doc(_uid).get();
    final data = doc.data();

    if (data == null) return [];
    return List<String>.from(data['favoriteRestaurants'] ?? []);
  }

  Future<void> toggleFavoriteRestaurant(String restaurantId) async {
    if (_uid == null) {
      throw Exception('No authenticated user');
    }

    final userRef = _firestore.collection('users').doc(_uid);
    final snapshot = await userRef.get();
    final data = snapshot.data() ?? {};

    final favorites = List<String>.from(data['favoriteRestaurants'] ?? []);

    if (favorites.contains(restaurantId)) {
      favorites.remove(restaurantId);
    } else {
      favorites.add(restaurantId);
    }

    await userRef.update({
      'favoriteRestaurants': favorites,
    });
  }
}