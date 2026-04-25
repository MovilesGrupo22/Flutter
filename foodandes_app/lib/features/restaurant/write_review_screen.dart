import 'dart:async';

import 'package:flutter/material.dart';
import 'package:foodandes_app/core/constants/app_colors.dart';
import 'package:foodandes_app/data/repositories/review_repository.dart';
import 'package:foodandes_app/data/services/connectivity_service.dart';
import 'package:foodandes_app/data/services/review_draft_service.dart';
import 'package:foodandes_app/data/services/user_service.dart';
import 'package:foodandes_app/models/user_profile.dart';
import 'package:foodandes_app/shared/widgets/offline_protected_notice.dart';

class WriteReviewScreen extends StatefulWidget {
  static const String routeName = '/write-review';

  const WriteReviewScreen({super.key});

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  final ReviewRepository _reviewRepository = ReviewRepository();
  final UserService _userService = UserService();
  final ReviewDraftService _reviewDraftService = ReviewDraftService.instance;
  final TextEditingController _commentController = TextEditingController();

  int _selectedRating = 5;
  bool _isLoading = false;
  bool _isOffline = false;
  StreamSubscription<bool>? _connectivitySubscription;
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
    _loadDraft();
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    final online = await ConnectivityService.instance.isOnline;
    if (!mounted) return;
    setState(() => _isOffline = !online);
    await _connectivitySubscription?.cancel();
    _connectivitySubscription =
        ConnectivityService.instance.isOnlineStream.listen((isOnline) {
      if (!mounted) return;
      setState(() => _isOffline = !isOnline);
    });
  }

  Future<void> _loadUser() async {
    final profile = await _userService.getCurrentUserProfile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
    });
  }

  Future<void> _loadDraft() async {
    if (_restaurantId == null) return;
    final draft = await _reviewDraftService.getDraft(_restaurantId!);
    if (!mounted) return;
    _commentController.text = draft['comment'] as String? ?? '';
    setState(() {
      _selectedRating = draft['rating'] as int? ?? 5;
    });
  }

  Future<void> _saveDraft() async {
    if (_restaurantId == null) return;
    await _reviewDraftService.saveDraft(
      restaurantId: _restaurantId!,
      comment: _commentController.text,
      rating: _selectedRating,
    );
  }

  Future<void> _submitReview() async {
    if (_restaurantId == null || _profile == null) return;

    if (_isOffline) {
      await _saveDraft();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Offline mode: your draft was saved locally. Connect to submit the review.',
          ),
        ),
      );
      return;
    }

    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a comment')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _reviewRepository.addReview(
        restaurantId: _restaurantId!,
        comment: _commentController.text.trim(),
        rating: _selectedRating,
        userName: _profile!.name,
      );

      await _reviewDraftService.clearDraft(_restaurantId!);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error submitting review')),
      );
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
        unawaited(_saveDraft());
      },
      icon: Icon(
        value <= _selectedRating ? Icons.star : Icons.star_border,
        color: AppColors.primary,
      ),
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
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
              if (_isOffline)
                const OfflineProtectedNotice(
                  message:
                      'Offline mode · review draft is saved locally, but submission requires internet',
                ),
              if (_isOffline) const SizedBox(height: 16),
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
                onChanged: (_) => unawaited(_saveDraft()),
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
                      : Text(_isOffline ? 'Save Draft Offline' : 'Submit Review'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
