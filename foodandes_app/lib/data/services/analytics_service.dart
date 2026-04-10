import 'package:firebase_analytics/firebase_analytics.dart';

enum AppSection {
  home,
  map,
  search,
  favorites,
  profile,
  detail,
}

class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    await _analytics.setAnalyticsCollectionEnabled(true);
    await _analytics.setDefaultEventParameters({
      'app_source': 'flutter',
      'app_platform': 'flutter',
    });

    _initialized = true;
  }

  Future<void> setUser({
    required String userId,
    String? email,
  }) async {
    await _analytics.setUserId(id: userId);

    if (email != null && email.isNotEmpty) {
      await _analytics.setUserProperty(
        name: 'user_email',
        value: email,
      );
    }
  }

  Future<void> clearUser() async {
    await _analytics.setUserId(id: null);
  }

  Future<void> logUserSessionStart({
    required String userId,
  }) async {
    await _analytics.logEvent(
      name: 'user_session_start',
      parameters: {
        'user_id': userId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<void> logUserSessionEnd({
    required String userId,
    required int sessionDurationSeconds,
  }) async {
    await _analytics.logEvent(
      name: 'user_session_end',
      parameters: {
        'user_id': userId,
        'session_duration': sessionDurationSeconds,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<void> logSectionView({
    required AppSection section,
    String? userId,
  }) async {
    await _analytics.setCurrentScreen(
      screenName: section.name,
    );

    await _analytics.logEvent(
      name: 'section_view',
      parameters: {
        'section': section.name,
        if (userId != null) 'user_id': userId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<void> logSectionInteraction({
    required AppSection section,
    required String action,
    String? userId,
  }) async {
    await _analytics.logEvent(
      name: 'section_interaction',
      parameters: {
        'section': section.name,
        'action': action,
        if (userId != null) 'user_id': userId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<void> logRestaurantView({
    required String restaurantId,
    required String restaurantName,
    String? userId,
  }) async {
    await _analytics.logEvent(
      name: 'restaurant_view',
      parameters: {
        'restaurant_id': restaurantId,
        'restaurant_name': restaurantName,
        if (userId != null) 'user_id': userId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<void> logRestaurantFavorited({
    required String restaurantId,
    required String restaurantName,
    required String userId,
  }) async {
    await _analytics.logEvent(
      name: 'restaurant_favorited',
      parameters: {
        'restaurant_id': restaurantId,
        'restaurant_name': restaurantName,
        'user_id': userId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<void> logRestaurantUnfavorited({
    required String restaurantId,
    required String userId,
  }) async {
    await _analytics.logEvent(
      name: 'restaurant_unfavorited',
      parameters: {
        'restaurant_id': restaurantId,
        'user_id': userId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<void> logSignIn({
    required String method,
    required String userId,
  }) async {
    await _analytics.logLogin(
      loginMethod: method,
      parameters: {
        'user_id': userId,
      },
    );
  }

  Future<void> logSignUp({
    required String method,
    required String userId,
  }) async {
    await _analytics.logSignUp(
      signUpMethod: method,
      parameters: {
        'user_id': userId,
      },
    );
  }

  Future<void> logSearch({
    required String query,
    required int resultsCount,
    String? userId,
  }) async {
    await _analytics.logSearch(
      searchTerm: query,
      parameters: {
        'results_count': resultsCount,
        if (userId != null) 'user_id': userId,
      },
    );
  }

  Future<void> logCompareUsed({
    required String primaryRestaurantId,
    required String secondaryRestaurantId,
    required String selectionMode,
    String? userId,
  }) async {
    await _analytics.logEvent(
      name: 'compare_used',
      parameters: {
        'primary_restaurant_id': primaryRestaurantId,
        'secondary_restaurant_id': secondaryRestaurantId,
        'selection_mode': selectionMode,
        if (userId != null) 'user_id': userId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<void> logFilterUsed({
    required String filterType,
    String? userId,
  }) async {
    await _analytics.logEvent(
      name: 'filter_applied',
      parameters: {
        'filter_type': filterType,
        if (userId != null) 'user_id': userId,
      },
    );
  }

  Future<void> logDirectionsRequested({
    required String restaurantId,
    required String restaurantName,
    String? userId,
  }) async {
    await _analytics.logEvent(
      name: 'directions_requested',
      parameters: {
        'restaurant_id': restaurantId,
        'restaurant_name': restaurantName,
        if (userId != null) 'user_id': userId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<void> logFlutterSmokeTest() async {
    await _analytics.logEvent(
      name: 'flutter_smoke_test',
      parameters: {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }
}