import 'package:flutter/material.dart';

class CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const CategoryChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap?.call(),
        selectedColor: colorScheme.primary,
        backgroundColor: colorScheme.surface,
        labelStyle: TextStyle(
          color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}
