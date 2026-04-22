import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mombongo/models/client.dart';
import 'package:mombongo/services/cart_service.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/ui/screens/caissier/create_client_screen.dart';
import 'package:mombongo/models/article_data.dart';
import 'package:mombongo/ui/widgets/invoice_generator.dart';
import 'package:provider/provider.dart';

class FastSaleBottomSheet extends StatefulWidget {
  final NumberFormat currencyFormat;
  final String currencySymbol;
  final ArticleData? initialFocusedArticle;
  final VoidCallback onClose;
  final VoidCallback? onSaleCompleted;

  const FastSaleBottomSheet({
    super.key,
    required this.currencyFormat,
    required this.currencySymbol,
    required this.initialFocusedArticle,
    required this.onClose,
    this.onSaleCompleted,
  });

  @override
  State<FastSaleBottomSheet> createState() => FastSaleBottomSheetState();
}

class FastSaleBottomSheetState extends State<FastSaleBottomSheet> {
  String _selectedPaymentMethod = 'Espèces';
  Client? _selectedClient;
  bool _isProcessing = false;
  String _invoiceNumber = '';
  final TextEditingController _clientSearchController = TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();
  List<dynamic> _clientSearchResults = [];
  ArticleData? _focusedArticle;
  final DraggableScrollableController _dragController =
      DraggableScrollableController();
  bool _isExpanded = false;

  // transaction type state used inside bottom sheet (mirrors parent)
  int _typeTransaction = 3; // Default to 'Complet'
  static const int _typeTransactionAcompte = 1;
  static const int _typeTransactionComplet = 3;
  static const List<String> _transactionLabels = [
    '', // Index 0 (unused)
    'Avance/Acompte',
    'Solde',
    'Complet',
    'Versement',
  ];

