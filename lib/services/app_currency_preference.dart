import 'package:intl/intl.dart';

import 'database_service.dart';
import 'service_locator.dart';

class AppCurrencyPreference {
  static const String prefKey = 'pref_currency_code';

  static const String cdfCode = 'CDF';
  static const String usdCode = 'USD';

  static const String defaultCode = cdfCode;

  static String normalizeCode(String? value) {
    if (value == usdCode) return usdCode;
    return cdfCode;
  }

  static String readCode(DatabaseService databaseService) {
    final saved = databaseService.get<String>(prefKey);
    return normalizeCode(saved);
  }

  static Future<void> saveCode(DatabaseService databaseService, String code) {
    final normalized = normalizeCode(code);
    return databaseService.save<String>(prefKey, normalized);
  }

  static String symbolFor(String code) {
    final normalized = normalizeCode(code);
    if (normalized == usdCode) {
      return r'$';
    }
    // Pour le franc congolais, afficher "FC" en majuscule
    return 'FC';
  }

  static double getTauxActuel() {
    final taux = locator.tauxService.getTauxActuel();
    double value = double.tryParse(taux.tauxActuel) ?? 0.0;
    if (value <= 0) value = 1.0;
    return value;
  }

  static String displayNameFor(String code) {
    final taux = locator.tauxService.getTauxActuel();
    if (taux.nomDevise.isNotEmpty) {
      return '${taux.nomDevise} ($code)';
    }
    return normalizeCode(code) == usdCode
        ? 'Dollar américain (USD)'
        : 'Franc congolais (CDF)';
  }

  static String inputPrefixFor(String code) {
    final normalized = normalizeCode(code);
    if (normalized == usdCode) {
      return r'$ ';
    }
    return ''; // Pas de préfixe pour FC
  }

  /// Formatage global et réutilisable pour l'affichage des montants
  /// USD: $123456.00 (symbole avant, point, 2 décimales)
  /// CDF: 123456fc (pas de décimales)
  static String formatCurrency(double amount, {String? code}) {
    final currencyCode = code ?? readCode(locator.databaseService);
    final normalized = normalizeCode(currencyCode);
    
    if (normalized == usdCode) {
      // Format dollar: $123 456.00 (espace comme séparateur de milliers)
      final formatterUsd = NumberFormat('#,##0.00', 'en_US');
      final formatted = formatterUsd.format(amount).replaceAll(',', ' ');
      return '\$$formatted';
    } else {
      // Format franc congolais: 123 456fc (espace comme séparateur de milliers)
      final amountEnFranc = amount * getTauxActuel();
      final formatterFc = NumberFormat('###0', 'fr_CD');
      final formatted = formatterFc.format(amountEnFranc).replaceAll(',', ' ');
      return '${formatted} FC';
    }
  }

  static String formatPrice(double amount, {String? code}) {
    final currencyCode = code ?? readCode(locator.databaseService);
    final normalized = normalizeCode(currencyCode);
    
    if (normalized == usdCode) {
      // Format dollar : $5.00
      return r'$' + amount.toStringAsFixed(2);
    } else {
      // Format franc : 5000fc (sans décimales)
      // Pour convertir en franc : montant en dollar * taux
      final amountEnFranc = amount * getTauxActuel();
      return '${amountEnFranc.toStringAsFixed(0)} FC';
    }
  }

  static NumberFormat formatterFor(String code, {int decimalDigits = 0}) {
    final normalized = normalizeCode(code);
    return NumberFormat.currency(
      locale: normalized == usdCode ? 'en_US' : 'fr_CD',
      symbol: '',
      decimalDigits: decimalDigits,
    );
  }
}
