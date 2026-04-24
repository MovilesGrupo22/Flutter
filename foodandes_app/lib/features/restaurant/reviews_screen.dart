import 'package:flutter/material.dart';
import 'package:foodandes_app/core/constants/app_colors.dart';
import 'package:foodandes_app/data/repositories/review_repository.dart';
import 'package:foodandes_app/data/services/user_service.dart';
import 'package:foodandes_app/models/review.dart';
import 'package:foodandes_app/models/user_profile.dart';
import 'package:foodandes_app/features/restaurant/write_review_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:foodandes_app/data/services/review_stats_isolate.dart';

class ReviewsInitialData {
  final List<Review> reviews;
  final UserProfile? profile;

  const ReviewsInitialData({
    required this.reviews,
    required this.profile,
  });
}

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

  Future<ReviewsInitialData>? _initialDataFuture;
  Stream<List<Review>>? _reviewsStream;

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
      _initialDataFuture = _loadInitialData(_restaurantId!);
      _reviewsStream = _reviewRepository.watchReviewsByRestaurant(_restaurantId!);
    }
  }

  Future<ReviewsInitialData> _loadInitialData(String restaurantId) async {
    final results = await Future.wait<dynamic>([
      _reviewRepository
          .fetchReviewsByRestaurant(restaurantId)
          .catchError((error) {
        debugPrint('Initial reviews loading failed: $error');
        return <Review>[];
      }),
      _userService.getCurrentUserProfile().catchError((error) {
        debugPrint('Profile loading failed: $error');
        return null;
      }),
    ]);

    return ReviewsInitialData(
      reviews: results[0] as List<Review>,
      profile: results[1] as UserProfile?,
    );
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
      body: FutureBuilder<ReviewsInitialData>(
        future: _initialDataFuture,
        builder: (context, initialSnapshot) {
          if (_initialDataFuture == null) {
            return const Center(child: Text('No restaurant selected'));
          }

          if (initialSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final initialData = initialSnapshot.data ??
              const ReviewsInitialData(reviews: [], profile: null);

          return StreamBuilder<List<Review>>(
            stream: _reviewsStream,
            initialData: initialData.reviews,
            builder: (context, reviewSnapshot) {
              final reviews = reviewSnapshot.data ?? initialData.reviews;
              final profile = initialData.profile;

              return FutureBuilder<ReviewStats>(
                future: computeReviewStats(reviews),
                builder: (context, statsSnapshot) {
                  final stats = statsSnapshot.data ??
                      const ReviewStats(
                        average: 0.0,
                        total: 0,
                        distribution: {
                          1: 0,
                          2: 0,
                          3: 0,
                          4: 0,
                          5: 0,
                        },
                      );

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (reviewSnapshot.hasError)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3CD),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Showing cached reviews. Real-time updates are temporarily unavailable.',
                          ),
                        ),

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
                              '⭐ ${stats.average.toStringAsFixed(2)} (${stats.total} reviews)',
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
                          child: Center(child: Text('No reviews yet')),
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
                                          Text('⭐' * review.rating),
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
          );
        },
      ),
    );
  }
}