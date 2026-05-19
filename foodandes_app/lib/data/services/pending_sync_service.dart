import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:foodandes_app/data/services/connectivity_service.dart';
import 'package:foodandes_app/data/services/review_service.dart';
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

    await ConnectivityService.instance.start();
    var firstEvent = true;
    _subscription = ConnectivityService.instance.onlineStream.listen((isOnline) {
      if (firstEvent) {
        firstEvent = false;
        return;
      }
      if (isOnline) {
        unawaited(syncAllPending());
      }
    });

    if (await ConnectivityService.instance.isOnline()) {
      Future<void>.delayed(const Duration(seconds: 2), () => syncAllPending());
    }
  }

  Future<void> syncAllPending() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      await Future.wait([
        UserService().syncPendingFavoriteActions(),
        ReviewService().syncPendingReviews(),
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
