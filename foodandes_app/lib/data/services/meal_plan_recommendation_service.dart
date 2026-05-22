import 'dart:math';

import 'package:foodandes_app/data/services/meal_plan_cache_service.dart';
import 'package:foodandes_app/models/meal_plan.dart';
import 'package:foodandes_app/models/restaurant.dart';

class _MealSlotDefinition {
  final String title;
  final String subtitle;
  final List<String> preferredTokens;

  const _MealSlotDefinition({
    required this.title,
    required this.subtitle,
    required this.preferredTokens,
  });
}

extension _MealPlanGoalSlots on MealPlanGoal {
  List<_MealSlotDefinition> get slots {
    switch (this) {
      case MealPlanGoal.balanced:
        return const [
          _MealSlotDefinition(
            title: 'Breakfast or brunch',
            subtitle: 'Start with something light but filling.',
            preferredTokens: ['breakfast', 'brunch', 'coffee', 'cafe', 'café', 'bakery', 'toast'],
          ),
          _MealSlotDefinition(
            title: 'Lunch',
            subtitle: 'Main meal near campus.',
            preferredTokens: ['lunch', 'almuerzo', 'casero', 'traditional', 'colombian', 'parrilla'],
          ),
          _MealSlotDefinition(
            title: 'Study snack',
            subtitle: 'A small option for the afternoon.',
            preferredTokens: ['snack', 'coffee', 'cafe', 'café', 'dessert', 'bakery', 'fast food'],
          ),
          _MealSlotDefinition(
            title: 'Dinner',
            subtitle: 'A reliable option to close the day.',
            preferredTokens: ['dinner', 'pizza', 'italian', 'grill', 'burger', 'parrilla', 'casero'],
          ),
        ];
      case MealPlanGoal.highProtein:
        return const [
          _MealSlotDefinition(
            title: 'Protein breakfast',
            subtitle: 'Searches for filling breakfast or brunch options.',
            preferredTokens: ['eggs', 'protein', 'breakfast', 'brunch', 'toast'],
          ),
          _MealSlotDefinition(
            title: 'Protein lunch',
            subtitle: 'Prioritizes grill, chicken, meat, and filling meals.',
            preferredTokens: ['protein', 'chicken', 'meat', 'beef', 'steak', 'grill', 'parrilla', 'burger'],
          ),
          _MealSlotDefinition(
            title: 'Post-class meal',
            subtitle: 'A second filling option after classes.',
            preferredTokens: ['grill', 'burger', 'steak', 'fast food', 'parrilla', 'protein'],
          ),
        ];
      case MealPlanGoal.vegetarian:
        return const [
          _MealSlotDefinition(
            title: 'Fresh breakfast',
            subtitle: 'Vegetarian-friendly start.',
            preferredTokens: ['vegetarian', 'vegan', 'brunch', 'toast', 'healthy', 'fresh'],
          ),
          _MealSlotDefinition(
            title: 'Vegetarian lunch',
            subtitle: 'Looks for fresh or plant-forward lunch options.',
            preferredTokens: ['vegetarian', 'vegan', 'healthy', 'salad', 'fresh', 'soup', 'casero'],
          ),
          _MealSlotDefinition(
            title: 'Light dinner',
            subtitle: 'Keeps the plan consistent at night.',
            preferredTokens: ['vegetarian', 'healthy', 'salad', 'fresh', 'italian', 'pizza'],
          ),
        ];
      case MealPlanGoal.budget:
        return const [
          _MealSlotDefinition(
            title: 'Affordable lunch',
            subtitle: 'Best balance between price and rating.',
            preferredTokens: ['lunch', 'almuerzo', 'casero', 'corrientazo', 'traditional', 'fast food'],
          ),
          _MealSlotDefinition(
            title: 'Cheap snack',
            subtitle: 'Small option for a student budget.',
            preferredTokens: ['snack', 'coffee', 'cafe', 'café', 'bakery', 'fast food', 'dessert'],
          ),
          _MealSlotDefinition(
            title: 'Budget dinner',
            subtitle: 'A low-cost closing meal.',
            preferredTokens: ['burger', 'fast food', 'pizza', 'casero', 'traditional', 'grill'],
          ),
        ];
      case MealPlanGoal.light:
        return const [
          _MealSlotDefinition(
            title: 'Light breakfast',
            subtitle: 'Fresh start without a heavy meal.',
            preferredTokens: ['healthy', 'fresh', 'toast', 'brunch', 'fruit', 'coffee'],
          ),
          _MealSlotDefinition(
            title: 'Healthy lunch',
            subtitle: 'Prioritizes healthy, salad, soup, or fresh options.',
            preferredTokens: ['healthy', 'salad', 'fresh', 'vegetarian', 'soup', 'casero'],
          ),
          _MealSlotDefinition(
            title: 'Light snack',
            subtitle: 'Useful before class or training.',
            preferredTokens: ['smoothie', 'snack', 'healthy', 'coffee', 'bakery', 'dessert'],
          ),
        ];
      case MealPlanGoal.energy:
        return const [
          _MealSlotDefinition(
            title: 'Coffee boost',
            subtitle: 'Good before a long study block.',
            preferredTokens: ['coffee', 'cafe', 'café', 'bakery', 'brunch', 'dessert'],
          ),
          _MealSlotDefinition(
            title: 'Focus lunch',
            subtitle: 'A complete meal to keep energy stable.',
            preferredTokens: ['lunch', 'almuerzo', 'casero', 'healthy', 'traditional', 'colombian'],
          ),
          _MealSlotDefinition(
            title: 'Late study snack',
            subtitle: 'Fast and practical option during the afternoon.',
            preferredTokens: ['snack', 'coffee', 'fast food', 'dessert', 'bakery', 'burger'],
          ),
          _MealSlotDefinition(
            title: 'Dinner after studying',
            subtitle: 'Useful if the study day runs late.',
            preferredTokens: ['dinner', 'pizza', 'burger', 'italian', 'grill', 'parrilla'],
          ),
        ];
    }
  }
}

