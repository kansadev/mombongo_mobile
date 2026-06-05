/// Parse une valeur numérique API (int, double ou "1.0") en entier.
int parseAsInt(dynamic value, {int defaultValue = 0}) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is double) return value.round();
  final asDouble = double.tryParse(value.toString());
  if (asDouble != null) return asDouble.round();
  return int.tryParse(value.toString()) ?? defaultValue;
}

/// Parse une valeur numérique API en double.
double parseAsDouble(dynamic value, {double defaultValue = 0}) {
  if (value == null) return defaultValue;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString()) ?? defaultValue;
}

/// Normalise les lignes commande : quantite en int (l'API renvoie souvent 1.0).
List<Map<String, dynamic>> normalizeCommandeArticles(List<dynamic> articles) {
  return articles.map((raw) {
    final ligne = Map<String, dynamic>.from(raw as Map);
    if (ligne.containsKey('quantite')) {
      ligne['quantite'] = parseAsInt(ligne['quantite']);
    }
    return ligne;
  }).toList();
}
