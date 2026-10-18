import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../data/services/backend_locator.dart';

/// Monitors network connectivity changes and triggers pending report sync
/// when internet connection is restored.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;

  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isInitialized = false;

  /// Start listening for connectivity changes.
  /// Call this once during app initialization.
  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    _subscription = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
    debugPrint('ConnectivityService: initialized and listening for connectivity changes');
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    // Check if any connectivity result indicates internet access
    final hasInternet = results.any((result) => result != ConnectivityResult.none);

    if (hasInternet) {
      debugPrint('ConnectivityService: internet connection detected, flushing pending reports...');
      // Flush pending reports in the background
      BackendLocator.pendingReportsService.flushPendingReports().then((count) {
        if (count > 0) {
          debugPrint('ConnectivityService: successfully flushed $count pending reports');
        }
      }).catchError((e) {
        debugPrint('ConnectivityService: error flushing pending reports: $e');
      });
    } else {
      debugPrint('ConnectivityService: no internet connection');
    }
  }

  /// Check if device currently has internet connection.
  Future<bool> hasInternetConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((result) => result != ConnectivityResult.none);
    } catch (e) {
      debugPrint('ConnectivityService: error checking connectivity: $e');
      return false;
    }
  }

  /// Stop listening for connectivity changes.
  /// Call this during app teardown or testing.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _isInitialized = false;
    debugPrint('ConnectivityService: disposed');
  }
}
