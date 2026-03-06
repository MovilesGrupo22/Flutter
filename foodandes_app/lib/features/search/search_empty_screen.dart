import 'package:flutter/material.dart';
import 'package:foodandes_app/features/search/search_active_screen.dart';
import 'package:foodandes_app/shared/widgets/custom_bottom_navbar.dart';
import 'package:foodandes_app/shared/widgets/custom_search_bar.dart';
import 'package:foodandes_app/shared/widgets/empty_state_widget.dart';

class SearchEmptyScreen extends StatelessWidget {
  static const String routeName = '/search-empty';

  const SearchEmptyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
      bottomNavigationBar: const CustomBottomNavbar(currentIndex: 2),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CustomSearchBar(
              readOnly: true,
              onTap: () {
                Navigator.pushNamed(context, SearchActiveScreen.routeName);
              },
            ),
            const Expanded(
              child: EmptyStateWidget(
                icon: Icons.search,
                title: 'Start typing to search',
                subtitle: 'Find restaurants by name or category',
              ),
            ),
          ],
        ),
      ),
    );
  }
}