import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

abstract class NetworkMonitor {
  Future<bool> isOnline();

  Stream<bool> get onOnlineChanged;
}

class ConnectivityPlusNetworkMonitor implements NetworkMonitor {
  ConnectivityPlusNetworkMonitor({
    Connectivity? connectivity,
  }) : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return _hasReachableNetwork(results);
  }

  @override
  Stream<bool> get onOnlineChanged => _connectivity.onConnectivityChanged
      .map(_hasReachableNetwork);

  static bool _hasReachableNetwork(List<ConnectivityResult> results) {
    if (results.isEmpty) {
      return false;
    }
    for (final type in results) {
      if (type != ConnectivityResult.none) {
        return true;
      }
    }
    return false;
  }
}
