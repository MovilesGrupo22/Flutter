import 'package:flutter/material.dart';
import 'package:foodandes_app/core/constants/app_colors.dart';
import 'package:foodandes_app/features/favorites/favorites_empty_screen.dart';
import 'package:foodandes_app/features/home/home_screen.dart';
import 'package:foodandes_app/features/map/map_screen.dart';
import 'package:foodandes_app/features/search/search_empty_screen.dart';
import 'package:foodandes_app/features/favorites/favorites_screen.dart';

class CustomBottomNavbar extends StatelessWidget {
  final int currentIndex;

  const CustomBottomNavbar({
    super.key,
    required this.currentIndex,
  });

  void _onTap(BuildContext context, int index) {
    final routes = [
      HomeScreen.routeName,
      MapScreen.routeName,
      SearchEmptyScreen.routeName,
      FavoritesScreen.routeName,
    ];

    if (index != currentIndex) {
      Navigator.pushReplacementNamed(context, routes[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      indicatorColor: Colors.transparent,
      backgroundColor: Colors.white,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      onDestinationSelected: (index) => _onTap(context, index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home, color: AppColors.primary),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map, color: AppColors.primary),
          label: 'Map',
        ),
        NavigationDestination(
          icon: Icon(Icons.search_outlined),
          selectedIcon: Icon(Icons.search, color: AppColors.primary),
          label: 'Search',
        ),
        NavigationDestination(
          icon: Icon(Icons.favorite_border),
          selectedIcon: Icon(Icons.favorite, color: AppColors.primary),
          label: 'Favorites',
        ),
      ],
    );
  }
}