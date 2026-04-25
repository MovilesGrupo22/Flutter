import 'package:flutter/material.dart';

class OfflineSyncBanner extends StatelessWidget {
  final bool isOffline;
  final bool isSyncing;
  final DateTime? lastSync;
  final String? offlineLabel;

  const OfflineSyncBanner({
    super.key,
    required this.isOffline,
    required this.isSyncing,
    required this.lastSync,
    this.offlineLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOffline && !isSyncing && lastSync == null) {
      return const SizedBox.shrink();
    }

    late final Color backgroundColor;
    late final IconData icon;
    late final String title;
    late final String subtitle;

    if (isSyncing) {
      backgroundColor = Colors.blue.shade50;
      icon = Icons.sync;
      title = 'Syncing data';
      subtitle = 'Refreshing the latest information from the cloud.';
    } else if (isOffline) {
      backgroundColor = Colors.orange.shade50;
      icon = Icons.wifi_off;
      title = 'Offline mode';
      final label = offlineLabel ?? 'Showing locally saved data.';
      subtitle = lastSync == null
          ? label
          : '$label Last sync ${_formatRelative(lastSync!)}.';
    } else {
      backgroundColor = Colors.green.shade50;
      icon = Icons.cloud_done_outlined;
      title = 'Local snapshot available';
      subtitle = 'Last sync ${_formatRelative(lastSync!)}.';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatRelative(DateTime lastSync) {
    final difference = DateTime.now().difference(lastSync);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes} min ago';
    if (difference.inDays < 1) return '${difference.inHours} h ago';
    return '${difference.inDays} d ago';
  }
}
