import 'package:flutter/material.dart';
import 'package:foodandes_app/shared/widgets/custom_bottom_navbar.dart';
import 'package:foodandes_app/shared/widgets/empty_state_widget.dart';

class FavoritesEmptyScreen extends StatelessWidget {
  static const String routeName = '/favorites-empty';

  const FavoritesEmptyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Favorites'),
      ),
      bottomNavigationBar: const CustomBottomNavbar(currentIndex: 3),
      body: const EmptyStateWidget(
        icon: Icons.favorite_border,
        title: 'No favorites yet',
        subtitle: 'Save restaurants to access them quickly later.',
      ),
    );
  }
}