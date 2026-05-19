import 'package:flutter/material.dart';
import 'package:foodandes_app/core/constants/app_colors.dart';
import 'package:foodandes_app/data/repositories/review_repository.dart';
import 'package:foodandes_app/data/services/user_service.dart';
import 'package:foodandes_app/models/user_profile.dart';
import 'package:foodandes_app/data/services/connectivity_service.dart';
import 'package:foodandes_app/data/services/pending_reviews_queue_service.dart';

class WriteReviewScreen extends StatefulWidget {
  static const String routeName = '/write-review';

  const WriteReviewScreen({super.key});

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  final ReviewRepository _reviewRepository = ReviewRepository();
  final UserService _userService = UserService();
  final TextEditingController _commentController = TextEditingController();

  int _selectedRating = 5;
  bool _isLoading = false;
  String? _restaurantId;
  String? _restaurantName;
  UserProfile? _profile;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (args != null) {
      _restaurantId = args['restaurantId'] as String?;
      _restaurantName = args['restaurantName'] as String?;
    }

    _loadUser();
  }

  Future<void> _loadUser() async {
    final profile = await _userService.getCurrentUserProfile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
    });
  }

  Future<void> _submitReview() async {
    if (_restaurantId == null || _profile == null) return;

    final comment = _commentController.text.trim();

    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a comment')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final isOnline = await ConnectivityService.instance.isOnline;

      if (!isOnline) {
        await PendingReviewsQueueService.instance.enqueueReview(
          restaurantId: _restaurantId!,
          restaurantName: _restaurantName ?? 'Restaurant',
          comment: comment,
          rating: _selectedRating,
          userName: _profile!.name,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are offline. Your review will be sent when connection returns.'),
          ),
        );

        Navigator.pop(context);
        return;
      }

      await _reviewRepository.addReview(
        restaurantId: _restaurantId!,
        comment: comment,
        rating: _selectedRating,
        userName: _profile!.name,
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      await PendingReviewsQueueService.instance.enqueueReview(
        restaurantId: _restaurantId!,
        restaurantName: _restaurantName ?? 'Restaurant',
        comment: comment,
        rating: _selectedRating,
        userName: _profile!.name,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection failed. Your review was saved and will sync later.'),
        ),
      );

      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildStar(int value) {
    return IconButton(
      onPressed: () {
        setState(() {
          _selectedRating = value;
        });
      },
      icon: Icon(
        value <= _selectedRating ? Icons.star : Icons.star_border,
        color: AppColors.primary,
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Write a Review'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(18, 18, 18, 18 + bottomInset),
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
              const SizedBox(height: 18),
              const Text(
                'Your rating',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              Wrap(
                children: List.generate(5, (index) => _buildStar(index + 1)),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _commentController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Write your review here...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: _isLoading ? null : _submitReview,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text('Submit Review'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
