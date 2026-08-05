import 'package:flutter/foundation.dart';
import '../../models/ligne_commande.dart';
import '../../models/vente.dart';
import '../../services/service_locator.dart';

/// Résultat d'un enregistrement de vente (online ou offline).
class VenteEnregistrementResult {
  final Map<String, dynamic> response;
  final bool isOffline;
  final String localId;
  final String reference;

  const VenteEnregistrementResult({
    required this.response,
    required this.isOffline,
    required this.localId,
    required this.reference,
  });
}

/// Résultat d'une synchronisation de la file offline.
class SyncVentesResult {
  final int synced;
  final int failed;
  final int remaining;

  const SyncVentesResult({
    required this.synced,
    required this.failed,
    required this.remaining,
  });
}

class VenteRepository {
  Future<List<Vente>> getAllVentes({bool forceRefresh = false}) async {
    return await locator.cacheStrategy.getVentes(forceRefresh: forceRefresh);
  }

  /// Point d'entrée unique vente : online API ou file offline.
  Future<VenteEnregistrementResult> enregistrerVente(
    Map<String, dynamic> venteData,
  ) async {
    if (venteData['lignesCommandes'] == null ||
        (venteData['lignesCommandes'] as List).isEmpty) {
      throw Exception('Au moins une ligne de commande est requise');
    }

    final isConnected = await locator.connectivityService.checkNow();

    if (isConnected) {
      try {
        final response = await locator.apiService.enregistrerVente(venteData);
        await _applyLocalStockDecrement(venteData);
        await _persistVenteFromResponse(response, venteData);

        final responseMap = response is Map
            ? Map<String, dynamic>.from(response)
            : <String, dynamic>{'success': true, 'raw': response};

        final reference = (venteData['referencePaiement'] ??
                responseMap['reference'] ??
                responseMap['referencePaiement'] ??
                '')
            .toString();

        return VenteEnregistrementResult(
          response: responseMap,
          isOffline: false,
          localId: '',
          reference: reference,
        );
      } catch (e) {
        // Si l'API échoue alors qu'on pensait être online, bascule offline
        final stillOnline = await locator.apiService.checkConnectivity();
        if (stillOnline) rethrow;
        if (kDebugMode) {
          debugPrint('API vente échouée sans réseau, bascule offline: $e');
        }
        return _enqueueOfflineVente(venteData);
      }
    }

    return _enqueueOfflineVente(venteData);
  }

  /// Alias conservé pour compatibilité.
  Future<Vente> createVente(Map<String, dynamic> venteData) async {
    final result = await enregistrerVente(venteData);
    return Vente(
      id: int.tryParse(result.localId) ??
          (result.response['id'] is int
              ? result.response['id'] as int
              : int.tryParse('${result.response['id']}') ?? 0),
      idClient: int.tryParse('${venteData['idClient'] ?? -1}') ?? -1,
      idUtilisateur:
          int.tryParse('${venteData['idUtilisateur'] ?? 0}') ?? 0,
      dateCommande: DateTime.tryParse('${venteData['dateCommande']}') ??
          DateTime.now(),
      statutCommande: result.isOffline
          ? 'En attente de synchronisation'
          : '${venteData['statutCommande'] ?? 'VALIDEE'}',
      montantTotal: _calculateTotalAmount(
        venteData['lignesCommandes'] as List? ?? [],
      ),
      reference: result.reference,
      typeTransaction: venteData['typeTransaction'] as int? ?? 0,
      lignesCommandes: _mapLignes(venteData['lignesCommandes'] as List? ?? []),
    );
  }

