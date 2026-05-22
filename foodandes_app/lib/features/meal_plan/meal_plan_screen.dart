import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foodandes_app/core/constants/app_colors.dart';
import 'package:foodandes_app/data/repositories/restaurant_repository.dart';
import 'package:foodandes_app/data/services/analytics_service.dart';
import 'package:foodandes_app/data/services/connectivity_service.dart';
import 'package:foodandes_app/data/services/meal_plan_cache_service.dart';
import 'package:foodandes_app/data/services/meal_plan_recommendation_service.dart';
import 'package:foodandes_app/data/services/saved_meal_plan_service.dart';
import 'package:foodandes_app/features/restaurant/restaurant_detail_screen.dart';
import 'package:foodandes_app/models/meal_plan.dart';
import 'package:foodandes_app/models/restaurant.dart';
import 'package:foodandes_app/shared/widgets/offline_banner.dart';
import 'package:foodandes_app/shared/widgets/restaurant_card.dart';

class MealPlanScreen extends StatefulWidget {
  static const String routeName = '/meal-plan';

  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  final RestaurantRepository _repository = RestaurantRepository();
  final SavedMealPlanService _savedMealPlanService = SavedMealPlanService.instance;

  Future<MealPlanResult>? _mealPlanFuture;
  Future<List<SavedMealPlan>>? _savedPlansFuture;
  StreamSubscription<bool>? _connectivitySubscription;

  MealPlanGoal _selectedGoal = MealPlanGoal.balanced;
  String _selectedPriceRange = 'All';
  bool _onlyOpen = true;
  bool _isOffline = false;
  List<String> _priceOptions = const ['All'];
  List<String> _availableTagOptions = const [
    'Healthy',
    'Vegetarian',
    'Protein',
    'Coffee',
    'Brunch',
    'Fast Food',
    'Pizza',
    'Burger',
    'Bakery',
    'Dessert',
  ];
  final Set<String> _selectedTags = <String>{};

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _savedPlansFuture = _savedMealPlanService.getSavedPlans();
    _mealPlanFuture = _loadMealPlan();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      unawaited(
        AnalyticsService.instance.logSectionView(
          section: AppSection.mealPlan,
          userId: userId,
        ),
      );
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _initConnectivity() {
    _connectivitySubscription = ConnectivityService.instance.isOnlineStream.listen(
      (isOnline) {
        if (!mounted) return;
        setState(() => _isOffline = !isOnline);
      },
    );
    unawaited(_loadInitialConnectivityState());
  }

  Future<void> _loadInitialConnectivityState() async {
    final online = await ConnectivityService.instance.isOnline;
    if (!mounted) return;
    setState(() => _isOffline = !online);
  }

  Future<MealPlanResult> _loadMealPlan({bool forceRefresh = false}) async {
    final restaurants = await _repository.fetchRestaurants();
    _updateFilterOptions(restaurants);

    final selectedTags = _selectedTags.toList()..sort();
    final result = await MealPlanRecommendationService.instance.buildPlan(
      restaurants: restaurants,
      goal: _selectedGoal,
      onlyOpen: _onlyOpen,
      selectedPriceRange: _selectedPriceRange,
      selectedTags: selectedTags,
      forceRefresh: forceRefresh,
    );

    unawaited(
      _logMealPlanInteraction(
        result.fromCache ? 'meal_plan_cache_hit' : 'meal_plan_cache_miss',
        additionalParameters: {
          'goal': _selectedGoal.name,
          'only_open': _onlyOpen ? 'true' : 'false',
          'price_range': _selectedPriceRange,
          'selected_tags': selectedTags.join(','),
          'recommendations_count': result.recommendations.length,
        },
      ),
    );

    return result;
  }

