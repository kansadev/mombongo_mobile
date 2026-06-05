import 'package:flutter/foundation.dart';
import 'package:mombongo/services/api_exception.dart';

/// Message affiché à l'utilisateur — jamais de détails techniques en production.
String apiErrorUserMessage(Object error) {
  final raw = _extractRawMessage(error);
  final normalized = raw.toLowerCase();

  if (_containsResteAPayerError(normalized)) {
    return 'Impossible de retirer tous les articles : un paiement est encore associé à cette commande.';
  }

  if (normalized.contains('ligne de commande introuvable')) {
    return 'Ligne de commande introuvable. Fermez et rouvrez le détail de la commande, puis réessayez.';
  }

  if (_isTransientInfrastructureError(normalized)) {
    return 'Le serveur est temporairement occupé. Veuillez réessayer dans quelques instants.';
  }

  if (error is ApiException) {
    if (error.statusCode == 401) {
      return 'Session expirée. Veuillez vous reconnecter.';
    }
    if (error.statusCode == 404) {
      return 'Ressource introuvable.';
    }
    if (error.statusCode == 429) {
      return 'Trop de requêtes. Patientez quelques secondes avant de réessayer.';
    }
    if (error.statusCode >= 500) {
      return 'Le serveur a rencontré un problème. Veuillez réessayer.';
    }
  }

  if (normalized.contains('failed host lookup') ||
      normalized.contains('socketexception') ||
      normalized.contains('connection refused') ||
      normalized.contains('timeout')) {
    return 'Problème de connexion. Vérifiez votre réseau et réessayez.';
  }

  // En debug uniquement : message API brut pour faciliter le diagnostic.
  if (kDebugMode && raw.isNotEmpty) {
    return raw;
  }

  return 'Une erreur est survenue. Veuillez réessayer.';
}

bool isRetryableApiError(Object error) {
  final raw = _extractRawMessage(error).toLowerCase();

  if (_isTransientInfrastructureError(raw)) {
    return true;
  }

  if (error is ApiException) {
    if (error.statusCode >= 500 || error.statusCode == 429) {
      return true;
    }
  }

  return raw.contains('timeout') || raw.contains('temporarily unavailable');
}

String _extractRawMessage(Object error) {
  if (error is ApiException) {
    final buffer = StringBuffer(error.message);
    final details = error.details;
    if (details != null) {
      final errors = details['errors'];
      if (errors is List && errors.isNotEmpty) {
        buffer.write(' ');
        buffer.write(errors.map((e) => e.toString()).join(' '));
      }
    }
    return buffer.toString().trim();
  }
  return error.toString().replaceAll('ApiException:', '').trim();
}

bool _containsResteAPayerError(String normalized) {
  return normalized.contains('reste') &&
      (normalized.contains('payer') || normalized.contains('payé'));
}

bool _isTransientInfrastructureError(String normalized) {
  return normalized.contains('mysqlconnection') ||
      normalized.contains('mysql-conn-reuse') ||
      normalized.contains('already in use') ||
      normalized.contains('deadlock') ||
      normalized.contains('lock wait timeout');
}
