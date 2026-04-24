import 'package:flutter/material.dart';
import 'package:foodandes_app/core/constants/app_colors.dart';

class OfflineProtectedNotice extends StatelessWidget {
  final String message;

  const OfflineProtectedNotice({
    super.key,
    this.message = 'Offline mode · showing last saved version',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE08A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}