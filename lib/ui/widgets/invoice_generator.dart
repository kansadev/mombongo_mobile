import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mombongo/models/client.dart';
import 'package:mombongo/models/utilisateur.dart';
import 'package:mombongo/services/app_currency_preference.dart';
import 'package:mombongo/services/cart_service.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/utils/receipt/receipt_paper.dart';
import 'package:mombongo/utils/receipt/receipt_pdf_builder.dart';
import 'package:mombongo/utils/receipt/receipt_print_dialog.dart';
import 'package:pdf/widgets.dart' as pdf_lib;

/// Reçu de vente (panier) : utilisé par la vente rapide et l'écran de paiement.
///
/// Travaille sur une copie des lignes du panier ([items]) : le panier peut
/// être vidé dès la vente enregistrée, le reçu reste imprimable ensuite.
class InvoiceGenerator {
  final BuildContext context;
  final List<CartItem> items;
  final Client? selectedClient;
  final dynamic saleResponse;
  final String invoiceNumber;
  final double? paidAmountOverride; // Optional override for paid amount

  InvoiceGenerator({
    required this.context,
    required this.items,
    required this.selectedClient,
    required this.saleResponse,
    required this.invoiceNumber,
    this.paidAmountOverride,
  });

  /// Hauteur historique de la page des factures (mm).
  static const double _pageHeightMm = 350;

  /// Affiche le choix 58/80 mm puis imprime ou partage la facture.
  Future<ReceiptOutcome> generateAndShow() {
    return ReceiptPrintFlow.show(
      context: context,
      title: 'Facture générée',
      fileName: fileName,
      buildPdf: _buildPdf,
    );
  }

  /// Nom du fichier PDF de la facture.
  String get fileName => 'facture_$invoiceNumber.pdf';

  /// Génère le PDF au format demandé (utilisé pour l'impression directe).
  Future<Uint8List> buildPdf(ReceiptPaperSize paper) => _buildPdf(paper);

  Future<Uint8List> _buildPdf(ReceiptPaperSize paper) {
    final currentUser = locator.authRepository.currentUser;
    final branding = ReceiptBranding.load();

    return buildReceiptPdf(
      paper: paper,
      pageHeightMm: _pageHeightMm,
      content: (spec) => [
        _buildInvoiceHeader(currentUser, branding, spec),
        _buildInvoiceInfo(currentUser),
        _buildItemsTable(spec),
        _buildInvoiceSummary(),
        _buildPaymentInfo(),
        _buildInvoiceFooter(branding),
      ],
    );
  }

  String get _reference => saleResponse is Map
      ? (saleResponse['referencePaiement'] ?? invoiceNumber).toString()
      : invoiceNumber;

  /// Montant réellement facturé (et envoyé à l'API).
  /// Aucune TVA n'est calculée côté application : l'app n'est pas homologuée
  /// DGI pour la facture normalisée, la TVA reste du ressort de l'API.
  double get _total => _subtotal - _discount;

  double get _subtotal =>
      items.fold(0.0, (sum, item) => sum + item.unitPrice * item.quantity);

  double get _discount =>
      items.fold(0.0, (sum, item) => sum + item.totalDiscount);

  pdf_lib.Widget _buildInvoiceHeader(
    Utilisateur? user,
    ReceiptBranding branding,
    ReceiptPaperSpec spec,
  ) {
    final companyName = user?.nomSociete ?? 'KANSA BUSINESS';
    final siteName = user?.nomSite ?? 'SIEGE PRINCIPAL';
    final address = user?.adresseSite ?? '';
    final phone = user?.contact ?? '';

    return pdf_lib.Column(
      crossAxisAlignment: pdf_lib.CrossAxisAlignment.center,
      children: [
        receiptLogo(branding, spec),
        receiptCentered(companyName, size: 10, bold: true),
        pdf_lib.SizedBox(height: 3),
        receiptCentered(siteName, size: 9, bold: true),
        if (address.isNotEmpty) ...[
          pdf_lib.SizedBox(height: 3),
          receiptCentered(address),
        ],
        if (phone.isNotEmpty) ...[
          pdf_lib.SizedBox(height: 3),
          receiptCentered(phone),
        ],
        pdf_lib.SizedBox(height: 5),
        pdf_lib.Center(child: pdf_lib.Divider()),
        pdf_lib.SizedBox(height: 4),
      ],
    );
  }

  pdf_lib.Widget _buildInvoiceInfo(Utilisateur? user) {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final agentName = user?.nomComplet ?? 'Agent';
    final isOffline = saleResponse is Map && saleResponse['offline'] == true;

    return pdf_lib.Column(
      crossAxisAlignment: pdf_lib.CrossAxisAlignment.center,
      children: [
        receiptCentered('Ref: $_reference', size: 9, bold: true),
        pdf_lib.SizedBox(height: 3),
        receiptCentered('Date: $dateStr $timeStr'),
        pdf_lib.SizedBox(height: 3),
        receiptCentered('Agent: $agentName'),
        if (isOffline) ...[
          pdf_lib.SizedBox(height: 4),
          receiptCentered('*** VENTE HORS LIGNE ***', bold: true),
          receiptCentered('Synchronisation en attente', size: 7),
        ],
        pdf_lib.SizedBox(height: 4),
        pdf_lib.Center(child: pdf_lib.Divider()),
        pdf_lib.SizedBox(height: 4),
      ],
    );
  }

