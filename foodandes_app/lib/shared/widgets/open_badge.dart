import 'package:flutter/material.dart';
import 'package:foodandes_app/core/constants/app_colors.dart';

class OpenBadge extends StatelessWidget {
  final bool isOpen;

  const OpenBadge({
    super.key,
    required this.isOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOpen ? AppColors.success : AppColors.textSecondary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isOpen ? 'Open' : 'Closed',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}