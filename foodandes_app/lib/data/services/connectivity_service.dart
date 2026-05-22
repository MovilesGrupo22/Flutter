import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

// Network falling back to cache strategy:
// When the device goes offline, the app stops receiving Firestore pushes.
// ConnectivityService detects this transition and broadcasts it so that
// protected views can display a clear offline state and use local caches.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();
  factory ConnectivityService() => instance;

  final Connectivity _connectivity = Connectivity();

  bool _hasNetwork(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  // Emits true when the device has a network connection and false when it does
  // not. This is a Stream strategy: screens keep listening while they are alive
  // and cancel the subscription in dispose().
  Stream<bool> get isOnlineStream => _connectivity.onConnectivityChanged
      .map(_hasNetwork)
      .distinct()
      .handleError((Object error) {
        debugPrint('Connectivity stream ERROR -> $error');
      });

  // Future + async/await strategy. Used by guarded actions before touching
  // Firebase/Auth so the user gets an immediate offline notice instead of a
  // failed request.
  Future<bool> get isOnline async {
    try {
      final results = await _connectivity.checkConnectivity();
      return _hasNetwork(results);
    } catch (error) {
      debugPrint('Connectivity check ERROR -> $error');
      return false;
    }
  }

  // Future with handler strategy. Kept as an explicit example for places where
  // a chained Future is clearer than async/await, such as fire-and-forget status
  // probes from widgets.
  Future<bool> isOnlineWithHandlers() {
    return _connectivity
        .checkConnectivity()
        .then(_hasNetwork)
        .catchError((Object error) {
      debugPrint('Connectivity handler ERROR -> $error');
      return false;
    });
  }
}
