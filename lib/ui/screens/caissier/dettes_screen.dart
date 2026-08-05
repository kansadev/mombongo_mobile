import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:intl/intl.dart';
import 'package:mombongo/ui/screens/caissier/dettes_statistiques_screen.dart';

class DettesScreen extends StatefulWidget {
  /// Si true (admin), filtre les dettes sur le site opérationnel courant.
  final bool filterByOperationalSite;

  const DettesScreen({super.key, this.filterByOperationalSite = false});

  @override
  State<DettesScreen> createState() => _DettesScreenState();
}

class _DettesScreenState extends State<DettesScreen> {
  bool _isLoading = true;
  List<dynamic> _dettes = [];
  List<dynamic> _filteredDettes = [];
  String _errorMessage = '';
  String? _selectedStatut;
  Map<String, Map<String, dynamic>> _commandesCache = {};
  Map<String, Map<String, dynamic>> _clientsCache = {};

  static const List<String> _statutFilters = [
    'TOUS',
    'PARTIEL',
    'EN_ATTENTE',
    'PAYE',
  ];

  @override
  void initState() {
    super.initState();
    _loadDettes();
  }

  Future<void> _loadDettes() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _commandesCache.clear();
      _clientsCache.clear();
    });

    try {
      final response = await locator.apiService.getAvanceAcompte();

      // Handle response format: { "data": [...] } or direct list
      List<dynamic> allDettes = [];
      final responseData = response as dynamic;

      if (responseData is Map) {
        if (responseData.containsKey('data')) {
          final data = responseData['data'];
          if (data is List) {
            allDettes = List<dynamic>.from(data);
          }
        }
      } else if (responseData is List) {
        allDettes = List<dynamic>.from(responseData);
      }

      debugPrint('Dettes received from API: ${allDettes.length}');

      // Charger les détails des commandes et clients
      await _loadDetailsForDettes(allDettes);

      if (widget.filterByOperationalSite) {
        final idSite =
            int.tryParse(locator.authRepository.currentUser?.idSite ?? '') ?? 0;
        if (idSite > 0) {
          allDettes = allDettes.where((dette) {
            if (dette is! Map) return false;

            final detteSite = dette['idSite'] ??
                dette['IdSite'] ??
                dette['siteId'] ??
                dette['id_site'];
            if (detteSite != null) {
              return int.tryParse(detteSite.toString()) == idSite;
            }

            final idCommande = dette['idCommande']?.toString();
            if (idCommande == null) return false;
            final cmd = _commandesCache[idCommande];
            if (cmd == null) return false;
            final cmdSite = cmd['idSite'] ?? cmd['IdSite'] ?? cmd['siteId'];
            return int.tryParse(cmdSite?.toString() ?? '') == idSite;
          }).toList();
          debugPrint('Dettes filtrées site $idSite: ${allDettes.length}');
        }
      }

      if (!mounted) return;
      setState(() {
        _dettes = allDettes;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Error loading dettes: $e');
      debugPrint('Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDetailsForDettes(List<dynamic> dettes) async {
    for (final dette in dettes) {
      final idCommande = dette['idCommande'] as int?;
      final idClient = dette['idClient'] as int?;

      // Charger les détails de la commande
      if (idCommande != null && !_commandesCache.containsKey(idCommande.toString())) {
        try {
          final commande = await locator.apiService.getCommandeById(idCommande);
          _commandesCache[idCommande.toString()] = commande;
        } catch (e) {
          debugPrint('Error loading commande $idCommande: $e');
        }
      }

      // Charger les détails du client
      if (idClient != null && !_clientsCache.containsKey(idClient.toString())) {
        try {
          final client = await locator.apiService.getClientById(idClient);
          _clientsCache[idClient.toString()] = client;
        } catch (e) {
          debugPrint('Error loading client $idClient: $e');
        }
      }
    }
  }

  void _applyFilters() {
    List<dynamic> filtered = _dettes;

    // Filter by statut
    if (_selectedStatut != null && _selectedStatut != 'TOUS') {
      filtered = filtered.where((d) {
        final statut = d['statut']?.toString().toUpperCase() ?? '';
        return statut == _selectedStatut;
      }).toList();
    }

    setState(() {
      _filteredDettes = filtered;
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
      case 'PARTIEL':
        return Colors.orange;
      case 'EN_ATTENTE':
        return Colors.red;
      case 'PAYE':
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

  Widget _buildFinancialRow(String label, double amount, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        Text(
          _formatCurrency(amount),
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
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
          'Dettes & Acomptes',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Statistiques',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DettesStatistiquesScreen(),
                ),
              );
            },
          ),
        ],
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
                          onPressed: _loadDettes,
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  )
                : _filteredDettes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance_wallet, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune dette trouvée',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadDettes,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredDettes.length,
                      itemBuilder: (context, index) {
                        final dette = Map<String, dynamic>.from(
                          _filteredDettes[index] as Map,
                        );
                        final montant =
                            double.tryParse(
                              dette['montant']?.toString() ?? '0',
                            ) ??
                            0;
                        final mode =
                            dette['modePaiement']?.toString() ?? '-';
                        final statut = dette['statut']?.toString() ?? '-';
                        final reference =
                            dette['referencePaiemenet']?.toString() ??
                            dette['referencePaiement']?.toString() ??
                            '-';
                        final libelle = dette['libelle']?.toString() ?? '-';
                        final date = _formatDate(
                          dette['datePaiement']?.toString(),
                        );
                        final typeTransaction = dette['typeTransaction']?.toString() ?? '0';
                        
                        // Récupérer les détails de la commande
                        final idCommande = dette['idCommande']?.toString();
                        final commande = idCommande != null ? _commandesCache[idCommande] : null;
                        final montantTotal = double.tryParse(commande?['montantTotal']?.toString() ?? '0') ?? 0;
                        final montantPaye = double.tryParse(commande?['montantPaye']?.toString() ?? '0') ?? 0;
                        final resteAPayer = double.tryParse(commande?['resteAPayer']?.toString() ?? '0') ?? 0;
                        final statutCommande = commande?['statut']?.toString() ?? '';
                        
                        // Récupérer les détails du client
                        final idClient = dette['idClient']?.toString();
                        final client = idClient != null ? _clientsCache[idClient] : null;
                        final nomClient = client?['nom']?.toString() ?? '';
                        final prenomClient = client?['prenom']?.toString() ?? '';
                        final telephoneClient = client?['telephone']?.toString() ?? '';
                        final nomCompletClient = '$nomClient $prenomClient'.trim();

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // En-tête avec référence et statut
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
                                              fontSize: 14,
                                            ),
                                          ),
                                          if (idCommande != null)
                                            Text(
                                              'Commande #$idCommande',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                        ],
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
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  libelle,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                
                                // Mode de paiement et type transaction
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
                                    const Spacer(),
                                    if (typeTransaction == '1')
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Acompte',
                                          style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            color: Colors.blue,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    if (statutCommande.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.purple.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          statutCommande,
                                          style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            color: Colors.purple,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                
                                // Détails financiers
                                if (montantTotal > 0) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey[200]!),
                                    ),
                                    child: Column(
                                      children: [
                                        _buildFinancialRow('Total', montantTotal, Colors.black),
                                        const SizedBox(height: 4),
                                        _buildFinancialRow('Payé', montantPaye, Colors.green),
                                        const SizedBox(height: 4),
                                        _buildFinancialRow('Reste', resteAPayer, 
                                            resteAPayer > 0 ? Colors.red : Colors.green),
                                      ],
                                    ),
                                  ),
                                ] else ...[
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
                                              color: Colors.orange[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                                
                                const SizedBox(height: 12),
                                Divider(height: 1, color: Colors.grey[300]),
                                const SizedBox(height: 12),
                                
                                // Informations client
                                if (nomCompletClient.isNotEmpty) ...[
                                  Row(
                                    children: [
                                      Icon(Icons.person, size: 16, color: Colors.grey[600]),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          nomCompletClient,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      if (telephoneClient.isNotEmpty)
                                        Row(
                                          children: [
                                            Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                                            const SizedBox(width: 4),
                                            Text(
                                              telephoneClient,
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ] else ...[
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
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
                                ],
                              ],
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
}
