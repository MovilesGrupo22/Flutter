import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:foodandes_app/data/services/section_usage_service.dart';

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

  AppSection? sectionFromRouteName(String? routeName) {
    switch (routeName) {
      case '/home':
      case '/home-filtered':
        return AppSection.home;
      case '/map':
        return AppSection.map;
      case '/search-empty':
      case '/search-active':
        return AppSection.search;
      case '/favorites':
      case '/favorites-empty':
        return AppSection.favorites;
      case '/profile':
        return AppSection.profile;
      case '/restaurant-detail':
      case '/reviews':
      case '/write-review':
      case '/compare-restaurants':
        return AppSection.detail;
      default:
        return null;
    }
  }

  String _normalizeRouteName(String? routeName) {
    if (routeName == null || routeName.trim().isEmpty) {
      return 'unknown';
    }
    return routeName.replaceAll('/', '').replaceAll('-', '_');
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

    unawaited(
      SectionUsageService.instance.recordSectionView(section.name),
    );
  }

  Future<void> logSectionInteraction({
    required AppSection section,
    required String action,
    String? userId,
    Map<String, Object>? additionalParameters,
  }) async {
    await _analytics.logEvent(
      name: 'section_interaction',
      parameters: {
        'section': section.name,
        'action': action,
        if (userId != null) 'user_id': userId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        ...?additionalParameters,
      },
    );

    unawaited(
      SectionUsageService.instance.recordSectionInteraction(
        section: section.name,
        action: action,
      ),
    );
  }

  Future<void> logNavigationFlow({
    required String destinationRoute,
    String? sourceRoute,
    String? userId,
  }) async {
    final fromSection = sectionFromRouteName(sourceRoute);
    final toSection = sectionFromRouteName(destinationRoute);

    await _analytics.logEvent(
      name: 'screen_navigation_flow',
      parameters: {
        'from_route': _normalizeRouteName(sourceRoute),
        'to_route': _normalizeRouteName(destinationRoute),
        if (fromSection != null) 'from_section': fromSection.name,
        if (toSection != null) 'to_section': toSection.name,
        if (userId != null) 'user_id': userId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<void> logRestaurantView({
    required String restaurantId,
    required String restaurantName,
    String? userId,
    String? source,
  }) async {
    await _analytics.logEvent(
      name: 'restaurant_view',
      parameters: {
        'restaurant_id': restaurantId,
        'restaurant_name': restaurantName,
        if (userId != null) 'user_id': userId,
        if (source != null) 'source': source,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<void> logRestaurantFavorited({
    required String restaurantId,
    required String restaurantName,
    required String userId,
    String? favoriteSource,
  }) async {
    await _analytics.logEvent(
      name: 'restaurant_favorited',
      parameters: {
        'restaurant_id': restaurantId,
        'restaurant_name': restaurantName,
        'user_id': userId,
        if (favoriteSource != null) 'favorite_source': favoriteSource,
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

class AppNavigationObserver extends NavigatorObserver {
  void _trackNavigation(
    Route<dynamic>? route,
    Route<dynamic>? previousRoute,
  ) {
    final destinationRoute = route?.settings.name;
    final sourceRoute = previousRoute?.settings.name;

    if (destinationRoute == null || destinationRoute == sourceRoute) {
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;

    unawaited(
      AnalyticsService.instance.logNavigationFlow(
        sourceRoute: sourceRoute,
        destinationRoute: destinationRoute,
        userId: userId,
      ),
    );
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _trackNavigation(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _trackNavigation(newRoute, oldRoute);
  }
}
