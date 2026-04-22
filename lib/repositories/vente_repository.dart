import '../../models/vente.dart';
import '../../services/service_locator.dart';

class VenteRepository {
  Future<List<Vente>> getAllVentes({bool forceRefresh = false}) async {
    return await locator.cacheStrategy.getVentes(forceRefresh: forceRefresh);
  }

  Future<Vente> createVente(Map<String, dynamic> venteData) async {
    try {
      // Validate required fields
      if (venteData['nom'] == null || venteData['prenom'] == null) {
        throw Exception('Nom et prénom du client requis');
      }

      if (venteData['lignesCommandes'] == null || 
          (venteData['lignesCommandes'] as List).isEmpty) {
        throw Exception('Au moins une ligne de commande est requise');
      }

      // Create client if needed (simplified - in real app, would check if client exists)
      /*final clientData = {
        'nom': venteData['nom'],
        'prenom': venteData['prenom'],
        'genre': venteData['genre'] ?? 'M',
        'email': venteData['email'],
        'telephone': venteData['telephone'],
        'statut': true,
        'idSite': venteData['idSite'] ?? 1,
      };*/

      // Create vente
      final response = await locator.apiService.enregistrerVente(venteData);
      
      // Convert response to Vente model
      final vente = Vente.fromJson(response);
      
      // Save to local database
      final currentVentes = locator.databaseService.getVentes();
      currentVentes.add(vente);
      await locator.databaseService.saveVentes(currentVentes);
      
      return vente;
      
    } catch (e) {
      // Handle offline creation
      final isConnected = await locator.apiService.checkConnectivity();
      if (!isConnected) {
        // Create offline vente
        final offlineVente = Vente(
          id: -DateTime.now().millisecondsSinceEpoch,
          idClient: -1, // Will be updated when synced
          idUtilisateur: int.tryParse(locator.authRepository.currentUser?.idUtilisateur ?? '1') ?? 1,
          dateCommande: DateTime.now(),
          statutCommande: 'En attente de synchronisation',
          montantTotal: _calculateTotalAmount(venteData['lignesCommandes']),
          reference: 'OFFLINE_${DateTime.now().millisecondsSinceEpoch}',
          typeTransaction: venteData['typeTransaction'] as int? ?? 0,
          lignesCommandes: [], // Simplified for now
        );
        
        // Save to local database
        final currentVentes = locator.databaseService.getVentes();
        currentVentes.add(offlineVente);
        await locator.databaseService.saveVentes(currentVentes);
        
        return offlineVente;
      }
      
      rethrow;
    }
  }

  double _calculateTotalAmount(List<dynamic> lignesCommandes) {
    return lignesCommandes.fold(0.0, (sum, ligne) {
      final quantite = ligne['quantite'] as int;
      final prixUnitaire = ligne['prixUnitaire'] as double;
      final tva = ligne['tva'] as double? ?? 0.0;
      final remise = ligne['remise'] as double? ?? 0.0;
      
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
        matches &= vente.reference.toLowerCase().contains(reference.toLowerCase());
      }
      
      if (dateFrom != null) {
        matches &= vente.dateCommande.isAfter(dateFrom);
      }
      
      if (dateTo != null) {
        matches &= vente.dateCommande.isBefore(dateTo);
      }
      
      if (statut != null) {
        matches &= vente.statutCommande.toLowerCase().contains(statut.toLowerCase());
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

  // Sync offline ventes when connection is restored
  Future<void> syncOfflineVentes() async {
    final isConnected = await locator.apiService.checkConnectivity();
    if (!isConnected) return;

    // TODO: Implement offline vente synchronization logic
    // This would involve sending queued offline ventes to the server
  }
}