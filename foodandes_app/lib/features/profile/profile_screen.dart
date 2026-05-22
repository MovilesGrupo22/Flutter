import 'dart:async';

import 'package:flutter/material.dart';
import 'package:foodandes_app/core/constants/app_colors.dart';
import 'package:foodandes_app/data/services/auth_services.dart';
import 'package:foodandes_app/data/services/connectivity_service.dart';
import 'package:foodandes_app/data/services/saved_meal_plan_service.dart';
import 'package:foodandes_app/data/services/theme_mode_service.dart';
import 'package:foodandes_app/shared/widgets/app_cached_image.dart';
import 'package:foodandes_app/shared/widgets/offline_protected_notice.dart';
import 'package:foodandes_app/data/services/user_service.dart';
import 'package:foodandes_app/data/services/review_service.dart';
import 'package:foodandes_app/features/auth/login_screen.dart';
import 'package:foodandes_app/features/meal_plan/saved_meal_plans_screen.dart';
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
  late Future<int> _savedMealPlanCountFuture;
  bool _isOffline = false;
  StreamSubscription<bool>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    unawaited(_authServices.syncCurrentUserDocument());
    _profileFuture = _userService.getCurrentUserProfile();
    _reviewCountFuture = _reviewService
        .getCurrentUserReviewCount()
        .catchError((_) => 0);
    _savedMealPlanCountFuture = _loadSavedMealPlanCount();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      AnalyticsService.instance.logSectionView(
        section: AppSection.profile,
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

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<int> _loadSavedMealPlanCount() async {
    final plans = await SavedMealPlanService.instance.getSavedPlans();
    return plans.length;
  }

  Future<void> _openSavedMealPlans() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    await AnalyticsService.instance.logSectionInteraction(
      section: AppSection.profile,
      action: 'open_saved_meal_plans_from_profile',
      userId: currentUser?.uid,
    );

    if (!mounted) return;
    await Navigator.pushNamed(context, SavedMealPlansScreen.routeName);
    if (!mounted) return;
    setState(() {
      _savedMealPlanCountFuture = _loadSavedMealPlanCount();
    });
  }

  Future<void> _updateThemePreference(AppThemePreference preference) async {
    await ThemeModeService.instance.setPreference(preference);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Appearance updated: ${preference.label}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _ambientLightDescription(ThemeModeService themeModeService) {
    final lux = themeModeService.lastLux;
    if (lux == null) {
      return 'Waiting for the ambient-light sensor on this device.';
    }

    final roundedLux = lux.toStringAsFixed(1);
    final lightState = themeModeService.isLowLight ? 'low light' : 'enough light';
    return 'Ambient light: $roundedLux lux · $lightState';
  }

  Widget _buildAppearanceSettingsCard() {
    return AnimatedBuilder(
      animation: ThemeModeService.instance,
      builder: (context, _) {
        final themeModeService = ThemeModeService.instance;
        final colorScheme = Theme.of(context).colorScheme;
        final isAdaptive = themeModeService.preference == AppThemePreference.adaptive;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        themeModeService.preference.icon,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Appearance',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            themeModeService.effectiveLabel,
                            style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.68),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<AppThemePreference>(
                  value: themeModeService.preference,
                  decoration: const InputDecoration(
                    labelText: 'Theme mode',
                  ),
                  items: AppThemePreference.values.map((preference) {
                    return DropdownMenuItem(
                      value: preference,
                      child: Row(
                        children: [
                          Icon(preference.icon, size: 20),
                          const SizedBox(width: 10),
                          Text(preference.label),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (preference) {
                    if (preference == null) return;
                    unawaited(_updateThemePreference(preference));
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  themeModeService.preference.description,
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.68),
                  ),
                ),
                if (isAdaptive) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: themeModeService.isLowLight
                          ? colorScheme.primary.withOpacity(0.14)
                          : colorScheme.surfaceContainerHighest.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          themeModeService.isLowLight
                              ? Icons.nights_stay_outlined
                              : Icons.wb_sunny_outlined,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _ambientLightDescription(themeModeService),
                            style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.76),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
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

  Widget _buildSavedMealPlansAccessCard(int savedPlansCount) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _openSavedMealPlans,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.bookmarks_outlined,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Saved meal plans',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      savedPlansCount == 0
                          ? 'Open your locally saved food plans'
                          : '$savedPlansCount plans saved locally',
                      style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.68),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
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
                        if (_isOffline) ...[
                          const OfflineProtectedNotice(
                            message: 'Offline mode · showing local account data',
                          ),
                          const SizedBox(height: 16),
                        ],
                        const SizedBox(height: 20),
                        Center(
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: AppColors.primary,
                            child: profile.photoURL.isNotEmpty
                                ? AppCachedImage(
                                    imageUrl: profile.photoURL,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    borderRadius: BorderRadius.circular(40),
                                    errorWidget: Center(
                                      child: Text(
                                        initials.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  )
                                : Text(
                                    initials.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
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
                        FutureBuilder<int>(
                          future: _savedMealPlanCountFuture,
                          builder: (context, savedPlansSnapshot) {
                            return _buildSavedMealPlansAccessCard(
                              savedPlansSnapshot.data ?? 0,
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildAppearanceSettingsCard(),
                        const SizedBox(height: 16),
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
