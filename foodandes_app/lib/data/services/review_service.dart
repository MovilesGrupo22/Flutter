import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:foodandes_app/models/review.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<Review>> getReviewsByRestaurant(String restaurantId) async {
    final snapshot = await _firestore
        .collection('reviews')
        .where('restaurantId', isEqualTo: restaurantId)
        .get();

    final reviews = snapshot.docs
        .map((doc) => Review.fromFirestore(doc.id, doc.data()))
        .toList();

    reviews.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return reviews;
  }


  Future<int> getCurrentUserReviewCount() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return 0;

    final snapshot = await _firestore
        .collection('reviews')
        .where('userId', isEqualTo: currentUser.uid)
        .get();

    return snapshot.docs.length;
  }

  Future<void> createReview({
    required String restaurantId,
    required String comment,
    required int rating,
    required String userName,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('No authenticated user');
    }

    final reviewsRef = _firestore.collection('reviews');
    final restaurantRef = _firestore.collection('restaurants').doc(restaurantId);

    await _firestore.runTransaction((transaction) async {
      final restaurantSnapshot = await transaction.get(restaurantRef);

      if (!restaurantSnapshot.exists) {
        throw Exception('Restaurant not found');
      }

      final restaurantData = restaurantSnapshot.data()!;
      final currentReviewCount =
          (restaurantData['reviewCount'] ?? 0) is int
              ? restaurantData['reviewCount'] ?? 0
              : ((restaurantData['reviewCount'] ?? 0) as num).toInt();

      final currentRating =
          (restaurantData['rating'] ?? 0) is num
              ? ((restaurantData['rating'] ?? 0) as num).toDouble()
              : 0.0;

      final newReviewCount = currentReviewCount + 1;
      final newAverageRating =
          ((currentRating * currentReviewCount) + rating) / newReviewCount;

      final newReviewRef = reviewsRef.doc();

      transaction.set(newReviewRef, {
        'restaurantId': restaurantId,
        'userId': currentUser.uid,
        'userName': userName,
        'comment': comment,
        'rating': rating,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'imageUrls': <String>[],
      });

      transaction.update(restaurantRef, {
        'reviewCount': newReviewCount,
        'rating': double.parse(newAverageRating.toStringAsFixed(2)),
      });
    });
  }
}