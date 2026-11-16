// lib/screens/payment_screen.dart
import 'package:flutter/material.dart';
import 'package:mombongo/services/app_currency_preference.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/services/cart_service.dart';
import 'package:mombongo/utils/invoice_receipt_helper.dart';
import 'package:mombongo/models/client.dart';
import 'package:mombongo/ui/screens/caissier/create_client_screen.dart';
import 'package:mombongo/utils/google_fonts_compat.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:mombongo/ui/widgets/invoice_generator.dart';
import 'package:mombongo/utils/receipt/receipt_print_dialog.dart';
import 'dart:convert';
import 'package:mombongo/utils/api_error_message.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  // Selected payment method
  String _selectedPaymentMethod = 'Espèces';

  // Invoice number
  String _invoiceNumber = '';

  // Selected client
  Client? _selectedClient;

  // Client search for payment section
  final TextEditingController _paymentSearchController =
      TextEditingController();
  List<dynamic> _paymentSearchResults = [];

  // Payment amount
  double _paidAmount = 0.0;

  // transaction type codes
  int _typeTransaction = 3; // Default to 'Complet'
  static const List<String> _transactionLabels = [
    '', // Index 0 (unused)
    'Avance/Acompte', // 1
    'Solde',          // 2
    'Complet',        // 3
    'Versement',      // 4
  ];

  @override
  void initState() {
    super.initState();
    // Generate invoice number
    _generateInvoiceNumber();
    // Set initial paid amount to total
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final cartService = Provider.of<CartService>(context, listen: false);
        setState(() {
          _paidAmount = cartService.total;
        });
      }
    });
  }

  void _generateInvoiceNumber() {
    final now = DateTime.now();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final randomNum = Random().nextInt(9000) + 1000; // Random 4-digit number

    setState(() {
      _invoiceNumber = 'FAC-$year$month$day-$randomNum';
    });
  }

  Future<void> _showLoyaltyDialog() async {
    debugPrint('=== OUVERTURE ECRAN CREATION CLIENT ===');

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateClientScreen()),
    );

    debugPrint('Retour de l\'écran de création client');
    debugPrint('Résultat: $result');
    debugPrint('Type: ${result.runtimeType}');

    // If a client was created, update the selected client
    if (result != null && result is Client) {
      debugPrint('Client reçu avec succès:');
      debugPrint('  - ID: ${result.id}');
      debugPrint('  - Nom: ${result.nom} ${result.prenom}');
      debugPrint('  - Email: ${result.email}');
      debugPrint('  - Téléphone: ${result.telephone}');

      setState(() {
        _selectedClient = result;
      });

      debugPrint('Client sélectionné mis à jour dans payment_screen');
      debugPrint('=== FIN TRAITEMENT CLIENT ===');
    } else {
      debugPrint('Aucun client reçu ou type incorrect');
      debugPrint('=== FIN TRAITEMENT CLIENT (ANNULE) ===');
    }
  }

  @override
  void dispose() {
    _paymentSearchController.dispose();
    super.dispose();
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

      if (clientDataFixed.containsKey('dateCreation')) {
        final dateCreationValue = clientDataFixed['dateCreation'];
        if (dateCreationValue is! String) {
          clientDataFixed['dateCreation'] = dateCreationValue.toString();
        }
      } else {
        clientDataFixed['dateCreation'] = DateTime.now().toIso8601String();
      }

      if (clientDataFixed.containsKey('statut')) {
        final statutValue = clientDataFixed['statut'];
        if (statutValue is String) {
          clientDataFixed['statut'] =
              statutValue.toLowerCase() == 'true' || statutValue == '1';
        } else if (statutValue is int) {
          clientDataFixed['statut'] = statutValue == 1;
        } else if (statutValue is! bool) {
          clientDataFixed['statut'] = true;
        }
      } else {
        clientDataFixed['statut'] = true;
      }

      final client = Client.fromJson(clientDataFixed);
      setState(() {
        _selectedClient = client;
      });
    } catch (e) {
      debugPrint('Erreur lors de la sélection du client: $e');
    }
  }

  Future<void> _searchClientsFromPayment(String query) async {
    if (query.length < 2) {
      setState(() {
        _paymentSearchResults = [];
      });
      return;
    }

    try {
      // Try searching by email first (if it looks like an email)
      final isEmail = query.contains('@');
      final isPhone = RegExp(r'^[0-9+\s-]+$').hasMatch(query);

      final results = await locator.apiService.searchClients(
        email: isEmail ? query : null,
        nom: (isEmail || isPhone) ? null : query,
        telephone: isPhone ? query : null,
        pageSize: 10,
      );

      if (!mounted) return;

      debugPrint('=== RECHERCHE CLIENTS ===');
      debugPrint('Nombre de résultats: ${results.length}');
      debugPrint('Résultats: $results');
      debugPrint('Type de résultats: ${results.runtimeType}');
      if (results.isNotEmpty) {
        debugPrint('Premier résultat: ${results[0]}');
        debugPrint('Clés du premier résultat: ${results[0].keys}');
      }

      if (!mounted) return;

      setState(() {
        _paymentSearchResults = results;
        debugPrint(
          '_paymentSearchResults mis à jour: ${_paymentSearchResults.length} éléments',
        );
      });
    } catch (e) {
      debugPrint('Erreur lors de la recherche de clients: $e');
      if (!mounted) return;

      setState(() {
        _paymentSearchResults = [];
      });
    }
  }

  Widget _buildSearchBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: TextField(
            controller: _paymentSearchController,
            decoration: InputDecoration(
              hintText: 'Rechercher par nom, email ou téléphone',
              hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
              prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
              suffixIcon: _paymentSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey[600]),
                      onPressed: () {
                        setState(() {
                          _paymentSearchController.clear();
                          _paymentSearchResults = [];
                          _selectedClient = null;
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
            ),
            style: GoogleFonts.poppins(fontSize: 16),
            onChanged: (value) {
              if (value.length >= 2) {
                _searchClientsFromPayment(value);
              } else {
                setState(() {
                  _paymentSearchResults = [];
                });
              }
            },
          ),
        ),
        if (_paymentSearchResults.isNotEmpty) ...[
          SizedBox(height: 8),
          Container(
            constraints: BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _paymentSearchResults.length,
              itemBuilder: (context, index) {
                final client = _paymentSearchResults[index];
                debugPrint('Building client item $index: $client');
                final clientName =
                    '${client['nom'] ?? ''} ${client['prenom'] ?? ''}'.trim();
                final clientEmail = client['email'] ?? '';
                final clientPhone = client['telephone'] ?? '';
                final clientId =
                    int.tryParse(client['idClient']?.toString() ?? '0') ?? 0;
                final isSelected =
                    _selectedClient != null && _selectedClient!.id == clientId;

                debugPrint(
                  'Client name: $clientName, ID: $clientId, Selected: $isSelected',
                );

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSelected
                        ? Colors.green
                        : Colors.grey[300],
                    child: Icon(
                      Icons.person,
                      color: isSelected ? Colors.white : Colors.grey[600],
                    ),
                  ),
                  title: Text(
                    clientName,
                    style: GoogleFonts.poppins(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (clientEmail.isNotEmpty) Text(clientEmail),
                      if (clientPhone.isNotEmpty) Text(clientPhone),
                    ],
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: Colors.green)
                      : Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey,
                        ),
                  onTap: () {
                    _selectClientFromSearch(client);
                    setState(() {
                      _paymentSearchController.clear();
                      _paymentSearchResults = [];
                    });
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  void _processPayment() async {
    debugPrint('=== DEBUT PROCESSUS PAIEMENT ===');
    debugPrint('Payment method: $_selectedPaymentMethod');
    debugPrint('Paid amount: $_paidAmount');

    if (_selectedPaymentMethod.isEmpty) {
      debugPrint('No payment method selected');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Veuillez sélectionner un mode de paiement'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final cartService = Provider.of<CartService>(context, listen: false);
    final total = cartService.total;
    debugPrint('Cart total: $total');

    // Le paiement partiel n'est autorisé que pour les clients inscrits
    if (_paidAmount < total && _selectedClient == null) {
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
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
      return;
    }

    if (_paidAmount < total) {
      // treat as deposit/acompte
      debugPrint('Acompte detected: $_paidAmount of $total');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Acompte de ${locator.tauxService.formatPrice(_paidAmount)} enregistré ' 
            '(total ${locator.tauxService.formatPrice(total)})',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      // continue to build saleData with partial status
    }

    try {
      // Prepare sale data
      final currentUser = locator.authRepository.currentUser;
      debugPrint('Current user: ${currentUser?.nomComplet}');
      debugPrint('User site: ${currentUser?.idSite}');

      // Parse address components
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
      debugPrint(
        'Address parsed - Province: $province, Ville: $ville, Commune: $commune',
      );

      // Use selected client if available, otherwise use defaults
      final saleData = {
        'nom': _selectedClient?.nom ?? 'Client',
        'prenom': _selectedClient?.prenom ?? 'Anonyme',
        'genre': _selectedClient?.genre ?? 'M',
        'email': _selectedClient?.email ?? '',
        'telephone': _selectedClient?.telephone ?? '',
        'dateNaissance':
            _selectedClient?.dateNaissance?.toIso8601String() ??
            DateTime.now().subtract(Duration(days: 365 * 25)).toIso8601String(),
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
        'datePaiement': DateTime.now().toIso8601String(),
        'modePaiement': _selectedPaymentMethod,
        'montant': _paidAmount, // send amount paid (deposit allowed)
        'referencePaiement': _invoiceNumber,
        'statutPaiement': _paidAmount < total ? 'PARTIEL' : 'COMPLETED',
        'libellePaiement': _paidAmount < total
            ? 'Acompte pour la facture $_invoiceNumber'
            : 'Paiement pour la facture $_invoiceNumber',
        // conform to /api/Vente/enregistrer schema
        // defaults worked in swagger example
        'typeTransaction': _typeTransaction,
        'catalogueId': 0,
        'statutCommande': _paidAmount < total ? 'EN ATTENTE' : 'VALIDEE',
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

      debugPrint('Sale data prepared: ${saleData.keys}');
      final lignesCommandes = saleData['lignesCommandes'] as List?;
      debugPrint('Number of items: ${lignesCommandes?.length ?? 0}');
      debugPrint('Total amount: ${saleData['montant']}');
      debugPrint('Invoice number: $_invoiceNumber');

      debugPrint('Calling VenteRepository to record sale...');
      // log payload for debugging
      debugPrint('saleData JSON: ${jsonEncode(saleData)}');
      final result = await locator.venteRepository.enregistrerVente(saleData);
      final response = result.response;
      debugPrint('Sale result offline=${result.isOffline}: $response');

      // Notifie le SyncService pour déclencher le rafraîchissement du dashboard
      // (même en ligne, pour éviter d'attendre un reload de la page).
      locator.syncService.refreshPending();

      if (result.isOffline) {
        debugPrint('Sale queued offline: ${result.reference}');
      } else if (response['success'] == true) {
        debugPrint('Sale recorded successfully!');
      } else {
        debugPrint('Warning: Sale response indicates failure: $response');
      }

      // IMPORTANT: Generate PDF BEFORE clearing cart (we need cart items for invoice)
      debugPrint('Starting invoice generation (before clearing cart)...');
      debugPrint('Cart items before generation: ${cartService.items.length}');
      // Reçu commun à toute l'app (choix 58/80 mm dans la boîte d'impression).
      final receiptOutcome = await InvoiceGenerator(
        context: context,
        items: snapshotCartItemsForReceipt(cartService),
        selectedClient: _selectedClient,
        saleResponse: response,
        invoiceNumber: _invoiceNumber,
        paidAmountOverride: _paidAmount > 0 ? _paidAmount : null,
      ).generateAndShow();
      debugPrint('Invoice generation completed: $receiptOutcome');

      // Clear cart AFTER invoice generation
      debugPrint('Clearing cart...');
      cartService.clearAfterPayment();
      debugPrint('Cart cleared');

      // Clear selected client
      if (mounted) {
        setState(() {
          _selectedClient = null;
        });
      }

      // Show success message
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.isOffline
                  ? 'Vente hors ligne enregistrée (sync en attente). Facture: ${result.reference}'
                  : 'Paiement effectué avec succès! Numéro de facture: $_invoiceNumber',
            ),
            backgroundColor: result.isOffline ? Colors.orange : Colors.green,
          ),
        );
      }

      // Comme avant : on quitte l'écran de paiement après une impression.
      if (receiptOutcome == ReceiptOutcome.printed && mounted) {
        Navigator.of(context).pop();
      }
      debugPrint('=== FIN PROCESSUS PAIEMENT (SUCCES) ===');
    } catch (e, stackTrace) {
      debugPrint('=== ERREUR PROCESSUS PAIEMENT ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('===================================');

      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(apiErrorUserMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartService = Provider.of<CartService>(context);
    final currencyCode = AppCurrencyPreference.readCode(
      locator.databaseService,
    );
    final NumberFormat currencyFormat = AppCurrencyPreference.formatterFor(
      currencyCode,
    );
    final currencySymbol = AppCurrencyPreference.symbolFor(currencyCode);
    final currencyInputPrefix = AppCurrencyPreference.inputPrefixFor(
      currencyCode,
    );

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Paiement',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cart Summary
            Text(
              'Récapitulatif du panier',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.tertiary,
              ),
            ),
            SizedBox(height: 16),

            // Selected client display
            if (_selectedClient != null) ...[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.green[300]!),
                ),
                color: Colors.green[50],
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.person, color: Colors.green[700], size: 32),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Client sélectionné',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '${_selectedClient!.nom} ${_selectedClient!.prenom}',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            if (_selectedClient!.email != null &&
                                _selectedClient!.email!.isNotEmpty)
                              Text(
                                _selectedClient!.email!,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            if (_selectedClient!.telephone != null &&
                                _selectedClient!.telephone!.isNotEmpty)
                              Text(
                                _selectedClient!.telephone!,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.green[700]),
                        onPressed: _showLoyaltyDialog,
                        tooltip: 'Modifier',
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
            ],

            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'N° de fac: ',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          _invoiceNumber,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Divider(),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total:',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                        ),
                        Text(
                          locator.tauxService.formatPrice(cartService.total),
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            // Customer Selection
            Text(
              'Client',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.tertiary,
              ),
            ),
            SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (_selectedClient != null) ...[
                      // Affichage du client sélectionné
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.green[700],
                              child: Text(
                                '${_selectedClient!.nom[0].toUpperCase()}${_selectedClient!.prenom[0].toUpperCase()}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Client sélectionné',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '${_selectedClient!.prenom} ${_selectedClient!.nom}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  if (_selectedClient!.email != null &&
                                      _selectedClient!.email!.isNotEmpty) ...[
                                    SizedBox(height: 2),
                                    Text(
                                      _selectedClient!.email!,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                  if (_selectedClient!.telephone != null &&
                                      _selectedClient!
                                          .telephone!
                                          .isNotEmpty) ...[
                                    SizedBox(height: 2),
                                    Text(
                                      _selectedClient!.telephone!,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.green[700]),
                              onPressed: _showLoyaltyDialog,
                              tooltip: 'Modifier',
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: Colors.grey[600]),
                              onPressed: () {
                                setState(() {
                                  _selectedClient = null;
                                  _paymentSearchController.clear();
                                  _paymentSearchResults = [];
                                });
                              },
                              tooltip: 'Désélectionner',
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Barre de recherche si aucun client sélectionné
                      _buildSearchBar(),
                      SizedBox(height: 16),
                      // Bouton pour créer un client
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _showLoyaltyDialog,
                              icon: Icon(
                                Icons.person_add,
                                color: Theme.of(context).colorScheme.tertiary,
                              ),
                              label: Text(
                                'Créer un client',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.tertiary,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: Theme.of(context).colorScheme.tertiary,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // Payment Method Selection
            Text(
              'Mode de paiement',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.tertiary,
              ),
            ),
            SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ChoiceChip(
                          label: Text(
                            'Espèces',
                            style: GoogleFonts.poppins(
                              color: _selectedPaymentMethod == 'Espèces'
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.tertiary,
                            ),
                          ),
                          selected: _selectedPaymentMethod == 'Espèces',
                          selectedColor: Theme.of(context).colorScheme.tertiary,
                          backgroundColor: Colors.white,
                          onSelected: (selected) {
                            setState(() {
                              _selectedPaymentMethod = selected
                                  ? 'Espèces'
                                  : '';
                            });
                          },
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.tertiary,
                            width: 1,
                          ),
                        ),
                        ChoiceChip(
                          label: Text(
                            'Carte Bancaire',
                            style: GoogleFonts.poppins(
                              color: _selectedPaymentMethod == 'Carte Bancaire'
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.tertiary,
                            ),
                          ),
                          selected: _selectedPaymentMethod == 'Carte Bancaire',
                          selectedColor: Theme.of(context).colorScheme.tertiary,
                          backgroundColor: Colors.white,
                          onSelected: (selected) {
                            setState(() {
                              _selectedPaymentMethod = selected
                                  ? 'Carte Bancaire'
                                  : '';
                            });
                          },
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.tertiary,
                            width: 1,
                          ),
                        ),
                        ChoiceChip(
                          label: Text(
                            'Mobile Money',
                            style: GoogleFonts.poppins(
                              color: _selectedPaymentMethod == 'Mobile Money'
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.tertiary,
                            ),
                          ),
                          selected: _selectedPaymentMethod == 'Mobile Money',
                          selectedColor: Theme.of(context).colorScheme.tertiary,
                          backgroundColor: Colors.white,
                          onSelected: (selected) {
                            setState(() {
                              _selectedPaymentMethod = selected
                                  ? 'Mobile Money'
                                  : '';
                            });
                          },
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.tertiary,
                            width: 1,
                          ),
                        ),
                        ChoiceChip(
                          label: Text(
                            'Chèque',
                            style: GoogleFonts.poppins(
                              color: _selectedPaymentMethod == 'Chèque'
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.tertiary,
                            ),
                          ),
                          selected: _selectedPaymentMethod == 'Chèque',
                          selectedColor: Theme.of(context).colorScheme.tertiary,
                          backgroundColor: Colors.white,
                          onSelected: (selected) {
                            setState(() {
                              _selectedPaymentMethod = selected ? 'Chèque' : '';
                            });
                          },
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.tertiary,
                            width: 1,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    // transaction type selector
                    DropdownButtonFormField<int>(
                      value: _typeTransaction,
                      decoration: InputDecoration(
                        labelText: 'Type de transaction',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: List.generate(_transactionLabels.length, (i) {
                        return DropdownMenuItem(
                          value: i,
                          child: Text(_transactionLabels[i]),
                        );
                      }),
                      onChanged: (val) {
                        setState(() {
                          _typeTransaction = val ?? 3;
                        });
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Montant payé',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixText: currencyInputPrefix,
                      ),
                      keyboardType: TextInputType.number,
                      initialValue: cartService.total.toStringAsFixed(2),
                      onChanged: (value) {
                        setState(() {
                          _paidAmount = double.tryParse(value) ?? 0.0;
                        });
                      },
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Reste à payer:',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          locator.tauxService.formatPrice(_paidAmount - cartService.total),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: (_paidAmount - cartService.total) < 0
                                ? Colors.red
                                : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 30),

            // Confirm Payment Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.tertiary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'CONFIRMER LE PAIEMENT',
                  style: GoogleFonts.poppins(
                    color: Theme.of(context).colorScheme.onTertiary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
