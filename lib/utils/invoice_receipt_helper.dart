import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mombongo/services/cart_service.dart';
import 'package:mombongo/ui/widgets/service_description_dialog.dart';
import 'package:pdf/widgets.dart' as pdf_lib;

/// Demande une description facultative pour chaque service du panier.
Future<void> collectOptionalServiceDescriptions(
  BuildContext context,
  CartService cartService,
) async {
  for (final item in cartService.items) {
    if (!item.isService) {
      if (kDebugMode) {
        debugPrint(
          '[Receipt] Pas de dialogue pour "${item.article.libelle}" '
          '(withStock=${item.article.withStock})',
        );
      }
      continue;
    }

    final existing = item.description?.trim();
    if (existing != null && existing.isNotEmpty) continue;

    final description = await showServiceDescriptionDialog(
      context,
      articleName: item.article.libelle,
    );
    if (description != null && description.trim().isNotEmpty) {
      cartService.updateDescription(
        item.article.idArticle,
        description.trim(),
      );
      if (kDebugMode) {
        debugPrint(
          '[Receipt] Description enregistrée pour '
          '"${item.article.libelle}": ${description.trim()}',
        );
      }
    }
  }
}

/// Copie explicite des lignes panier pour le reçu (évite toute perte de description).
List<CartItem> snapshotCartItemsForReceipt(CartService cartService) {
  return cartService.items
      .map(
        (item) => CartItem(
          article: item.article,
          quantity: item.quantity,
          discountPercentage: item.discountPercentage,
          description: item.description,
        ),
      )
      .toList(growable: false);
}

String? receiptDescriptionForCartItem(CartItem item) {
  final description = item.description?.trim();
  if (description == null || description.isEmpty) return null;
  return description;
}

String receiptArticleNameFromLigne(Map<String, dynamic> ligne) {
  final stock = ligne['stock'] as Map<String, dynamic>?;
  final article = stock?['article'] as Map<String, dynamic>?;
  return article?['libelle']?.toString() ??
      ligne['libelle']?.toString() ??
      'Article';
}

String? receiptDescriptionFromLigne(Map<String, dynamic> ligne) {
  final description = ligne['description']?.toString().trim();
  if (description == null || description.isEmpty) return null;
  return description;
}

/// Nom d'article seul dans le tableau (sans description).
pdf_lib.Widget buildPdfReceiptArticleNameCell(String articleName) {
  return pdf_lib.Text(
    articleName,
    style: pdf_lib.TextStyle(fontSize: 8),
    textAlign: pdf_lib.TextAlign.left,
    maxLines: 3,
  );
}

List<Map<String, String>> collectServiceDescriptionsForReceipt(
  List<CartItem> items,
) {
  final entries = <Map<String, String>>[];
  for (final item in items) {
    final description = receiptDescriptionForCartItem(item);
    if (description == null) continue;
    entries.add({
      'name': item.article.libelle,
      'description': description,
    });
  }
  return entries;
}

List<Map<String, String>> collectServiceDescriptionsFromLignes(
  List<dynamic> lignes,
) {
  final entries = <Map<String, String>>[];
  for (final raw in lignes) {
    final ligne = raw as Map<String, dynamic>;
    final description = receiptDescriptionFromLigne(ligne);
    if (description == null) continue;
    entries.add({
      'name': receiptArticleNameFromLigne(ligne),
      'description': description,
    });
  }
  return entries;
}

/// Bloc descriptions services, affiché avant le message de remerciement.
pdf_lib.Widget buildPdfServiceDescriptionsBlock(
  List<Map<String, String>> entries,
) {
  if (entries.isEmpty) {
    return pdf_lib.SizedBox();
  }

  return pdf_lib.Column(
    crossAxisAlignment: pdf_lib.CrossAxisAlignment.stretch,
    children: [
      pdf_lib.SizedBox(height: 8),
      pdf_lib.Divider(),
      pdf_lib.SizedBox(height: 4),
      pdf_lib.Text(
        'DESCRIPTIONS SERVICES',
        style: pdf_lib.TextStyle(
          fontSize: 8,
          fontWeight: pdf_lib.FontWeight.bold,
        ),
        textAlign: pdf_lib.TextAlign.left,
      ),
      pdf_lib.SizedBox(height: 4),
      ...entries.expand((entry) {
        final name = entry['name'] ?? '';
        final description = entry['description'] ?? '';
        return [
          pdf_lib.Text(
            name,
            style: pdf_lib.TextStyle(
              fontSize: 7,
              fontWeight: pdf_lib.FontWeight.bold,
            ),
            textAlign: pdf_lib.TextAlign.left,
          ),
          pdf_lib.Text(
            description,
            style: const pdf_lib.TextStyle(fontSize: 7),
            textAlign: pdf_lib.TextAlign.left,
            maxLines: 6,
          ),
          pdf_lib.SizedBox(height: 4),
        ];
      }),
    ],
  );
}