  Future<VenteEnregistrementResult> _enqueueOfflineVente(
    Map<String, dynamic> venteData,
  ) async {
    final localId = '-${DateTime.now().millisecondsSinceEpoch}';
    final reference = (venteData['referencePaiement'] as String?)?.isNotEmpty ==
            true
        ? venteData['referencePaiement'] as String
        : 'OFFLINE_${DateTime.now().millisecondsSinceEpoch}';

    final payload = Map<String, dynamic>.from(venteData);
    payload['referencePaiement'] = reference;

    final entry = <String, dynamic>{
      'localId': localId,
      'timestamp': DateTime.now().toIso8601String(),
      'operation': 'create',
      'synced': false,
      'data': payload,
    };

    await locator.databaseService.enqueueOfflineVente(entry);
    await _applyLocalStockDecrement(payload);

    final offlineVente = Vente(
      id: int.tryParse(localId) ?? -DateTime.now().millisecondsSinceEpoch,
      idClient: -1,
      idUtilisateur:
          int.tryParse('${payload['idUtilisateur'] ?? 0}') ?? 0,
      dateCommande:
          DateTime.tryParse('${payload['dateCommande']}') ?? DateTime.now(),
      statutCommande: 'En attente de synchronisation',
      montantTotal: _calculateTotalAmount(
        payload['lignesCommandes'] as List? ?? [],
      ),
      reference: reference,
      typeTransaction: payload['typeTransaction'] as int? ?? 0,
      lignesCommandes: _mapLignes(payload['lignesCommandes'] as List? ?? []),
    );

    final currentVentes = locator.databaseService.getVentes();
    currentVentes.add(offlineVente);
    await locator.databaseService.saveVentes(currentVentes);

    final syntheticResponse = <String, dynamic>{
      ...payload,
      'success': true,
      'offline': true,
      'localId': localId,
      'reference': reference,
      'referencePaiement': reference,
      'message': 'Vente enregistrée hors ligne — synchronisation en attente',
    };

    return VenteEnregistrementResult(
      response: syntheticResponse,
      isOffline: true,
      localId: localId,
      reference: reference,
    );
  }

  Future<void> _applyLocalStockDecrement(Map<String, dynamic> venteData) async {
    final idSite = int.tryParse('${venteData['idSite']}') ?? 0;
    if (idSite <= 0) return;

    final lignes = venteData['lignesCommandes'];
    if (lignes is! List) return;

    for (final ligne in lignes) {
      if (ligne is! Map) continue;
      final idStock = int.tryParse('${ligne['idStock']}') ?? 0;
      final quantite = int.tryParse('${ligne['quantite']}') ?? 0;
      if (idStock <= 0 || quantite <= 0) continue;
      await locator.databaseService.decrementStockLocally(
        idSite: idSite,
        idStock: idStock,
        quantity: quantite,
      );
    }
  }

