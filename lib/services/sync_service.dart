import 'dart:async';
import 'package:flutter/foundation.dart';
import '../repositories/vente_repository.dart';
import 'connectivity_service.dart';

/// Écoute la reconnexion et synchronise la file des ventes offline.
class SyncService extends ChangeNotifier {
  final ConnectivityService _connectivity;
  final VenteRepository _venteRepository;

  StreamSubscription<bool>? _sub;
  bool _isSyncing = false;
  bool _isOnline = true;
  int _pendingCount = 0;
  String? _lastSyncMessage;

  SyncService(this._connectivity, this._venteRepository);

  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;
  int get pendingCount => _pendingCount;
  String? get lastSyncMessage => _lastSyncMessage;

  Future<void> initialize() async {
    _isOnline = _connectivity.isOnline;
    _refreshPendingCount();

    _sub = _connectivity.onStatusChanged.listen((online) async {
      _isOnline = online;
      notifyListeners();
      if (online) {
        await syncNow(triggeredByReconnect: true);
      }
    });
  }

  void _refreshPendingCount() {
    _pendingCount = _venteRepository.pendingOfflineCount;
  }

  /// À appeler après une vente offline pour rafraîchir le bandeau.
  void refreshPending() {
    _refreshPendingCount();
    notifyListeners();
  }

  Future<SyncVentesResult> syncNow({bool triggeredByReconnect = false}) async {
    if (_isSyncing) {
      return SyncVentesResult(
        synced: 0,
        failed: 0,
        remaining: _pendingCount,
      );
    }

    final online = await _connectivity.checkNow();
    _isOnline = online;
    if (!online) {
      _lastSyncMessage = 'Hors ligne — synchronisation impossible';
      notifyListeners();
      return SyncVentesResult(
        synced: 0,
        failed: 0,
        remaining: _venteRepository.pendingOfflineCount,
      );
    }

    _isSyncing = true;
    notifyListeners();

    try {
      final result = await _venteRepository.syncOfflineVentes();
      _refreshPendingCount();

      if (result.synced > 0 || result.failed > 0) {
        _lastSyncMessage = result.failed == 0
            ? '${result.synced} vente(s) synchronisée(s)'
            : '${result.synced} sync, ${result.failed} échec(s), ${result.remaining} en attente';
      } else if (triggeredByReconnect && result.remaining == 0) {
        _lastSyncMessage = null;
      }

      if (kDebugMode) {
        debugPrint(
          'SyncService: synced=${result.synced} failed=${result.failed} remaining=${result.remaining}',
        );
      }

      return result;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