class _ScoredRestaurant {
  final Restaurant restaurant;
  final double score;
  final List<String> reasons;

  const _ScoredRestaurant({
    required this.restaurant,
    required this.score,
    required this.reasons,
  });
}

class MealPlanRecommendationService {
  MealPlanRecommendationService._();

  static final MealPlanRecommendationService instance =
      MealPlanRecommendationService._();

  final MealPlanCacheService _cache = MealPlanCacheService.instance;

  Future<MealPlanResult> buildPlan({
    required List<Restaurant> restaurants,
    required MealPlanGoal goal,
    bool onlyOpen = true,
    String selectedPriceRange = 'All',
    List<String> selectedTags = const <String>[],
    bool forceRefresh = false,
  }) async {
    final cacheKey = _cache.buildKey(
      goal: goal,
      onlyOpen: onlyOpen,
      selectedPriceRange: selectedPriceRange,
      selectedTags: selectedTags,
      restaurants: restaurants,
    );

    if (!forceRefresh) {
      final cached = _cache.get(cacheKey);
      if (cached != null) return cached;
    } else {
      _cache.invalidate(cacheKey);
    }

    final result = _calculatePlan(
      restaurants: restaurants,
      goal: goal,
      onlyOpen: onlyOpen,
      selectedPriceRange: selectedPriceRange,
      selectedTags: selectedTags,
      cacheKey: cacheKey,
    );

    _cache.put(cacheKey, result);
    return result;
  }

  MealPlanResult _calculatePlan({
    required List<Restaurant> restaurants,
    required MealPlanGoal goal,
    required bool onlyOpen,
    required String selectedPriceRange,
    required List<String> selectedTags,
    required String cacheKey,
  }) {
    final normalizedTags = _normalizeTokens(selectedTags);
    final filtered = restaurants.where((restaurant) {
      final matchesOpen = !onlyOpen || restaurant.isOpen;
      final matchesPrice = selectedPriceRange == 'All' ||
          restaurant.priceRange.trim() == selectedPriceRange.trim();
      return matchesOpen && matchesPrice;
    }).toList();

    final tagFiltered = normalizedTags.isEmpty
        ? filtered
        : filtered.where((restaurant) {
            final haystack = _searchableText(restaurant);
            return normalizedTags.any((tag) => haystack.contains(tag));
          }).toList();

    final candidates = tagFiltered.isNotEmpty
        ? tagFiltered
        : (filtered.isNotEmpty ? filtered : restaurants);
    final tagFallback = normalizedTags.isNotEmpty &&
        tagFiltered.isEmpty &&
        candidates.isNotEmpty;
    final usedRestaurantIds = <String>{};
    final recommendations = <MealPlanRecommendation>[];

    for (final slot in goal.slots) {
      final scored = candidates.map((restaurant) {
        final baseScore = _scoreRestaurant(
          restaurant: restaurant,
          goal: goal,
          slot: slot,
          selectedTags: normalizedTags,
        );
        final duplicatePenalty = usedRestaurantIds.contains(restaurant.id) ? 22.0 : 0.0;
        final double score = max(0.0, baseScore - duplicatePenalty).toDouble();
        return _ScoredRestaurant(
          restaurant: restaurant,
          score: score,
          reasons: _buildReasons(
            restaurant: restaurant,
            goal: goal,
            slot: slot,
            selectedPriceRange: selectedPriceRange,
            selectedTags: normalizedTags,
            cameFromFallback: (filtered.isEmpty && restaurants.isNotEmpty) || tagFallback,
          ),
        );
      }).toList()
        ..sort((a, b) => b.score.compareTo(a.score));

      if (scored.isEmpty) continue;

      final selected = scored.first;
      usedRestaurantIds.add(selected.restaurant.id);
      recommendations.add(
        MealPlanRecommendation(
          slotTitle: slot.title,
          slotSubtitle: slot.subtitle,
          restaurant: selected.restaurant,
          matchScore: selected.score.clamp(0.0, 100.0).toDouble(),
          reasons: selected.reasons,
        ),
      );
    }

    return MealPlanResult(
      goal: goal,
      recommendations: recommendations,
      generatedAt: DateTime.now(),
      fromCache: false,
      cacheKey: cacheKey,
      selectedTags: selectedTags,
    );
  }

