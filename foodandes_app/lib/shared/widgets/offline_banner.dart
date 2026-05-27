import 'package:flutter/material.dart';

class OfflineBanner extends StatelessWidget {
  final bool isOffline;
  final String message;

  const OfflineBanner({
    super.key,
    required this.isOffline,
    this.message = 'Offline mode · Home is using saved restaurants and local filters',
  });

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();
    return Container(
      color: Colors.amber.shade200,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message),
          ),
        ],
      ),
    );
  }
}
