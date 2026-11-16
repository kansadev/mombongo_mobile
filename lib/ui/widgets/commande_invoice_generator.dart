import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/utils/invoice_receipt_helper.dart';
import 'package:mombongo/utils/parse_utils.dart';
import 'package:mombongo/utils/receipt/receipt_paper.dart';
import 'package:mombongo/utils/receipt/receipt_pdf_builder.dart';
import 'package:mombongo/utils/receipt/receipt_print_dialog.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pdf_lib;

enum CommandeInvoiceType { vente, retrait }

/// Facture d'une commande existante (réimpression, retrait d'article).
class CommandeInvoiceGenerator {
  CommandeInvoiceGenerator({
    required this.context,
    required this.commandeDetail,
    this.type = CommandeInvoiceType.vente,
    this.withdrawnArticleName,
    this.withdrawnQuantity,
    this.withdrawnAmount,
  });

  final BuildContext context;
  final Map<String, dynamic> commandeDetail;
  final CommandeInvoiceType type;
  final String? withdrawnArticleName;
  final int? withdrawnQuantity;
  final double? withdrawnAmount;

  /// Hauteur historique de la page des factures (mm).
  static const double _pageHeightMm = 350;

  /// Affiche le choix 58/80 mm puis imprime ou partage la facture.
  Future<ReceiptOutcome> generateAndShow() {
    return ReceiptPrintFlow.show(
      context: context,
      title: 'Facture générée',
      fileName: 'facture_commande.pdf',
      buildPdf: _buildPdf,
    );
  }

  double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  int _parseInt(dynamic value) => parseAsInt(value);

  Future<Uint8List> _buildPdf(ReceiptPaperSize paper) {
    final user = locator.authRepository.currentUser;
    final tauxService = locator.tauxService;
    final branding = ReceiptBranding.load();
    final rawArticles = commandeDetail['articles'] as List<dynamic>? ?? [];
    final articles = normalizeCommandeArticles(rawArticles);
    final client = commandeDetail['client'] as Map<String, dynamic>?;
    final paiements = commandeDetail['paiements'] as List<dynamic>? ?? [];
    final idCommande = commandeDetail['idCommande']?.toString() ?? '-';
    final montantTotal = _parseDouble(commandeDetail['montantTotal']);
    final montantPaye = _parseDouble(commandeDetail['montantPaye']);
    final reste = _parseDouble(commandeDetail['resteAPayer']);
    final statut = commandeDetail['statut']?.toString() ?? '';

    final title = type == CommandeInvoiceType.retrait
        ? 'FACTURE DE RETRAIT'
        : 'FACTURE';

    final firstPayment = paiements.isNotEmpty
        ? paiements.first as Map<String, dynamic>
        : null;
    final reference =
        firstPayment?['referencePaiement']?.toString() ??
        firstPayment?['referencePaiemenet']?.toString() ??
        'CMD-$idCommande';

    final itemRows = articles.map((ligne) {
      return ReceiptItemRow(
        name: receiptArticleNameFromLigne(ligne),
        quantity: '${_parseInt(ligne['quantite'])}',
        amount: tauxService.formatPrice(_parseDouble(ligne['totalLigne'])),
      );
    }).toList();

    return buildReceiptPdf(
      paper: paper,
      pageHeightMm: _pageHeightMm,
      content: (spec) => [
        receiptLogo(branding, spec, bottomSpacing: 0),
        receiptCentered(user?.nomSociete ?? 'MONBONGO', size: 10, bold: true),
        receiptCentered(user?.nomSite ?? ''),
        pdf_lib.SizedBox(height: 6),
        pdf_lib.Divider(),
        pdf_lib.SizedBox(height: 4),
        receiptCentered(title, size: 9, bold: true),
        pdf_lib.SizedBox(height: 4),
        receiptCentered('Commande #$idCommande'),
        receiptCentered('Ref: $reference'),
        if (statut.isNotEmpty) receiptCentered('Statut: $statut'),
        if (type == CommandeInvoiceType.retrait &&
            withdrawnArticleName != null) ...[
          pdf_lib.SizedBox(height: 6),
          pdf_lib.Container(
            padding: const pdf_lib.EdgeInsets.all(6),
            decoration: pdf_lib.BoxDecoration(
              border: pdf_lib.Border.all(color: PdfColors.grey400),
            ),
            child: pdf_lib.Column(
              crossAxisAlignment: pdf_lib.CrossAxisAlignment.start,
              children: [
                receiptText('Article retiré', bold: true),
                receiptText(withdrawnArticleName!),
                if (withdrawnQuantity != null)
                  receiptText('Quantité: $withdrawnQuantity'),
                if (withdrawnAmount != null)
                  receiptText(
                    'Montant: ${tauxService.formatPrice(withdrawnAmount!)}',
                  ),
              ],
            ),
          ),
        ],
        if (client != null) ...[
          pdf_lib.SizedBox(height: 6),
          receiptText('CLIENT', bold: true),
          receiptText(
            '${client['nom'] ?? ''} ${client['prenom'] ?? ''}'.trim(),
          ),
          if ((client['telephone']?.toString() ?? '').isNotEmpty)
            receiptText(client['telephone'].toString()),
        ],
        pdf_lib.SizedBox(height: 6),
        receiptText('DETAIL DES ARTICLES', bold: true),
        pdf_lib.SizedBox(height: 4),
        receiptItemsTable(
          spec: spec,
          rows: itemRows,
          qtyHeader: 'Qté',
          amountHeader: 'Total',
          nameMaxLines: 3,
          valueMaxLines: 3,
        ),
        pdf_lib.SizedBox(height: 8),
        _amountRow('Total', tauxService.formatPrice(montantTotal), bold: true),
        _amountRow('Payé', tauxService.formatPrice(montantPaye)),
        _amountRow('Reste', tauxService.formatPrice(reste), bold: true),
        buildPdfServiceDescriptionsBlock(
          collectServiceDescriptionsFromLignes(articles),
        ),
        pdf_lib.SizedBox(height: 6),
        ...receiptThanksFooter(
          branding,
          messageSpacing: 10,
          messageSize: 7,
          messageItalic: false,
        ),
      ],
    );
  }

  pdf_lib.Widget _amountRow(String label, String value, {bool bold = false}) {
    return pdf_lib.Padding(
      padding: const pdf_lib.EdgeInsets.symmetric(vertical: 2),
      child: receiptRow(
        '$label:',
        value,
        size: 8,
        boldLabel: bold,
        boldValue: bold,
      ),
    );
  }
}
