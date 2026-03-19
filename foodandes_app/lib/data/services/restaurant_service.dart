import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:foodandes_app/models/restaurant.dart';

class RestaurantService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Restaurant>> getRestaurants() async {
    final snapshot = await _firestore.collection('restaurants').get();

    return snapshot.docs
        .map((doc) => Restaurant.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  Future<Restaurant?> getRestaurantById(String restaurantId) async {
    final doc =
        await _firestore.collection('restaurants').doc(restaurantId).get();

    if (!doc.exists) return null;

    return Restaurant.fromFirestore(doc.id, doc.data()!);
  }
}