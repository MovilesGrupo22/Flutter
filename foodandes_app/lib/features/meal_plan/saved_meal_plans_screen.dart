import 'package:flutter/material.dart';
import 'package:foodandes_app/core/constants/app_colors.dart';
import 'package:foodandes_app/data/services/saved_meal_plan_service.dart';
import 'package:foodandes_app/features/meal_plan/meal_plan_screen.dart';
import 'package:foodandes_app/features/restaurant/restaurant_detail_screen.dart';
import 'package:foodandes_app/models/meal_plan.dart';

class SavedMealPlansScreen extends StatefulWidget {
  static const String routeName = '/saved-meal-plans';

  const SavedMealPlansScreen({super.key});

  @override
  State<SavedMealPlansScreen> createState() => _SavedMealPlansScreenState();
}

class _SavedMealPlansScreenState extends State<SavedMealPlansScreen> {
  final SavedMealPlanService _savedMealPlanService = SavedMealPlanService.instance;
  late Future<List<SavedMealPlan>> _savedPlansFuture;

  @override
  void initState() {
    super.initState();
    _savedPlansFuture = _savedMealPlanService.getSavedPlans();
  }

  void _reload() {
    setState(() {
      _savedPlansFuture = _savedMealPlanService.getSavedPlans();
    });
  }

  Future<void> _deletePlan(String id) async {
    await _savedMealPlanService.deletePlan(id);
    if (!mounted) return;
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved meal plan deleted.')),
    );
  }

  Future<void> _clearSavedPlans() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear saved plans?'),
          content: const Text(
            'This removes all locally saved meal plans from this device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await _savedMealPlanService.clear();
    if (!mounted) return;
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All saved meal plans were cleared.')),
    );
  }

  Future<void> _openMealPlanner() async {
    await Navigator.pushNamed(context, MealPlanScreen.routeName);
    if (!mounted) return;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved meal plans'),
        actions: [
          IconButton(
            tooltip: 'Clear saved plans',
            onPressed: _clearSavedPlans,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: FutureBuilder<List<SavedMealPlan>>(
        future: _savedPlansFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load saved meal plans: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final savedPlans = snapshot.data ?? const <SavedMealPlan>[];

          if (savedPlans.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _savedPlansFuture;
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: savedPlans.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) return _buildHeaderCard(savedPlans.length);
                return _buildSavedPlanCard(savedPlans[index - 1]);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7C8A5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.bookmarks_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count saved locally',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'These plans are stored on this device with SharedPreferences, so they can be reviewed later without recalculating the recommendation.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.bookmarks_outlined,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'No saved meal plans yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Generate a meal plan, select your tags, and save the recommendation to keep it here.',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _openMealPlanner,
              icon: const Icon(Icons.restaurant_menu),
              label: const Text('Create meal plan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedPlanCard(SavedMealPlan plan) {
    final recommendations = plan.result.recommendations;
    final tags = plan.result.selectedTags;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showSavedPlanDetails(plan),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.restaurant_menu, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.result.goal.label,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Saved ${_formatDateTime(plan.savedAt)}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete saved plan',
                    onPressed: () => _deletePlan(plan.id),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tags.map((tag) => Chip(label: Text(tag))).toList(),
                ),
              ],
              const SizedBox(height: 10),
              ...recommendations.take(4).map(
                    (recommendation) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• '),
                          Expanded(
                            child: Text(
                              '${recommendation.slotTitle}: ${recommendation.restaurant.name}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showSavedPlanDetails(plan),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Preview'),
                ),
              ),
            ],
          ),
        ),
      ),
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
                'Saved ${_formatDateTime(plan.savedAt)}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              if (plan.result.selectedTags.isNotEmpty) ...[
                const SizedBox(height: 10),
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

  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }
}
