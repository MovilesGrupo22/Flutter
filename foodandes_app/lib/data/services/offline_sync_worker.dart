import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:foodandes_app/data/services/connectivity_service.dart';
import 'package:foodandes_app/data/services/pending_reviews_queue_service.dart';

class OfflineSyncWorker {
  OfflineSyncWorker._();

  static final OfflineSyncWorker instance = OfflineSyncWorker._();

  StreamSubscription<bool>? _subscription;
  bool _isSyncing = false;

  void start() {
    _subscription ??= ConnectivityService.instance.isOnlineStream.listen(
      (isOnline) async {
        if (!isOnline || _isSyncing) return;

        _isSyncing = true;
        try {
          await PendingReviewsQueueService.instance.syncPendingReviews();
        } catch (e) {
          debugPrint('OfflineSyncWorker error: $e');
        } finally {
          _isSyncing = false;
        }
      },
    );
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}