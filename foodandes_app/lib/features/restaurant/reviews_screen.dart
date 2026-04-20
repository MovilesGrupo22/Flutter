import 'package:flutter/material.dart';
import 'package:foodandes_app/core/constants/app_colors.dart';
import 'package:foodandes_app/data/repositories/review_repository.dart';
import 'package:foodandes_app/data/services/user_service.dart';
import 'package:foodandes_app/models/review.dart';
import 'package:foodandes_app/models/user_profile.dart';
import 'package:foodandes_app/features/restaurant/write_review_screen.dart';

class ReviewsScreen extends StatefulWidget {
  static const String routeName = '/reviews';

  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final ReviewRepository _reviewRepository = ReviewRepository();
  final UserService _userService = UserService();

  String? _restaurantId;
  String? _restaurantName;

  Future<List<Review>>? _reviewsFuture;
  Future<UserProfile?>? _profileFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (args != null) {
      final restaurantId = args['restaurantId'] as String?;
      final restaurantName = args['restaurantName'] as String?;

      if (restaurantId != null && restaurantId != _restaurantId) {
        _restaurantId = restaurantId;
        _restaurantName = restaurantName;
        _loadData();
      }
    }
  }

  void _loadData() {
    if (_restaurantId != null) {
      _reviewsFuture = _reviewRepository.fetchReviewsByRestaurant(_restaurantId!);
      _profileFuture = _userService.getCurrentUserProfile();
    }
  }

  Future<void> _goToWriteReview() async {
    if (_restaurantId == null) return;

    await Navigator.pushNamed(
      context,
      WriteReviewScreen.routeName,
      arguments: {
        'restaurantId': _restaurantId,
        'restaurantName': _restaurantName,
      },
    );

    setState(() {
      _loadData();
    });
  }

  String _formatRelativeTime(int timestamp) {
    final reviewDate =
        DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(reviewDate);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    }
    if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    }
    if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    }
    return 'today';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reviews'),
      ),
      body: FutureBuilder<List<Review>>(
        future: _reviewsFuture,
        builder: (context, reviewSnapshot) {
          return FutureBuilder<UserProfile?>(
            future: _profileFuture,
            builder: (context, profileSnapshot) {
              if (_reviewsFuture == null) {
                return const Center(child: Text('No restaurant selected'));
              }

              if (reviewSnapshot.connectionState == ConnectionState.waiting ||
                  profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (reviewSnapshot.hasError) {
                return Center(
                  child: Text('Error loading reviews: ${reviewSnapshot.error}'),
                );
              }

              final reviews = reviewSnapshot.data ?? [];
              final profile = profileSnapshot.data;

              final average = reviews.isEmpty
                  ? 0.0
                  : reviews
                          .map((r) => r.rating)
                          .reduce((a, b) => a + b) /
                      reviews.length;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 6),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _restaurantName ?? 'Restaurant',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '⭐ ${average.toStringAsFixed(2)} (${reviews.length} reviews)',
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          profile != null
                              ? 'Active session as ${profile.name}'
                              : 'Active session',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: _goToWriteReview,
                    icon: const Icon(Icons.edit, color: AppColors.primary),
                    label: const Text(
                      'Write a Review',
                      style: TextStyle(color: AppColors.primary),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Recent Reviews',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (reviews.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: Center(
                        child: Text('No reviews yet'),
                      ),
                    ),
                  ...reviews.map(
                    (review) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 4),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primary,
                              child: Text(
                                review.userName.isNotEmpty
                                    ? review.userName[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    review.userName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        '⭐' * review.rating,
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatRelativeTime(review.timestamp),
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    review.comment,
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}