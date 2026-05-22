import 'dart:async';

import 'package:flutter/material.dart';
import 'package:foodandes_app/data/repositories/restaurant_repository.dart';
import 'package:foodandes_app/shared/widgets/offline_protected_notice.dart';
import 'package:foodandes_app/data/services/restaurant_filter_isolate.dart';
import 'package:foodandes_app/data/services/connectivity_service.dart';
import 'package:foodandes_app/data/services/search_history_service.dart';
import 'package:foodandes_app/features/restaurant/restaurant_detail_screen.dart';
import 'package:foodandes_app/models/restaurant.dart';
import 'package:foodandes_app/shared/widgets/custom_bottom_navbar.dart';
import 'package:foodandes_app/shared/widgets/custom_search_bar.dart';
import 'package:foodandes_app/shared/widgets/empty_state_widget.dart';
import 'package:foodandes_app/shared/widgets/restaurant_card.dart';
import 'package:foodandes_app/data/services/analytics_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SearchEmptyScreen extends StatefulWidget {
  static const String routeName = '/search-empty';

  const SearchEmptyScreen({super.key});

  @override
  State<SearchEmptyScreen> createState() => _SearchEmptyScreenState();
}

class _SearchEmptyScreenState extends State<SearchEmptyScreen> {
  final RestaurantRepository _repository = RestaurantRepository();
  final SearchHistoryService _historyService = SearchHistoryService.instance;
  final TextEditingController _searchController = TextEditingController();

  late Future<List<Restaurant>> _allRestaurantsFuture;

  List<Restaurant> _allRestaurants = [];
  List<Restaurant> _filteredRestaurants = [];
  List<String> _searchHistory = [];
  bool _isLoadingRestaurants = true;
  bool _isSearching = false;
  bool _isOffline = false;
  int _searchRunId = 0;
  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _searchAnalyticsDebounce;
  String _lastTrackedQuery = '';

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _loadRestaurants();
    _loadHistory();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = FirebaseAuth.instance.currentUser?.uid;