  void _updateFilterOptions(List<Restaurant> restaurants) {
    final priceOptions = _repository.extractPriceRanges(restaurants);
    final tagOptions = _extractTagOptions(restaurants);

    if (!mounted) return;
    setState(() {
      _priceOptions = priceOptions;
      _availableTagOptions = tagOptions;
      if (!_priceOptions.contains(_selectedPriceRange)) {
        _selectedPriceRange = 'All';
      }
      _selectedTags.removeWhere((tag) => !_availableTagOptions.contains(tag));
    });
  }

  List<String> _extractTagOptions(List<Restaurant> restaurants) {
    const curatedTags = <String>[
      'Healthy',
      'Vegetarian',
      'Vegan',
      'Protein',
      'Salad',
      'Soup',
      'Fresh',
      'Coffee',
      'Brunch',
      'Lunch',
      'Bakery',
      'Dessert',
      'Fast Food',
      'Pizza',
      'Burger',
      'Grill',
      'Parrilla',
      'Casero',
      'Traditional',
      'Colombian',
    ];

    final tags = <String>{...curatedTags};
    for (final restaurant in restaurants) {
      tags.add(restaurant.category.trim());
      for (final tag in restaurant.tags) {
        tags.add(tag.trim());
      }
    }

    final sorted = tags
        .where((tag) => tag.isNotEmpty && tag.length <= 24)
        .map(_titleCase)
        .toSet()
        .toList()
      ..sort();

    final prioritized = [
      ...curatedTags.where(sorted.contains),
      ...sorted.where((tag) => !curatedTags.contains(tag)),
    ];

    return prioritized.take(28).toList();
  }

