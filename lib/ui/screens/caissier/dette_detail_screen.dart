import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/services/app_currency_preference.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pdfLib;
import 'package:printing/printing.dart';
import 'dart:io' as io;

class DetteDetailScreen extends StatefulWidget {
  final Map<String, dynamic> dette;
  final Map<String, dynamic>? commande;
  final Map<String, dynamic>? client;

  const DetteDetailScreen({
    super.key,
    required this.dette,
    this.commande,
    this.client,
  });

  @override
  State<DetteDetailScreen> createState() => _DetteDetailScreenState();
}

class _DetteDetailScreenState extends State<DetteDetailScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _clientData;

  @override
  void initState() {
    super.initState();
    _loadClientData();
  }

  Future<void> _loadClientData() async {
    if (widget.client != null) {
      setState(() => _clientData = widget.client);
      return;
    }

    final dette = widget.dette;
    final commande = widget.commande;

    // Try to get client from commande.client first (API nested format)
    final clientFromCommande = commande?['client'] as Map<String, dynamic>?;
    if (clientFromCommande != null && clientFromCommande.isNotEmpty) {
      setState(() => _clientData = clientFromCommande);
      return;
    }

    // Fallback: get client by ID from commande or dette
    int? clientId;

    final idClientFromCommande = commande?['idClient'] as int?;
    if (idClientFromCommande != null) {
      clientId = idClientFromCommande;
    } else {
      clientId = dette['idClient'] as int?;
    }

    if (clientId != null) {
      try {
        final client = await locator.apiService.getClientById(clientId);
        if (mounted) {
          setState(() => _clientData = client);
        }
      } catch (e) {
        debugPrint('Error loading client: $e');
      }
    }
  }

  String _formatCurrency(double amount) {
    return locator.tauxService.formatPrice(amount);
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  Color _getStatusColor(String? statut) {
    if (statut == null) return Colors.grey;
    switch (statut.toUpperCase()) {
      case 'PARTIEL':
        return Colors.orange;
      case 'EN_ATTENTE':
        return Colors.red;
      case 'PAYE':
      case 'COMPLET':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getModeColor(String? mode) {
    if (mode == null) return Colors.grey;
    switch (mode.toUpperCase()) {
      case 'ESPECE':
      case 'ESPÈCES':
        return Colors.green;
      case 'MOBILE_MONEY':
      case 'MOBILE':
        return Colors.blue;
      case 'CARTE':
        return Colors.purple;
      case 'VIREMENT':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getModeIcon(String mode) {
    switch (mode.toUpperCase()) {
      case 'ESPECE':
      case 'ESPÈCES':
        return Icons.money;
      case 'MOBILE_MONEY':
      case 'MOBILE':
        return Icons.phone_android;
      case 'CARTE':
        return Icons.credit_card;
      case 'VIREMENT':
        return Icons.account_balance;
      default:
        return Icons.payment;
    }
  }

  Future<void> _payerDette() async {
    final dette = widget.dette;
    final montant = double.tryParse(dette['montant']?.toString() ?? '0') ?? 0;
    final resteAPayer =
        double.tryParse(widget.commande?['resteAPayer']?.toString() ?? '0') ??
        0;

    final typeTransaction = dette['typeTransaction']?.toString() ?? '0';
    String typeLabel = 'Paiement';
    if (typeTransaction == '1') {
      typeLabel = 'Acompte';
    } else if (typeTransaction == '2') {
      typeLabel = 'Solde';
    } else if (typeTransaction == '4') {
      typeLabel = 'Versement';
    }

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PaiementDialog(
        montant: montant,
        resteAPayer: resteAPayer,
        typeLabel: typeLabel,
        clientNomComplet: _clientData != null
            ? '${_clientData!['prenom'] ?? ''} ${_clientData!['nom'] ?? ''}'
                  .trim()
            : null,
      ),
    );

    if (result != null && mounted) {
      setState(() => _isLoading = true);

      try {
        final currentUser = locator.authRepository.currentUser;
        if (currentUser == null) {
          throw Exception('Utilisateur non connecté');
        }

        // Convert UI mode to API mode
        String apiMode;
        switch (result['modePaiement'] as String) {
          case 'Espèces':
            apiMode = 'ESPECE';
            break;
          case 'Mobile Money':
            apiMode = 'MOBILE_MONEY';
            break;
          case 'Carte':
            apiMode = 'CARTE';
            break;
          case 'Virement':
            apiMode = 'VIREMENT';
            break;
          default:
            apiMode = 'ESPECE';
        }

        final now = DateTime.now().toUtc().toIso8601String();

        final paiementData = {
          'dateCreation': now,
          'dateLastModification': now,
          'statut': 'ACTIF',
          'idPaiement': 0,
          'datePaiement': now,
          'modePaiement': apiMode,
          'montant': result['montant'],
          'referencePaiemenet': 'FAC-${DateTime.now().millisecondsSinceEpoch}',
          'libelle': result['libelle'] ?? 'Paiement dette',
          'idCommande': dette['idCommande'],
          'idReservation': dette['idReservation'] ?? 0,
          'typeTransaction': result['typeTransaction'] ?? 2,
        };

        debugPrint('Paiement data sent: $paiementData');

        final response = await locator.apiService.createPaiement(paiementData);
        debugPrint('Paiement créé: $response');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Paiement effectué avec succès'),
              backgroundColor: Colors.green,
            ),
          );

          await _genererRecu(result['montant']);

          Navigator.of(context).pop(true);
        }
      } catch (e) {
        debugPrint('Erreur paiement: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _genererRecu(double? montantPaye) async {
    final dette = widget.dette;
    final commande = widget.commande;
    final client = widget.client;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Génération du reçu...'),
          ],
        ),
      ),
    );

    try {
      final pdf = await _createRecuPDF(dette, commande, client, montantPaye);

      if (mounted) {
        Navigator.of(context).pop();
        await _showPrintOptionsDialog(context, pdf);
      }
    } catch (e) {
      debugPrint('Erreur génération reçu: $e');
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<pdfLib.Document> _createRecuPDF(
    Map<String, dynamic> dette,
    Map<String, dynamic>? commande,
    Map<String, dynamic>? client,
    double? montantPaye,
  ) async {
    final pdf = pdfLib.Document();
    final currentUser = locator.authRepository.currentUser;

    // Use _clientData if client param is null
    final clientData = client ?? _clientData;

    final reference =
        dette['referencePaiemenet']?.toString() ??
        dette['referencePaiement']?.toString() ??
        '-';
    final montant = double.tryParse(dette['montant']?.toString() ?? '0') ?? 0;
    final mode = dette['modePaiement']?.toString() ?? 'Espèces';
    final date = _formatDate(dette['datePaiement']);
    final typeTransaction = dette['typeTransaction']?.toString() ?? '0';
    final typeLabel = typeTransaction == '1'
        ? 'Acompte'
        : (typeTransaction == '2' ? 'Solde' : 'Paiement');

    final montantTotal =
        double.tryParse(commande?['montantTotal']?.toString() ?? '0') ?? 0;
    final montantPayeTotal =
        double.tryParse(commande?['montantPaye']?.toString() ?? '0') ?? 0;
    final resteAPayer =
        double.tryParse(commande?['resteAPayer']?.toString() ?? '0') ?? 0;

    final clientNom = clientData?['nom']?.toString() ?? '';
    final clientPrenom = clientData?['prenom']?.toString() ?? '';
    final clientNomComplet = '$clientNom $clientPrenom'.trim();

    String receiptLogoPath = '';
    List<int>? logoBytes;
    try {
      receiptLogoPath =
          locator.databaseService.get<String>('pref_receipt_logo_path') ?? '';
      if (receiptLogoPath.isNotEmpty) {
        final file = io.File(receiptLogoPath);
        if (file.existsSync()) {
          logoBytes = file.readAsBytesSync();
        }
      }
    } catch (e) {
      debugPrint('Erreur chargement logo: $e');
    }

    String receiptFooterMessage = '';
    try {
      receiptFooterMessage =
          locator.databaseService.get<String>('pref_receipt_footer_message') ??
          '';
    } catch (e) {
      debugPrint('Erreur chargement message: $e');
    }

    pdf.addPage(
      pdfLib.MultiPage(
        pageFormat: PdfPageFormat(
          70 * PdfPageFormat.mm,
          200 * PdfPageFormat.mm,
          marginLeft: 8 * PdfPageFormat.mm,
          marginRight: 8 * PdfPageFormat.mm,
          marginTop: 8 * PdfPageFormat.mm,
          marginBottom: 8 * PdfPageFormat.mm,
        ),
        build: (context) => [
          pdfLib.Column(
            crossAxisAlignment: pdfLib.CrossAxisAlignment.center,
            children: [
              if (receiptLogoPath.isNotEmpty && logoBytes != null)
                pdfLib.Container(
                  height: 30,
                  margin: const pdfLib.EdgeInsets.only(bottom: 5),
                  child: pdfLib.Image(
                    pdfLib.MemoryImage(
                      io.File(receiptLogoPath).readAsBytesSync(),
                    ),
                    fit: pdfLib.BoxFit.contain,
                  ),
                ),
              pdfLib.Text(
                currentUser?.nomSociete ?? 'MONBONGO',
                style: pdfLib.TextStyle(
                  fontSize: 10,
                  fontWeight: pdfLib.FontWeight.bold,
                ),
                textAlign: pdfLib.TextAlign.center,
              ),
              pdfLib.SizedBox(height: 2),
              pdfLib.Text(
                currentUser?.nomSite ?? 'Siège',
                style: pdfLib.TextStyle(fontSize: 8),
                textAlign: pdfLib.TextAlign.center,
              ),
              pdfLib.SizedBox(height: 5),
              pdfLib.Divider(thickness: 0.5),
              pdfLib.SizedBox(height: 5),

              pdfLib.Text(
                'REÇU DE PAIEMENT',
                style: pdfLib.TextStyle(
                  fontSize: 9,
                  fontWeight: pdfLib.FontWeight.bold,
                ),
              ),
              pdfLib.SizedBox(height: 8),

              pdfLib.Row(
                mainAxisAlignment: pdfLib.MainAxisAlignment.spaceBetween,
                children: [
                  pdfLib.Text('Ref:', style: pdfLib.TextStyle(fontSize: 7)),
                  pdfLib.Text(
                    reference,
                    style: pdfLib.TextStyle(
                      fontSize: 7,
                      fontWeight: pdfLib.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pdfLib.SizedBox(height: 2),
              pdfLib.Row(
                mainAxisAlignment: pdfLib.MainAxisAlignment.spaceBetween,
                children: [
                  pdfLib.Text('Date:', style: pdfLib.TextStyle(fontSize: 7)),
                  pdfLib.Text(date, style: pdfLib.TextStyle(fontSize: 7)),
                ],
              ),
              pdfLib.SizedBox(height: 2),
              pdfLib.Row(
                mainAxisAlignment: pdfLib.MainAxisAlignment.spaceBetween,
                children: [
                  pdfLib.Text('Type:', style: pdfLib.TextStyle(fontSize: 7)),
                  pdfLib.Text(
                    typeLabel,
                    style: pdfLib.TextStyle(
                      fontSize: 7,
                      fontWeight: pdfLib.FontWeight.bold,
                    ),
                  ),
                ],
              ),

              pdfLib.SizedBox(height: 8),
              pdfLib.Divider(thickness: 0.5),
              pdfLib.SizedBox(height: 8),

              if (clientNomComplet.isNotEmpty) ...[
                pdfLib.Row(
                  mainAxisAlignment: pdfLib.MainAxisAlignment.spaceBetween,
                  children: [
                    pdfLib.Text(
                      'Client:',
                      style: pdfLib.TextStyle(fontSize: 7),
                    ),
                    pdfLib.Text(
                      clientNomComplet,
                      style: pdfLib.TextStyle(
                        fontSize: 7,
                        fontWeight: pdfLib.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pdfLib.SizedBox(height: 4),
              ],

              pdfLib.Row(
                mainAxisAlignment: pdfLib.MainAxisAlignment.spaceBetween,
                children: [
                  pdfLib.Text('Mode:', style: pdfLib.TextStyle(fontSize: 7)),
                  pdfLib.Text(mode, style: pdfLib.TextStyle(fontSize: 7)),
                ],
              ),
              pdfLib.SizedBox(height: 4),

              pdfLib.Row(
                mainAxisAlignment: pdfLib.MainAxisAlignment.spaceBetween,
                children: [
                  pdfLib.Text('Montant:', style: pdfLib.TextStyle(fontSize: 8)),
                  pdfLib.Text(
                    '${AppCurrencyPreference.symbolFor(AppCurrencyPreference.readCode(locator.databaseService))}${AppCurrencyPreference.formatterFor(AppCurrencyPreference.readCode(locator.databaseService)).format(montantPaye ?? montant)}',
                    style: pdfLib.TextStyle(
                      fontSize: 10,
                      fontWeight: pdfLib.FontWeight.bold,
                    ),
                  ),
                ],
              ),

              if (montantTotal > 0) ...[
                pdfLib.SizedBox(height: 8),
                pdfLib.Divider(thickness: 0.5),
                pdfLib.SizedBox(height: 5),

                pdfLib.Row(
                  mainAxisAlignment: pdfLib.MainAxisAlignment.spaceBetween,
                  children: [
                    pdfLib.Text('Total:', style: pdfLib.TextStyle(fontSize: 7)),
                    pdfLib.Text(
                      '${AppCurrencyPreference.symbolFor(AppCurrencyPreference.readCode(locator.databaseService))}${AppCurrencyPreference.formatterFor(AppCurrencyPreference.readCode(locator.databaseService)).format(montantTotal)}',
                      style: pdfLib.TextStyle(fontSize: 7),
                    ),
                  ],
                ),
                pdfLib.SizedBox(height: 2),
                pdfLib.Row(
                  mainAxisAlignment: pdfLib.MainAxisAlignment.spaceBetween,
                  children: [
                    pdfLib.Text('Payé:', style: pdfLib.TextStyle(fontSize: 7)),
                    pdfLib.Text(
                      '${AppCurrencyPreference.symbolFor(AppCurrencyPreference.readCode(locator.databaseService))}${AppCurrencyPreference.formatterFor(AppCurrencyPreference.readCode(locator.databaseService)).format(montantPayeTotal + (montantPaye ?? 0))}',
                      style: pdfLib.TextStyle(
                        fontSize: 7,
                        color: PdfColors.green,
                      ),
                    ),
                  ],
                ),
                pdfLib.SizedBox(height: 2),
                pdfLib.Row(
                  mainAxisAlignment: pdfLib.MainAxisAlignment.spaceBetween,
                  children: [
                    pdfLib.Text('Reste:', style: pdfLib.TextStyle(fontSize: 7)),
                    pdfLib.Text(
                      '${AppCurrencyPreference.symbolFor(AppCurrencyPreference.readCode(locator.databaseService))}${AppCurrencyPreference.formatterFor(AppCurrencyPreference.readCode(locator.databaseService)).format(resteAPayer - (montantPaye ?? 0))}',
                      style: pdfLib.TextStyle(
                        fontSize: 7,
                        fontWeight: pdfLib.FontWeight.bold,
                        color: (resteAPayer - (montantPaye ?? 0)) > 0
                            ? PdfColors.red
                            : PdfColors.green,
                      ),
                    ),
                  ],
                ),
              ],

              pdfLib.SizedBox(height: 15),
              pdfLib.Text(
                'MERCI DE VOTRE CONFIANCE !',
                style: pdfLib.TextStyle(
                  fontSize: 8,
                  fontWeight: pdfLib.FontWeight.bold,
                ),
                textAlign: pdfLib.TextAlign.center,
              ),

              if (receiptFooterMessage.isNotEmpty) ...[
                pdfLib.SizedBox(height: 6),
                pdfLib.Text(
                  receiptFooterMessage,
                  style: pdfLib.TextStyle(
                    fontSize: 6,
                    fontStyle: pdfLib.FontStyle.italic,
                  ),
                  textAlign: pdfLib.TextAlign.center,
                ),
              ],
            ],
          ),
        ],
      ),
    );

    return pdf;
  }

  Future<void> _showPrintOptionsDialog(
    BuildContext context,
    pdfLib.Document pdf,
  ) async {
    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long,
                  size: 32,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Reçu généré',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Voulez-vous-imprimer ou partager le reçu?',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        await Printing.sharePdf(
                          bytes: await pdf.save(),
                          filename: 'recupaiement.pdf',
                        );
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('Partager'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        await Printing.layoutPdf(
                          onLayout: (format) async => pdf.save(),
                        );
                      },
                      icon: const Icon(Icons.print),
                      label: const Text('Imprimer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C3E50),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dette = widget.dette;
    final commande = widget.commande;
    final client = _clientData;

    final montant = double.tryParse(dette['montant']?.toString() ?? '0') ?? 0;
    final mode = dette['modePaiement']?.toString() ?? '-';
    final statut = dette['statut']?.toString() ?? '-';
    final reference =
        dette['referencePaiemenet']?.toString() ??
        dette['referencePaiement']?.toString() ??
        '-';
    final date = _formatDate(dette['datePaiement']);
    final typeTransaction = dette['typeTransaction']?.toString() ?? '0';
    final typeLabel = typeTransaction == '1'
        ? 'Acompte'
        : (typeTransaction == '2' ? 'Solde' : 'Paiement');

    final montantTotal =
        double.tryParse(commande?['montantTotal']?.toString() ?? '0') ?? 0;
    final montantPaye =
        double.tryParse(commande?['montantPaye']?.toString() ?? '0') ?? 0;
    final resteAPayer =
        double.tryParse(commande?['resteAPayer']?.toString() ?? '0') ?? 0;

    final clientNom = client?['nom']?.toString() ?? '';
    final clientPrenom = client?['prenom']?.toString() ?? '';
    final clientTelephone = client?['telephone']?.toString() ?? '';
    final clientEmail = client?['email']?.toString() ?? '';
    final clientNomComplet = '$clientNom $clientPrenom'.trim();

    // Adresse complète
    final province = client?['province']?.toString() ?? '';
    final ville = client?['ville']?.toString() ?? '';
    final commune = client?['commune']?.toString() ?? '';
    final quartier = client?['quartier']?.toString() ?? '';
    final avenue = client?['avenue']?.toString() ?? '';
    final numero = client?['numero']?.toString() ?? '';

    String adresseComplete = '';
    List<String> adresseParts = [];
    if (numero.isNotEmpty) adresseParts.add(numero);
    if (avenue.isNotEmpty) adresseParts.add(avenue);
    if (quartier.isNotEmpty) adresseParts.add(quartier);
    if (commune.isNotEmpty) adresseParts.add(commune);
    if (ville.isNotEmpty) adresseParts.add(ville);
    if (province.isNotEmpty) adresseParts.add(province);
    adresseComplete = adresseParts.join(', ');

    final hasClient = clientNomComplet.isNotEmpty || clientTelephone.isNotEmpty;

    final userRole =
        locator.authRepository.currentUser?.role.toUpperCase() ?? '';
    final isGestionnaire = userRole == 'GESTIONNAIRE';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Détail Paiement',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      reference,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: const Color(0xFF2C3E50),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      date,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    statut,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  statut,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _getStatusColor(statut),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _getModeColor(
                                      mode,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _getModeIcon(mode),
                                    color: _getModeColor(mode),
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        mode,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          color: _getModeColor(mode),
                                        ),
                                      ),
                                      Text(
                                        typeLabel,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _formatCurrency(montant),
                                      style: GoogleFonts.poppins(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF2C3E50),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (hasClient) ...[
                    const SizedBox(height: 16),
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Client',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: const Color(0xFF2C3E50),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: const Color(
                                    0xFF2C3E50,
                                  ).withValues(alpha: 0.1),
                                  child: const Icon(
                                    Icons.person,
                                    color: Color(0xFF2C3E50),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        clientNomComplet,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (clientTelephone.isNotEmpty)
                                        Text(
                                          clientTelephone,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      if (clientEmail.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.email,
                                              size: 14,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              clientEmail,
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      if (adresseComplete.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              Icons.location_on,
                                              size: 14,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                adresseComplete,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  if (montantTotal > 0) ...[
                    const SizedBox(height: 16),
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Détails financiers',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: const Color(0xFF2C3E50),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              'Total commande',
                              _formatCurrency(montantTotal),
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              'Montant payé',
                              _formatCurrency(montantPaye),
                              color: Colors.green,
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              'Reste à payer',
                              _formatCurrency(resteAPayer),
                              color: resteAPayer > 0
                                  ? Colors.red
                                  : Colors.green,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      if (!isGestionnaire) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _payerDette,
                            icon: const Icon(Icons.payment),
                            label: const Text('Payer'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _genererRecu(null),
                          icon: const Icon(Icons.receipt_long),
                          label: const Text('Imprimer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2C3E50),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color ?? Colors.black,
          ),
        ),
      ],
    );
  }
}

class _PaiementDialog extends StatefulWidget {
  final double montant;
  final double resteAPayer;
  final String typeLabel;
  final String? clientNomComplet;

  const _PaiementDialog({
    required this.montant,
    required this.resteAPayer,
    required this.typeLabel,
    this.clientNomComplet,
  });

  @override
  State<_PaiementDialog> createState() => _PaiementDialogState();
}

class _PaiementDialogState extends State<_PaiementDialog> {
  String _selectedMode = 'Espèces';
  late double _montant;
  late int _selectedTypeTransaction;
  final String nomComplet = "";
  final TextEditingController _libelleController = TextEditingController(
    text: 'Paiement dette',
  );
  final _formKey = GlobalKey<FormState>();

  final List<Map<String, dynamic>> _modes = [
    {'label': 'Espèces', 'icon': Icons.money, 'color': Colors.green},
    {
      'label': 'Mobile Money',
      'icon': Icons.phone_android,
      'color': Colors.blue,
    },
    {'label': 'Carte', 'icon': Icons.credit_card, 'color': Colors.purple},
    {
      'label': 'Virement',
      'icon': Icons.account_balance,
      'color': Colors.orange,
    },
  ];

  final List<Map<String, dynamic>> _transactionTypes = [
    {'label': 'Acompte', 'value': 1, 'description': 'Paiement partiel'},
    {'label': 'Solde', 'value': 2, 'description': 'Paiement complet'},
    {'label': 'Versement', 'value': 4, 'description': 'Versement'},
  ];

  @override
  void initState() {
    super.initState();
    _montant = widget.resteAPayer > 0 ? widget.resteAPayer : widget.montant;
    _updateTransactionType();
  }

  void _updateTransactionType() {
    if (widget.resteAPayer > 0) {
      if (_montant != widget.resteAPayer) {
        _selectedTypeTransaction = 4; // Versement
      } else {
        _selectedTypeTransaction = 2; // Solde
      }
    } else {
      _selectedTypeTransaction = 2;
    }
  }

  Color _getTransactionTypeColor(int value) {
    switch (value) {
      case 1:
        return Colors.blue;
      case 2:
        return Colors.green;
      case 4:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _libelleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.payment,
                        color: Colors.green,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Effectuer un paiement',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Montant à payer',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: _montant.toString(),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    prefixText: '\$ ',
                    prefixStyle: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                    filled: true,
                    fillColor: Colors.green.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.green.withValues(alpha: 0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.green.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.green,
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _montant = double.tryParse(value) ?? 0;
                      _updateTransactionType();
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer un montant';
                    }
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) {
                      return 'Montant invalide';
                    }
                    return null;
                  },
                ),
                if (widget.resteAPayer > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Reste à payer: \$${widget.resteAPayer.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Mode de paiement',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _modes.map((mode) {
                    final isSelected = _selectedMode == mode['label'];
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedMode = mode['label'];
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (mode['color'] as Color).withValues(alpha: 0.15)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? mode['color'] as Color
                                : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              mode['icon'] as IconData,
                              color: isSelected
                                  ? mode['color'] as Color
                                  : Colors.grey[600],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              mode['label'],
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isSelected
                                    ? mode['color'] as Color
                                    : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Text(
                  'Type de transaction',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _selectedTypeTransaction,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF2C3E50),
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  items: _transactionTypes.map((type) {
                    final typeValue = type['value'] as int;
                    return DropdownMenuItem<int>(
                      value: typeValue,
                      child: Text(
                        type['label'] as String,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: _getTransactionTypeColor(typeValue),
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedTypeTransaction = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Libellé (optionnel)',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _libelleController,
                  decoration: InputDecoration(
                    hintText: 'Paiement dette',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF2C3E50),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Annuler',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            Navigator.pop(context, {
                              'montant': _montant,
                              'modePaiement': _selectedMode,
                              'libelle': _libelleController.text,
                              'typeTransaction': _selectedTypeTransaction,
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Confirmer',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
