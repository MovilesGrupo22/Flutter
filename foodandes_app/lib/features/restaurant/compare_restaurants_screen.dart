import 'package:flutter/material.dart';
import 'package:foodandes_app/core/constants/app_colors.dart';
import 'package:foodandes_app/data/repositories/restaurant_repository.dart';
import 'package:foodandes_app/data/services/smart_compare_service.dart';
import 'package:foodandes_app/data/services/section_usage_service.dart';
import 'package:foodandes_app/data/services/trending_restaurants_service.dart';
import 'package:foodandes_app/models/restaurant.dart';
import 'package:foodandes_app/shared/widgets/open_badge.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:foodandes_app/data/services/analytics_service.dart';

class CompareRestaurantsScreen extends StatefulWidget {
  static const String routeName = '/compare-restaurants';

  const CompareRestaurantsScreen({super.key});

  @override
  State<CompareRestaurantsScreen> createState() =>
      _CompareRestaurantsScreenState();
}

class _CompareRestaurantsScreenState extends State<CompareRestaurantsScreen> {
  final RestaurantRepository _repository = RestaurantRepository();
  final TextEditingController _searchController = TextEditingController();

  bool _compareLogged = false;
  String? _baseRestaurantId;
  Restaurant? _baseRestaurant;
  List<Restaurant> _restaurants = [];
  String? _selectedRestaurantId;

  Map<String, dynamic>? _mostEngagedSection;
  String? _topTrendingCategory;
  int _topTrendingCategoryCount = 0;
  int _topTrendingSampleSize = 0;

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final restaurantId =
        ModalRoute.of(context)?.settings.arguments as String?;

