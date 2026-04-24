import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:foodandes_app/models/restaurant.dart';

class DemandAnalyticsService {
  DemandAnalyticsService._();

  static final DemandAnalyticsService instance = DemandAnalyticsService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _eventsCollection = 'food_demand_events';
  static const String _aggregatesCollection = 'food_demand_time_slots';

  String _dayOfWeek(DateTime date) {
    const days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    return days[date.weekday - 1];
  }

  String _timeSlot(DateTime date) {
    final hour = date.hour;

    if (hour >= 6 && hour < 10) return '06:00-10:00 breakfast';
    if (hour >= 10 && hour < 12) return '10:00-12:00 mid_morning';
    if (hour >= 12 && hour < 15) return '12:00-15:00 lunch';
    if (hour >= 15 && hour < 18) return '15:00-18:00 afternoon';
    if (hour >= 18 && hour < 22) return '18:00-22:00 dinner';

    return '22:00-06:00 night';
  }

  Future<void> recordDemandEvent({
    required Restaurant restaurant,
    required String eventType,
    String? userId,
  }) async {
    try {
      final now = DateTime.now();
      final dayOfWeek = _dayOfWeek(now);
      final timeSlot = _timeSlot(now);
      final normalizedCategory = restaurant.category.trim().toLowerCase();

      final eventData = {
        'restaurant_id': restaurant.id,
        'restaurant_name': restaurant.name,
        'category': restaurant.category,
        'category_normalized': normalizedCategory,
        'event_type': eventType,
        'day_of_week': dayOfWeek,
        'time_slot': timeSlot,
        'hour': now.hour,
        'weekday_number': now.weekday,
        'timestamp': FieldValue.serverTimestamp(),
        if (userId != null) 'user_id': userId,
      };

      await _firestore.collection(_eventsCollection).add(eventData);

      final aggregateId = '${dayOfWeek}_${timeSlot}_$normalizedCategory'
          .replaceAll(' ', '_')
          .replaceAll(':', '');

      await _firestore
          .collection(_aggregatesCollection)
          .doc(aggregateId)
          .set({
        'category': restaurant.category,
        'category_normalized': normalizedCategory,
        'day_of_week': dayOfWeek,
        'time_slot': timeSlot,
        'weekday_number': now.weekday,
        'total_demand_events': FieldValue.increment(1),
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('DemandAnalyticsService.recordDemandEvent ERROR -> $e');
    }
  }
}