import 'package:flutter/material.dart';
import 'package:foodandes_app/core/constants/app_colors.dart';
import 'package:foodandes_app/data/repositories/restaurant_repository.dart';
import 'package:foodandes_app/data/services/quick_picks_isolate.dart';
import 'package:foodandes_app/features/restaurant/restaurant_detail_screen.dart';
import 'package:foodandes_app/shared/widgets/restaurant_card.dart';

class QuickPicksScreen extends StatefulWidget {
  static const String routeName = '/quick-picks';

  const QuickPicksScreen({super.key});

  @override
  State<QuickPicksScreen> createState() => _QuickPicksScreenState();
}

class _QuickPicksScreenState extends State<QuickPicksScreen> {
  final RestaurantRepository _repository = RestaurantRepository();

  Future<List<QuickPickResult>>? _quickPicksFuture;

  @override
  void initState() {
    super.initState();
    _quickPicksFuture = _loadQuickPicks();
  }

  Future<List<QuickPickResult>> _loadQuickPicks() async {
    final restaurants = await _repository.fetchRestaurants();

    return QuickPicksIsolate.run(
      restaurants: restaurants,
      hour: DateTime.now().hour,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _quickPicksFuture = _loadQuickPicks();
    });
    await _quickPicksFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Quick Picks'),
      ),
      body: FutureBuilder<List<QuickPickResult>>(
        future: _quickPicksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 14),
                  Text('Ranking restaurants in a background isolate...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not calculate quick picks: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final quickPicks = snapshot.data ?? [];

          if (quickPicks.isEmpty) {
            return const Center(
              child: Text('No quick picks available'),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildExplanationCard(),
                const SizedBox(height: 16),
                ...quickPicks.map(_buildQuickPickCard),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildExplanationCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7C8A5)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, color: AppColors.primary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'These recommendations are calculated in a background isolate using rating, reviews, price, open status, favorites, and current time.',
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

  Widget _buildQuickPickCard(QuickPickResult result) {
    final restaurant = result.restaurant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RestaurantCard(
            restaurant: restaurant,
            showFavoriteIcon: true,
            favoriteFilled: restaurant.isFavorite,
            onTap: () {
              Navigator.pushNamed(
                context,
                RestaurantDetailScreen.routeName,
                arguments: restaurant.id,
              );
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                label: Text('Score ${result.score.toStringAsFixed(1)}'),
                avatar: const Icon(Icons.speed, size: 18),
              ),
              ...result.reasons.map(
                (reason) => Chip(
                  label: Text(reason),
                  avatar: const Icon(Icons.check_circle_outline, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}