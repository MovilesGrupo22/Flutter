import 'package:connectivity_plus/connectivity_plus.dart';

// Network falling back to cache strategy:
// When the device goes offline, the app stops receiving Firestore pushes.
// ConnectivityService detects this transition and broadcasts it so that
// HomeScreen can display the OfflineBanner and load data from the local
// SQLite cache (LocalDatabaseService) instead of waiting for the network.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();
  factory ConnectivityService() => instance;

  final Connectivity _connectivity = Connectivity();

  // Emits true when online, false when offline.
  Stream<bool> get isOnlineStream => _connectivity.onConnectivityChanged
      .map((results) => results.any((r) => r != ConnectivityResult.none));

  // One-shot check of current connectivity state.
  Future<bool> get isOnline async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }
}
