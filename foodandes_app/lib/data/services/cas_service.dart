import 'dart:async';
import 'package:flutter/material.dart';

class CasService {
  CasService._();
  static final CasService instance = CasService._();

  // Parses "11:30 AM-6:30 PM" and returns true if current device time is within range
  bool isOpenNow(String openingHours) {
    try {
      // Split by "-" → ["11:30 AM", "6:30 PM"]
      final parts = openingHours.split('-');
      if (parts.length != 2) return false;

      final openTime = _parseTime(parts[0].trim());
      final closeTime = _parseTime(parts[1].trim());
      final now = TimeOfDay.now();

      if (openTime == null || closeTime == null) return false;

      final nowMinutes = now.hour * 60 + now.minute;
      final openMinutes = openTime.hour * 60 + openTime.minute;
      final closeMinutes = closeTime.hour * 60 + closeTime.minute;

      return nowMinutes >= openMinutes && nowMinutes < closeMinutes;
    } catch (_) {
      return false;
    }
  }

  // Returns a human-readable context message based on current time
  String getContextMessage() {
    final hour = TimeOfDay.now().hour;

    if (hour >= 6 && hour < 11) return '🌅 Good morning! Breakfast time.';
    if (hour >= 11 && hour < 14) return '☀️ Lunch time! Check what\'s open.';
    if (hour >= 14 && hour < 18) return '🕑 Afternoon snack time.';
    if (hour >= 18 && hour < 21) return '🌆 Dinner time! Find a restaurant.';
    return '🌙 Most restaurants may be closed now.';
  }

  // Returns true if it's a peak meal hour (app should auto-enable Open filter)
  bool isMealTime() {
    final hour = TimeOfDay.now().hour;
    return (hour >= 7 && hour < 10) ||   // breakfast
           (hour >= 11 && hour < 15) ||  // lunch
           (hour >= 18 && hour < 21);    // dinner
  }

  // Parses "11:30 AM" or "6:30 PM" into TimeOfDay
  TimeOfDay? _parseTime(String timeStr) {
    try {
      final isPM = timeStr.toUpperCase().contains('PM');
      final isAM = timeStr.toUpperCase().contains('AM');

      final cleaned = timeStr
          .toUpperCase()
          .replaceAll('AM', '')
          .replaceAll('PM', '')
          .trim();

      final timeParts = cleaned.split(':');
      if (timeParts.length != 2) return null;

      int hour = int.parse(timeParts[0].trim());
      final minute = int.parse(timeParts[1].trim());

      if (isPM && hour != 12) hour += 12;
      if (isAM && hour == 12) hour = 0;

      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }
}