import 'dart:async';
import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mombongo/models/article_data.dart';
import 'package:mombongo/services/cart_service.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/ui/theme/pos_colors.dart';
import 'package:mombongo/ui/widgets/invoice_generator.dart';
import 'package:mombongo/utils/google_fonts_compat.dart';
import 'package:mombongo/utils/pos_money.dart';
import 'package:mombongo/utils/receipt/receipt_paper.dart';
import 'package:mombongo/utils/receipt/receipt_pdf_builder.dart';
import 'package:mombongo/utils/receipt/receipt_print_dialog.dart';

/// Réglages des reçus : largeur du papier, copies, logo, message, avec un
/// aperçu et l'impression d'un reçu de test.
///
/// Mêmes clés de stockage que l'ancien profil : `pref_receipt_logo_path`,
/// `pref_receipt_footer_message`, `pref_receipt_copies`,
/// `pref_receipt_paper_size`.
class RecusSettingsScreen extends StatefulWidget {
  const RecusSettingsScreen({super.key});

  @override
  State<RecusSettingsScreen> createState() => _RecusSettingsScreenState();
}

class _RecusSettingsScreenState extends State<RecusSettingsScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _footerController = TextEditingController();
  Timer? _footerDebounce;

  String _logoPath = '';
  int _copies = 1;
  ReceiptPaperSize _paper = ReceiptPaperPreference.defaultSize;
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    final db = locator.databaseService;
    try {
      _logoPath = db.get<String>(ReceiptBranding.logoPrefKey) ?? '';
      _footerController.text =
          db.get<String>(ReceiptBranding.footerPrefKey) ?? '';
    } catch (_) {}
    _copies = ReceiptPrintFlow.defaultCopies();
    _paper = ReceiptPaperPreference.read(db);
  }

  @override
  void dispose() {
    _footerDebounce?.cancel();
    _saveFooter(_footerController.text);
    _footerController.dispose();
    super.dispose();
  }

  bool get _hasLogo => _logoPath.isNotEmpty && io.File(_logoPath).existsSync();

  Future<void> _setPaper(ReceiptPaperSize value) async {
    setState(() => _paper = value);
    try {
      await ReceiptPaperPreference.save(locator.databaseService, value);
    } catch (_) {}
  }

  Future<void> _setCopies(int value) async {
    setState(() => _copies = value);
    try {
      await locator.databaseService.save<int>(
        ReceiptPrintFlow.copiesPrefKey,
        value,
      );
    } catch (_) {}
  }

  Future<void> _pickLogo() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 300,
        maxHeight: 150,
        imageQuality: 80,
      );
      if (image == null || !mounted) return;
      setState(() => _logoPath = image.path);
      await locator.databaseService.save<String>(
        ReceiptBranding.logoPrefKey,
        image.path,
      );
    } catch (e) {
      debugPrint('Reçus : sélection du logo impossible ($e)');
    }
  }

  Future<void> _removeLogo() async {
    setState(() => _logoPath = '');
    try {
      await locator.databaseService.save<String>(
        ReceiptBranding.logoPrefKey,
        '',
      );
    } catch (_) {}
  }

  void _onFooterChanged(String value) {
    setState(() {}); // aperçu
    _footerDebounce?.cancel();
    _footerDebounce = Timer(
      const Duration(milliseconds: 500),
      () => _saveFooter(value),
    );
  }

  void _saveFooter(String value) {
    try {
      locator.databaseService.save<String>(
        ReceiptBranding.footerPrefKey,
        value,
      );
    } catch (_) {}
  }

  /// Reçu fictif (2 articles, 1 service) pour vérifier l'imprimante.
  Future<void> _printTest() async {
    _footerDebounce?.cancel();
    _saveFooter(_footerController.text);
    setState(() => _printing = true);

    ArticleData sample(int id, String name, double displayPrice, bool stock) {
      final price = PosMoney.toBase(displayPrice);
      return ArticleData(
        idStock: id,
        idArticle: id,
        libelle: name,
        quantiteStock: 99,
        prixAchat: 0,
        prixVentHT: price,
        prixVentTTC: price,
        seuilAlerte: 0,
        tva: 0,
        codeBarreQR: '',
        remise: 0,
        idSite: 0,
        nomSite: '',
        idSociete: 0,
        withStock: stock,
      );
    }

    final usd = PosMoney.isUsd;
    final items = [
      CartItem(
        article: sample(-1, 'Article de test', usd ? 6.5 : 18500, true),
        quantity: 2,
      ),
      CartItem(article: sample(-2, 'Service de test', usd ? 1 : 2000, false)),
    ];
    final total = items.fold<double>(0, (sum, i) => sum + i.totalPrice);

    final invoice = InvoiceGenerator(
      context: context,
      items: items,
      selectedClient: null,
      saleResponse: {
        'referencePaiement': 'RECU-TEST',
        'modePaiement': 'Espèces',
        'typeTransaction': 'Test',
      },
      invoiceNumber: 'RECU-TEST',
      paidAmountOverride: total,
    );

    await ReceiptPrintFlow.printDirect(
      context: context,
      buildPdf: invoice.buildPdf,
      paper: _paper,
      copies: 1,
      fileName: 'recu_test.pdf',
    );
    if (mounted) setState(() => _printing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PosColors.background,
      appBar: AppBar(
        backgroundColor: PosColors.surface,
        foregroundColor: PosColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Text(
          'Reçus & impression',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: PosColors.ink,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: PosColors.line),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          _ReceiptPreview(
            paper: _paper,
            logoPath: _hasLogo ? _logoPath : null,
            footer: _footerController.text,
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: PosColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PosColors.line),
            ),
            child: Column(
              children: [
                _row(
                  title: 'Largeur du papier',
                  subtitle: 'Proposée par défaut à l\'impression',
                  trailing: SegmentedButton<ReceiptPaperSize>(
                    segments: ReceiptPaperSize.values
                        .map(
                          (size) => ButtonSegment<ReceiptPaperSize>(
                            value: size,
                            label: Text(size.label),
                          ),
                        )
                        .toList(),
                    selected: {_paper},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => _setPaper(s.first),
                  ),
                ),
                const Divider(height: 1, color: PosColors.lineSoft),
                _row(
                  title: 'Copies par défaut',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Moins de copies',
                        onPressed: _copies > 1
                            ? () => _setCopies(_copies - 1)
                            : null,
                        icon: const Icon(Icons.remove),
                      ),
                      Text(
                        '$_copies',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Plus de copies',
                        onPressed: _copies < ReceiptPrintFlow.maxCopies
                            ? () => _setCopies(_copies + 1)
                            : null,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: PosColors.lineSoft),
                _row(
                  leading: _LogoThumb(path: _hasLogo ? _logoPath : null),
                  title: 'Logo du reçu',
                  subtitle: 'Image noir et blanc conseillée',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: _pickLogo,
                        style: TextButton.styleFrom(
                          foregroundColor: PosColors.green,
                        ),
                        child: Text(_hasLogo ? 'Changer' : 'Ajouter'),
                      ),
                      if (_hasLogo)
                        IconButton(
                          tooltip: 'Supprimer le logo',
                          onPressed: _removeLogo,
                          icon: const Icon(
                            Icons.delete_outline,
                            color: PosColors.terracotta,
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: PosColors.lineSoft),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: TextField(
                    controller: _footerController,
                    onChanged: _onFooterChanged,
                    maxLines: 3,
                    minLines: 2,
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Message en bas du reçu',
                      hintText:
                          'Ex : Ce reçu fait office de preuve de paiement.',
                      filled: true,
                      fillColor: PosColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: PosColors.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: PosColors.line),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _printing ? null : _printTest,
              icon: _printing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.print_outlined),
              label: Text('Imprimer un reçu test (${_paper.label})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: PosColors.ink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row({
    Widget? leading,
    required String title,
    String? subtitle,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Row(
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: PosColors.ink,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: PosColors.muted,
                    ),
                  ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _LogoThumb extends StatelessWidget {
  const _LogoThumb({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: PosColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PosColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: path == null
          ? const Icon(Icons.image_outlined, color: PosColors.muted)
          : Image.file(
              io.File(path!),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.broken_image_outlined),
            ),
    );
  }
}

/// Aperçu simplifié du reçu (la largeur suit le format choisi).
class _ReceiptPreview extends StatelessWidget {
  const _ReceiptPreview({
    required this.paper,
    required this.logoPath,
    required this.footer,
  });

  final ReceiptPaperSize paper;
  final String? logoPath;
  final String footer;

  @override
  Widget build(BuildContext context) {
    final user = locator.authRepository.currentUser;
    final width = paper == ReceiptPaperSize.mm80 ? 240.0 : 176.0;
    final usd = PosMoney.isUsd;
    final line1 = PosMoney.formatDisplay(usd ? 13 : 37000);
    final line2 = PosMoney.formatDisplay(usd ? 1 : 2000);
    final total = PosMoney.formatDisplay(usd ? 14 : 39000);

    TextStyle s(double size, {bool bold = false, bool italic = false}) =>
        TextStyle(
          fontSize: size,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          color: Colors.black,
          height: 1.3,
        );

    Widget row(String a, String b, {bool bold = false}) => Row(
      children: [
        Expanded(
          child: Text(a, style: s(bold ? 10 : 9, bold: bold)),
        ),
        Text(b, style: s(bold ? 10 : 9, bold: bold)),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: PosColors.line,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: PosColors.ink.withValues(alpha: 0.12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (logoPath != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Image.file(
                    io.File(logoPath!),
                    height: 28,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              Text(
                user?.nomSociete ?? 'MOMBONGO',
                textAlign: TextAlign.center,
                style: s(10, bold: true),
              ),
              Text(
                user?.nomSite ?? '',
                textAlign: TextAlign.center,
                style: s(9),
              ),
              const Divider(color: Colors.black, height: 10),
              row('Article de test x2', line1),
              row('Service de test x1', line2),
              const SizedBox(height: 4),
              row('TOTAL', total, bold: true),
              const Divider(color: Colors.black, height: 10),
              Text('MERCI DE VOTRE CONFIANCE !', style: s(9, bold: true)),
              if (footer.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  footer.trim(),
                  textAlign: TextAlign.center,
                  style: s(8, italic: true),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
