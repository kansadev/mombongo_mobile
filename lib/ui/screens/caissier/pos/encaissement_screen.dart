import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mombongo/models/client.dart';
import 'package:mombongo/services/cart_service.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/ui/screens/caissier/pos/vente_validee_screen.dart';
import 'package:mombongo/ui/theme/pos_colors.dart';
import 'package:mombongo/ui/widgets/pos/client_picker_sheet.dart';
import 'package:mombongo/ui/widgets/pos/pos_cart_actions.dart';
import 'package:mombongo/ui/widgets/pos/pos_qty_stepper.dart';
import 'package:mombongo/utils/api_error_message.dart';
import 'package:mombongo/utils/google_fonts_compat.dart';
import 'package:mombongo/utils/invoice_receipt_helper.dart';
import 'package:mombongo/utils/pos_money.dart';
import 'package:provider/provider.dart';

/// Encaissement en un seul écran : lignes du panier, client, mode de
/// paiement, montant reçu, monnaie à rendre ou acompte.
///
/// Retourne `true` (via la page « Vente validée ») quand une vente a été
/// enregistrée, pour que le catalogue recharge les stocks.
class EncaissementScreen extends StatefulWidget {
  const EncaissementScreen({super.key, this.onGoHome});

  /// Retour à l'onglet Accueil depuis l'écran « Vente validée ».
  final VoidCallback? onGoHome;

  @override
  State<EncaissementScreen> createState() => _EncaissementScreenState();
}

class _EncaissementScreenState extends State<EncaissementScreen> {
  /// Modes de paiement : valeurs envoyées à l'API (inchangées) + libellés.
  static const List<(String, String)> _paymentMethods = [
    ('Espèces', 'Espèces'),
    ('Mobile Money', 'Mobile'),
    ('Carte Bancaire', 'Carte'),
    ('Chèque', 'Chèque'),
  ];

  static const int _typeTransactionAcompte = 1;
  static const int _typeTransactionComplet = 3;

  final TextEditingController _receivedController = TextEditingController();
  late final String _invoiceNumber;

  Client? _client;
  String _method = 'Espèces';

