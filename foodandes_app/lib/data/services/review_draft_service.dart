import 'package:shared_preferences/shared_preferences.dart';

class ReviewDraftService {
  ReviewDraftService._();
  static final ReviewDraftService instance = ReviewDraftService._();
  factory ReviewDraftService() => instance;

  String _commentKey(String restaurantId) => 'review_draft_comment_' + restaurantId;
  String _ratingKey(String restaurantId) => 'review_draft_rating_' + restaurantId;

  Future<void> saveDraft({
    required String restaurantId,
    required String comment,
    required int rating,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_commentKey(restaurantId), comment);
    await prefs.setInt(_ratingKey(restaurantId), rating);
  }

  Future<Map<String, dynamic>> getDraft(String restaurantId) async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'comment': prefs.getString(_commentKey(restaurantId)) ?? '',
      'rating': prefs.getInt(_ratingKey(restaurantId)) ?? 5,
    };
  }

  Future<void> clearDraft(String restaurantId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_commentKey(restaurantId));
    await prefs.remove(_ratingKey(restaurantId));
  }
}
