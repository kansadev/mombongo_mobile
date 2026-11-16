import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mombongo/services/app_currency_preference.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/utils/receipt/receipt_paper.dart';
import 'package:mombongo/utils/receipt/receipt_pdf_builder.dart';
import 'package:mombongo/utils/receipt/receipt_print_dialog.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pdf_lib;

/// Reçu de paiement d'une dette (acompte / solde).
class DetteReceiptGenerator {
  DetteReceiptGenerator({
    required this.context,
    required this.dette,
    required this.commande,
    required this.client,
    required this.dateLabel,
    this.montantPaye,
  });

  final BuildContext context;
  final Map<String, dynamic> dette;
  final Map<String, dynamic>? commande;
  final Map<String, dynamic>? client;

  /// Date du paiement déjà formatée par l'écran.
  final String dateLabel;

  /// Montant du paiement qui vient d'être saisi (null en réimpression).
  final double? montantPaye;

  /// Hauteur historique de la page des reçus de dette (mm).
  static const double _pageHeightMm = 200;

  /// Affiche le choix 58/80 mm puis imprime ou partage le reçu.
  Future<ReceiptOutcome> generateAndShow() {
    return ReceiptPrintFlow.show(
      context: context,
      title: 'Reçu généré',
      fileName: 'recupaiement.pdf',
      buildPdf: _buildPdf,
    );
  }

  double _parse(dynamic value) =>
      double.tryParse(value?.toString() ?? '0') ?? 0;

  /// Format des montants identique à l'ancien reçu de dette.
  String _amount(double value) {
    final code = AppCurrencyPreference.readCode(locator.databaseService);
    return '${AppCurrencyPreference.symbolFor(code)}'
        '${AppCurrencyPreference.formatterFor(code).format(value)}';
  }

  Future<Uint8List> _buildPdf(ReceiptPaperSize paper) {
    final currentUser = locator.authRepository.currentUser;
    final branding = ReceiptBranding.load();

    final reference =
        dette['referencePaiemenet']?.toString() ??
        dette['referencePaiement']?.toString() ??
        '-';
    final montant = _parse(dette['montant']);
    final mode = dette['modePaiement']?.toString() ?? 'Espèces';
    final typeTransaction = dette['typeTransaction']?.toString() ?? '0';
    final typeLabel = typeTransaction == '1'
        ? 'Acompte'
        : (typeTransaction == '2' ? 'Solde' : 'Paiement');

    final montantTotal = _parse(commande?['montantTotal']);
    final montantPayeTotal = _parse(commande?['montantPaye']);
    final resteAPayer = _parse(commande?['resteAPayer']);
    final reste = resteAPayer - (montantPaye ?? 0);

    final clientNomComplet =
        '${client?['nom']?.toString() ?? ''} ${client?['prenom']?.toString() ?? ''}'
            .trim();

    return buildReceiptPdf(
      paper: paper,
      pageHeightMm: _pageHeightMm,
      crossAxisAlignment: pdf_lib.CrossAxisAlignment.center,
      content: (spec) => [
        receiptLogo(branding, spec, baseHeight: 30),
        receiptText(
          currentUser?.nomSociete ?? 'MONBONGO',
          size: 10,
          bold: true,
          align: pdf_lib.TextAlign.center,
        ),
        pdf_lib.SizedBox(height: 2),
        receiptText(
          currentUser?.nomSite ?? 'Siège',
          align: pdf_lib.TextAlign.center,
        ),
        pdf_lib.SizedBox(height: 5),
        pdf_lib.Divider(thickness: 0.5),
        pdf_lib.SizedBox(height: 5),
        receiptText('REÇU DE PAIEMENT', size: 9, bold: true),
        pdf_lib.SizedBox(height: 8),
        receiptRow('Ref:', reference, boldValue: true),
        pdf_lib.SizedBox(height: 2),
        receiptRow('Date:', dateLabel),
        pdf_lib.SizedBox(height: 2),
        receiptRow('Type:', typeLabel, boldValue: true),
        pdf_lib.SizedBox(height: 8),
        pdf_lib.Divider(thickness: 0.5),
        pdf_lib.SizedBox(height: 8),
        if (clientNomComplet.isNotEmpty) ...[
          receiptRow('Client:', clientNomComplet, boldValue: true),
          pdf_lib.SizedBox(height: 4),
        ],
        receiptRow('Mode:', mode),
        pdf_lib.SizedBox(height: 4),
        receiptRow(
          'Montant:',
          _amount(montantPaye ?? montant),
          size: 8,
          valueSize: 10,
          boldValue: true,
        ),
        ..._buildArticlesSection(),
        if (montantTotal > 0) ...[
          pdf_lib.SizedBox(height: 8),
          pdf_lib.Divider(thickness: 0.5),
          pdf_lib.SizedBox(height: 5),
          receiptRow('Total:', _amount(montantTotal)),
          pdf_lib.SizedBox(height: 2),
          receiptRow(
            'Payé:',
            _amount(montantPayeTotal + (montantPaye ?? 0)),
            valueColor: PdfColors.green,
          ),
          pdf_lib.SizedBox(height: 2),
          receiptRow(
            'Reste:',
            _amount(reste),
            boldValue: true,
            valueColor: reste > 0 ? PdfColors.red : PdfColors.green,
          ),
        ],
        pdf_lib.SizedBox(height: 15),
        ...receiptThanksFooter(branding),
      ],
    );
  }

  List<pdf_lib.Widget> _buildArticlesSection() {
    final articles = commande?['articles'] as List<dynamic>? ?? [];
    if (articles.isEmpty) return [];

    return [
      pdf_lib.SizedBox(height: 8),
      pdf_lib.Divider(thickness: 0.5),
      pdf_lib.SizedBox(height: 5),
      receiptText('ARTICLES', bold: true),
      pdf_lib.SizedBox(height: 4),
      ...articles.map((raw) {
        final ligne = raw as Map<String, dynamic>;
        final stock = ligne['stock'] as Map<String, dynamic>?;
        final article = stock?['article'] as Map<String, dynamic>?;
        final libelle = article?['libelle']?.toString() ?? 'Article';
        final description = ligne['description']?.toString().trim();
        final label = description != null && description.isNotEmpty
            ? '$libelle ($description)'
            : libelle;
        final qte = ligne['quantite']?.toString() ?? '0';
        final total = locator.tauxService.formatPrice(
          _parse(ligne['totalLigne']),
        );

        return pdf_lib.Padding(
          padding: const pdf_lib.EdgeInsets.only(bottom: 3),
          child: pdf_lib.Row(
            mainAxisAlignment: pdf_lib.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pdf_lib.CrossAxisAlignment.start,
            children: [
              pdf_lib.Expanded(child: receiptText('$label x$qte', size: 7)),
              receiptText(total, size: 7),
            ],
          ),
        );
      }),
    ];
  }
}
