import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Surveille l'état réseau et expose un stream pour déclencher la sync.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _onlineController =
      StreamController<bool>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = true;
  bool _initialized = false;

  bool get isOnline => _isOnline;
  Stream<bool> get onStatusChanged => _onlineController.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final initial = await _connectivity.checkConnectivity();
    _isOnline = _hasConnection(initial);
    _onlineController.add(_isOnline);

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final online = _hasConnection(results);
      if (online != _isOnline) {
        _isOnline = online;
        _onlineController.add(_isOnline);
        if (kDebugMode) {
          debugPrint('ConnectivityService: ${_isOnline ? "en ligne" : "hors ligne"}');
        }
      }
    });
  }

  Future<bool> checkNow() async {
    final results = await _connectivity.checkConnectivity();
    final online = _hasConnection(results);
    if (online != _isOnline) {
      _isOnline = online;
      _onlineController.add(_isOnline);
    }
    return _isOnline;
  }

  static bool _hasConnection(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _onlineController.close();
    _initialized = false;
  }
}
