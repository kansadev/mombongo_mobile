import 'package:flutter/material.dart';

/// Palette de l'interface caissier (écrans de vente).
///
/// Reprend les couleurs de marque définies dans `main.dart`
/// (violet foncé, vert, terre cuite) et ajoute les neutres de l'interface.
class PosColors {
  PosColors._();

  /// Texte principal, en-têtes sombres, boutons secondaires pleins.
  static const Color ink = Color(0xFF1E0F1C);

  /// Action principale (Nouvelle vente, Encaisser, Valider).
  static const Color green = Color(0xFF18534F);
  static const Color greenSoft = Color(0xFFE3EFEE);

  /// Crédit, reste dû, alertes.
  static const Color terracotta = Color(0xFF955149);
  static const Color terracottaSoft = Color(0xFFF4E1DE);

  /// Stock faible.
  static const Color amber = Color(0xFF7A4A1E);
  static const Color amberSoft = Color(0xFFF6E7D8);

  /// Services.
  static const Color plum = Color(0xFF4A3346);
  static const Color plumSoft = Color(0xFFECE6EB);

  /// Neutres.
  static const Color background = Color(0xFFF5F3F4);
  static const Color surface = Colors.white;
  static const Color line = Color(0xFFE7E2E5);
  static const Color lineSoft = Color(0xFFF0ECEE);
  static const Color muted = Color(0xFF6B5F68);
  static const Color onInkMuted = Color(0xFFD9CFD6);
}