  @override
  void initState() {
    super.initState();
    _focusedArticle = widget.initialFocusedArticle;
    _generateInvoiceNumber();
    _dragController.addListener(_onDragChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cartService = Provider.of<CartService>(context, listen: false);
      _paidAmountController.text = cartService.total.toStringAsFixed(0);
    });
  }

  @override
  void dispose() {
    _dragController.removeListener(_onDragChanged);
    _dragController.dispose();
    _clientSearchController.dispose();
    _paidAmountController.dispose();
    super.dispose();
  }

  void _onDragChanged() {
    final expanded = _dragController.size > 0.45;
    if (expanded != _isExpanded) {
      setState(() {
        _isExpanded = expanded;
      });
    }
  }

  void focusArticle(ArticleData article) {
    setState(() {
      _focusedArticle = article;
    });
  }

  void _generateInvoiceNumber() {
    final now = DateTime.now();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final randomNum = Random().nextInt(9000) + 1000;
    _invoiceNumber = 'FAC-$year$month$day-$randomNum';
  }

  Future<void> _searchClients(String query) async {
    if (query.length < 2) {
      setState(() {
        _clientSearchResults = [];
      });
      return;
    }

    try {
      final isEmail = query.contains('@');
      final isPhone = RegExp(r'^[0-9+\s-]+$').hasMatch(query);
      final results = await locator.apiService.searchClients(
        email: isEmail ? query : null,
        nom: (isEmail || isPhone) ? null : query,
        telephone: isPhone ? query : null,
        pageSize: 10,
      );

      if (!mounted) return;
      setState(() {
        _clientSearchResults = results;
      });
    } catch (_) {}
  }

  void _selectClientFromSearch(Map<String, dynamic> clientData) {
    try {
      final clientDataFixed = Map<String, dynamic>.from(clientData);

      if (clientDataFixed.containsKey('idClient') &&
          !clientDataFixed.containsKey('id')) {
        final idClientValue = clientDataFixed['idClient'];
        if (idClientValue is String) {
          final parsedId = int.tryParse(idClientValue);
          if (parsedId != null) {
            clientDataFixed['id'] = parsedId;
          } else {
            return;
          }
        } else if (idClientValue is num) {
          clientDataFixed['id'] = idClientValue.toInt();
        } else {
          return;
        }
      }

      if (!clientDataFixed.containsKey('dateCreation')) {
        clientDataFixed['dateCreation'] = DateTime.now().toIso8601String();
      } else if (clientDataFixed['dateCreation'] is! String) {
        clientDataFixed['dateCreation'] = clientDataFixed['dateCreation']
            .toString();
      }

      if (!clientDataFixed.containsKey('statut')) {
        clientDataFixed['statut'] = true;
      } else {
        final statutValue = clientDataFixed['statut'];
        if (statutValue is String) {
          clientDataFixed['statut'] =
              statutValue.toLowerCase() == 'true' || statutValue == '1';
        } else if (statutValue is int) {
          clientDataFixed['statut'] = statutValue == 1;
        } else if (statutValue is! bool) {
          clientDataFixed['statut'] = true;
        }
      }

      final client = Client.fromJson(clientDataFixed);
      setState(() {
        _selectedClient = client;
        _clientSearchResults = [];
        _clientSearchController.text = '';
      });
    } catch (_) {}
  }

  Future<void> _createClient() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateClientScreen()),
    );

    if (!mounted) return;
    if (result != null && result is Client) {
      setState(() {
        _selectedClient = result;
      });
    }
  }

  Future<void> _confirmSale() async {
    final cartService = Provider.of<CartService>(context, listen: false);
    final total = cartService.total;
    final paidAmount = double.tryParse(_paidAmountController.text) ?? 0.0;
    final saleInvoiceNumber = _invoiceNumber;
    final isPartialPayment = paidAmount < total;

    // Le paiement partiel n'est autorisé que pour les clients inscrits
    if (isPartialPayment && _selectedClient == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Paiement partiel non autorisé',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Le paiement partiel (avance/acompte) est réservé uniquement aux clients inscrits.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Veuillez sélectionner un client ou payer la somme totale.',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Compris',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
      return;
    }

    final resolvedTypeTransaction = isPartialPayment
        ? _typeTransactionAcompte
        : (_typeTransaction == _typeTransactionAcompte
              ? _typeTransactionComplet
              : _typeTransaction);

    if (cartService.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Panier vide'),
          content: const Text(
            'Le panier est vide. Ajoutez des articles avant de valider.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (isPartialPayment) {
      // allow a deposit; user will pay the remainder later
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Acompte de ${locator.tauxService.formatPrice(paidAmount)} enregistré '
            '(total ${locator.tauxService.formatPrice(total)})',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      // keep going – statut fields below will mark this sale as partial
    }

    // note: we no longer require equality between paidAmount and total
    // because partial payments are allowed

    setState(() {
      _isProcessing = true;
    });

    try {
      final currentUser = locator.authRepository.currentUser;
      final addressParts = currentUser?.adresseSite.split(',') ?? [];
      final province = addressParts.isNotEmpty
          ? addressParts[0].trim()
          : 'Inconnue';
      final ville = addressParts.length > 1
          ? addressParts[1].trim()
          : 'Inconnue';
      final commune = addressParts.length > 2
          ? addressParts[2].trim()
          : 'Inconnue';

      final saleData = {
        'nom': _selectedClient?.nom ?? 'Client',
        'prenom': _selectedClient?.prenom ?? 'Anonyme',
        'genre': _selectedClient?.genre ?? 'M',
        'email': _selectedClient?.email ?? '',
        'telephone': _selectedClient?.telephone ?? '',
        'dateNaissance':
            _selectedClient?.dateNaissance?.toIso8601String() ??
            DateTime.now()
                .subtract(const Duration(days: 365 * 25))
                .toIso8601String(),
        'idSite': int.tryParse(currentUser?.idSite ?? '1') ?? 1,
        'pieceIdentite': _selectedClient?.pieceIdentite ?? '',
        'province': province,
        'ville': ville,
        'commune': commune,
        'quartier': '',
        'avenue': '',
        'numero': '',
        'idUtilisateur': int.tryParse(currentUser?.idUtilisateur ?? '1') ?? 1,
        'dateCommande': DateTime.now().toIso8601String(),
        'statutCommande': isPartialPayment ? 'EN ATTENTE' : 'VALIDEE',
        'datePaiement': DateTime.now().toIso8601String(),
        'modePaiement': _selectedPaymentMethod,
        'montant': paidAmount, // actual money received (may be an acompte)
        'referencePaiement': saleInvoiceNumber,
        'statutPaiement': isPartialPayment ? 'PARTIEL' : 'COMPLETED',
        'libellePaiement': isPartialPayment
            ? 'Acompte pour la facture $saleInvoiceNumber'
            : 'Paiement pour la facture $saleInvoiceNumber',
        // API specification includes a typeTransaction integer field.
        // We default to 0 (e.g. vente normale). Adjust if needed in the future.
        // use same defaults as sample request
        'typeTransaction': resolvedTypeTransaction,
        'catalogueId': int.tryParse('0')?.toString(),
        'lignesCommandes': cartService.items
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

      print('Sale data prepared: ${saleData.keys}');
      print('saleData JSON: ${jsonEncode(saleData)}');
      final response = await locator.apiService.enregistrerVente(saleData);

      if (mounted && context.mounted) {
        final invoice = InvoiceGenerator(
          context: context,
          cartService: cartService,
          selectedClient: _selectedClient,
          saleResponse: response,
          invoiceNumber: saleInvoiceNumber,
          paidAmountOverride: paidAmount,
        );
        await invoice.generateAndShow();
      }

      cartService.clearAfterPayment();

      if (mounted) {
        widget.onSaleCompleted?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vente validée. Facture: $saleInvoiceNumber'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onClose();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du paiement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _dragController,
      initialChildSize: 0.92,
      minChildSize: 0.18,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const [0.18, 0.92],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Consumer<CartService>(
            builder: (context, cartService, child) {
              final total = cartService.total;
              final paidAmount =
                  double.tryParse(_paidAmountController.text) ?? 0.0;
              final change = paidAmount - total;
              final isPartialPayment = paidAmount < total;

              // Keep transaction type consistent if total changes while sheet is open
              // or if the paid amount is updated programmatically.
              if (isPartialPayment &&
                  _typeTransaction != _typeTransactionAcompte) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() => _typeTransaction = _typeTransactionAcompte);
                });
              } else if (!isPartialPayment &&
                  _typeTransaction == _typeTransactionAcompte) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() => _typeTransaction = _typeTransactionComplet);
                });
              }

              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 20,
                        color: Colors.grey[700],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${cartService.totalQuantity} article(s)',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        locator.tauxService.formatPrice(total),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          widget.onClose();
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.close, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),

                  /*                   if (!_isExpanded) ...[
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        'Glisser vers le haut pour payer',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ),
                  ], */
                  const SizedBox(height: 12),
                  if (_focusedArticle != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue[100]!),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_focusedArticle!.libelle} - ${locator.tauxService.formatPrice(_focusedArticle!.prixVentTTC)}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    'Panier',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (cartService.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Aucun article dans le panier',
                        style: GoogleFonts.poppins(color: Colors.grey[600]),
                      ),
                    )
                  else
                    ...cartService.items.map((item) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.article.libelle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    locator.tauxService.formatPrice(
                                      item.unitPrice,
                                    ),
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                // Confirmer avant de supprimer
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Supprimer l\'article'),
                                    content: Text(
                                      'Voulez-vous supprimer "${item.article.libelle}" du panier?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('ANNULER'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          cartService.removeItem(
                                            item.article.idArticle,
                                          );
                                          // Si le panier est vide, vider le champ montant payé
                                          if (cartService.isEmpty) {
                                            _paidAmountController.clear();
                                          }
                                          Navigator.pop(context);
                                        },
                                        child: const Text(
                                          'SUPPRIMER',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: Colors.red,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            IconButton(
                              onPressed: item.quantity > 1
                                  ? () {
                                      cartService.updateQuantity(
                                        item.article.idArticle,
                                        item.quantity - 1,
                                      );
                                      // Mettre à jour le montant payé avec le nouveau total
                                      _paidAmountController.text = cartService
                                          .total
                                          .toStringAsFixed(2);
                                    }
                                  : () => cartService.removeItem(
                                      item.article.idArticle,
                                    ),
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            SizedBox(
                              width: 28,
                              child: Center(
                                child: Text(
                                  item.quantity.toString(),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                cartService.updateQuantity(
                                  item.article.idArticle,
                                  item.quantity + 1,
                                );
                                // Mettre à jour le montant payé avec le nouveau total
                                _paidAmountController.text = cartService.total
                                    .toStringAsFixed(2);
                              },
                              icon: const Icon(
                                Icons.add_circle_outline,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 8),
                  // Bouton Tout vider
                  if (cartService.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Vider le panier'),
                            content: const Text(
                              'Voulez-vous vraiment supprimer tous les articles du panier?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('ANNULER'),
                              ),
                              TextButton(
                                onPressed: () {
                                  cartService.clear();
                                  _paidAmountController.clear();
                                  Navigator.pop(context);
                                  Navigator.pop(context);
                                },
                                child: const Text(
                                  'OUI, VIDER',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.delete_sweep,
                        color: Colors.red,
                        size: 18,
                      ),
                      label: const Text(
                        'Tout vider',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Client',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_selectedClient != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 20,
                            color: Colors.green[700],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_selectedClient!.nom} ${_selectedClient!.prenom}',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                setState(() => _selectedClient = null),
                            icon: const Icon(Icons.close, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: [
                        TextField(
                          controller: _clientSearchController,
                          onChanged: _searchClients,
                          decoration: InputDecoration(
                            hintText: 'Rechercher client...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _createClient,
                            icon: const Icon(Icons.person_add_alt_1, size: 18),
                            label: const Text('Nouveau client'),
                          ),
                        ),
                        if (_clientSearchResults.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          ...(_clientSearchResults
                              .whereType<Map<String, dynamic>>()
                              .map((item) {
                                final nom = item['nom']?.toString() ?? '';
                                final prenom = item['prenom']?.toString() ?? '';
                                final tel = item['telephone']?.toString() ?? '';
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('$nom $prenom'),
                                  subtitle: tel.isNotEmpty ? Text(tel) : null,
                                  onTap: () => _selectClientFromSearch(item),
                                );
                              })),
                        ],
                      ],
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Paiement',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPaymentMethod,
                    items: const [
                      DropdownMenuItem(
                        value: 'Espèces',
                        child: Text('Espèces'),
                      ),
                      DropdownMenuItem(
                        value: 'Mobile Money',
                        child: Text('Mobile Money'),
                      ),
                      DropdownMenuItem(value: 'Carte', child: Text('Carte')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedPaymentMethod = value);
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: _typeTransaction,
                    decoration: InputDecoration(
                      labelText: 'Type de transaction',
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: List.generate(_transactionLabels.length, (i) {
                      return DropdownMenuItem(
                        value: i,
                        child: Text(_transactionLabels[i]),
                      );
                    }),
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() => _typeTransaction = val);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _paidAmountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Montant payé',
                      prefixIcon: const Icon(Icons.payments_outlined),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) {
                      final cartService = Provider.of<CartService>(
                        context,
                        listen: false,
                      );
                      final total = cartService.total;
                      final paidAmount =
                          double.tryParse(_paidAmountController.text) ?? 0.0;
                      final isPartialPayment = paidAmount < total;

                      setState(() {
                        if (isPartialPayment) {
                          _typeTransaction = _typeTransactionAcompte;
                        } else if (_typeTransaction ==
                            _typeTransactionAcompte) {
                          _typeTransaction = _typeTransactionComplet;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total:',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        locator.tauxService.formatPrice(total),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Montant payé:',
                        style: GoogleFonts.poppins(color: Colors.grey[700]),
                      ),
                      Text(
                        locator.tauxService.formatPrice(paidAmount),
                        style: GoogleFonts.poppins(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Reste à payer:',
                        style: GoogleFonts.poppins(
                          color: change < 0 ? Colors.red[700] : Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        locator.tauxService.formatPrice(
                          change < 0 ? change.abs() : 0,
                        ),
                        style: GoogleFonts.poppins(
                          color: change < 0 ? Colors.red[700] : Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.secondary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isProcessing ? null : _confirmSale,
                      child: _isProcessing
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              'Valider la vente',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

// Fonction utilitaire pour afficher le bottomsheet de vente rapide
Future<void> showFastSaleBottomSheet({
  required BuildContext context,
  required NumberFormat currencyFormat,
  required String currencySymbol,
  ArticleData? initialFocusedArticle,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (context) => FastSaleBottomSheet(
      currencyFormat: currencyFormat,
      currencySymbol: currencySymbol,
      initialFocusedArticle: initialFocusedArticle,
      onClose: () => Navigator.pop(context),
    ),
  );
}
