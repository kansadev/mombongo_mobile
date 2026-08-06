import 'package:flutter/foundation.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final Map<String, dynamic>? details;

  ApiException(this.message, this.statusCode, {this.details});

  /// Message destiné à l'UI (sans préfixe technique).
  @override
  String toString() => message;

  /// Détail technique réservé aux logs / debug.
  String toDebugString() =>
      'ApiException: $message (Status: $statusCode)';

  void logIfDebug() {
    if (kDebugMode) {
      debugPrint(toDebugString());
    }
  }
}
