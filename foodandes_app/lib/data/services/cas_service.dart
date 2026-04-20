import 'dart:async';
import 'package:flutter/material.dart';
import 'package:foodandes_app/models/restaurant.dart';

// ─── DiningMood ──────────────────────────────────────────────────────────────

/// A rich context object produced by [CasService.getDiningMood].
class DiningMood {
  final String emoji;
  final String title;
  final String subtitle;

  /// Restaurant categories that fit this meal moment.
  final List<String> recommendedCategories;

  /// Tags that signal a good match (e.g. 'coffee', 'healthy', 'fast').
  final List<String> recommendedTags;

  /// Whether the app should auto-enable the "Open now" filter.
  final bool autoFilterOpen;

  const DiningMood({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.recommendedCategories,
    required this.recommendedTags,
    required this.autoFilterOpen,
  });
}

// ─── CasService ──────────────────────────────────────────────────────────────

/// Context-Aware Service — all decisions driven by the device's local time.
///
/// Features:
///   • [isOpenNow]          — parses "HH:MM AM–HH:MM PM" and checks clock
///   • [getContextMessage]  — greeting string for the current time slot
///   • [isMealTime]         — true during breakfast / lunch / dinner peaks
///   • [getDiningMood]      — rich context object for UI banners & filters
///   • [rankByMoodRelevance]— sorts a restaurant list for the current mood
class CasService {
  CasService._();
  static final CasService instance = CasService._();

  // ─── isOpenNow ─────────────────────────────────────────────────────────────

  /// Parses `"11:30 AM-6:30 PM"` and returns `true` if the current
  /// device time falls within that range.
  bool isOpenNow(String openingHours) {
    try {
      final parts = openingHours.split('-');
      if (parts.length != 2) return false;

      final openTime = _parseTime(parts[0].trim());
      final closeTime = _parseTime(parts[1].trim());
      final now = TimeOfDay.now();

      if (openTime == null || closeTime == null) return false;

      final nowMin = now.hour * 60 + now.minute;
      final openMin = openTime.hour * 60 + openTime.minute;
      final closeMin = closeTime.hour * 60 + closeTime.minute;

      return nowMin >= openMin && nowMin < closeMin;
    } catch (_) {
      return false;
    }
  }

  // ─── getContextMessage ─────────────────────────────────────────────────────

  /// Short greeting shown in banners and app headers.
  String getContextMessage() {
    final hour = TimeOfDay.now().hour;

    if (hour >= 6 && hour < 11) return '🌅 Good morning! Breakfast time.';
    if (hour >= 11 && hour < 14) return '☀️ Lunch time! Check what\'s open.';
    if (hour >= 14 && hour < 18) return '🕑 Afternoon snack time.';
    if (hour >= 18 && hour < 21) return '🌆 Dinner time! Find a restaurant.';
    return '🌙 Most restaurants may be closed now.';
  }

  // ─── isMealTime ────────────────────────────────────────────────────────────

  /// `true` during peak meal windows (app should promote "Open now").
  bool isMealTime() {
    final hour = TimeOfDay.now().hour;
    return (hour >= 7 && hour < 10) ||   // breakfast
           (hour >= 11 && hour < 15) ||  // lunch
           (hour >= 18 && hour < 21);    // dinner
  }

  // ─── getDiningMood ─────────────────────────────────────────────────────────

  /// Returns a rich [DiningMood] for the current moment.
  /// Used by [CasDiningBanner] to render contextual recommendations.
  DiningMood getDiningMood() {
    final hour = TimeOfDay.now().hour;

    if (hour >= 6 && hour < 10) {
      return const DiningMood(
        emoji: '☕',
        title: 'Breakfast time',
        subtitle: 'Start your day with something great',
        recommendedCategories: ['Café', 'Bakery', 'Breakfast', 'Coffee'],
        recommendedTags: ['coffee', 'healthy', 'fast', 'breakfast', 'tea'],
        autoFilterOpen: true,
      );
    }

    if (hour >= 10 && hour < 12) {
      return const DiningMood(
        emoji: '🥐',
        title: 'Brunch o\'clock',
        subtitle: 'The perfect mid-morning bite',
        recommendedCategories: ['Café', 'Bakery', 'International', 'Brunch'],
        recommendedTags: ['brunch', 'coffee', 'eggs', 'sandwich', 'juice'],
        autoFilterOpen: true,
      );
    }

    if (hour >= 12 && hour < 15) {
      return const DiningMood(
        emoji: '🍽️',
        title: 'Lunch time',
        subtitle: 'Recharge for the rest of the day',
        recommendedCategories: [
          'Colombian',
          'Corrientazo',
          'Fast Food',
          'International',
          'Vegetarian',
        ],
        recommendedTags: [
          'almuerzo',
          'corrientazo',
          'fast',
          'healthy',
          'set menu',
        ],
        autoFilterOpen: true,
      );
    }

    if (hour >= 15 && hour < 18) {
      return const DiningMood(
        emoji: '🧃',
        title: 'Afternoon snack',
        subtitle: 'Something light to keep you going',
        recommendedCategories: ['Café', 'Bakery', 'Juice Bar', 'Snacks'],
        recommendedTags: ['coffee', 'juice', 'snack', 'light', 'sweet'],
        autoFilterOpen: false,
      );
    }

    if (hour >= 18 && hour < 22) {
      return const DiningMood(
        emoji: '🌆',
        title: 'Dinner time',
        subtitle: 'Treat yourself after a long day',
        recommendedCategories: [
          'Colombian',
          'Italian',
          'International',
          'Grill',
          'Sushi',
        ],
        recommendedTags: ['dinner', 'grill', 'pizza', 'sushi', 'romantic'],
        autoFilterOpen: true,
      );
    }

    // Late night / dawn
    return const DiningMood(
      emoji: '🌙',
      title: 'Late night',
      subtitle: 'Most places may be closed — check carefully',
      recommendedCategories: ['Fast Food', 'Pizza', '24h'],
      recommendedTags: ['late night', '24h', 'delivery', 'pizza'],
      autoFilterOpen: false,
    );
  }

  // ─── rankByMoodRelevance ───────────────────────────────────────────────────

  /// Returns a new list sorted so that restaurants matching the current
  /// [DiningMood] appear first.
  ///
  /// Relevance score:
  ///   +3  category is in [mood.recommendedCategories]
  ///   +2  each tag that appears in [mood.recommendedTags]
  ///   +1  restaurant is open right now
  List<Restaurant> rankByMoodRelevance(
    List<Restaurant> restaurants, {
    DiningMood? mood,
  }) {
    final m = mood ?? getDiningMood();

    int relevance(Restaurant r) {
      int score = 0;
      final cat = r.category.toLowerCase();
      final rTags = r.tags.map((t) => t.toLowerCase()).toList();

      if (m.recommendedCategories.any((c) => c.toLowerCase() == cat)) {
        score += 3;
      }
      for (final tag in m.recommendedTags) {
        if (rTags.contains(tag.toLowerCase())) score += 2;
      }
      if (r.isOpen) score += 1;
      return score;
    }

    final sorted = List<Restaurant>.from(restaurants);
    sorted.sort((a, b) => relevance(b).compareTo(relevance(a)));
    return sorted;
  }

  // ─── Internal helpers ──────────────────────────────────────────────────────

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