  double _scoreRestaurant({
    required Restaurant restaurant,
    required MealPlanGoal goal,
    required _MealSlotDefinition slot,
    required List<String> selectedTags,
  }) {
    final haystack = _searchableText(restaurant);
    var score = 0.0;

    score += restaurant.isOpen ? 16 : 0;
    score += (restaurant.rating / 5.0).clamp(0.0, 1.0).toDouble() * 22;
    score += min(restaurant.reviewCount, 80).toDouble() / 80 * 10;
    score += _priceScore(restaurant.priceRange, goal);

    for (final token in slot.preferredTokens) {
      if (haystack.contains(token.toLowerCase())) {
        score += 11;
      }
    }

    for (final token in _goalTokens(goal)) {
      if (haystack.contains(token.toLowerCase())) {
        score += 7;
      }
    }

    for (final token in selectedTags) {
      if (haystack.contains(token)) {
        score += 14;
      }
    }

    if (restaurant.isFavorite) score += 5;

    return score.clamp(0.0, 100.0).toDouble();
  }

  List<String> _normalizeTokens(List<String> tokens) {
    return tokens
        .map((token) => token.trim().toLowerCase())
        .where((token) => token.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  String _searchableText(Restaurant restaurant) {
    return [
      restaurant.name,
      restaurant.category,
      restaurant.description,
      restaurant.tags.join(' '),
    ].join(' ').toLowerCase();
  }

  List<String> _goalTokens(MealPlanGoal goal) {
    switch (goal) {
      case MealPlanGoal.balanced:
        return ['casero', 'healthy', 'traditional', 'lunch', 'brunch', 'dinner'];
      case MealPlanGoal.highProtein:
        return ['protein', 'grill', 'parrilla', 'steak', 'meat', 'beef', 'chicken', 'burger'];
      case MealPlanGoal.vegetarian:
        return ['vegetarian', 'vegan', 'healthy', 'salad', 'fresh', 'toast'];
      case MealPlanGoal.budget:
        return ['casero', 'corrientazo', 'fast food', 'lunch', 'snack', 'burger'];
      case MealPlanGoal.light:
        return ['healthy', 'fresh', 'salad', 'soup', 'vegetarian', 'toast'];
      case MealPlanGoal.energy:
        return ['coffee', 'cafe', 'café', 'lunch', 'snack', 'dessert', 'bakery'];
    }
  }

  double _priceScore(String priceRange, MealPlanGoal goal) {
    final normalized = priceRange.trim();

    if (goal == MealPlanGoal.budget) {
      switch (normalized) {
        case r'$':
          return 22;
        case r'$$':
          return 17;
        case r'$$$':
          return 7;
        case r'$$$$':
          return 2;
        default:
          return 8;
      }
    }

    switch (normalized) {
      case r'$':
        return 12;
      case r'$$':
        return 10;
      case r'$$$':
        return 7;
      case r'$$$$':
        return 4;
      default:
        return 6;
    }
  }

  List<String> _buildReasons({
    required Restaurant restaurant,
    required MealPlanGoal goal,
    required _MealSlotDefinition slot,
    required String selectedPriceRange,
    required List<String> selectedTags,
    required bool cameFromFallback,
  }) {
    final reasons = <String>[];
    final haystack = _searchableText(restaurant);

    final matchedSlotTokens = slot.preferredTokens
        .where((token) => haystack.contains(token.toLowerCase()))
        .take(2)
        .toList();

    if (matchedSlotTokens.isNotEmpty) {
      reasons.add('Matches ${matchedSlotTokens.join(', ')}');
    }

    final matchedSelectedTags = selectedTags
        .where((token) => haystack.contains(token))
        .take(2)
        .toList();
    if (matchedSelectedTags.isNotEmpty) {
      reasons.add('Selected tags: ${matchedSelectedTags.join(', ')}');
    }

    if (restaurant.rating >= 4.5) reasons.add('High rating');
    if (restaurant.isOpen) reasons.add('Open now');
    if (restaurant.priceRange == r'$' || restaurant.priceRange == r'$$') {
      reasons.add('Student-friendly price');
    }
    if (restaurant.isFavorite) reasons.add('Already in favorites');
    if (selectedPriceRange != 'All') reasons.add('Fits $selectedPriceRange budget');
    if (cameFromFallback) reasons.add('Fallback: few exact matches');

    if (reasons.isEmpty) reasons.add(goal.label);
    return reasons.take(4).toList();
  }
}
