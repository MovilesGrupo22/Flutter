import 'package:flutter/material.dart';
import 'package:foodandes_app/core/constants/app_strings.dart';

class CustomSearchBar extends StatelessWidget {
  final String hintText;
  final String? initialValue;
  final bool readOnly;
  final VoidCallback? onTap;

  const CustomSearchBar({
    super.key,
    this.hintText = AppStrings.searchHint,
    this.initialValue,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search),
      ),
    );
  }
}