  String _titleCase(String value) {
    final words = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) {
      if (word.length == 1) return word.toUpperCase();
      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    });
    return words.join(' ');
  }

  Future<void> _logMealPlanInteraction(
    String action, {
    Map<String, Object>? additionalParameters,
  }) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      await AnalyticsService.instance.logSectionInteraction(
        section: AppSection.mealPlan,
        action: action,
        userId: userId,
        additionalParameters: additionalParameters,
      );
    } catch (error) {
      debugPrint('MealPlanScreen analytics ERROR -> $error');
    }
  }

  void _reload({bool forceRefresh = false}) {
    setState(() {
      _mealPlanFuture = _loadMealPlan(forceRefresh: forceRefresh);
    });
  }

  void _reloadSavedPlans() {
    setState(() {
      _savedPlansFuture = _savedMealPlanService.getSavedPlans();
    });
  }

  Future<void> _refresh() async {
    _reload(forceRefresh: true);
    await _mealPlanFuture;
  }

  Future<void> _savePlan(MealPlanResult result) async {
    await _savedMealPlanService.savePlan(
      result.copyWith(selectedTags: _selectedTags.toList()..sort()),
    );
    if (!mounted) return;
    _reloadSavedPlans();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Meal plan saved locally.')),
    );
    unawaited(
      _logMealPlanInteraction(
        'meal_plan_saved',
        additionalParameters: {
          'goal': result.goal.name,
          'selected_tags': result.selectedTags.join(','),
          'recommendations_count': result.recommendations.length,
        },
      ),
    );
  }

  Future<void> _deleteSavedPlan(String id) async {
    await _savedMealPlanService.deletePlan(id);
    if (!mounted) return;
    _reloadSavedPlans();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved meal plan deleted.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Planner'),
        actions: [
          IconButton(
            tooltip: 'Clear meal-plan cache',
            onPressed: () {
              MealPlanCacheService.instance.clear();
              _reload(forceRefresh: true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Meal-plan cache cleared.')),
              );
            },
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          OfflineBanner(isOffline: _isOffline),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<MealPlanResult>(
                future: _mealPlanFuture,
                builder: (context, snapshot) {
                  final children = <Widget>[
                    _buildIntroCard(),
                    const SizedBox(height: 14),
                    _buildControlsCard(),
                    const SizedBox(height: 14),
                    _buildSavedPlansCard(),
                    const SizedBox(height: 14),
                  ];

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    children.add(_buildLoadingCard());
                  } else if (snapshot.hasError) {
                    children.add(_buildErrorCard(snapshot.error));
                  } else {
                    final result = snapshot.data;
                    if (result == null || result.recommendations.isEmpty) {
                      children.add(_buildEmptyCard());
                    } else {
                      children
                        ..add(_buildCacheStatusCard(result))
                        ..add(const SizedBox(height: 14))
                        ..add(_buildSavePlanCard(result))
                        ..add(const SizedBox(height: 14));

                      for (final recommendation in result.recommendations) {
                        children
                          ..add(_buildMealSlotCard(recommendation))
                          ..add(const SizedBox(height: 16));
                      }
                    }
                  }

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: children,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7C8A5)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.restaurant_menu, color: AppColors.primary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Build a food plan and match each meal with restaurants using multiple selected tags, categories, price, rating, and open status. Generated plans are cached and saved plans stay available locally.',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Food goal',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedGoal.description,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MealPlanGoal.values.map((goal) {
                return ChoiceChip(
                  label: Text(goal.label),
                  selected: _selectedGoal == goal,
                  onSelected: (_) async {
                    setState(() => _selectedGoal = goal);
                    _reload();
                    await _logMealPlanInteraction(
                      'meal_plan_goal_selected',
                      additionalParameters: {'goal': goal.name},
                    );
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Preference tags',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                if (_selectedTags.isNotEmpty)
                  TextButton.icon(
                    onPressed: () async {
                      setState(_selectedTags.clear);
                      _reload();
                      await _logMealPlanInteraction('meal_plan_tags_cleared');
                    },
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Select more than one tag to personalize the restaurants used in the plan.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableTagOptions.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (selected) async {
                    setState(() {
                      if (selected) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                    _reload();
                    await _logMealPlanInteraction(
                      selected ? 'meal_plan_tag_selected' : 'meal_plan_tag_removed',
                      additionalParameters: {
                        'tag': tag,
                        'selected_tags': (_selectedTags.toList()..sort()).join(','),
                      },
                    );
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedPriceRange,
              decoration: const InputDecoration(
                labelText: 'Budget filter',
                border: OutlineInputBorder(),
              ),
              items: _priceOptions
                  .map(
                    (price) => DropdownMenuItem(
                      value: price,
                      child: Text(price),
                    ),
                  )
                  .toList(),
              onChanged: (value) async {
                if (value == null) return;
                setState(() => _selectedPriceRange = value);
                _reload();
                await _logMealPlanInteraction(
                  'meal_plan_price_filter_selected',
                  additionalParameters: {'price_range': value},
                );
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Recommend only open restaurants'),
              subtitle: const Text('If there are no exact matches, the plan falls back to the best available options.'),
              value: _onlyOpen,
              onChanged: (value) async {
                setState(() => _onlyOpen = value);
                _reload();
                await _logMealPlanInteraction(
                  'meal_plan_open_filter_changed',
                  additionalParameters: {'only_open': value ? 'true' : 'false'},
                );
              },
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  _reload(forceRefresh: true);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Regenerate plan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedPlansCard() {
    return FutureBuilder<List<SavedMealPlan>>(
      future: _savedPlansFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: ListTile(
              leading: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              title: Text('Loading saved meal plans...'),
            ),
          );
        }

        final savedPlans = snapshot.data ?? const <SavedMealPlan>[];
        return Card(
          child: ExpansionTile(
            leading: const Icon(Icons.bookmarks_outlined),
            title: const Text('Saved meal plans'),
            subtitle: Text(
              savedPlans.isEmpty
                  ? 'Save a recommended plan to keep it locally.'
                  : '${savedPlans.length} saved locally',
            ),
            children: savedPlans.isEmpty
                ? const [
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text(
                        'No saved plans yet. Generate a recommendation and use Save this plan.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ]
                : savedPlans.map(_buildSavedPlanTile).toList(),
          ),
        );
      },
    );
  }

  Widget _buildSavedPlanTile(SavedMealPlan plan) {
    final selectedTags = plan.result.selectedTags;
    final summary = plan.result.recommendations
        .map((item) => '${item.slotTitle}: ${item.restaurant.name}')
        .join(' • ');

    return ListTile(
      title: Text(plan.result.goal.label),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Saved ${_formatTime(plan.savedAt)}'),
          if (selectedTags.isNotEmpty)
            Text('Tags: ${selectedTags.join(', ')}'),
          Text(
            summary,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const Text(
            'Tap to preview saved plan.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
      isThreeLine: true,
      trailing: IconButton(
        tooltip: 'Delete saved plan',
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _deleteSavedPlan(plan.id),
      ),
      onTap: () => _showSavedPlanDetails(plan),
    );
  }

  void _showSavedPlanDetails(SavedMealPlan plan) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: [
              Text(
                plan.result.goal.label,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Saved ${_formatTime(plan.savedAt)}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              if (plan.result.selectedTags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: plan.result.selectedTags
                      .map((tag) => Chip(label: Text(tag)))
                      .toList(),
                ),
              ],
              const SizedBox(height: 12),
              ...plan.result.recommendations.map(
                (recommendation) => Card(
                  child: ListTile(
                    title: Text(recommendation.slotTitle),
                    subtitle: Text(
                      '${recommendation.restaurant.name}\nMatch ${recommendation.matchScore.toStringAsFixed(0)} · ${recommendation.reasons.join(', ')}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(
                        this.context,
                        RestaurantDetailScreen.routeName,
                        arguments: recommendation.restaurant.id,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Matching restaurants with your food plan...'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(Object? error) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          'Could not build the meal plan: $error',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildEmptyCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Text(
          'No restaurants were available to build a meal plan. Try syncing the app online first.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildCacheStatusCard(MealPlanResult result) {
    final label = result.fromCache
        ? 'Loaded from meal-plan cache'
        : 'Fresh plan calculated and cached';
    final icon = result.fromCache ? Icons.cached : Icons.auto_awesome;
    final cacheTime = result.cachedAt ?? result.generatedAt;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: result.fromCache ? const Color(0xFFE9F7EF) : const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: result.fromCache ? const Color(0xFF9AD4AF) : const Color(0xFFA7C7F2),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: result.fromCache ? AppColors.success : AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$label · ${_formatTime(cacheTime)} · cache entries: ${MealPlanCacheService.instance.size}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavePlanCard(MealPlanResult result) {
    final selectedTags = result.selectedTags.isEmpty
        ? 'No extra tags'
        : result.selectedTags.join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Keep this recommendation',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Goal: ${result.goal.label} · Tags: $selectedTags',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _savePlan(result),
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Save this plan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealSlotCard(MealPlanRecommendation recommendation) {
    final restaurant = recommendation.restaurant;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFFFE1C2),
                  foregroundColor: AppColors.primary,
                  child: Text(
                    recommendation.matchScore.round().toString(),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recommendation.slotTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        recommendation.slotSubtitle,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            RestaurantCard(
              restaurant: restaurant,
              compact: true,
              onTap: () async {
                await _logMealPlanInteraction(
                  'open_restaurant_from_meal_plan',
                  additionalParameters: {
                    'restaurant_id': restaurant.id,
                    'slot': recommendation.slotTitle,
                    'goal': _selectedGoal.name,
                  },
                );
                if (!mounted) return;
                await Navigator.pushNamed(
                  context,
                  RestaurantDetailScreen.routeName,
                  arguments: restaurant.id,
                );
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.insights, size: 18),
                  label: Text('Match ${recommendation.matchScore.toStringAsFixed(0)}'),
                ),
                ...recommendation.reasons.map(
                  (reason) => Chip(
                    avatar: const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(reason),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
