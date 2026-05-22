import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foodandes_app/data/services/analytics_service.dart';
import 'package:foodandes_app/features/favorites/favorites_screen.dart';
import 'package:foodandes_app/features/home/home_screen.dart';
import 'package:foodandes_app/features/map/map_screen.dart';
import 'package:foodandes_app/features/search/search_empty_screen.dart';

class CustomBottomNavbar extends StatelessWidget {
  final int currentIndex;

  const CustomBottomNavbar({
    super.key,
    required this.currentIndex,
  });

  AppSection _sectionFromIndex(int index) {
    switch (index) {
      case 0:
        return AppSection.home;
      case 1:
        return AppSection.map;
      case 2:
        return AppSection.search;
      case 3:
        return AppSection.favorites;
      default:
        return AppSection.home;
    }
  }

  void _onTap(BuildContext context, int index) {
    final routes = [
      HomeScreen.routeName,
      MapScreen.routeName,
      SearchEmptyScreen.routeName,
      FavoritesScreen.routeName,
    ];

    if (index == currentIndex) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    final currentSection = _sectionFromIndex(currentIndex);
    final targetSection = _sectionFromIndex(index);

    unawaited(
      AnalyticsService.instance.logSectionInteraction(
        section: currentSection,
        action: 'bottom_nav_tap',
        userId: userId,
        additionalParameters: {
          'target_section': targetSection.name,
        },
      ),
    );

    Navigator.pushReplacementNamed(context, routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return NavigationBar(
      selectedIndex: currentIndex,
      indicatorColor: colorScheme.primary.withOpacity(0.12),
      backgroundColor: colorScheme.surface,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      onDestinationSelected: (index) => _onTap(context, index),
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home, color: colorScheme.primary),
          label: 'Home',
        ),
        NavigationDestination(
          icon: const Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map, color: colorScheme.primary),
          label: 'Map',
        ),
        NavigationDestination(
          icon: const Icon(Icons.search_outlined),
          selectedIcon: Icon(Icons.search, color: colorScheme.primary),
          label: 'Search',
        ),
        NavigationDestination(
          icon: const Icon(Icons.favorite_border),
          selectedIcon: Icon(Icons.favorite, color: colorScheme.primary),
          label: 'Favorites',
        ),
      ],
    );
  }
}