  Future<void> _persistVenteFromResponse(
    dynamic response,
    Map<String, dynamic> venteData,
  ) async {
    try {
      Map<String, dynamic> map;
      if (response is Map<String, dynamic>) {
        map = response;
      } else if (response is Map) {
        map = Map<String, dynamic>.from(response);
      } else {
        return;
      }

      // L'API peut ne pas renvoyer un objet Vente complet
      final vente = Vente(
        id: int.tryParse('${map['id'] ?? map['idVente'] ?? 0}') ?? 0,
        idClient: int.tryParse('${map['idClient'] ?? -1}') ?? -1,
        idUtilisateur:
            int.tryParse('${venteData['idUtilisateur'] ?? 0}') ?? 0,
        dateCommande:
            DateTime.tryParse('${venteData['dateCommande']}') ?? DateTime.now(),
        statutCommande: '${venteData['statutCommande'] ?? 'VALIDEE'}',
        montantTotal: _calculateTotalAmount(
          venteData['lignesCommandes'] as List? ?? [],
        ),
        reference:
            '${venteData['referencePaiement'] ?? map['reference'] ?? ''}',
        typeTransaction: venteData['typeTransaction'] as int? ?? 0,
        lignesCommandes: _mapLignes(venteData['lignesCommandes'] as List? ?? []),
      );

      final currentVentes = locator.databaseService.getVentes();
      currentVentes.add(vente);
      await locator.databaseService.saveVentes(currentVentes);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Impossible de persister la vente locale: $e');
      }
    }
  }

  List<LigneCommande> _mapLignes(List lignes) {
    final result = <LigneCommande>[];
    for (final ligne in lignes) {
      if (ligne is! Map) continue;
      try {
        final quantite = int.tryParse('${ligne['quantite']}') ?? 0;
        final prixUnitaire =
            double.tryParse('${ligne['prixUnitaire']}') ?? 0.0;
        final tva = double.tryParse('${ligne['tva']}') ?? 0.0;
        final remise = double.tryParse('${ligne['remise']}') ?? 0.0;
        final subtotal = quantite * prixUnitaire;
        final montant =
            subtotal + (subtotal * tva / 100) - (subtotal * remise / 100);
        result.add(
          LigneCommande(
            id: 0,
            idCommande: 0,
            idStock: int.tryParse('${ligne['idStock']}') ?? 0,
            quantite: quantite,
            prixUnitaire: prixUnitaire,
            tva: tva,
            remise: remise,
            montantTotal: montant,
          ),
        );
      } catch (_) {}
    }
    return result;
  }

  double _calculateTotalAmount(List<dynamic> lignesCommandes) {
    return lignesCommandes.fold(0.0, (sum, ligne) {
      if (ligne is! Map) return sum;
      final quantite = int.tryParse('${ligne['quantite']}') ?? 0;
      final prixUnitaire =
          double.tryParse('${ligne['prixUnitaire']}') ?? 0.0;
      final tva = double.tryParse('${ligne['tva']}') ?? 0.0;
      final remise = double.tryParse('${ligne['remise']}') ?? 0.0;

      final subtotal = quantite * prixUnitaire;
      final tvaAmount = subtotal * (tva / 100);
      final discountAmount = subtotal * (remise / 100);

      return sum + subtotal + tvaAmount - discountAmount;
    });
  }

  Future<List<Vente>> searchVentes({
    String? reference,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? statut,
    bool forceRefresh = false,
  }) async {
    final allVentes = await getAllVentes(forceRefresh: forceRefresh);

    return allVentes.where((vente) {
      bool matches = true;

      if (reference != null) {
        matches &=
            vente.reference.toLowerCase().contains(reference.toLowerCase());
      }

      if (dateFrom != null) {
        matches &= vente.dateCommande.isAfter(dateFrom);
      }

      if (dateTo != null) {
        matches &= vente.dateCommande.isBefore(dateTo);
      }

      if (statut != null) {
        matches &=
            vente.statutCommande.toLowerCase().contains(statut.toLowerCase());
      }

      return matches;
    }).toList();
  }

  Future<Vente?> getVenteById(int id) async {
    final ventes = await getAllVentes();
    try {
      return ventes.firstWhere((vente) => vente.id == id);
    } catch (e) {
      return null;
    }
  }

  int get pendingOfflineCount =>
      locator.databaseService.pendingOfflineVentesCount;

  /// Synchronise les ventes offline. Ne retire un item qu'après succès API.
  Future<SyncVentesResult> syncOfflineVentes() async {
    final isConnected = await locator.connectivityService.checkNow();
    if (!isConnected) {
      return SyncVentesResult(
        synced: 0,
        failed: 0,
        remaining: pendingOfflineCount,
      );
    }

    final queue = locator.databaseService.getOfflineVentesQueue();
    if (queue.isEmpty) {
      return const SyncVentesResult(synced: 0, failed: 0, remaining: 0);
    }

    final remaining = <Map<String, dynamic>>[];
    var synced = 0;
    var failed = 0;

    for (final entry in queue) {
      final data = entry['data'];
      if (data is! Map) {
        remaining.add(entry);
        failed++;
        continue;
      }

      final payload = Map<String, dynamic>.from(data);

      try {
        final response = await locator.apiService.enregistrerVente(payload);
        synced++;
        if (kDebugMode) {
          debugPrint(
            'Vente offline sync OK localId=${entry['localId']} → $response',
          );
        }
        // Succès : on ne remet pas dans remaining
      } catch (e) {
        failed++;
        remaining.add(entry);
        if (kDebugMode) {
          debugPrint('Échec sync vente offline ${entry['localId']}: $e');
        }
      }
    }

    await locator.databaseService.saveOfflineVentesQueue(remaining);

    return SyncVentesResult(
      synced: synced,
      failed: failed,
      remaining: remaining.length,
    );
  }
}
