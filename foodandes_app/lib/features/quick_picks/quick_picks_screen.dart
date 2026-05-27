import 'dart:async';

import 'package:flutter/material.dart';
import 'package:foodandes_app/core/constants/app_colors.dart';
import 'package:foodandes_app/data/repositories/restaurant_repository.dart';
import 'package:foodandes_app/data/services/connectivity_service.dart';
import 'package:foodandes_app/data/services/quick_picks_cache_service.dart';
import 'package:foodandes_app/data/services/quick_picks_isolate.dart';
import 'package:foodandes_app/features/restaurant/restaurant_detail_screen.dart';
import 'package:foodandes_app/shared/widgets/offline_protected_notice.dart';
import 'package:foodandes_app/shared/widgets/restaurant_card.dart';

class QuickPicksScreen extends StatefulWidget {
  static const String routeName = '/quick-picks';

  const QuickPicksScreen({super.key});

  @override
  State<QuickPicksScreen> createState() => _QuickPicksScreenState();
}

class _QuickPicksLoadResult {
  final List<QuickPickResult> quickPicks;
  final bool fromCache;
  final bool isOffline;

  const _QuickPicksLoadResult({
    required this.quickPicks,
    required this.fromCache,
    required this.isOffline,
  });
}

class _QuickPicksScreenState extends State<QuickPicksScreen> {
  final RestaurantRepository _repository = RestaurantRepository();
  final QuickPicksCacheService _cacheService = QuickPicksCacheService.instance;

  Future<_QuickPicksLoadResult>? _quickPicksFuture;
  StreamSubscription<bool>? _connectivitySubscription;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _quickPicksFuture = _loadQuickPicks();
  }

  Future<void> _initConnectivity() async {
    final online = await ConnectivityService.instance.isOnline;
    if (!mounted) return;
    setState(() => _isOffline = !online);

    _connectivitySubscription =
        ConnectivityService.instance.isOnlineStream.listen((isOnline) {
      if (!mounted) return;
      setState(() => _isOffline = !isOnline);
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<_QuickPicksLoadResult> _loadQuickPicks() async {
    final online = await ConnectivityService.instance.isOnline;
    if (mounted) setState(() => _isOffline = !online);

    final restaurants = await _repository.fetchRestaurants(forceRefresh: false);
    final hour = DateTime.now().hour;
    final cacheKey = _cacheService.buildKey(
      restaurants: restaurants,
      hour: hour,
    );

    final cachedResults = _cacheService.get(cacheKey);
    if (cachedResults != null) {
      return _QuickPicksLoadResult(
        quickPicks: cachedResults,
        fromCache: true,
        isOffline: !online,
      );
    }

    final quickPicks = await QuickPicksIsolate.run(
      restaurants: restaurants,
      hour: hour,
    );
    _cacheService.put(cacheKey, quickPicks);

    return _QuickPicksLoadResult(
      quickPicks: quickPicks,
      fromCache: false,
      isOffline: !online,
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
      body: FutureBuilder<_QuickPicksLoadResult>(
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

          final loadResult = snapshot.data;
          final quickPicks = loadResult?.quickPicks ?? const <QuickPickResult>[];
          final isOffline = loadResult?.isOffline ?? _isOffline;
          final fromCache = loadResult?.fromCache ?? false;

          if (quickPicks.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isOffline) ...[
                      const OfflineProtectedNotice(
                        message:
                            'Offline mode · quick picks need saved restaurant data to work',
                      ),
                      const SizedBox(height: 18),
                    ],
                    const Icon(
                      Icons.auto_awesome_outlined,
                      size: 64,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No quick picks available',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Open the app online once so restaurants can be saved locally, then this view can rank them offline.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (isOffline) ...[
                  const OfflineProtectedNotice(
                    message:
                        'Offline mode · ranking saved restaurants from local storage',
                  ),
                  const SizedBox(height: 16),
                ],
                _buildExplanationCard(fromCache: fromCache),
                const SizedBox(height: 16),
                ...quickPicks.map(_buildQuickPickCard),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildExplanationCard({required bool fromCache}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7C8A5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            fromCache ? Icons.cached : Icons.auto_awesome,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fromCache
                  ? 'These recommendations were served from a bounded LRU cache, avoiding a repeated isolate calculation for the same restaurant snapshot.'
                  : 'These recommendations are calculated in a background isolate using rating, reviews, price, open status, favorites, and current time. The result is cached for fast repeated access.',
              style: const TextStyle(
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
