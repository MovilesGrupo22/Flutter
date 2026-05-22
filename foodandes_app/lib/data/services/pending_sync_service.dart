import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:foodandes_app/data/services/connectivity_service.dart';
import 'package:foodandes_app/data/services/pending_reviews_queue_service.dart';
import 'package:foodandes_app/data/services/user_service.dart';

class PendingSyncService {
  PendingSyncService._();

  static final PendingSyncService instance = PendingSyncService._();

  StreamSubscription<bool>? _subscription;
  bool _started = false;
  bool _isSyncing = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    _subscription = ConnectivityService.instance.isOnlineStream.listen((isOnline) {
      if (isOnline) {
        unawaited(syncAllPending());
      }
    });

    if (await ConnectivityService.instance.isOnline) {
      Future<void>.delayed(const Duration(seconds: 2), () => syncAllPending());
    }
  }

  Future<void> syncAllPending() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      await Future.wait([
        UserService().syncPendingFavoriteActions(),
        PendingReviewsQueueService.instance.syncPendingReviews(),
      ]);
    } catch (e) {
      debugPrint('PendingSyncService.syncAllPending ERROR -> $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _started = false;
  }
}
