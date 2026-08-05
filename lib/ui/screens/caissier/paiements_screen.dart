import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pdf_lib;
import 'package:printing/printing.dart';
import 'package:mombongo/services/app_currency_preference.dart';

class PaiementsScreen extends StatefulWidget {
  const PaiementsScreen({super.key});

  @override
  State<PaiementsScreen> createState() => _PaiementsScreenState();
}

class _PaiementsScreenState extends State<PaiementsScreen> {
  bool _isLoading = true;
  List<dynamic> _paiements = [];
  List<dynamic> _filteredPaiements = [];
  String _errorMessage = '';
  String? _selectedStatut; // Filter by statut

  static const List<String> _statutFilters = [
    'TOUS',
    'PAYE',
    'PARTIEL',
    'EN_ATTENTE',
    'COMPLETED',
    'ANNULE',
  ];

  @override
  void initState() {
    super.initState();
    _loadPaiements();
  }

  Future<void> _loadPaiements() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final currentUser = locator.authRepository.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      final idUser = int.tryParse(currentUser.idUtilisateur) ?? 0;
      debugPrint('Loading Paiements for caissier: $idUser');

      // Use the specific API endpoint for caissier payments
      final response = await locator.apiService.getPaiementsByCaissier(idUser);

      // Handle response format: { "data": [...] } or direct list
      List<dynamic> allPaiements = [];
      final responseData = response as dynamic;

      if (responseData is Map) {
        if (responseData.containsKey('data')) {
          final data = responseData['data'];
          if (data is List) {
            allPaiements = List<dynamic>.from(data);
          }
        }
      } else if (responseData is List) {
        allPaiements = List<dynamic>.from(responseData);
      }

      debugPrint('Paiements received from API: ${allPaiements.length}');

