import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  Future<void> logSectionOpened(String sectionName) async {
    await _analytics.logEvent(
      name: 'section_opened',
      parameters: {
        'section_name': sectionName,
      },
    );
  }

  Future<void> logRestaurantView({
    required String restaurantId,
    required String restaurantName,
    required String category,
    required String priceRange,
  }) async {
    await _analytics.logEvent(
      name: 'restaurant_view',
      parameters: {
        'restaurant_id': restaurantId,
        'restaurant_name': restaurantName,
        'category': category,
        'price_range': priceRange,
      },
    );
  }

  Future<void> logFilterApplied({
    required String filterType,
    required String filterValue,
  }) async {
    await _analytics.logEvent(
      name: 'filter_applied',
      parameters: {
        'filter_type': filterType,
        'filter_value': filterValue,
      },
    );
  }

  Future<void> logFavoriteToggled({
    required String restaurantId,
    required bool isFavoriteAfterAction,
  }) async {
    await _analytics.logEvent(
      name: 'favorite_toggled',
      parameters: {
        'restaurant_id': restaurantId,
        'action': isFavoriteAfterAction ? 'added' : 'removed',
      },
    );
  }
}