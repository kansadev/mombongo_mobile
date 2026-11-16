import 'package:flutter/material.dart';
import 'package:mombongo/models/client.dart';
import 'package:mombongo/services/cart_service.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/ui/theme/pos_colors.dart';
import 'package:mombongo/ui/widgets/invoice_generator.dart';
import 'package:mombongo/utils/google_fonts_compat.dart';
import 'package:mombongo/utils/pos_money.dart';
import 'package:mombongo/utils/receipt/receipt_paper.dart';
import 'package:mombongo/utils/receipt/receipt_print_dialog.dart';

/// Confirmation de vente : montant à rendre (ou reste dû) et impression du
/// reçu au format choisi (58 / 80 mm).
class VenteValideeScreen extends StatefulWidget {
  const VenteValideeScreen({
    super.key,
    required this.items,
    required this.client,
    required this.saleResponse,
    required this.reference,
    required this.isOffline,
    required this.paymentMethod,
    required this.totalBase,
    required this.paidBase,
    required this.receivedDisplay,
    required this.changeDisplay,
    required this.isPartial,
    this.onGoHome,
  });

  /// Copie des lignes vendues (le panier est déjà vidé).
  final List<CartItem> items;
  final Client? client;
  final dynamic saleResponse;
  final String reference;
  final bool isOffline;
  final String paymentMethod;
  final double totalBase;

  /// Montant encaissé, en devise de base (envoyé à l'API).
  final double paidBase;

  /// Montant remis par le client et monnaie rendue, en devise affichée.
  final double receivedDisplay;
  final double changeDisplay;
  final bool isPartial;
  final VoidCallback? onGoHome;

  @override
  State<VenteValideeScreen> createState() => _VenteValideeScreenState();
}

class _VenteValideeScreenState extends State<VenteValideeScreen> {
  late final ReceiptPaperSize _savedPaper;
  late ReceiptPaperSize _paper;
  late int _copies;
  bool _remember = false;
  bool _busy = false;
  bool _printed = false;

  late final InvoiceGenerator _invoice;

  @override
  void initState() {
    super.initState();
    _savedPaper = ReceiptPaperPreference.read(locator.databaseService);
    _paper = _savedPaper;
    _copies = ReceiptPrintFlow.defaultCopies();
    _invoice = InvoiceGenerator(
      context: context,
      items: widget.items,
      selectedClient: widget.client,
      saleResponse: widget.saleResponse,
      invoiceNumber: widget.reference,
      paidAmountOverride: widget.paidBase,
    );
  }

  Future<void> _print({required bool share}) async {
    setState(() => _busy = true);
    if (_remember && _paper != _savedPaper) {
      try {
        await ReceiptPaperPreference.save(locator.databaseService, _paper);
      } catch (_) {}
    }
    if (!mounted) return;
    final outcome = await ReceiptPrintFlow.printDirect(
      context: context,
      buildPdf: _invoice.buildPdf,
      paper: _paper,
      copies: _copies,
      share: share,
      fileName: _invoice.fileName,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (outcome == ReceiptOutcome.printed) _printed = true;
    });
  }

  void _newSale() => Navigator.of(context).pop();

  void _goHome() {
    widget.onGoHome?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final resteBase = widget.totalBase - widget.paidBase;

    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildSummary(resteBase),
            const SizedBox(height: 16),
            _buildPrintPanel(),
            const SizedBox(height: 24),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _busy ? null : _newSale,
                style: ElevatedButton.styleFrom(
                  backgroundColor: PosColors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Nouvelle vente',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (widget.onGoHome != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : _goHome,
                style: TextButton.styleFrom(foregroundColor: PosColors.green),
                child: Text(
                  'Retour à l\'accueil',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final now = TimeOfDay.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: widget.isPartial ? PosColors.terracotta : PosColors.green,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, size: 40, color: Colors.white),
        ),
        const SizedBox(height: 12),
        Text(
          widget.isPartial ? 'Acompte enregistré' : 'Vente enregistrée',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: PosColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${widget.reference} · $time',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 13, color: PosColors.muted),
        ),
        if (widget.isOffline) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: PosColors.amberSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Hors ligne · synchronisation en attente',
              style: GoogleFonts.poppins(fontSize: 12, color: PosColors.amber),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummary(double resteBase) {
    final muted = GoogleFonts.poppins(fontSize: 14, color: PosColors.muted);
    final value = GoogleFonts.poppins(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: PosColors.ink,
    );

    Widget line(String label, String amount) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              amount,
              style: value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    final highlightColor = widget.isPartial
        ? PosColors.terracotta
        : PosColors.green;
    final highlightLabel = widget.isPartial ? 'Reste dû' : 'Monnaie à rendre';
    final highlightValue = widget.isPartial
        ? PosMoney.format(resteBase)
        : PosMoney.formatDisplay(widget.changeDisplay);

    return _Card(
      child: Column(
        children: [
          line('Total', PosMoney.format(widget.totalBase)),
          line(
            'Reçu (${widget.paymentMethod.toLowerCase()})',
            PosMoney.formatDisplay(widget.receivedDisplay),
          ),
          if (widget.client != null)
            line(
              'Client',
              '${widget.client!.prenom} ${widget.client!.nom}'.trim(),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: PosColors.lineSoft),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                highlightLabel,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: highlightColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      highlightValue,
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: highlightColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrintPanel() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _printed ? 'Reçu imprimé' : 'Imprimer le reçu',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: PosColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<ReceiptPaperSize>(
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
            onSelectionChanged: _busy
                ? null
                : (selection) => setState(() => _paper = selection.first),
          ),
          if (_paper != _savedPaper)
            CheckboxListTile(
              value: _remember,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _remember = value ?? false),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Mémoriser ce choix'),
            )
          else
            const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Copies',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: PosColors.muted,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Moins de copies',
                onPressed: !_busy && _copies > 1
                    ? () => setState(() => _copies--)
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
                onPressed: !_busy && _copies < ReceiptPrintFlow.maxCopies
                    ? () => setState(() => _copies++)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _print(share: true),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Partager'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PosColors.ink,
                    minimumSize: const Size.fromHeight(50),
                    side: const BorderSide(color: PosColors.ink),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : () => _print(share: false),
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.print_outlined),
                  label: Text(_printed ? 'Réimprimer' : 'Imprimer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PosColors.ink,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PosColors.line),
      ),
      child: child,
    );
  }
}
