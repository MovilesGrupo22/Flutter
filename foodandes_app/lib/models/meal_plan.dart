import 'package:foodandes_app/models/restaurant.dart';

enum MealPlanGoal {
  balanced,
  highProtein,
  vegetarian,
  budget,
  light,
  energy,
}

extension MealPlanGoalPresentation on MealPlanGoal {
  String get label {
    switch (this) {
      case MealPlanGoal.balanced:
        return 'Balanced day';
      case MealPlanGoal.highProtein:
        return 'High protein';
      case MealPlanGoal.vegetarian:
        return 'Vegetarian';
      case MealPlanGoal.budget:
        return 'Budget student';
      case MealPlanGoal.light:
        return 'Light & healthy';
      case MealPlanGoal.energy:
        return 'Study energy';
    }
  }

  String get description {
    switch (this) {
      case MealPlanGoal.balanced:
        return 'A mix of filling, healthy, and reliable options for the day.';
      case MealPlanGoal.highProtein:
        return 'Prioritizes grill, meat, eggs, chicken, and filling meals.';
      case MealPlanGoal.vegetarian:
        return 'Looks for vegetarian, fresh, salad, healthy, and brunch tags.';
      case MealPlanGoal.budget:
        return 'Prioritizes affordable student-friendly restaurants.';
      case MealPlanGoal.light:
        return 'Prioritizes fresh, healthy, salad, soup, and low-heavy meals.';
      case MealPlanGoal.energy:
        return 'Looks for coffee, snacks, lunch, and dinner options for study days.';
    }
  }

  static MealPlanGoal fromName(String? name) {
    return MealPlanGoal.values.firstWhere(
      (goal) => goal.name == name,
      orElse: () => MealPlanGoal.balanced,
    );
  }
}

class MealPlanRecommendation {
  final String slotTitle;
  final String slotSubtitle;
  final Restaurant restaurant;
  final double matchScore;
  final List<String> reasons;

  const MealPlanRecommendation({
    required this.slotTitle,
    required this.slotSubtitle,
    required this.restaurant,
    required this.matchScore,
    required this.reasons,
  });

  Map<String, dynamic> toJson() {
    return {
      'slotTitle': slotTitle,
      'slotSubtitle': slotSubtitle,
      'restaurant': restaurant.toJson(),
      'matchScore': matchScore,
      'reasons': reasons,
    };
  }

  factory MealPlanRecommendation.fromJson(Map<String, dynamic> json) {
    return MealPlanRecommendation(
      slotTitle: (json['slotTitle'] ?? '') as String,
      slotSubtitle: (json['slotSubtitle'] ?? '') as String,
      restaurant: Restaurant.fromJson(
        Map<String, dynamic>.from(json['restaurant'] as Map? ?? const {}),
      ),
      matchScore: (json['matchScore'] is num)
          ? (json['matchScore'] as num).toDouble()
          : 0.0,
      reasons: json['reasons'] is List
          ? List<String>.from(json['reasons'] as List)
          : const <String>[],
    );
  }
}

class MealPlanResult {
  final MealPlanGoal goal;
  final List<MealPlanRecommendation> recommendations;
  final DateTime generatedAt;
  final bool fromCache;
  final String cacheKey;
  final DateTime? cachedAt;
  final List<String> selectedTags;

  const MealPlanResult({
    required this.goal,
    required this.recommendations,
    required this.generatedAt,
    required this.fromCache,
    required this.cacheKey,
    this.cachedAt,
    this.selectedTags = const <String>[],
  });

  MealPlanResult copyWith({
    MealPlanGoal? goal,
    List<MealPlanRecommendation>? recommendations,
    DateTime? generatedAt,
    bool? fromCache,
    String? cacheKey,
    DateTime? cachedAt,
    List<String>? selectedTags,
  }) {
    return MealPlanResult(
      goal: goal ?? this.goal,
      recommendations: recommendations ?? this.recommendations,
      generatedAt: generatedAt ?? this.generatedAt,
      fromCache: fromCache ?? this.fromCache,
      cacheKey: cacheKey ?? this.cacheKey,
      cachedAt: cachedAt ?? this.cachedAt,
      selectedTags: selectedTags ?? this.selectedTags,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'goal': goal.name,
      'recommendations': recommendations.map((item) => item.toJson()).toList(),
      'generatedAt': generatedAt.toIso8601String(),
      'fromCache': fromCache,
      'cacheKey': cacheKey,
      'cachedAt': cachedAt?.toIso8601String(),
      'selectedTags': selectedTags,
    };
  }

  factory MealPlanResult.fromJson(Map<String, dynamic> json) {
    final recommendationsJson = json['recommendations'];
    return MealPlanResult(
      goal: MealPlanGoalPresentation.fromName(json['goal'] as String?),
      recommendations: recommendationsJson is List
          ? recommendationsJson
              .map(
                (item) => MealPlanRecommendation.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList()
          : const <MealPlanRecommendation>[],
      generatedAt: DateTime.tryParse((json['generatedAt'] ?? '') as String) ??
          DateTime.now(),
      fromCache: (json['fromCache'] ?? false) as bool,
      cacheKey: (json['cacheKey'] ?? '') as String,
      cachedAt: DateTime.tryParse((json['cachedAt'] ?? '') as String),
      selectedTags: json['selectedTags'] is List
          ? List<String>.from(json['selectedTags'] as List)
          : const <String>[],
    );
  }
}

class SavedMealPlan {
  final String id;
  final DateTime savedAt;
  final MealPlanResult result;

  const SavedMealPlan({
    required this.id,
    required this.savedAt,
    required this.result,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'savedAt': savedAt.toIso8601String(),
      'result': result.toJson(),
    };
  }

  factory SavedMealPlan.fromJson(Map<String, dynamic> json) {
    return SavedMealPlan(
      id: (json['id'] ?? '') as String,
      savedAt: DateTime.tryParse((json['savedAt'] ?? '') as String) ??
          DateTime.now(),
      result: MealPlanResult.fromJson(
        Map<String, dynamic>.from(json['result'] as Map? ?? const {}),
      ),
    );
  }
}
