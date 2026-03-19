import 'package:flutter/material.dart';
import 'package:foodandes_app/features/search/search_empty_screen.dart';

class SearchActiveScreen extends StatelessWidget {
  static const String routeName = '/search-active';

  const SearchActiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SearchEmptyScreen();
  }
}