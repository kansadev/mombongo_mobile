import 'package:flutter/foundation.dart';
import 'package:mombongo/services/app_currency_preference.dart';
import '../models/taux.dart';
import 'database_service.dart';

/// Service pour gérer le taux de change et la devise
class TauxService {
  static const String _tauxBoxKey = 'current_taux';
  static const String _devisePrefKey = 'pref_devise_code';

  final DatabaseService _databaseService;

  TauxService(this._databaseService);

  /// Obtient le taux actuellement actif.
  ///
  /// Le taux est stocké en cache local via [sauvegarderTaux]. Si rien n'a
  /// encore été enregistré, renvoie [Taux.defaultTaux()].
  Taux getTauxActuel() {
    final savedTaux = _databaseService.get<Taux>(_tauxBoxKey);
    return savedTaux ?? Taux.defaultTaux();
  }

  /// Sauvegarde le taux dans le cache local
  Future<void> sauvegarderTaux(Taux taux) async {
    await _databaseService.save<Taux>(_tauxBoxKey, taux);
    
    if (kDebugMode) {
      print('Taux sauvegardé: ${taux.codeDevise} - ${taux.tauxActuel}');
    }
  }

  /// Met à jour le taux en mémoire/caché sans se baser sur l'utilisateur.
  ///
  /// Cette méthode reste pour compatibilité mais n'est plus utilisée.
  Future<void> synchroniserAvecUtilisateur() async {
    // noop; currency data is no longer stored on the user object.
  }

  /// Obtient la devise préférée de l'utilisateur (locale)
  String getDevisePreferee() {
    final saved = _databaseService.get<String>(_devisePrefKey);
    return saved ?? 'USD';
  }

  /// Sauvegarde la devise préférée
  Future<void> sauvegarderDevisePreferee(String codeDevise) async {
    await _databaseService.save<String>(_devisePrefKey, codeDevise);
  }

  /// Convertit un montant d'une devise à une autre
  /// Si deviseSource == USD et cible == CDF, on multiplie par le taux
  double convertir(double montant, String deviseSource, String deviseCible, double taux) {
    if (deviseSource == deviseCible) {
      return montant;
    }

    if (deviseSource == 'USD' && deviseCible == 'CDF') {
      return montant * taux;
    } else if (deviseSource == 'CDF' && deviseCible == 'USD') {
      return montant / taux;
    }

    return montant;
  }

  /// Formate un montant avec la devise
  String formaterMontant(double montant, String codeDevise) {
    return AppCurrencyPreference.formatCurrency(montant, code: codeDevise);
  }

  /// Formate un montant avec le taux de change
  String formaterMontantAvecTaux(double montant, String codeDevise) {
    final taux = getTauxActuel();
    final tauxValeur = double.tryParse(taux.tauxActuel) ?? 1.0;
    
    if (codeDevise == 'USD') {
      // Afficher en USD
      return AppCurrencyPreference.formatCurrency(montant, code: 'USD');
    } else {
      // Afficher en CDF avec taux
      final montantCDF = montant * tauxValeur;
      final formattedCdf = AppCurrencyPreference.formatCurrency(montantCDF, code: 'CDF');
      return '$formattedCdf (${AppCurrencyPreference.formatCurrency(montant, code: 'USD')} x ${taux.tauxActuel})';
    }
  }

  /// Convertit et formate un montant en fonction de la devise préférée
  /// de l'utilisateur (prise dans les préférences).
  ///
  /// Le montant passé est supposé être en USD. Si la devise sélectionnée
  /// est la même, on affiche simplement le montant. Sinon on multiplie par
  /// le taux et on applique le format/ symbole adéquat.
  String formatPrice(double montant) {
    return AppCurrencyPreference.formatCurrency(montant);
  }
}
