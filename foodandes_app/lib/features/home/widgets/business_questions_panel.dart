import 'package:flutter/material.dart';
import 'package:foodandes_app/core/constants/app_colors.dart';
import 'package:foodandes_app/data/services/section_usage_service.dart';
import 'package:foodandes_app/models/restaurant.dart';

class BusinessQuestionsPanel extends StatelessWidget {
  final List<Restaurant> trendingRestaurants;

  const BusinessQuestionsPanel({
    super.key,
    required this.trendingRestaurants,
  });

  String _sectionLabel(String section) {
    switch (section) {
      case 'home':
        return 'Home';
      case 'map':
        return 'Map';
      case 'search':
        return 'Search';
      case 'favorites':
        return 'Favorites';
      case 'profile':
        return 'Profile';
      default:
        return section;
    }
  }

  Map<String, dynamic>? _buildBq2Answer() {
    if (trendingRestaurants.isEmpty) return null;

    final counts = <String, int>{};
    for (final restaurant in trendingRestaurants) {
      counts[restaurant.category] = (counts[restaurant.category] ?? 0) + 1;
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final winner = sorted.first;

    return {
      'category': winner.key,
      'count': winner.value,
      'total': trendingRestaurants.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    final bq2 = _buildBq2Answer();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Business Questions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        StreamBuilder<Map<String, dynamic>?>(
          stream: SectionUsageService.instance.watchMostEngagedSection(),
          builder: (context, snapshot) {
            final sectionData = snapshot.data;
            final section = sectionData?['section'] as String?;
            final viewCount = sectionData?['viewCount'] as int? ?? 0;
            final interactionCount = sectionData?['interactionCount'] as int? ?? 0;

            return _BusinessQuestionCard(
              label: 'BQ4',
              title: 'Which section generates the highest user interaction?',
              answer: section == null
                  ? 'Not enough navigation data yet.'
                  : 'Right now, ${_sectionLabel(section)} is the most used section.',
              detail: section == null
                  ? 'Open the app and move through Home, Map, Search and Favorites to populate the counter.'
                  : 'Views: $viewCount · Interactions: $interactionCount',
              icon: Icons.insights,
            );
          },
        ),
        const SizedBox(height: 12),
        _BusinessQuestionCard(
          label: 'BQ2',
          title: 'Which restaurant category is driving the most engagement on campus right now?',
          answer: bq2 == null
              ? 'Not enough trending data yet.'
              : '${bq2['category']} is the category leading current engagement.',
          detail: bq2 == null
              ? 'The answer is calculated from the restaurants currently ranked as trending.'
              : '${bq2['count']} of the top ${bq2['total']} trending restaurants belong to this category.',
          icon: Icons.local_fire_department,
        ),
      ],
    );
  }
}

class _BusinessQuestionCard extends StatelessWidget {
  final String label;
  final String title;
  final String answer;
  final String detail;
  final IconData icon;

  const _BusinessQuestionCard({
    required this.label,
    required this.title,
    required this.answer,
    required this.detail,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.background,
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    answer,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    detail,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
