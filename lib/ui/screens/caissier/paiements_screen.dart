import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:intl/intl.dart';

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
  String? _selectedStatut;
  String _searchQuery = '';
  DateTime? _dateDebut;
  DateTime? _dateFin;
  bool _showSearch = false;
  bool _showFilters = false;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dateDebutController = TextEditingController();
  final TextEditingController _dateFinController = TextEditingController();

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

  @override
  void dispose() {
    _searchController.dispose();
    _dateDebutController.dispose();
    _dateFinController.dispose();
    super.dispose();
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

      final userRole = currentUser.role.toUpperCase();
      final isGestionnaire = userRole == 'GESTIONNAIRE';
      final idSociete = int.tryParse(currentUser.idSociete) ?? 0;
      final idUser = int.tryParse(currentUser.idUtilisateur) ?? 0;

      List<dynamic> response;
      if (isGestionnaire) {
        debugPrint('Loading Paiements by societe for gestionnaire: $idSociete');
        final apiResponse = await locator.apiService.getPaiementsBySociete(
          idSociete,
        );
        response = apiResponse;
      } else {
        debugPrint('Loading Paiements for caissier: $idUser');
        final apiResponse = await locator.apiService.getPaiementsByCaissier(
          idUser,
        );
        response = apiResponse;
      }

      // API service already returns List<dynamic>, just use it directly
      final allPaiements = response;

      // Sort by date (most recent first)
      allPaiements.sort((a, b) {
        final dateA = a['datePaiement']?.toString() ?? '';
        final dateB = b['datePaiement']?.toString() ?? '';
        if (dateA.isEmpty && dateB.isEmpty) return 0;
        if (dateA.isEmpty) return 1;
        if (dateB.isEmpty) return -1;
        return dateB.compareTo(dateA); // Descending order
      });

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
    setState(() {
      _filteredPaiements = _paiements.where((paiement) {
        if (_selectedStatut != null) {
          final statut = paiement['statut']?.toString() ?? '';
          if (statut != _selectedStatut) return false;
        }

        if (_searchQuery.isNotEmpty) {
          final reference =
              paiement['referencePaiemenet']?.toString() ??
              paiement['referencePaiement']?.toString() ??
              '';
          final mode = paiement['modePaiement']?.toString() ?? '';

          if (!reference.toLowerCase().contains(_searchQuery.toLowerCase()) &&
              !mode.toLowerCase().contains(_searchQuery.toLowerCase())) {
            return false;
          }
        }

        final datePaiement = paiement['datePaiement']?.toString();
        if (datePaiement != null) {
          try {
            final date = DateTime.parse(datePaiement);

            if (_dateDebut != null && date.isBefore(_dateDebut!)) {
              return false;
            }
            if (_dateFin != null) {
              final dateFinEndOfDay = DateTime(
                _dateFin!.year,
                _dateFin!.month,
                _dateFin!.day,
                23,
                59,
                59,
              );
              if (date.isAfter(dateFinEndOfDay)) {
                return false;
              }
            }
          } catch (e) {
            // Ignorer les erreurs de parsing de date
          }
        }

        return true;
      }).toList();
    });
  }

  void _onStatutFilterChanged(String statut) {
    setState(() {
      _selectedStatut = statut == 'TOUS' ? null : statut;
    });
    _applyFilters();
  }

  Future<void> _selectDateDebut(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _dateDebut ?? DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _dateDebut) {
      setState(() {
        _dateDebut = picked;
        _dateDebutController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
      _applyFilters();
    }
  }

  Future<void> _selectDateFin(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateFin ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _dateFin) {
      setState(() {
        _dateFin = picked;
        _dateFinController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
      _applyFilters();
    }
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _dateDebut = null;
      _dateFin = null;
      _dateDebutController.clear();
      _dateFinController.clear();
      _selectedStatut = null;
    });
    _applyFilters();
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
      case 'PARTIEL':
        return Colors.blue;
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

  bool get _hasActiveFilters {
    return _searchQuery.isNotEmpty ||
        _dateDebut != null ||
        _dateFin != null ||
        _selectedStatut != null;
  }

  String _getActiveFiltersText() {
    final filters = <String>[];

    if (_searchQuery.isNotEmpty) {
      filters.add('Recherche: "$_searchQuery"');
    }
    if (_dateDebut != null || _dateFin != null) {
      filters.add('Période');
    }
    if (_selectedStatut != null) {
      filters.add('Statut: $_selectedStatut');
    }

    return filters.isNotEmpty ? 'Filtres actifs: ${filters.join(", ")}' : '';
  }

  Widget _buildPaiementCard(Map<String, dynamic> paiement) {
    final montant =
        double.tryParse(paiement['montant']?.toString() ?? '0') ?? 0;
    final mode = paiement['modePaiement']?.toString() ?? '-';
    final statut = paiement['statut']?.toString() ?? '-';
    final reference =
        paiement['referencePaiemenet']?.toString() ??
        paiement['referencePaiement']?.toString() ??
        '-';
    final date = _formatDate(paiement['datePaiement']?.toString());
    final typeTransaction = paiement['typeTransaction']?.toString() ?? '0';

    final commande = paiement['commande'] as Map<String, dynamic>?;
    final montantTotal =
        double.tryParse(commande?['montantTotal']?.toString() ?? '0') ?? 0;
    final montantPaye =
        double.tryParse(commande?['montantPaye']?.toString() ?? '0') ?? 0;
    final resteAPayer =
        double.tryParse(commande?['resteAPayer']?.toString() ?? '0') ?? 0;

    final client = commande?['client'] as Map<String, dynamic>?;
    final nomClient = client?['nom']?.toString() ?? '';
    final prenomClient = client?['prenom']?.toString() ?? '';
    final telephoneClient = client?['telephone']?.toString() ?? '';
    final nomCompletClient = '$nomClient $prenomClient'.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Action quand on clique sur la carte
        },
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
                            fontSize: 16,
                            color: const Color(0xFF2C3E50),
                          ),
                        ),
                        if (paiement['idCommande'] != null)
                          Text(
                            'Commande #${paiement['idCommande']}',
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
                      color: _getStatusColor(statut).withOpacity(0.1),
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
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    if (telephoneClient.isNotEmpty) ...[
                      Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        telephoneClient,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Mode de paiement et montant
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getModeColor(mode).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getModeIcon(mode),
                      size: 20,
                      color: _getModeColor(mode),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mode,
                          style: GoogleFonts.poppins(
                            color: _getModeColor(mode),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatCurrency(montant),
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2C3E50),
                        ),
                      ),
                      if (typeTransaction == '2')
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Paiement',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              // Détails financiers si commande associée
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
                      _buildFinancialRow(
                        'Total commande',
                        montantTotal,
                        Colors.black,
                      ),
                      const SizedBox(height: 4),
                      _buildFinancialRow(
                        'Montant payé',
                        montantPaye,
                        Colors.green,
                      ),
                      const SizedBox(height: 4),
                      _buildFinancialRow(
                        'Reste à payer',
                        resteAPayer,
                        resteAPayer > 0 ? Colors.red : Colors.green,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinancialRow(String label, double amount, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
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
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        elevation: 0,
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                  _applyFilters();
                },
                decoration: InputDecoration(
                  hintText: 'Rechercher...',
                  hintStyle: const TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _showSearch = false;
                      });
                      _applyFilters();
                    },
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              )
            : Text(
                'Paiements',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
        leading: _showSearch
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _showSearch = false;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                  _applyFilters();
                },
              )
            : null,
        actions: [
          if (!_showSearch)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Rechercher',
              onPressed: () {
                setState(() {
                  _showSearch = true;
                });
              },
            ),
          if (!_showSearch)
            IconButton(
              icon: const Icon(Icons.filter_list),
              tooltip: 'Filtres',
              onPressed: () {
                setState(() {
                  _showFilters = !_showFilters;
                });
              },
            ),
          if (!_showSearch)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Exporter PDF',
              onPressed: () {
                // TODO: Implement PDF export
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Section de filtres (affichée conditionnellement)
          if (_showFilters)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                children: [
                  // Filtres par date
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _dateDebutController,
                          readOnly: true,
                          onTap: () => _selectDateDebut(context),
                          decoration: InputDecoration(
                            labelText: 'Date début',
                            prefixIcon: const Icon(Icons.calendar_today),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _dateFinController,
                          readOnly: true,
                          onTap: () => _selectDateFin(context),
                          decoration: InputDecoration(
                            labelText: 'Date fin',
                            prefixIcon: const Icon(Icons.calendar_today),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Effacer les filtres',
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Filtres par statut
                  SingleChildScrollView(
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
                              _onStatutFilterChanged(
                                selected ? statut : 'TOUS',
                              );
                            },
                            selectedColor: const Color(
                              0xFF2C3E50,
                            ).withOpacity(0.1),
                            checkmarkColor: const Color(0xFF2C3E50),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

          // Indicateurs de filtres actifs
          if (_hasActiveFilters && !_showFilters)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF2C3E50).withOpacity(0.1),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_list,
                    size: 16,
                    color: const Color(0xFF2C3E50),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getActiveFiltersText(),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF2C3E50),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _clearFilters,
                    child: Text(
                      'Effacer',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF2C3E50),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: 1),

          // Contenu principal
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
                        if (_hasActiveFilters)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Essayez d\'ajuster vos filtres',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
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
                        return _buildPaiementCard(paiement);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
