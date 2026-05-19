import 'package:flutter/foundation.dart';
import 'package:foodandes_app/data/services/local_database_service.dart';
import 'package:foodandes_app/data/services/review_service.dart';

class PendingReviewsQueueService {
  PendingReviewsQueueService._();

  static final PendingReviewsQueueService instance =
      PendingReviewsQueueService._();

  final LocalDatabaseService _localDb = LocalDatabaseService.instance;
  final ReviewService _reviewService = ReviewService();

  Future<void> enqueueReview({
    required String restaurantId,
    required String restaurantName,
    required String comment,
    required int rating,
    required String userName,
  }) async {
    await _localDb.insertPendingReview(
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      comment: comment,
      rating: rating,
      userName: userName,
    );
  }

  Future<void> syncPendingReviews() async {
    final pendingReviews = await _localDb.getPendingReviews();

    for (final review in pendingReviews) {
      final id = review['id'] as int;

      try {
        await _reviewService.createReview(
          restaurantId: review['restaurant_id'] as String,
          comment: review['comment'] as String,
          rating: review['rating'] as int,
          userName: review['user_name'] as String,
        );

        await _localDb.deletePendingReview(id);
      } catch (e) {
        debugPrint('Pending review sync failed: $e');
        await _localDb.incrementPendingReviewRetries(id);
      }
    }
  }
}