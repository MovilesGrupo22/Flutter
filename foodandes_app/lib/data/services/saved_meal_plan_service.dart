import 'dart:convert';

import 'package:foodandes_app/models/meal_plan.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedMealPlanService {
  SavedMealPlanService._();

  static final SavedMealPlanService instance = SavedMealPlanService._();
  factory SavedMealPlanService() => instance;

  static const String _keySavedPlans = 'saved_meal_plans_v1';
  static const int _maxSavedPlans = 10;

  Future<List<SavedMealPlan>> getSavedPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySavedPlans);
    if (raw == null || raw.trim().isEmpty) return const <SavedMealPlan>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <SavedMealPlan>[];

      final plans = decoded
          .whereType<Map>()
          .map((item) => SavedMealPlan.fromJson(Map<String, dynamic>.from(item)))
          .where((plan) => plan.result.recommendations.isNotEmpty)
          .toList()
        ..sort((a, b) => b.savedAt.compareTo(a.savedAt));

      return plans;
    } catch (_) {
      return const <SavedMealPlan>[];
    }
  }

  Future<void> savePlan(MealPlanResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final plans = await getSavedPlans();
    final now = DateTime.now();
    final newPlan = SavedMealPlan(
      id: '${now.millisecondsSinceEpoch}_${result.goal.name}',
      savedAt: now,
      result: result.copyWith(
        fromCache: false,
        cachedAt: null,
        generatedAt: result.generatedAt,
      ),
    );

    final updated = <SavedMealPlan>[
      newPlan,
      ...plans.where((plan) => !_isSamePlan(plan.result, result)),
    ].take(_maxSavedPlans).toList();

    await prefs.setString(
      _keySavedPlans,
      jsonEncode(updated.map((plan) => plan.toJson()).toList()),
    );
  }

  Future<void> deletePlan(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final plans = await getSavedPlans();
    final updated = plans.where((plan) => plan.id != id).toList();
    await prefs.setString(
      _keySavedPlans,
      jsonEncode(updated.map((plan) => plan.toJson()).toList()),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySavedPlans);
  }

  bool _isSamePlan(MealPlanResult a, MealPlanResult b) {
    final aRestaurants = a.recommendations.map((item) => item.restaurant.id).join('|');
    final bRestaurants = b.recommendations.map((item) => item.restaurant.id).join('|');
    final aTags = [...a.selectedTags]..sort();
    final bTags = [...b.selectedTags]..sort();

    return a.goal == b.goal &&
        aRestaurants == bRestaurants &&
        aTags.join('|') == bTags.join('|');
  }
}