      AnalyticsService.instance.logSectionView(
        section: AppSection.search,
        userId: userId,
      );
    });
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

  Future<void> _loadHistory() async {
    final history = await _historyService.getAll();
    if (!mounted) return;
    setState(() => _searchHistory = history);
  }

  Future<void> _deleteHistoryItem(String query) async {
    await _historyService.delete(query);
    await _loadHistory();
  }

  Future<void> _clearHistory() async {
    await _historyService.clear();
    await _loadHistory();
  }

  void _applyHistoryQuery(String query) {
    _searchController.text = query;
    _onSearchChanged(query);
  }

  Future<void> _saveSearchQuery(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return;

    await _historyService.save(trimmedQuery);
    await _loadHistory();

    await _logSearchInteraction(
      'search_submitted',
      additionalParameters: {
        'query_length': trimmedQuery.length,
      },
    );
  }

  Future<void> _logSearchInteraction(
    String action, {
    Map<String, Object>? additionalParameters,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    await AnalyticsService.instance.logSectionInteraction(
      section: AppSection.search,
      action: action,
      userId: userId,
      additionalParameters: additionalParameters,
    );
  }

  Future<void> _loadRestaurants() async {
    setState(() {
      _isLoadingRestaurants = true;
    });

    _allRestaurantsFuture = _repository.fetchRestaurants();

    try {
      final restaurants = await _allRestaurantsFuture;

      if (!mounted) return;

      setState(() {
        _allRestaurants = restaurants;
        _filteredRestaurants = [];
        _isLoadingRestaurants = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _allRestaurants = [];
        _filteredRestaurants = [];
        _isLoadingRestaurants = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load restaurants: $error')),
      );
    }
  }

  void _onSearchChanged(String value) {
    unawaited(_applySearchAsync(value));
  }

  Future<void> _applySearchAsync(String value) async {
    final trimmedValue = value.trim();
    final runId = ++_searchRunId;

    if (_allRestaurants.isEmpty) {
      setState(() {
        _filteredRestaurants = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    final params = FilterParams(
      restaurants: _allRestaurants,
      query: value,
    );

    try {
      final results = await RestaurantFilterIsolate.run(params);

      if (!mounted || runId != _searchRunId) return;

      setState(() {
        _filteredRestaurants = results;
        _isSearching = false;
      });

      _searchAnalyticsDebounce?.cancel();

      if (trimmedValue.isEmpty) {
        _lastTrackedQuery = '';
        return;
      }

      _searchAnalyticsDebounce = Timer(const Duration(milliseconds: 500), () {
        if (!mounted || trimmedValue == _lastTrackedQuery) return;

        _lastTrackedQuery = trimmedValue;
        final userId = FirebaseAuth.instance.currentUser?.uid;

        AnalyticsService.instance.logSearch(
          query: trimmedValue,
          resultsCount: results.length,
          userId: userId,
        );

        _logSearchInteraction(
          'search_executed',
          additionalParameters: {
            'results_count': results.length,
          },
        );
      });
    } catch (error) {
      debugPrint('Search isolate ERROR -> $error');
      final results = _repository.filterRestaurants(
        restaurants: _allRestaurants,
        query: value,
      );
      if (!mounted || runId != _searchRunId) return;
      setState(() {
        _filteredRestaurants = results;
        _isSearching = false;
      });
    }
  }

  Future<void> _toggleFavorite(Restaurant restaurant) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final willBeFavorite = !restaurant.isFavorite;

    try {
      await _repository.toggleFavorite(restaurant.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update favorite: $error')),
      );
      return;
    }

    if (_isOffline && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Favorite change saved offline and will sync later.'),
        ),
      );
    }

    await _logSearchInteraction(
      willBeFavorite ? 'favorite_added' : 'favorite_removed',
      additionalParameters: {
        'restaurant_id': restaurant.id,
      },
    );

    if (userId != null) {
      if (willBeFavorite) {
        await AnalyticsService.instance.logRestaurantFavorited(
          restaurantId: restaurant.id,
          restaurantName: restaurant.name,
          userId: userId,
          favoriteSource: 'search_screen',
        );
      } else {
        await AnalyticsService.instance.logRestaurantUnfavorited(
          restaurantId: restaurant.id,
          userId: userId,
        );
      }
    }
    await _loadRestaurants();

    _onSearchChanged(_searchController.text);
  }

  @override
  void dispose() {
    _searchAnalyticsDebounce?.cancel();
    _connectivitySubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildSearchHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent searches',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            TextButton(
              onPressed: _clearHistory,
              child: const Text('Clear all'),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _searchHistory.map((query) {
            return InputChip(
              label: Text(query),
              avatar: const Icon(Icons.history, size: 16),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () => _deleteHistoryItem(query),
              onPressed: () => _applyHistoryQuery(query),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    final hasQuery = query.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
      bottomNavigationBar: const CustomBottomNavbar(currentIndex: 2),
      body: _isLoadingRestaurants
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_isOffline)
                    const OfflineProtectedNotice(
                      message: 'Offline mode · searching saved restaurants',
                    ),
                  if (_isOffline) const SizedBox(height: 12),
                  CustomSearchBar(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onSubmitted: _saveSearchQuery,
                  ),
                  const SizedBox(height: 8),
                  if (_isSearching)
                    const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: 16),
                  Expanded(
                    child: !hasQuery
                        ? _searchHistory.isEmpty
                            ? const EmptyStateWidget(
                                icon: Icons.search,
                                title: 'Start typing to search',
                                subtitle:
                                    'Find restaurants by name, category, tag, or address',
                              )
                            : _buildSearchHistory()
                        : _filteredRestaurants.isEmpty
                            ? const EmptyStateWidget(
                                icon: Icons.search_off,
                                title: 'No results found',
                                subtitle:
                                    'Try a different keyword or category',
                              )
                            : RefreshIndicator(
                                onRefresh: _loadRestaurants,
                                child: ListView.builder(
                                  itemCount: _filteredRestaurants.length,
                                  itemBuilder: (context, index) {
                                    final restaurant =
                                        _filteredRestaurants[index];

                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 18),
                                      child: RestaurantCard(
                                        restaurant: restaurant,
                                        showFavoriteIcon: true,
                                        favoriteFilled:
                                            restaurant.isFavorite,
                                        onFavoriteTap: () =>
                                            _toggleFavorite(restaurant),
                                        onTap: () async {
                                          final nav = Navigator.of(context);
                                          await _historyService.save(
                                            _searchController.text,
                                          );
                                          await _logSearchInteraction(
                                            'open_search_result',
                                            additionalParameters: {
                                              'restaurant_id': restaurant.id,
                                            },
                                          );
                                          await nav.pushNamed(
                                            RestaurantDetailScreen.routeName,
                                            arguments: restaurant.id,
                                          );

                                          await _loadRestaurants();
                                          _onSearchChanged(
                                            _searchController.text,
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                  ),
                ],
              ),
            ),
    );
  }
}