  /// true tant que le montant reçu suit automatiquement le total.
  bool _exactAmount = true;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _invoiceNumber = _generateInvoiceNumber();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncExactAmount());
  }

  @override
  void dispose() {
    _receivedController.dispose();
    super.dispose();
  }

  String _generateInvoiceNumber() {
    final now = DateTime.now();
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final random = Random().nextInt(9000) + 1000;
    return 'FAC-$date-$random';
  }

  CartService get _cart => context.read<CartService>();

  double get _totalDisplay => PosMoney.toDisplay(_cart.total);

  double get _receivedDisplay =>
      PosMoney.parseDisplay(_receivedController.text) ?? 0;

  /// Recale le montant reçu sur le total (montant exact).
  void _syncExactAmount() {
    if (!mounted || !_exactAmount) return;
    final text = PosMoney.inputText(_totalDisplay);
    if (_receivedController.text != text) {
      _receivedController.text = text;
    }
    setState(() {});
  }

  void _setReceived(double display, {bool exact = false}) {
    setState(() {
      _exactAmount = exact;
      _receivedController.text = PosMoney.inputText(display);
    });
  }

  void _changeQuantity(CartItem item, int delta) {
    PosCartActions.change(context, _cart, item.article, delta);
    if (_cart.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }
    // Le montant exact suit le nouveau total après la mise à jour du panier.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncExactAmount());
  }

  Future<void> _pickClient() async {
    final pick = await showClientPickerSheet(context, current: _client);
    if (pick == null || !mounted) return;
    setState(() => _client = pick.client);
  }

  Future<void> _confirmClearCart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vider le panier ?'),
        content: const Text('Tous les articles seront retirés de la vente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: PosColors.terracotta),
            child: const Text('Vider'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      _cart.clear();
      Navigator.of(context).pop(false);
    }
  }

  Future<void> _showClientRequired() async {
    final choose = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Client requis'),
        content: const Text(
          'Un paiement partiel (acompte) est réservé aux clients inscrits. '
          'Choisissez un client ou encaissez la totalité.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Fermer'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: PosColors.ink,
              foregroundColor: Colors.white,
            ),
            child: const Text('Choisir un client'),
          ),
        ],
      ),
    );
    if (choose == true && mounted) await _pickClient();
  }

  Future<void> _validate() async {
    if (_processing) return;
    final cart = _cart;
    if (cart.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }

    final totalBase = cart.total;
    final totalDisplay = PosMoney.toDisplay(totalBase);
    final receivedDisplay = _receivedDisplay;
    final isPartial = receivedDisplay < totalDisplay;

    if (isPartial && _client == null) {
      await _showClientRequired();
      return;
    }

    // Descriptions facultatives des services (comme avant).
    await collectOptionalServiceDescriptions(context, cart);
    if (!mounted) return;

    // Montant réellement encaissé, en devise de base : le total si le client
    // paie tout (la monnaie rendue n'est pas encaissée), sinon l'acompte.
    final paidBase = isPartial ? PosMoney.toBase(receivedDisplay) : totalBase;
    final changeDisplay = isPartial ? 0.0 : receivedDisplay - totalDisplay;

    setState(() => _processing = true);
    try {
      final user = locator.authRepository.currentUser;
      final addressParts = user?.adresseSite.split(',') ?? [];
      String part(int i) =>
          addressParts.length > i ? addressParts[i].trim() : 'Inconnue';
      final client = _client;

      final saleData = <String, dynamic>{
        'nom': client?.nom ?? 'Client',
        'prenom': client?.prenom ?? 'Anonyme',
        'genre': client?.genre ?? 'M',
        'email': client?.email ?? '',
        'telephone': client?.telephone ?? '',
        'dateNaissance':
            client?.dateNaissance?.toIso8601String() ??
            DateTime.now()
                .subtract(const Duration(days: 365 * 25))
                .toIso8601String(),
        'idSite': int.tryParse(user?.idSite ?? '1') ?? 1,
        'pieceIdentite': client?.pieceIdentite ?? '',
        'province': part(0),
        'ville': part(1),
        'commune': part(2),
        'quartier': '',
        'avenue': '',
        'numero': '',
        'idUtilisateur': int.tryParse(user?.idUtilisateur ?? '1') ?? 1,
        'dateCommande': DateTime.now().toIso8601String(),
        'statutCommande': isPartial ? 'EN ATTENTE' : 'VALIDEE',
        'datePaiement': DateTime.now().toIso8601String(),
        'modePaiement': _method,
        'montant': paidBase,
        'referencePaiement': _invoiceNumber,
        'statutPaiement': isPartial ? 'PARTIEL' : 'COMPLETED',
        'libellePaiement': isPartial
            ? 'Acompte pour la facture $_invoiceNumber'
            : 'Paiement pour la facture $_invoiceNumber',
        'typeTransaction': isPartial
            ? _typeTransactionAcompte
            : _typeTransactionComplet,
        'catalogueId': 0,
        'lignesCommandes': cart.items
            .map(
              (item) => {
                'idStock': item.article.idStock,
                'quantite': item.quantity,
                'prixUnitaire': item.unitPrice,
                'tva': item.article.tva,
                'remise': item.discountPercentage,
              },
            )
            .toList(),
      };

      if (kDebugMode) {
        debugPrint('Encaissement : ${jsonEncode(saleData['lignesCommandes'])}');
      }

      final result = await locator.venteRepository.enregistrerVente(saleData);
      locator.syncService.refreshPending();

      // Copie des lignes pour le reçu, puis panier vidé.
      final items = snapshotCartItemsForReceipt(cart);
      cart.clearAfterPayment();
      if (!mounted) return;

      HapticFeedback.mediumImpact();
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => VenteValideeScreen(
            items: items,
            client: client,
            saleResponse: result.response,
            reference: result.reference.isNotEmpty
                ? result.reference
                : _invoiceNumber,
            isOffline: result.isOffline,
            paymentMethod: _method,
            totalBase: totalBase,
            paidBase: paidBase,
            receivedDisplay: receivedDisplay,
            changeDisplay: changeDisplay,
            isPartial: isPartial,
            onGoHome: widget.onGoHome,
          ),
        ),
        result: true,
      );
    } catch (e) {
      debugPrint('Encaissement : échec de la vente ($e)');
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(apiErrorUserMessage(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final totalDisplay = PosMoney.toDisplay(cart.total);
    final received = _receivedDisplay;
    final isPartial = received < totalDisplay;
    final change = received - totalDisplay;

    return PopScope(
      canPop: !_processing,
      child: Scaffold(
        backgroundColor: PosColors.background,
        appBar: AppBar(
          backgroundColor: PosColors.surface,
          foregroundColor: PosColors.ink,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 0,
          title: Text(
            'Encaissement',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: PosColors.ink,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Vider le panier',
              onPressed: _processing ? null : _confirmClearCart,
              icon: const Icon(Icons.delete_outline),
            ),
            const SizedBox(width: 4),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: PosColors.line),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            _ClientTile(
              client: _client,
              onTap: _processing ? null : _pickClient,
            ),
            const SizedBox(height: 12),
            _buildLines(cart),
            const SizedBox(height: 14),
            _buildTotals(cart),
            const SizedBox(height: 16),
            _sectionTitle('Mode de paiement'),
            const SizedBox(height: 8),
            _buildMethods(),
            const SizedBox(height: 16),
            _buildReceived(totalDisplay, isPartial, change),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: PosColors.surface,
              border: Border(top: BorderSide(color: PosColors.line)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _processing || cart.isEmpty ? null : _validate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPartial
                      ? PosColors.terracotta
                      : PosColors.green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: PosColors.line,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _processing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isPartial
                            ? 'Valider l\'acompte · ${PosMoney.formatDisplay(received)}'
                            : 'Valider la vente · ${PosMoney.format(cart.total)}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
    text,
    style: GoogleFonts.poppins(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: PosColors.ink,
    ),
  );

  Widget _buildLines(CartService cart) {
    final items = cart.items;
    return Container(
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PosColors.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: i == items.length - 1
                    ? null
                    : const Border(
                        bottom: BorderSide(color: PosColors.lineSoft),
                      ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[i].article.libelle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: PosColors.ink,
                          ),
                        ),
                        Text(
                          items[i].isService
                              ? '${PosMoney.format(items[i].unitPrice)} · service'
                              : '${PosMoney.format(items[i].unitPrice)} / unité',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: PosColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  PosQtyStepper(
                    quantity: items[i].quantity,
                    onMinus: _processing
                        ? null
                        : () => _changeQuantity(items[i], -1),
                    onPlus: _processing
                        ? null
                        : () => _changeQuantity(items[i], 1),
                  ),
                  SizedBox(
                    width: 84,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          PosMoney.format(items[i].totalPrice),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: PosColors.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTotals(CartService cart) {
    final muted = GoogleFonts.poppins(fontSize: 13, color: PosColors.muted);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${cart.totalQuantity} ${cart.totalQuantity > 1 ? 'articles' : 'article'}',
                style: muted,
              ),
              Text(
                '${cart.itemCount} ${cart.itemCount > 1 ? 'lignes' : 'ligne'}',
                style: muted,
              ),
            ],
          ),
          if (cart.totalDiscount > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sous-total', style: muted),
                Text(PosMoney.format(cart.subtotal), style: muted),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Remise', style: muted),
                Text('-${PosMoney.format(cart.totalDiscount)}', style: muted),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Total à payer',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: PosColors.ink,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      PosMoney.format(cart.total),
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: PosColors.ink,
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

  Widget _buildMethods() {
    return Row(
      children: [
        for (var i = 0; i < _paymentMethods.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _ChoiceButton(
              label: _paymentMethods[i].$2,
              selected: _method == _paymentMethods[i].$1,
              onTap: _processing
                  ? null
                  : () => setState(() => _method = _paymentMethods[i].$1),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReceived(double totalDisplay, bool isPartial, double change) {
    final quick = PosMoney.quickAmounts(totalDisplay);
    final reste = totalDisplay - _receivedDisplay;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PosColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('Montant reçu'),
          const SizedBox(height: 6),
          TextField(
            controller: _receivedController,
            enabled: !_processing,
            keyboardType: TextInputType.numberWithOptions(
              decimal: PosMoney.decimals > 0,
            ),
            onChanged: (_) => setState(() => _exactAmount = false),
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: PosColors.ink,
            ),
            decoration: InputDecoration(
              suffixText: PosMoney.isUsd ? '\$' : 'fc',
              filled: true,
              fillColor: PosColors.background,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
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
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickChip(
                label: 'Montant exact',
                selected: _exactAmount,
                onTap: _processing
                    ? null
                    : () => _setReceived(totalDisplay, exact: true),
              ),
              for (final amount in quick)
                _QuickChip(
                  label: PosMoney.formatDisplay(amount),
                  selected: !_exactAmount && _receivedDisplay == amount,
                  onTap: _processing ? null : () => _setReceived(amount),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (isPartial)
            _InfoBand(
              background: PosColors.terracottaSoft,
              foreground: PosColors.terracotta,
              label: _client == null
                  ? 'Acompte · client requis'
                  : 'Acompte · reste dû',
              value: PosMoney.formatDisplay(reste),
            )
          else
            _InfoBand(
              background: PosColors.greenSoft,
              foreground: PosColors.green,
              label: 'Monnaie à rendre',
              value: PosMoney.formatDisplay(change),
            ),
        ],
      ),
    );
  }
}

class _ClientTile extends StatelessWidget {
  const _ClientTile({required this.client, required this.onTap});

  final Client? client;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final name = client == null
        ? 'Client comptoir'
        : '${client!.prenom} ${client!.nom}'.trim();
    final phone = client?.telephone ?? '';

    return Material(
      color: PosColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PosColors.line),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: client == null
                    ? PosColors.background
                    : PosColors.greenSoft,
                foregroundColor: client == null
                    ? PosColors.muted
                    : PosColors.green,
                child: Icon(
                  client == null
                      ? Icons.storefront_outlined
                      : Icons.person_outline,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: PosColors.ink,
                      ),
                    ),
                    if (phone.isNotEmpty)
                      Text(
                        phone,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: PosColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                client == null ? 'Choisir' : 'Changer',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: PosColors.green,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? PosColors.greenSoft : PosColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? PosColors.green : PosColors.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? PosColors.green : PosColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? PosColors.ink : PosColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? PosColors.ink : PosColors.line),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: selected ? Colors.white : PosColors.ink,
          ),
        ),
      ),
    );
  }
}

class _InfoBand extends StatelessWidget {
  const _InfoBand({
    required this.background,
    required this.foreground,
    required this.label,
    required this.value,
  });

  final Color background;
  final Color foreground;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: foreground,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
