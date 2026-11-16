import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'receipt_paper.dart';

/// Briques PDF communes à tous les reçus de Mombongo (vente, commande,
/// retrait, paiement de dette). Chaque reçu compose son contenu avec ces
/// briques ; la taille de page dépend uniquement du [ReceiptPaperSize].

/// Préférences visuelles du reçu (logo et message de pied), lues depuis Hive.
class ReceiptBranding {
  const ReceiptBranding({this.logoBytes, this.footerMessage = ''});

  static const String logoPrefKey = 'pref_receipt_logo_path';
  static const String footerPrefKey = 'pref_receipt_footer_message';

  /// Octets du logo, ou null si aucun logo / fichier introuvable.
  final Uint8List? logoBytes;

  /// Message personnalisé du pied de reçu (peut être vide).
  final String footerMessage;

  bool get hasLogo => logoBytes != null && logoBytes!.isNotEmpty;

  /// Charge le logo et le message. Ne lève jamais d'exception : si le fichier
  /// du logo a été supprimé, le reçu est simplement généré sans logo.
  static ReceiptBranding load() {
    Uint8List? logo;
    String footer = '';
    try {
      final path = locator.databaseService.get<String>(logoPrefKey) ?? '';
      if (path.isNotEmpty) {
        final file = io.File(path);
        if (file.existsSync()) {
          logo = file.readAsBytesSync();
        }
      }
    } catch (e) {
      debugPrint('Reçu : logo indisponible ($e)');
    }
    try {
      footer = locator.databaseService.get<String>(footerPrefKey) ?? '';
    } catch (e) {
      debugPrint('Reçu : message de pied indisponible ($e)');
    }
    return ReceiptBranding(logoBytes: logo, footerMessage: footer);
  }
}

/// Construit le contenu d'un reçu pour un format de papier donné.
typedef ReceiptContentBuilder = List<pw.Widget> Function(ReceiptPaperSpec spec);

/// Génère les octets PDF d'un reçu au format [paper].
///
/// [pageHeightMm] reprend la hauteur historique de chaque reçu
/// (350 mm pour les factures, 200 mm pour les reçus de dette).
Future<Uint8List> buildReceiptPdf({
  required ReceiptPaperSize paper,
  required double pageHeightMm,
  required ReceiptContentBuilder content,
  pw.CrossAxisAlignment crossAxisAlignment = pw.CrossAxisAlignment.stretch,
}) async {
  final spec = paper.spec;
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: spec.pageFormat(pageHeightMm),
      build: (_) => [
        pw.Column(
          crossAxisAlignment: crossAxisAlignment,
          children: content(spec),
        ),
      ],
    ),
  );
  return doc.save();
}

// ---------------------------------------------------------------------------
// Briques de mise en page
// ---------------------------------------------------------------------------

/// Texte standard du reçu.
pw.Widget receiptText(
  String text, {
  double size = 8,
  bool bold = false,
  bool italic = false,
  pw.TextAlign align = pw.TextAlign.left,
  int? maxLines,
  PdfColor? color,
}) {
  return pw.Text(
    text,
    style: pw.TextStyle(
      fontSize: size,
      fontWeight: bold ? pw.FontWeight.bold : null,
      fontStyle: italic ? pw.FontStyle.italic : null,
      color: color,
    ),
    textAlign: align,
    maxLines: maxLines,
  );
}

/// Texte centré (en-têtes, remerciements…).
pw.Widget receiptCentered(
  String text, {
  double size = 8,
  bool bold = false,
  bool italic = false,
}) {
  return pw.Center(
    child: receiptText(
      text,
      size: size,
      bold: bold,
      italic: italic,
      align: pw.TextAlign.center,
    ),
  );
}

/// Ligne « libellé ……… valeur ».
pw.Widget receiptRow(
  String label,
  String value, {
  double size = 7,
  double? valueSize,
  bool boldLabel = false,
  bool boldValue = false,
  PdfColor? valueColor,
}) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      receiptText(label, size: size, bold: boldLabel),
      receiptText(
        value,
        size: valueSize ?? size,
        bold: boldValue,
        color: valueColor,
      ),
    ],
  );
}

/// Logo du reçu ; [baseHeight] est la hauteur en 58 mm, agrandie en 80 mm.
pw.Widget receiptLogo(
  ReceiptBranding branding,
  ReceiptPaperSpec spec, {
  double baseHeight = 40,
  double bottomSpacing = 5,
}) {
  if (!branding.hasLogo) return pw.SizedBox();
  return pw.Container(
    height: baseHeight * spec.scale,
    margin: pw.EdgeInsets.only(bottom: bottomSpacing),
    alignment: pw.Alignment.center,
    child: pw.Image(
      pw.MemoryImage(branding.logoBytes!),
      fit: pw.BoxFit.contain,
    ),
  );
}

/// Ligne du tableau des articles.
class ReceiptItemRow {
  const ReceiptItemRow({
    required this.name,
    required this.quantity,
    required this.amount,
  });

  final String name;
  final String quantity;
  final String amount;
}

/// Tableau Article / Qté / Montant ; les largeurs de colonnes suivent le
/// format de papier.
pw.Widget receiptItemsTable({
  required ReceiptPaperSpec spec,
  required List<ReceiptItemRow> rows,
  String nameHeader = 'Article',
  String qtyHeader = 'Qte',
  String amountHeader = 'Prix',
  int nameMaxLines = 2,
  int? valueMaxLines,
}) {
  pw.Widget cell(
    String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
    int? maxLines,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(2),
      child: receiptText(text, bold: bold, align: align, maxLines: maxLines),
    );
  }

  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
    columnWidths: {
      0: const pw.FlexColumnWidth(3),
      1: pw.FixedColumnWidth(spec.qtyColumnWidth),
      2: pw.FixedColumnWidth(spec.amountColumnWidth),
    },
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          cell(nameHeader, bold: true, maxLines: valueMaxLines),
          cell(
            qtyHeader,
            bold: true,
            align: pw.TextAlign.center,
            maxLines: valueMaxLines,
          ),
          cell(
            amountHeader,
            bold: true,
            align: pw.TextAlign.right,
            maxLines: valueMaxLines,
          ),
        ],
      ),
      ...rows.map(
        (row) => pw.TableRow(
          children: [
            cell(row.name, maxLines: nameMaxLines),
            cell(
              row.quantity,
              align: pw.TextAlign.center,
              maxLines: valueMaxLines,
            ),
            cell(
              row.amount,
              align: pw.TextAlign.right,
              maxLines: valueMaxLines,
            ),
          ],
        ),
      ),
    ],
  );
}

/// « MERCI DE VOTRE CONFIANCE ! » suivi du message personnalisé éventuel.
List<pw.Widget> receiptThanksFooter(
  ReceiptBranding branding, {
  double messageSpacing = 6,
  double messageSize = 6,
  bool messageItalic = true,
}) {
  return [
    receiptCentered('MERCI DE VOTRE CONFIANCE !', bold: true),
    if (branding.footerMessage.isNotEmpty) ...[
      pw.SizedBox(height: messageSpacing),
      receiptCentered(
        branding.footerMessage,
        size: messageSize,
        italic: messageItalic,
      ),
    ],
  ];
}
