import 'package:flutter/foundation.dart';
import 'package:mombongo/services/service_locator.dart';

/// Une opération d'encaissement affichée sur l'accueil caissier.
class CaisseOperation {
  const CaisseOperation({
    required this.reference,
    required this.date,
    required this.montant,
    required this.modePaiement,
    required this.clientName,
    required this.isAcompte,
    required this.isPending,
  });

  final String reference;
  final DateTime date;

  /// Montant encaissé, en devise de base.
  final double montant;
  final String modePaiement;
  final String clientName;
  final bool isAcompte;

  /// Vente hors ligne pas encore synchronisée.
  final bool isPending;
}

/// Résumé de la caisse du jour pour le caissier connecté.
class CaisseDuJour {
  const CaisseDuJour({
    required this.total,
    required this.especes,
    required this.mobile,
    required this.autres,
    required this.count,
    required this.recent,
    required this.fromServer,
  });

  static const empty = CaisseDuJour(
    total: 0,
    especes: 0,
    mobile: 0,
    autres: 0,
    count: 0,
    recent: [],
    fromServer: false,
  );

  /// Montants en devise de base.
  final double total;
  final double especes;
  final double mobile;

  /// Carte bancaire, chèque et autres modes.
  final double autres;
  final int count;
  final List<CaisseOperation> recent;

  /// false : serveur injoignable, seules les ventes locales sont comptées.
  final bool fromServer;

  double get average => count == 0 ? 0 : total / count;
}

/// Calcule la caisse du jour à partir :
/// - des paiements du caissier renvoyés par l'API (triés du plus récent) ;
/// - des ventes hors ligne encore en file d'attente (pas encore sur le
///   serveur, donc jamais comptées deux fois).
class CaisseDuJourService {
  CaisseDuJourService._();

  static const int _pageSize = 50;
  static const int _maxPages = 6;

  static Future<CaisseDuJour> load() async {
    final user = locator.authRepository.currentUser;
    if (user == null) return CaisseDuJour.empty;
    final idUser = int.tryParse(user.idUtilisateur) ?? 0;

    final operations = <CaisseOperation>[..._pendingOperations(idUser)];
    var fromServer = false;

    if (idUser > 0) {
      try {
        operations.addAll(await _serverOperationsToday(idUser));
        fromServer = true;
      } catch (e) {
        debugPrint('Caisse du jour : serveur indisponible ($e)');
      }
    }

    operations.sort((a, b) => b.date.compareTo(a.date));

    double total = 0, especes = 0, mobile = 0, autres = 0;
    for (final op in operations) {
      total += op.montant;
      switch (_modeGroup(op.modePaiement)) {
        case _Mode.especes:
          especes += op.montant;
        case _Mode.mobile:
          mobile += op.montant;
        case _Mode.autres:
          autres += op.montant;
      }
    }

    return CaisseDuJour(
      total: total,
      especes: especes,
      mobile: mobile,
      autres: autres,
      count: operations.length,
      recent: operations.take(5).toList(),
      fromServer: fromServer,
    );
  }

  /// Nombre de dettes (avances / acomptes) du caissier, null si indisponible.
  static Future<int?> loadDettesCount() async {
    final user = locator.authRepository.currentUser;
    if (user == null) return null;
    try {
      final response = await locator.apiService.getAvanceAcompte(
        idSociete: int.tryParse(user.idSociete) ?? 0,
        idSite: int.tryParse(user.idSite) ?? 0,
        idUtilisateur: int.tryParse(user.idUtilisateur),
        pageNumber: 1,
        pageSize: 1,
      );
      final total = response['totalCount'];
      if (total is num) return total.toInt();
      final data = response['data'];
      return data is List ? data.length : null;
    } catch (e) {
      debugPrint('Caisse du jour : dettes indisponibles ($e)');
      return null;
    }
  }

  static Future<List<CaisseOperation>> _serverOperationsToday(
    int idUser,
  ) async {
    final result = <CaisseOperation>[];
    for (var page = 1; page <= _maxPages; page++) {
      final response = await locator.apiService.getPaiementsByCaissier(
        idUser,
        pageNumber: page,
        pageSize: _pageSize,
      );
      final data = response['data'];
      if (data is! List || data.isEmpty) break;

      var reachedOlderDays = false;
      for (final raw in data) {
        if (raw is! Map) continue;
        final p = Map<String, dynamic>.from(raw);
        final date = DateTime.tryParse('${p['datePaiement']}')?.toLocal();
        if (date == null) continue;
        if (!_isToday(date)) {
          reachedOlderDays = true;
          continue;
        }
        final commande = p['commande'] is Map
            ? Map<String, dynamic>.from(p['commande'] as Map)
            : null;
        final client = commande?['client'] is Map
            ? Map<String, dynamic>.from(commande!['client'] as Map)
            : null;
        result.add(
          CaisseOperation(
            reference:
                (p['referencePaiement'] ?? p['referencePaiemenet'] ?? '-')
                    .toString(),
            date: date,
            montant: _toDouble(p['montant']),
            modePaiement: (p['modePaiement'] ?? '').toString(),
            clientName: '${client?['prenom'] ?? ''} ${client?['nom'] ?? ''}'
                .trim(),
            isAcompte: '${p['typeTransaction']}' == '1',
            isPending: false,
          ),
        );
      }

      final hasNext = response['hasNextPage'] == true;
      if (reachedOlderDays || !hasNext) break;
    }
    return result;
  }

  static List<CaisseOperation> _pendingOperations(int idUser) {
    final result = <CaisseOperation>[];
    try {
      for (final entry in locator.databaseService.getOfflineVentesQueue()) {
        if (entry['synced'] == true) continue;
        final data = entry['data'];
        if (data is! Map) continue;
        final d = Map<String, dynamic>.from(data);
        if ((int.tryParse('${d['idUtilisateur']}') ?? -1) != idUser) continue;
        final date = DateTime.tryParse(
          '${d['datePaiement'] ?? d['dateCommande'] ?? entry['timestamp']}',
        )?.toLocal();
        if (date == null || !_isToday(date)) continue;
        final client = '${d['prenom'] ?? ''} ${d['nom'] ?? ''}'.trim();
        result.add(
          CaisseOperation(
            reference: '${d['referencePaiement'] ?? '-'}',
            date: date,
            montant: _toDouble(d['montant']),
            modePaiement: '${d['modePaiement'] ?? ''}',
            clientName: client == 'Anonyme Client' ? '' : client,
            isAcompte: '${d['typeTransaction']}' == '1',
            isPending: true,
          ),
        );
      }
    } catch (e) {
      debugPrint('Caisse du jour : file hors ligne illisible ($e)');
    }
    return result;
  }

  static bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  static double _toDouble(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  static _Mode _modeGroup(String mode) {
    final m = mode.toLowerCase();
    if (m.contains('esp')) return _Mode.especes;
    if (m.contains('mobile')) return _Mode.mobile;
    return _Mode.autres;
  }
}

enum _Mode { especes, mobile, autres }
