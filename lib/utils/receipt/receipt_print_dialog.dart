import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/utils/api_error_message.dart';
import 'package:mombongo/utils/google_fonts_compat.dart';
import 'package:printing/printing.dart';

import 'receipt_paper.dart';

/// Résultat de la boîte d'impression d'un reçu.
enum ReceiptOutcome { printed, shared, cancelled, failed }

/// Génère les octets PDF du reçu pour un format de papier.
typedef ReceiptPdfFactory = Future<Uint8List> Function(ReceiptPaperSize paper);

/// Point d'entrée unique pour imprimer / partager un reçu dans toute l'app.
///
/// Affiche une boîte permettant de choisir la largeur de papier (58/80 mm),
/// le nombre de copies, puis imprime ou partage. Le PDF est généré au moment
/// du clic, au format choisi. La fonction se termine une fois l'action
/// réalisée (ou annulée), ce qui permet à l'appelant de vider le panier
/// ensuite en toute sécurité.
class ReceiptPrintFlow {
  ReceiptPrintFlow._();

  static const String copiesPrefKey = 'pref_receipt_copies';
  static const int maxCopies = 9;

  static Future<ReceiptOutcome> show({
    required BuildContext context,
    required ReceiptPdfFactory buildPdf,
    String title = 'Facture générée',
    String fileName = 'recu.pdf',
  }) async {
    if (!context.mounted) return ReceiptOutcome.cancelled;
    final messenger = ScaffoldMessenger.maybeOf(context);

    final result = await showDialog<_ReceiptDialogResult>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _ReceiptPrintDialog(title: title, buildPdf: buildPdf),
    );

    if (result == null) return ReceiptOutcome.cancelled;

    if (result.error != null) {
      debugPrint('Reçu : erreur de génération ${result.error}');
      _snack(messenger, apiErrorUserMessage(result.error!), Colors.red);
      return ReceiptOutcome.failed;
    }

    return _deliver(
      messenger: messenger,
      bytes: result.bytes!,
      share: result.action == _ReceiptAction.share,
      copies: result.copies,
      fileName: fileName,
    );
  }

  /// Imprime (ou partage) directement, sans boîte de dialogue : utilisé par
  /// les écrans qui proposent déjà le choix 58/80 mm et les copies.
  static Future<ReceiptOutcome> printDirect({
    required BuildContext context,
    required ReceiptPdfFactory buildPdf,
    required ReceiptPaperSize paper,
    int copies = 1,
    bool share = false,
    String fileName = 'recu.pdf',
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final Uint8List bytes;
    try {
      bytes = await buildPdf(paper);
    } catch (e) {
      debugPrint('Reçu : erreur de génération $e');
      _snack(messenger, apiErrorUserMessage(e), Colors.red);
      return ReceiptOutcome.failed;
    }
    return _deliver(
      messenger: messenger,
      bytes: bytes,
      share: share,
      copies: copies.clamp(1, maxCopies),
      fileName: fileName,
    );
  }

  static Future<ReceiptOutcome> _deliver({
    required ScaffoldMessengerState? messenger,
    required Uint8List bytes,
    required bool share,
    required int copies,
    required String fileName,
  }) async {
    try {
      if (share) {
        await Printing.sharePdf(bytes: bytes, filename: fileName);
        return ReceiptOutcome.shared;
      }

      for (var i = 0; i < copies; i++) {
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name: fileName,
          dynamicLayout: false,
        );
      }
      _snack(messenger, 'Impression envoyée', Colors.green);
      return ReceiptOutcome.printed;
    } catch (e) {
      debugPrint('Reçu : erreur impression/partage $e');
      _snack(messenger, apiErrorUserMessage(e), Colors.red);
      return ReceiptOutcome.failed;
    }
  }

  static void _snack(
    ScaffoldMessengerState? messenger,
    String message,
    Color color,
  ) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Nombre de copies par défaut défini dans le profil (1 à 9).
  static int defaultCopies() {
    try {
      final saved = locator.databaseService.get<int>(copiesPrefKey) ?? 1;
      return saved.clamp(1, maxCopies);
    } catch (_) {
      return 1;
    }
  }
}

enum _ReceiptAction { print, share }

class _ReceiptDialogResult {
  const _ReceiptDialogResult({
    required this.action,
    this.bytes,
    this.copies = 1,
    this.error,
  });

  final _ReceiptAction action;
  final Uint8List? bytes;
  final int copies;
  final Object? error;
}

class _ReceiptPrintDialog extends StatefulWidget {
  const _ReceiptPrintDialog({required this.title, required this.buildPdf});

  final String title;
  final ReceiptPdfFactory buildPdf;

  @override
  State<_ReceiptPrintDialog> createState() => _ReceiptPrintDialogState();
}

class _ReceiptPrintDialogState extends State<_ReceiptPrintDialog> {
  late final ReceiptPaperSize _savedPaper;
  late ReceiptPaperSize _paper;
  late int _copies;
  bool _remember = false;
  _ReceiptAction? _busyAction;

  @override
  void initState() {
    super.initState();
    _savedPaper = ReceiptPaperPreference.read(locator.databaseService);
    _paper = _savedPaper;
    _copies = ReceiptPrintFlow.defaultCopies();
  }

  Future<void> _run(_ReceiptAction action) async {
    setState(() => _busyAction = action);
    try {
      final bytes = await widget.buildPdf(_paper);
      if (_remember && _paper != _savedPaper) {
        await ReceiptPaperPreference.save(locator.databaseService, _paper);
      }
      if (!mounted) return;
      Navigator.of(context).pop(
        _ReceiptDialogResult(action: action, bytes: bytes, copies: _copies),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(_ReceiptDialogResult(action: action, error: e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final busy = _busyAction != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.receipt_long, size: 32, color: primary),
            ),
            const SizedBox(height: 20),
            Text(
              widget.title,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Sur quelle imprimante voulez-vous imprimer ?',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Choix de la largeur du papier
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<ReceiptPaperSize>(
                segments: ReceiptPaperSize.values
                    .map(
                      (size) => ButtonSegment<ReceiptPaperSize>(
                        value: size,
                        label: Text(
                          size.label,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        icon: const Icon(Icons.print_outlined, size: 18),
                      ),
                    )
                    .toList(),
                selected: {_paper},
                showSelectedIcon: false,
                onSelectionChanged: busy
                    ? null
                    : (selection) => setState(() => _paper = selection.first),
              ),
            ),
            if (_paper != _savedPaper)
              CheckboxListTile(
                value: _remember,
                onChanged: busy
                    ? null
                    : (value) => setState(() => _remember = value ?? false),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  'Mémoriser ce choix',
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
              )
            else
              const SizedBox(height: 12),

            // Nombre de copies
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Copies :', style: GoogleFonts.poppins(fontSize: 14)),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: !busy && _copies > 1
                            ? () => setState(() => _copies--)
                            : null,
                      ),
                      SizedBox(
                        width: 36,
                        child: Center(
                          child: Text(
                            '$_copies',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: !busy && _copies < ReceiptPrintFlow.maxCopies
                            ? () => setState(() => _copies++)
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : () => _run(_ReceiptAction.share),
                    icon: _busyAction == _ReceiptAction.share
                        ? const _ButtonSpinner()
                        : const Icon(Icons.share_outlined),
                    label: Text(
                      'Partager',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: busy ? null : () => _run(_ReceiptAction.print),
                    icon: _busyAction == _ReceiptAction.print
                        ? const _ButtonSpinner(color: Colors.white)
                        : const Icon(Icons.print_outlined),
                    label: Text(
                      'Imprimer',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner({this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    );
  }
}