  pdf_lib.Widget _buildItemsTable(ReceiptPaperSpec spec) {
    final tauxService = locator.tauxService;

    return pdf_lib.Column(
      crossAxisAlignment: pdf_lib.CrossAxisAlignment.start,
      children: [
        receiptText('DETAIL DES ARTICLES:', size: 9, bold: true),
        pdf_lib.SizedBox(height: 4),
        receiptItemsTable(
          spec: spec,
          rows: items
              .map(
                (item) => ReceiptItemRow(
                  name: item.article.libelle,
                  quantity: item.quantity.toString(),
                  amount: tauxService.formatPrice(item.totalPrice),
                ),
              )
              .toList(),
        ),
        pdf_lib.SizedBox(height: 5),
      ],
    );
  }

  pdf_lib.Widget _buildInvoiceSummary() {
    final discount = _discount;

    return pdf_lib.Column(
      crossAxisAlignment: pdf_lib.CrossAxisAlignment.start,
      children: [
        receiptText('TOTAUX:', size: 9, bold: true),
        pdf_lib.SizedBox(height: 4),
        // Remise affichée uniquement si une remise a été appliquée.
        if (discount > 0) ...[
          receiptRow(
            'Sous-total:',
            AppCurrencyPreference.formatCurrency(_subtotal),
            size: 8,
          ),
          pdf_lib.SizedBox(height: 3),
          receiptRow(
            'Remise:',
            '-${AppCurrencyPreference.formatCurrency(discount)}',
            size: 8,
          ),
          pdf_lib.SizedBox(height: 3),
        ],
        receiptRow(
          'TOTAL:',
          AppCurrencyPreference.formatCurrency(_total),
          size: 10,
          boldLabel: true,
          boldValue: true,
        ),
        pdf_lib.SizedBox(height: 5),
        pdf_lib.Divider(),
        pdf_lib.SizedBox(height: 4),
      ],
    );
  }

  pdf_lib.Widget _buildPaymentInfo() {
    final paymentMethod = saleResponse is Map
        ? (saleResponse['modePaiement'] ?? 'Espèces').toString()
        : 'Espèces';
    final double paidAmount;
    if (paidAmountOverride != null) {
      paidAmount = paidAmountOverride!;
    } else {
      paidAmount = saleResponse is Map
          ? (saleResponse['montant'] as num? ?? _total).toDouble()
          : _total;
    }

    final remaining = (_total - paidAmount).clamp(0.0, double.infinity);
    final typeTransaction = saleResponse is Map
        ? (saleResponse['typeTransaction'] ?? 'Complete').toString()
        : 'Complete';

    final client = selectedClient;
    final clientName = client != null
        ? '${client.prenom} ${client.nom}'.trim()
        : '';
    final clientPhone = client?.telephone ?? '';
    final clientEmail = client?.email ?? '';

    return pdf_lib.Column(
      crossAxisAlignment: pdf_lib.CrossAxisAlignment.start,
      children: [
        if (clientName.isNotEmpty) ...[
          receiptText('CLIENT:', bold: true),
          pdf_lib.SizedBox(height: 3),
          receiptRow('Nom:', clientName, boldValue: true),
          if (clientPhone.isNotEmpty) ...[
            pdf_lib.SizedBox(height: 2),
            receiptRow('Tel:', clientPhone),
          ],
          if (clientEmail.isNotEmpty) ...[
            pdf_lib.SizedBox(height: 2),
            receiptRow('Email:', clientEmail),
          ],
          pdf_lib.SizedBox(height: 4),
        ],
        receiptText('PAIEMENT:', bold: true),
        pdf_lib.SizedBox(height: 3),
        receiptRow('Mode:', paymentMethod, boldValue: true),
        pdf_lib.SizedBox(height: 2),
        receiptRow('Type de Transaction:', typeTransaction, boldValue: true),
        pdf_lib.SizedBox(height: 2),
        receiptRow(
          'Montant payé:',
          AppCurrencyPreference.formatCurrency(paidAmount),
          boldValue: true,
        ),
        if (remaining > 0) ...[
          pdf_lib.SizedBox(height: 2),
          // Même conversion de devise que les autres montants du reçu.
          receiptRow(
            'Reste dû:',
            AppCurrencyPreference.formatCurrency(remaining),
            boldValue: true,
          ),
        ],
        pdf_lib.SizedBox(height: 2),
        receiptRow('Ref:', _reference),
        pdf_lib.SizedBox(height: 4),
        pdf_lib.Divider(),
        pdf_lib.SizedBox(height: 3),
      ],
    );
  }

  pdf_lib.Widget _buildInvoiceFooter(ReceiptBranding branding) {
    return pdf_lib.Column(
      crossAxisAlignment: pdf_lib.CrossAxisAlignment.center,
      children: [
        pdf_lib.SizedBox(height: 3),
        ...receiptThanksFooter(branding),
        pdf_lib.SizedBox(height: 6),
      ],
    );
  }
}
