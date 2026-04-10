import 'package:flutter/material.dart';
import 'package:foodandes_app/core/constants/app_colors.dart';
import 'package:foodandes_app/data/repositories/restaurant_repository.dart';
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

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final restaurantId = ModalRoute.of(context)?.settings.arguments as String?;

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

      if (!mounted) return;

      setState(() {
        _baseRestaurant = baseRestaurant;
        _restaurants = restaurants;
        _isLoading = false;
        if (baseRestaurant == null) {
          _error = 'Restaurant not found';
        }
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

  Restaurant? _restaurantById(String? id) {
    if (id == null) return null;

    for (final restaurant in _restaurants) {
      if (restaurant.id == id) return restaurant;
    }
    return null;
  }

  List<Restaurant> get _filteredRestaurants {
    final candidates =
        _restaurants.where((r) => r.id != _baseRestaurantId).toList();

    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) return candidates;

    return candidates.where((restaurant) {
      final tags = restaurant.tags.join(' ').toLowerCase();

      return restaurant.name.toLowerCase().contains(query) ||
          restaurant.category.toLowerCase().contains(query) ||
          restaurant.address.toLowerCase().contains(query) ||
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
      appBar: AppBar(
        title: const Text('Compare restaurants'),
      ),
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
                          'Choose another restaurant to compare with ${_baseRestaurant!.name}.',
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _SelectedRestaurantCard(
                                title: 'Current',
                                restaurant: _baseRestaurant!,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Icon(
                                Icons.compare_arrows,
                                color: AppColors.primary,
                                size: 28,
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
                                selected:
                                    restaurant.id == _selectedRestaurantId,
                                onTap: () {
                                  setState(() {
                                    _selectedRestaurantId = restaurant.id;
                                    _compareLogged = false;
                                  });
                                },
                              ),
                            ),
                          ),
                        if (selectedRestaurant != null) ...[
                          const SizedBox(height: 24),
                          const Text(
                            'Comparison summary',
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
                                        '${_baseRestaurant!.rating.toStringAsFixed(1)} ⭐',
                                    rightValue:
                                        '${selectedRestaurant.rating.toStringAsFixed(1)} ⭐',
                                  ),
                                  _CompareMetricRow(
                                    label: 'Reviews',
                                    leftValue:
                                        _baseRestaurant!.reviewCount.toString(),
                                    rightValue:
                                        selectedRestaurant.reviewCount.toString(),
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
                    child: Icon(Icons.image_not_supported),
                  ),
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
              style: const TextStyle(
                color: AppColors.textSecondary,
              ),
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
            Icon(
              Icons.restaurant_outlined,
              size: 36,
              color: AppColors.textSecondary,
            ),
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
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${restaurant.category} • ${restaurant.priceRange}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '⭐ ${restaurant.rating.toStringAsFixed(1)} • ${restaurant.reviewCount} reviews',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: selected ? AppColors.primary : AppColors.textSecondary,
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

  const _CompareMetricRow({
    required this.label,
    required this.leftValue,
    required this.rightValue,
    this.isLast = false,
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
              child: _MetricValueCard(value: leftValue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricValueCard(value: rightValue),
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

  const _MetricValueCard({
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}