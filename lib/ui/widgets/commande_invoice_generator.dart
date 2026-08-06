import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/utils/google_fonts_compat.dart';
import 'package:mombongo/utils/invoice_receipt_helper.dart';
import 'package:mombongo/utils/parse_utils.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pdf_lib;
import 'package:printing/printing.dart';
import 'package:mombongo/utils/api_error_message.dart';

enum CommandeInvoiceType { vente, retrait }

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

  Future<void> generateAndShow() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Génération de la facture...'),
          ],
        ),
      ),
    );

    try {
      final pdf = await _createPDF();
      if (!context.mounted) return;
      Navigator.of(context).pop();
      await _showPrintOptionsDialog(pdf);
    } catch (e) {
      if (!context.mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(apiErrorUserMessage(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  int _parseInt(dynamic value) => parseAsInt(value);

  Future<pdf_lib.Document> _createPDF() async {
    final pdf = pdf_lib.Document();
    final user = locator.authRepository.currentUser;
    final tauxService = locator.tauxService;
    final rawArticles = commandeDetail['articles'] as List<dynamic>? ?? [];
    final articles = normalizeCommandeArticles(rawArticles);
    final client = commandeDetail['client'] as Map<String, dynamic>?;
    final paiements = commandeDetail['paiements'] as List<dynamic>? ?? [];
    final idCommande = commandeDetail['idCommande']?.toString() ?? '-';
    final montantTotal = _parseDouble(commandeDetail['montantTotal']);
    final montantPaye = _parseDouble(commandeDetail['montantPaye']);
    final reste = _parseDouble(commandeDetail['resteAPayer']);
    final statut = commandeDetail['statut']?.toString() ?? '';

    String receiptLogoPath = '';
    try {
      receiptLogoPath =
          locator.databaseService.get<String>('pref_receipt_logo_path') ?? '';
    } catch (_) {}

    String footerMessage = '';
    try {
      footerMessage =
          locator.databaseService.get<String>('pref_receipt_footer_message') ??
          '';
    } catch (_) {}

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

    pdf.addPage(
      pdf_lib.MultiPage(
        pageFormat: PdfPageFormat(
          70 * PdfPageFormat.mm,
          350 * PdfPageFormat.mm,
          marginLeft: 8 * PdfPageFormat.mm,
          marginRight: 8 * PdfPageFormat.mm,
          marginTop: 8 * PdfPageFormat.mm,
          marginBottom: 8 * PdfPageFormat.mm,
        ),
        build: (ctx) => [
          pdf_lib.Column(
            crossAxisAlignment: pdf_lib.CrossAxisAlignment.stretch,
            children: [
              if (receiptLogoPath.isNotEmpty &&
                  io.File(receiptLogoPath).existsSync())
                pdf_lib.Center(
                  child: pdf_lib.Image(
                    pdf_lib.MemoryImage(
                      io.File(receiptLogoPath).readAsBytesSync(),
                    ),
                    height: 40,
                    fit: pdf_lib.BoxFit.contain,
                  ),
                ),
              pdf_lib.Center(
                child: pdf_lib.Text(
                  user?.nomSociete ?? 'MONBONGO',
                  style: pdf_lib.TextStyle(
                    fontSize: 10,
                    fontWeight: pdf_lib.FontWeight.bold,
                  ),
                ),
              ),
              pdf_lib.Center(
                child: pdf_lib.Text(
                  user?.nomSite ?? '',
                  style: const pdf_lib.TextStyle(fontSize: 8),
                ),
              ),
              pdf_lib.SizedBox(height: 6),
              pdf_lib.Divider(),
              pdf_lib.SizedBox(height: 4),
              pdf_lib.Center(
                child: pdf_lib.Text(
                  title,
                  style: pdf_lib.TextStyle(
                    fontSize: 9,
                    fontWeight: pdf_lib.FontWeight.bold,
                  ),
                ),
              ),
              pdf_lib.SizedBox(height: 4),
              pdf_lib.Center(
                child: pdf_lib.Text(
                  'Commande #$idCommande',
                  style: const pdf_lib.TextStyle(fontSize: 8),
                ),
              ),
              pdf_lib.Center(
                child: pdf_lib.Text(
                  'Ref: $reference',
                  style: const pdf_lib.TextStyle(fontSize: 8),
                ),
              ),
              if (statut.isNotEmpty)
                pdf_lib.Center(
                  child: pdf_lib.Text(
                    'Statut: $statut',
                    style: const pdf_lib.TextStyle(fontSize: 8),
                  ),
                ),
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
                      pdf_lib.Text(
                        'Article retiré',
                        style: pdf_lib.TextStyle(
                          fontSize: 8,
                          fontWeight: pdf_lib.FontWeight.bold,
                        ),
                      ),
                      pdf_lib.Text(
                        withdrawnArticleName!,
                        style: const pdf_lib.TextStyle(fontSize: 8),
                      ),
                      if (withdrawnQuantity != null)
                        pdf_lib.Text(
                          'Quantité: $withdrawnQuantity',
                          style: const pdf_lib.TextStyle(fontSize: 8),
                        ),
                      if (withdrawnAmount != null)
                        pdf_lib.Text(
                          'Montant: ${tauxService.formatPrice(withdrawnAmount!)}',
                          style: const pdf_lib.TextStyle(fontSize: 8),
                        ),
                    ],
                  ),
                ),
              ],
              if (client != null) ...[
                pdf_lib.SizedBox(height: 6),
                pdf_lib.Text(
                  'CLIENT',
                  style: pdf_lib.TextStyle(
                    fontSize: 8,
                    fontWeight: pdf_lib.FontWeight.bold,
                  ),
                ),
                pdf_lib.Text(
                  '${client['nom'] ?? ''} ${client['prenom'] ?? ''}'.trim(),
                  style: const pdf_lib.TextStyle(fontSize: 8),
                ),
                if ((client['telephone']?.toString() ?? '').isNotEmpty)
                  pdf_lib.Text(
                    client['telephone'].toString(),
                    style: const pdf_lib.TextStyle(fontSize: 8),
                  ),
              ],
              pdf_lib.SizedBox(height: 6),
              pdf_lib.Text(
                'DETAIL DES ARTICLES',
                style: pdf_lib.TextStyle(
                  fontSize: 8,
                  fontWeight: pdf_lib.FontWeight.bold,
                ),
              ),
              pdf_lib.SizedBox(height: 4),
              pdf_lib.Table(
                border: pdf_lib.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pdf_lib.FlexColumnWidth(3),
                  1: const pdf_lib.FixedColumnWidth(20),
                  2: const pdf_lib.FixedColumnWidth(35),
                },
                children: [
                  pdf_lib.TableRow(
                    decoration: const pdf_lib.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      _cell('Article', bold: true),
                      _cell('Qté', bold: true, align: pdf_lib.TextAlign.center),
                      _cell('Total', bold: true, align: pdf_lib.TextAlign.right),
                    ],
                  ),
                  ...articles.map((raw) {
                    final ligne = raw as Map<String, dynamic>;
                    final articleName = receiptArticleNameFromLigne(ligne);
                    return pdf_lib.TableRow(
                      children: [
                        pdf_lib.Padding(
                          padding: const pdf_lib.EdgeInsets.all(2),
                          child: buildPdfReceiptArticleNameCell(articleName),
                        ),
                        _cell(
                          '${_parseInt(ligne['quantite'])}',
                          align: pdf_lib.TextAlign.center,
                        ),
                        _cell(
                          tauxService.formatPrice(
                            _parseDouble(ligne['totalLigne']),
                          ),
                          align: pdf_lib.TextAlign.right,
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pdf_lib.SizedBox(height: 8),
              _amountRow('Total', tauxService.formatPrice(montantTotal), bold: true),
              _amountRow('Payé', tauxService.formatPrice(montantPaye)),
              _amountRow('Reste', tauxService.formatPrice(reste), bold: true),
              buildPdfServiceDescriptionsBlock(
                collectServiceDescriptionsFromLignes(articles),
              ),
              pdf_lib.SizedBox(height: 6),
              pdf_lib.Center(
                child: pdf_lib.Text(
                  'MERCI DE VOTRE CONFIANCE !',
                  style: pdf_lib.TextStyle(
                    fontSize: 8,
                    fontWeight: pdf_lib.FontWeight.bold,
                  ),
                  textAlign: pdf_lib.TextAlign.center,
                ),
              ),
              if (footerMessage.isNotEmpty) ...[
                pdf_lib.SizedBox(height: 10),
                pdf_lib.Center(
                  child: pdf_lib.Text(
                    footerMessage,
                    style: const pdf_lib.TextStyle(fontSize: 7),
                    textAlign: pdf_lib.TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    return pdf;
  }

  pdf_lib.Widget _cell(
    String text, {
    bool bold = false,
    pdf_lib.TextAlign align = pdf_lib.TextAlign.left,
  }) {
    return pdf_lib.Padding(
      padding: const pdf_lib.EdgeInsets.all(2),
      child: pdf_lib.Text(
        text,
        style: pdf_lib.TextStyle(
          fontSize: 8,
          fontWeight: bold ? pdf_lib.FontWeight.bold : pdf_lib.FontWeight.normal,
        ),
        textAlign: align,
        maxLines: 3,
      ),
    );
  }

  pdf_lib.Widget _amountRow(String label, String value, {bool bold = false}) {
    return pdf_lib.Padding(
      padding: const pdf_lib.EdgeInsets.symmetric(vertical: 2),
      child: pdf_lib.Row(
        mainAxisAlignment: pdf_lib.MainAxisAlignment.spaceBetween,
        children: [
          pdf_lib.Text(
            '$label:',
            style: pdf_lib.TextStyle(
              fontSize: 8,
              fontWeight: bold ? pdf_lib.FontWeight.bold : null,
            ),
          ),
          pdf_lib.Text(
            value,
            style: pdf_lib.TextStyle(
              fontSize: 8,
              fontWeight: bold ? pdf_lib.FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPrintOptionsDialog(pdf_lib.Document pdf) async {
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.receipt_long,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Facture générée',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    await Printing.layoutPdf(
                      onLayout: (format) async => pdf.save(),
                    );
                  },
                  icon: const Icon(Icons.print),
                  label: const Text('Imprimer'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    await Printing.sharePdf(
                      bytes: await pdf.save(),
                      filename: 'facture_commande.pdf',
                    );
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('Partager'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