    if (restaurantId != null && restaurantId != _baseRestaurantId) {
      _baseRestaurantId = restaurantId;
      _loadData();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_baseRestaurantId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final baseRestaurant =
          await _repository.fetchRestaurantById(_baseRestaurantId!);
      final restaurants = await _repository.fetchRestaurants();
      final mostEngagedSection =
          await SectionUsageService.instance.getMostEngagedSection();
      final trendingRestaurants = await TrendingRestaurantsService.instance
          .getTrendingRestaurants(
        topN: 5,
        sourceRestaurants: restaurants,
      );

      String? topTrendingCategory;
      int topTrendingCategoryCount = 0;
      final categoryCounts = <String, int>{};

      for (final restaurant in trendingRestaurants) {
        final category = restaurant.category.trim();
        if (category.isEmpty) continue;
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
      }

      if (categoryCounts.isNotEmpty) {
        final winner = categoryCounts.entries.reduce(
          (best, current) => current.value > best.value ? current : best,
        );
        topTrendingCategory = winner.key;
        topTrendingCategoryCount = winner.value;
      }

      if (!mounted) return;

      setState(() {
        _baseRestaurant = baseRestaurant;
        _restaurants = restaurants;
        _mostEngagedSection = mostEngagedSection;
        _topTrendingCategory = topTrendingCategory;
        _topTrendingCategoryCount = topTrendingCategoryCount;
        _topTrendingSampleSize = trendingRestaurants.length;
        _isLoading = false;
        if (baseRestaurant == null) _error = 'Restaurant not found';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error loading restaurants: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _logCompareIfNeeded({
    required Restaurant baseRestaurant,
    required Restaurant selectedRestaurant,
  }) async {
    if (_compareLogged) return;
    _compareLogged = true;

    final userId = FirebaseAuth.instance.currentUser?.uid;

    await AnalyticsService.instance.logCompareUsed(
      primaryRestaurantId: baseRestaurant.id,
      secondaryRestaurantId: selectedRestaurant.id,
      selectionMode: 'manual',
      userId: userId,
    );
  }


  Future<void> _swapSelectedRestaurants() async {
    final currentBaseRestaurant = _baseRestaurant;
    final selectedRestaurant = _restaurantById(_selectedRestaurantId);

    if (currentBaseRestaurant == null || selectedRestaurant == null) {
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;

    setState(() {
      _baseRestaurant = selectedRestaurant;
      _baseRestaurantId = selectedRestaurant.id;
      _selectedRestaurantId = currentBaseRestaurant.id;
      _compareLogged = false;
    });

    await AnalyticsService.instance.logSectionInteraction(
      section: AppSection.detail,
      action: 'swap_compare_order',
      userId: userId,
      additionalParameters: {
        'left_restaurant_id': selectedRestaurant.id,
        'right_restaurant_id': currentBaseRestaurant.id,
      },
    );
  }

  Restaurant? _restaurantById(String? id) {
    if (id == null) return null;
    for (final r in _restaurants) {
      if (r.id == id) return r;
    }
    return null;
  }

  List<Restaurant> get _filteredRestaurants {
    final candidates =
        _restaurants.where((r) => r.id != _baseRestaurantId).toList();

    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return candidates;

    return candidates.where((r) {
      final tags = r.tags.join(' ').toLowerCase();
      return r.name.toLowerCase().contains(query) ||
          r.category.toLowerCase().contains(query) ||
          r.address.toLowerCase().contains(query) ||
          tags.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final selectedRestaurant = _restaurantById(_selectedRestaurantId);

    if (_baseRestaurant != null && selectedRestaurant != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _logCompareIfNeeded(
          baseRestaurant: _baseRestaurant!,
          selectedRestaurant: selectedRestaurant,
        );
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Compare restaurants')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _baseRestaurant == null
                  ? const Center(child: Text('No restaurant selected'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          'Choose another restaurant to compare with '
                          '${_baseRestaurant!.name}.',
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Selected pair ──────────────────────────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _SelectedRestaurantCard(
                                title: 'Current',
                                restaurant: _baseRestaurant!,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Column(
                                children: [
                                  const SizedBox(height: 84),
                                  Material(
                                    color: selectedRestaurant != null
                                        ? AppColors.primary.withOpacity(0.10)
                                        : Colors.grey.shade200,
                                    shape: const CircleBorder(),
                                    child: IconButton(
                                      tooltip: 'Swap restaurants',
                                      onPressed: selectedRestaurant != null
                                          ? _swapSelectedRestaurants
                                          : null,
                                      icon: const Icon(Icons.compare_arrows),
                                      color: AppColors.primary,
                                      iconSize: 28,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: selectedRestaurant != null
                                  ? _SelectedRestaurantCard(
                                      title: 'Selected',
                                      restaurant: selectedRestaurant,
                                    )
                                  : const _EmptySelectionCard(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // ── Smart Verdict ──────────────────────────────────
                        if (selectedRestaurant != null) ...[
                          _SmartVerdictCard(
                            left: _baseRestaurant!,
                            right: selectedRestaurant,
                          ),
                          const SizedBox(height: 16),
                          _CampusContextCard(
                            left: _baseRestaurant!,
                            right: selectedRestaurant,
                            mostEngagedSection: _mostEngagedSection,
                            topTrendingCategory: _topTrendingCategory,
                            topTrendingCategoryCount: _topTrendingCategoryCount,
                            topTrendingSampleSize: _topTrendingSampleSize,
                          ),
                          const SizedBox(height: 24),
                        ],

                        // ── Search ─────────────────────────────────────────
                        TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Search by name, category or tag',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                        const SizedBox(height: 20),

                        const Text(
                          'Available restaurants',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (_filteredRestaurants.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text('No restaurants match your search'),
                            ),
                          )
                        else
                          ..._filteredRestaurants.map(
                            (restaurant) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _RestaurantSelectionCard(
                                restaurant: restaurant,
                                selected: restaurant.id == _selectedRestaurantId,
                                onTap: () => setState(() {
                                  _selectedRestaurantId = restaurant.id;
                                  _compareLogged = false;
                                }),
                              ),
                            ),
                          ),

                        // ── Metric table ───────────────────────────────────
                        if (selectedRestaurant != null) ...[
                          const SizedBox(height: 24),
                          const Text(
                            'Side-by-side details',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  _CompareMetricRow(
                                    label: 'Category',
                                    leftValue: _baseRestaurant!.category,
                                    rightValue: selectedRestaurant.category,
                                  ),
                                  _CompareMetricRow(
                                    label: 'Price range',
                                    leftValue: _baseRestaurant!.priceRange,
                                    rightValue: selectedRestaurant.priceRange,
                                  ),
                                  _CompareMetricRow(
                                    label: 'Rating',
                                    leftValue:
                                        '${_baseRestaurant!.rating.toStringAsFixed(2)} ⭐',
                                    rightValue:
                                        '${selectedRestaurant.rating.toStringAsFixed(2)} ⭐',
                                    highlightBetter: true,
                                    leftIsHigher: _baseRestaurant!.rating >=
                                        selectedRestaurant.rating,
                                  ),
                                  _CompareMetricRow(
                                    label: 'Reviews',
                                    leftValue:
                                        _baseRestaurant!.reviewCount.toString(),
                                    rightValue:
                                        selectedRestaurant.reviewCount.toString(),
                                    highlightBetter: true,
                                    leftIsHigher:
                                        _baseRestaurant!.reviewCount >=
                                            selectedRestaurant.reviewCount,
                                  ),
                                  _CompareMetricRow(
                                    label: 'Open now',
                                    leftValue:
                                        _baseRestaurant!.isOpen ? 'Yes' : 'No',
                                    rightValue:
                                        selectedRestaurant.isOpen ? 'Yes' : 'No',
                                  ),
                                  _CompareMetricRow(
                                    label: 'Opening hours',
                                    leftValue: _baseRestaurant!.openingHours,
                                    rightValue: selectedRestaurant.openingHours,
                                  ),
                                  _CompareMetricRow(
                                    label: 'Address',
                                    leftValue: _baseRestaurant!.address,
                                    rightValue: selectedRestaurant.address,
                                  ),
                                  _CompareMetricRow(
                                    label: 'Tags',
                                    leftValue: _baseRestaurant!.tags.isEmpty
                                        ? '-'
                                        : _baseRestaurant!.tags.join(', '),
                                    rightValue: selectedRestaurant.tags.isEmpty
                                        ? '-'
                                        : selectedRestaurant.tags.join(', '),
                                    isLast: true,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
    );
  }
}

// ─── Smart Verdict Card ──────────────────────────────────────────────────────

class _SmartVerdictCard extends StatelessWidget {
  final Restaurant left;
  final Restaurant right;

  const _SmartVerdictCard({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    final result = SmartCompareService.instance.compare(left, right);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: AppColors.primary.withOpacity(0.06),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.auto_awesome,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Smart Verdict',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Score bars ───────────────────────────────────────────────────
            _ScoreBar(
              label: left.name,
              score: result.leftScore,
              isWinner: result.winner == 'left',
            ),
            const SizedBox(height: 10),
            _ScoreBar(
              label: right.name,
              score: result.rightScore,
              isWinner: result.winner == 'right',
            ),
            const SizedBox(height: 16),

            // ── Verdict text ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                result.verdict,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),

            // ── Strengths ────────────────────────────────────────────────────
            if (result.leftStrengths.isNotEmpty ||
                result.rightStrengths.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (result.leftStrengths.isNotEmpty)
                    Expanded(
                      child: _StrengthsColumn(
                        name: left.name,
                        strengths: result.leftStrengths,
                        highlight: result.winner == 'left',
                      ),
                    ),
                  if (result.leftStrengths.isNotEmpty &&
                      result.rightStrengths.isNotEmpty)
                    const SizedBox(width: 12),
                  if (result.rightStrengths.isNotEmpty)
                    Expanded(
                      child: _StrengthsColumn(
                        name: right.name,
                        strengths: result.rightStrengths,
                        highlight: result.winner == 'right',
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final String label;
  final double score;
  final bool isWinner;

  const _ScoreBar({
    required this.label,
    required this.score,
    required this.isWinner,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      isWinner ? FontWeight.w700 : FontWeight.w500,
                  color: isWinner
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Row(
              children: [
                if (isWinner) ...[
                  const Icon(Icons.emoji_events,
                      size: 15, color: AppColors.primary),
                  const SizedBox(width: 4),
                ],
                Text(
                  '${score.toStringAsFixed(0)}/100',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isWinner
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: score / 100,
            minHeight: 10,
            backgroundColor: AppColors.border,
            color: isWinner ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _StrengthsColumn extends StatelessWidget {
  final String name;
  final List<String> strengths;
  final bool highlight;

  const _StrengthsColumn({
    required this.name,
    required this.strengths,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.primary.withOpacity(0.08)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? AppColors.primary.withOpacity(0.25)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color:
                  highlight ? AppColors.primary : AppColors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          ...strengths.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                s,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _CampusContextCard extends StatelessWidget {
  final Restaurant left;
  final Restaurant right;
  final Map<String, dynamic>? mostEngagedSection;
  final String? topTrendingCategory;
  final int topTrendingCategoryCount;
  final int topTrendingSampleSize;

  const _CampusContextCard({
    required this.left,
    required this.right,
    required this.mostEngagedSection,
    required this.topTrendingCategory,
    required this.topTrendingCategoryCount,
    required this.topTrendingSampleSize,
  });

  @override
  Widget build(BuildContext context) {
    final insightTiles = <Widget>[];

    final categoryPulse = _buildCategoryPulse();
    if (categoryPulse != null) {
      insightTiles.add(categoryPulse);
    }

    final discoveryFlow = _buildDiscoveryFlow();
    if (discoveryFlow != null) {
      if (insightTiles.isNotEmpty) {
        insightTiles.add(const SizedBox(height: 12));
      }
      insightTiles.add(discoveryFlow);
    }

    if (insightTiles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.insights_outlined,
                    color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Campus context',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...insightTiles,
          ],
        ),
      ),
    );
  }

  Widget? _buildCategoryPulse() {
    final category = topTrendingCategory;
    if (category == null || category.isEmpty || topTrendingSampleSize == 0) {
      return null;
    }

    String headline;
    if (left.category == category && right.category == category) {
      headline =
          'Both options fit the category that is standing out the most on campus right now.';
    } else if (left.category == category) {
      headline =
          '${left.name} aligns more closely with what is currently getting the most attention.';
    } else if (right.category == category) {
      headline =
          '${right.name} aligns more closely with what is currently getting the most attention.';
    } else {
      headline =
          '$category is showing the strongest momentum among restaurants students are checking right now.';
    }

    final detail =
        '$topTrendingCategoryCount of the top $topTrendingSampleSize trending restaurants belong to this category.';

    return _ContextInsightTile(
      icon: Icons.local_fire_department_outlined,
      title: 'Category pulse',
      headline: headline,
      detail: detail,
    );
  }

  Widget? _buildDiscoveryFlow() {
    final sectionName = mostEngagedSection?['section'] as String?;
    final interactions = mostEngagedSection?['interactionCount'];
    final views = mostEngagedSection?['viewCount'];

    if (sectionName == null || sectionName.isEmpty) {
      return null;
    }

    final prettySection =
        '${sectionName[0].toUpperCase()}${sectionName.substring(1)}';

    final headline =
        'Most recent restaurant exploration is still concentrating in $prettySection.';
    final detail = 'Views: ${views ?? 0} · Interactions: ${interactions ?? 0}';

    return _ContextInsightTile(
      icon: Icons.explore_outlined,
      title: 'Discovery flow',
      headline: headline,
      detail: detail,
    );
  }
}

class _ContextInsightTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String headline;
  final String detail;

  const _ContextInsightTile({
    required this.icon,
    required this.title,
    required this.headline,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  headline,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Existing widgets (unchanged) ────────────────────────────────────────────

class _SelectedRestaurantCard extends StatelessWidget {
  final String title;
  final Restaurant restaurant;

  const _SelectedRestaurantCard({
    required this.title,
    required this.restaurant,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                restaurant.imageURL,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 120,
                  color: Colors.grey.shade300,
                  child: const Center(
                      child: Icon(Icons.image_not_supported)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              restaurant.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${restaurant.category} • ${restaurant.priceRange}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            OpenBadge(isOpen: restaurant.isOpen),
          ],
        ),
      ),
    );
  }
}

class _EmptySelectionCard extends StatelessWidget {
  const _EmptySelectionCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        height: 230,
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_outlined,
                size: 36, color: AppColors.textSecondary),
            SizedBox(height: 10),
            Text(
              'Choose a restaurant to compare',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestaurantSelectionCard extends StatelessWidget {
  final Restaurant restaurant;
  final bool selected;
  final VoidCallback onTap;

  const _RestaurantSelectionCard({
    required this.restaurant,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  restaurant.imageURL,
                  width: 78,
                  height: 78,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 78,
                    height: 78,
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.image_not_supported),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${restaurant.category} • ${restaurant.priceRange}',
                      style:
                          const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '⭐ ${restaurant.rating.toStringAsFixed(2)} • '
                      '${restaurant.reviewCount} reviews',
                      style:
                          const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: selected
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompareMetricRow extends StatelessWidget {
  final String label;
  final String leftValue;
  final String rightValue;
  final bool isLast;
  final bool highlightBetter;
  final bool leftIsHigher;

  const _CompareMetricRow({
    required this.label,
    required this.leftValue,
    required this.rightValue,
    this.isLast = false,
    this.highlightBetter = false,
    this.leftIsHigher = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricValueCard(
                value: leftValue,
                highlight: highlightBetter && leftIsHigher,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricValueCard(
                value: rightValue,
                highlight: highlightBetter && !leftIsHigher,
              ),
            ),
          ],
        ),
        if (!isLast) ...[
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _MetricValueCard extends StatelessWidget {
  final String value;
  final bool highlight;

  const _MetricValueCard({required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.primary.withOpacity(0.08)
            : AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              highlight ? AppColors.primary.withOpacity(0.4) : AppColors.border,
        ),
      ),
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(
          color:
              highlight ? AppColors.primary : AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
