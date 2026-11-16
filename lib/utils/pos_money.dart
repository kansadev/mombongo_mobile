import 'package:mombongo/services/app_currency_preference.dart';
import 'package:mombongo/services/service_locator.dart';

/// Conversion entre la devise de base des prix (celle de l'API) et la devise
/// affichée au caissier (préférence CDF / USD).
///
/// Les montants du panier et ceux envoyés à l'API sont en devise de base.
/// [AppCurrencyPreference.formatCurrency] les convertit en FC (× taux) pour
/// l'affichage : la saisie du caissier suit la même règle en sens inverse,
/// pour qu'il tape exactement ce qu'il voit à l'écran.
class PosMoney {
  PosMoney._();

  static bool get isUsd =>
      AppCurrencyPreference.readCode(locator.databaseService) ==
      AppCurrencyPreference.usdCode;

  /// Taux appliqué à l'affichage (1 en USD).
  static double get rate => isUsd ? 1.0 : AppCurrencyPreference.getTauxActuel();

  /// Décimales significatives dans la devise affichée.
  static int get decimals => isUsd ? 2 : 0;

  /// Montant de base → montant affiché (arrondi comme à l'écran).
  static double toDisplay(double base) => _round(base * rate);

  /// Montant saisi (devise affichée) → montant de base.
  static double toBase(double display) => display / rate;

  /// Formatage standard d'un montant de base (ex. « 44 800fc »).
  static String format(double base) =>
      AppCurrencyPreference.formatCurrency(base);

  /// Formatage d'un montant déjà exprimé dans la devise affichée.
  static String formatDisplay(double display) => format(toBase(display));

  /// Lit un montant tapé par le caissier (« 50 000 », « 12,50 »…).
  static double? parseDisplay(String text) {
    final cleaned = text
        .replaceAll(RegExp(r'[\s  ]'), '')
        .replaceAll(',', '.')
        .replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  /// Texte à placer dans le champ de saisie pour un montant affiché.
  static String inputText(double display) => display.toStringAsFixed(decimals);

  /// Montants ronds proposés en raccourci, supérieurs au total affiché.
  static List<double> quickAmounts(double totalDisplay, {int count = 2}) {
    final steps = isUsd
        ? const [1.0, 5.0, 10.0, 20.0, 50.0, 100.0]
        : const [1000.0, 5000.0, 10000.0, 20000.0, 50000.0, 100000.0];
    final result = <double>[];
    for (final step in steps) {
      final rounded = (totalDisplay / step).ceil() * step;
      if (rounded > totalDisplay && !result.contains(rounded)) {
        result.add(rounded);
      }
      if (result.length == count) break;
    }
    return result;
  }

  static double _round(double value) {
    final factor = decimals == 2 ? 100 : 1;
    return (value * factor).roundToDouble() / factor;
  }
}