      if (!mounted) return;
      setState(() {
        _paiements = allPaiements;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Error loading paiements: $e');
      debugPrint('Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<dynamic> filtered = _paiements;

    // Filter by statut
    if (_selectedStatut != null && _selectedStatut != 'TOUS') {
      filtered = filtered.where((p) {
        final statut = p['statut']?.toString().toUpperCase() ?? '';
        return statut == _selectedStatut;
      }).toList();
    }

    setState(() {
      _filteredPaiements = filtered;
    });
  }

  void _onStatutFilterChanged(String? statut) {
    setState(() {
      _selectedStatut = statut;
      _applyFilters();
    });
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
      case 'PAYE':
        return Colors.green;
      case 'EN_ATTENTE':
        return Colors.orange;
      case 'ANNULE':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getModeColor(String? mode) {
    if (mode == null) return Colors.grey;
    switch (mode.toUpperCase()) {
      case 'ESPECE':
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Paiements',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Status filter chips
          Container(
            padding: const EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _statutFilters.map((statut) {
                  final isSelected =
                      _selectedStatut == statut ||
                      (_selectedStatut == null && statut == 'TOUS');
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(statut),
                      selected: isSelected,
                      onSelected: (selected) {
                        _onStatutFilterChanged(selected ? statut : 'TOUS');
                      },
                      selectedColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      checkmarkColor: Theme.of(context).colorScheme.primary,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Erreur: $_errorMessage',
                          style: GoogleFonts.poppins(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadPaiements,
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  )
                : _filteredPaiements.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payment, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun paiement trouvé',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                     onRefresh: _loadPaiements,
                     child: ListView.builder(
                       padding: const EdgeInsets.all(16),
                       itemCount: _filteredPaiements.length,
                       itemBuilder: (context, index) {
                        final paiement = Map<String, dynamic>.from(
                          _filteredPaiements[index] as Map,
                        );
                        final montant =
                            double.tryParse(
                              paiement['montant']?.toString() ?? '0',
                            ) ??
                            0;
                        final mode =
                            paiement['modePaiement']?.toString() ?? '-';
                        final statut = paiement['statut']?.toString() ?? '-';
                        final reference =
                            paiement['referencePaiemenet']?.toString() ??
                            paiement['referencePaiement']?.toString() ??
                            '-';
                        final client =
                            paiement['nomCompletClient']?.toString() ??
                            'Client';
                        final date = _formatDate(
                          paiement['datePaiement']?.toString(),
                        );
                        final agent =
                            paiement['nomCompletUtilisateur']?.toString() ??
                            '-';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              // Show details dialog
                              _showPaiementDetails(paiement);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          reference,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(
                                            statut,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                                      IconButton(
                                        tooltip: 'Imprimer',
                                        icon: const Icon(Icons.print_outlined),
                                        onPressed: () => _printPaiementReceipt(
                                          paiement,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: _getModeColor(
                                            mode,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Icon(
                                          _getModeIcon(mode),
                                          size: 16,
                                          color: _getModeColor(mode),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        mode,
                                        style: GoogleFonts.poppins(
                                          color: _getModeColor(mode),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Montant',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          Text(
                                            _formatCurrency(montant),
                                            style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Client',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          Text(
                                            client,
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Divider(height: 1, color: Colors.grey[300]),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 12,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            date,
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.person,
                                            size: 12,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            agent,
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  IconData _getModeIcon(String mode) {
    switch (mode.toUpperCase()) {
      case 'ESPECE':
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

  void _showPaiementDetails(Map<String, dynamic> paiement) {
    final montant =
        double.tryParse(paiement['montant']?.toString() ?? '0') ?? 0;
    final mode = paiement['modePaiement']?.toString() ?? '-';
    final statut = paiement['statut']?.toString() ?? '-';
    final reference =
        paiement['referencePaiemenet']?.toString() ??
        paiement['referencePaiement']?.toString() ??
        '-';
    final client = paiement['nomCompletClient']?.toString() ?? '-';
    final telephone = paiement['telephoneClient']?.toString() ?? '-';
    final email = paiement['emailClient']?.toString() ?? '-';
    final dateCommande = _formatDate(paiement['dateCommande']?.toString());
    final libelle = paiement['libelle']?.toString() ?? '-';
    final agent = paiement['nomCompletUtilisateur']?.toString() ?? '-';
    final site = paiement['nomSite']?.toString() ?? '-';
    final idPaiement = paiement['idPaiement']?.toString() ?? '-';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                Text(
                  'Détails du paiement',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _buildDetailRow('ID Paiement', idPaiement),
                _buildDetailRow('Référence', reference),
                _buildDetailRow('Libellé', libelle),
                _buildDetailRow(
                  'Montant',
                  _formatCurrency(montant),
                  isHighlighted: true,
                ),
                _buildDetailRow('Mode de paiement', mode),
                _buildDetailRow(
                  'Statut',
                  statut,
                  color: _getStatusColor(statut),
                ),
                const Divider(height: 32),
                Text(
                  'Informations client',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDetailRow('Nom complet', client),
                _buildDetailRow('Téléphone', telephone),
                _buildDetailRow('Email', email),
                const Divider(height: 32),
                Text(
                  'Informations supplémentaires',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDetailRow('Date commande', dateCommande),
                _buildDetailRow('Agent', agent),
                _buildDetailRow('Site', site),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _printPaiementReceipt(Map<String, dynamic> paiement) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Génération du reçu...'),
            ],
          ),
        );
      },
    );

    try {
      final pdf = pdf_lib.Document();
      final currentUser = locator.authRepository.currentUser;

      final montant =
          double.tryParse(paiement['montant']?.toString() ?? '0') ?? 0;
      final mode = paiement['modePaiement']?.toString() ?? '-';
      final statut = paiement['statut']?.toString() ?? '-';
      final reference =
          paiement['referencePaiement']?.toString() ??
          paiement['referencePaiemenet']?.toString() ??
          '-';
      final client = paiement['nomCompletClient']?.toString() ?? 'Client';
      final telephone = paiement['telephoneClient']?.toString() ?? '-';
      final email = paiement['emailClient']?.toString() ?? '';
      final datePaiementStr =
          paiement['datePaiement']?.toString() ??
          paiement['dateCommande']?.toString();
      final agent =
          paiement['nomCompletUtilisateur']?.toString() ??
          currentUser?.nomComplet ??
          '-';
      final site = paiement['nomSite']?.toString() ?? currentUser?.nomSite ?? '-';

      final totalAmount = double.tryParse(
            (paiement['total'] ??
                    paiement['montantTotal'] ??
                    paiement['montantCommande'] ??
                    paiement['montantFacture'] ??
                    paiement['montantVente'])
                ?.toString() ??
                '',
          ) ??
          0.0;
      final remaining = totalAmount > 0
          ? (totalAmount - montant).clamp(0.0, double.infinity).toDouble()
          : 0.0;

      // Get currency preference
      final currencyCode = AppCurrencyPreference.readCode(
        locator.databaseService,
      );
      final currencyFormat = AppCurrencyPreference.formatterFor(currencyCode);
      final currencySymbol = AppCurrencyPreference.symbolFor(currencyCode);

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
          build: (context) => [
            pdf_lib.Column(
              crossAxisAlignment: pdf_lib.CrossAxisAlignment.stretch,
              children: [
                _buildReceiptHeader(currentUser, site),
                _buildReceiptInfo(reference, datePaiementStr, agent),
                _buildReceiptPaymentInfo(
                  client: client,
                  telephone: telephone,
                  email: email,
                  mode: mode,
                  statut: statut,
                  currencySymbol: currencySymbol,
                  currencyFormat: currencyFormat,
                  montantPaye: montant,
                  totalAmount: totalAmount > 0 ? totalAmount : null,
                  remaining: remaining > 0 ? remaining : null,
                  reference: reference,
                ),
                _buildReceiptFooter(),
              ],
            ),
          ],
        ),
      );

      Navigator.of(context, rootNavigator: true).pop();
      
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la génération du reçu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  pdf_lib.Widget _buildReceiptHeader(dynamic user, String siteName) {
    final companyName = user?.nomSociete ?? 'KANSA BUSINESS';
    final address = user?.adresseSite ?? '';
    final phone = user?.contact ?? '';

    return pdf_lib.Column(
      crossAxisAlignment: pdf_lib.CrossAxisAlignment.center,
      children: [
        pdf_lib.Center(
          child: pdf_lib.Text(
            companyName,
            style: pdf_lib.TextStyle(
              fontSize: 10,
              fontWeight: pdf_lib.FontWeight.bold,
            ),
            textAlign: pdf_lib.TextAlign.center,
          ),
        ),
        pdf_lib.SizedBox(height: 3),
        pdf_lib.Center(
          child: pdf_lib.Text(
            siteName,
            style: pdf_lib.TextStyle(
              fontSize: 9,
              fontWeight: pdf_lib.FontWeight.bold,
            ),
            textAlign: pdf_lib.TextAlign.center,
          ),
        ),
        if (address.isNotEmpty) ...[
          pdf_lib.SizedBox(height: 3),
          pdf_lib.Center(
            child: pdf_lib.Text(
              address,
              style: const pdf_lib.TextStyle(fontSize: 8),
              textAlign: pdf_lib.TextAlign.center,
            ),
          ),
        ],
        if (phone.isNotEmpty) ...[
          pdf_lib.SizedBox(height: 3),
          pdf_lib.Center(
            child: pdf_lib.Text(
              phone,
              style: const pdf_lib.TextStyle(fontSize: 8),
              textAlign: pdf_lib.TextAlign.center,
            ),
          ),
        ],
        pdf_lib.SizedBox(height: 5),
        pdf_lib.Center(child: pdf_lib.Divider()),
        pdf_lib.SizedBox(height: 4),
      ],
    );
  }

  pdf_lib.Widget _buildReceiptInfo(
    String reference,
    String? datePaiementStr,
    String agentName,
  ) {
    DateTime ts;
    if (datePaiementStr == null) {
      ts = DateTime.now();
    } else {
      try {
        ts = DateTime.parse(datePaiementStr);
      } catch (_) {
        ts = DateTime.now();
      }
    }

    final dateStr = DateFormat('dd/MM/yyyy').format(ts);
    final timeStr = DateFormat('HH:mm').format(ts);

    return pdf_lib.Column(
      crossAxisAlignment: pdf_lib.CrossAxisAlignment.center,
      children: [
        pdf_lib.Center(
          child: pdf_lib.Text(
            'Ref: $reference',
            style: pdf_lib.TextStyle(
              fontSize: 9,
              fontWeight: pdf_lib.FontWeight.bold,
            ),
            textAlign: pdf_lib.TextAlign.center,
          ),
        ),
        pdf_lib.SizedBox(height: 3),
        pdf_lib.Center(
          child: pdf_lib.Text(
            'Date: $dateStr $timeStr',
            style: const pdf_lib.TextStyle(fontSize: 8),
            textAlign: pdf_lib.TextAlign.center,
          ),
        ),
        pdf_lib.SizedBox(height: 3),
        pdf_lib.Center(
          child: pdf_lib.Text(
            'Agent: $agentName',
            style: const pdf_lib.TextStyle(fontSize: 8),
            textAlign: pdf_lib.TextAlign.center,
          ),
        ),
        pdf_lib.SizedBox(height: 5),
      ],
    );
  }

  pdf_lib.Widget _buildReceiptPaymentInfo({
    required String client,
    required String telephone,
    required String email,
    required String mode,
    required String statut,
    required String currencySymbol,
    required NumberFormat currencyFormat,
    required double montantPaye,
    required double? totalAmount,
    required double? remaining,
    required String reference,
  }) {
    final formattedPaid = '$currencySymbol${currencyFormat.format(montantPaye)}';
    final formattedTotal = totalAmount == null
        ? null
        : '$currencySymbol${currencyFormat.format(totalAmount)}';
    final formattedRemaining = remaining == null
        ? null
        : '$currencySymbol${currencyFormat.format(remaining)}';

    return pdf_lib.Column(
      crossAxisAlignment: pdf_lib.CrossAxisAlignment.start,
      children: [
        if (client.isNotEmpty) ...[
          pdf_lib.Text(
            'CLIENT:',
            style: pdf_lib.TextStyle(
              fontSize: 8,
              fontWeight: pdf_lib.FontWeight.bold,
            ),
            textAlign: pdf_lib.TextAlign.left,
          ),
          pdf_lib.SizedBox(height: 3),
          _buildReceiptRow('Nom:', client, boldValue: true),
          if (telephone.isNotEmpty && telephone != '-') ...[
            _buildReceiptRow('Tel:', telephone),
          ],
          if (email.isNotEmpty && email != '-') ...[
            _buildReceiptRow('Email:', email),
          ],
          pdf_lib.SizedBox(height: 4),
        ],
        pdf_lib.Text(
          'PAIEMENT:',
          style: pdf_lib.TextStyle(
            fontSize: 8,
            fontWeight: pdf_lib.FontWeight.bold,
          ),
          textAlign: pdf_lib.TextAlign.left,
        ),
        pdf_lib.SizedBox(height: 3),
        _buildReceiptRow('Mode:', mode, boldValue: true),
        _buildReceiptRow('Montant payé:', formattedPaid, boldValue: true),
        if (formattedTotal != null) ...[
          _buildReceiptRow('Total:', formattedTotal),
        ],
        if (formattedRemaining != null) ...[
          _buildReceiptRow(
            'Reste à payer:',
            formattedRemaining,
            boldValue: true,
          ),
        ],
        if (statut.isNotEmpty && statut != '-') ...[
          _buildReceiptRow('Statut:', statut),
        ],
        _buildReceiptRow('Ref:', reference),
        pdf_lib.SizedBox(height: 4),
        pdf_lib.Divider(),
        pdf_lib.SizedBox(height: 3),
      ],
    );
  }

  pdf_lib.Widget _buildReceiptFooter() {
    return pdf_lib.Column(
      crossAxisAlignment: pdf_lib.CrossAxisAlignment.center,
      children: [
        pdf_lib.SizedBox(height: 3),
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
        pdf_lib.SizedBox(height: 6),
      ],
    );
  }

  pdf_lib.Widget _buildReceiptRow(
    String label,
    String value, {
    bool boldValue = false,
  }) {
    return pdf_lib.Padding(
      padding: const pdf_lib.EdgeInsets.symmetric(vertical: 2),
      child: pdf_lib.Row(
        mainAxisAlignment: pdf_lib.MainAxisAlignment.spaceBetween,
        children: [
          pdf_lib.Text(label, style: const pdf_lib.TextStyle(fontSize: 7)),
          pdf_lib.Text(
            value,
            style: pdf_lib.TextStyle(
              fontSize: 7,
              fontWeight:
                  boldValue ? pdf_lib.FontWeight.bold : pdf_lib.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    Color? color,
    bool isHighlighted = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
                color: color ?? Colors.black87,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
