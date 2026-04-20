import 'dart:async';

import 'package:flutter/material.dart';
import 'package:foodandes_app/core/constants/app_colors.dart';
import 'package:foodandes_app/data/services/auth_services.dart';
import 'package:foodandes_app/data/services/user_service.dart';
import 'package:foodandes_app/data/services/review_service.dart';
import 'package:foodandes_app/features/auth/login_screen.dart';
import 'package:foodandes_app/models/user_profile.dart';
import 'package:foodandes_app/data/services/analytics_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatefulWidget {
  static const String routeName = '/profile';

  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();
  final ReviewService _reviewService = ReviewService();
  final AuthServices _authServices = AuthServices();

  late Future<UserProfile?> _profileFuture;
  late Future<int> _reviewCountFuture;

  @override
  void initState() {
    super.initState();
    unawaited(_authServices.syncCurrentUserDocument());
    _profileFuture = _userService.getCurrentUserProfile();
    _reviewCountFuture = _reviewService.getCurrentUserReviewCount();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      AnalyticsService.instance.logSectionView(
        section: AppSection.profile,
        userId: userId,
      );
    });
  }

  Future<void> _logout() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      await AnalyticsService.instance.logUserSessionEnd(
        userId: currentUser.uid,
        sessionDurationSeconds: 0,
      );
    }

    await AnalyticsService.instance.clearUser();
    await _authServices.logout();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      LoginScreen.routeName,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: FutureBuilder<UserProfile?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading profile: ${snapshot.error}'),
            );
          }

          final profile = snapshot.data;

          if (profile == null) {
            return const Center(child: Text('No user profile found'));
          }

          final initials = profile.name.isNotEmpty
              ? profile.name.trim().split(' ').map((e) => e[0]).take(2).join()
              : 'U';

          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth < 420
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 16) / 2;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 40,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 20),
                        Center(
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: AppColors.primary,
                            backgroundImage: profile.photoURL.isNotEmpty
                                ? NetworkImage(profile.photoURL)
                                : null,
                            child: profile.photoURL.isEmpty
                                ? Text(
                                    initials.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          profile.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          profile.email,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: cardWidth,
                              child: _ProfileStatCard(
                                label: 'Favorites',
                                value: '${profile.favoriteRestaurants.length}',
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: FutureBuilder<int>(
                                future: _reviewCountFuture,
                                builder: (context, reviewCountSnapshot) {
                                  final reviewCount = reviewCountSnapshot.data ?? 0;

                                  return _ProfileStatCard(
                                    label: 'Reviews',
                                    value: reviewCount.toString(),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (profile.dietaryPreferences.isNotEmpty) ...[
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Dietary Preferences',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: profile.dietaryPreferences.map((pref) {
                              return Chip(label: Text(pref));
                            }).toList(),
                          ),
                          const SizedBox(height: 28),
                        ] else
                          const SizedBox(height: 28),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            minimumSize: const Size.fromHeight(56),
                          ),
                          onPressed: _logout,
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ProfileStatCard extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileStatCard({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
