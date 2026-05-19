import 'package:foodandes_app/data/services/review_service.dart';
import 'package:foodandes_app/models/review.dart';

class ReviewRepository {
  final ReviewService _reviewService = ReviewService();

  Future<List<Review>> fetchReviewsByRestaurant(String restaurantId) async {
    return await _reviewService.getReviewsByRestaurant(restaurantId);
  }

  Future<void> addReview({
    required String restaurantId,
    required String comment,
    required int rating,
    required String userName,
  }) async {
    await _reviewService.createReview(
      restaurantId: restaurantId,
      comment: comment,
      rating: rating,
      userName: userName,
    );
  }
}