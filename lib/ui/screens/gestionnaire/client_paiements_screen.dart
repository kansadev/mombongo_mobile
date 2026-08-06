import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/ui/screens/caissier/commande_detail_screen.dart';
import 'package:mombongo/utils/commande_invoice_helper.dart';
import 'package:intl/intl.dart';
import 'package:mombongo/utils/api_error_message.dart';

class ClientPaiementsScreen extends StatefulWidget {
  final Map<String, dynamic> client;

  const ClientPaiementsScreen({super.key, required this.client});

  @override
  State<ClientPaiementsScreen> createState() => _ClientPaiementsScreenState();
}

class _ClientPaiementsScreenState extends State<ClientPaiementsScreen> {
  bool _isLoading = true;
  List<dynamic> _paiements = [];
  List<dynamic> _filteredPaiements = [];
  String _errorMessage = '';
  String _searchQuery = '';
  DateTime? _dateDebut;
  DateTime? _dateFin;
  bool _showSearch = false;
  bool _showFilters = false;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dateDebutController = TextEditingController();
  final TextEditingController _dateFinController = TextEditingController();

  // Pagination
  int _currentPage = 1;
  int _pageSize = 15;
  int _totalCount = 0;
  int _totalPages = 1;
  bool _hasNextPage = false;
  bool _hasPreviousPage = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPaiements();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dateDebutController.dispose();
    _dateFinController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadNextPage();
    }
  }

  Future<void> _loadPaiements({bool reset = false}) async {
    if (!mounted) return;

    if (reset) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
        _currentPage = 1;
        _paiements.clear();
      });
    }

    try {
      final clientId =
          int.tryParse(widget.client['idClient']?.toString() ?? '0') ?? 0;
      if (clientId == 0) {
        throw Exception('ID client invalide');
      }

      final response = await locator.apiService.getPaiementsByClient(
        clientId,
        pageNumber: _currentPage,
        pageSize: _pageSize,
        dateDebut: _dateDebut,
        dateFin: _dateFin,
      );

      if (!mounted) return;

      final newPaiements = response['data'] as List<dynamic>? ?? [];
      final totalCount = response['totalCount'] as int? ?? 0;
      final totalPages = response['totalPages'] as int? ?? 1;

      setState(() {
        if (reset) {
          _paiements = newPaiements;
        } else {
          _paiements.addAll(newPaiements);
        }

        _totalCount = totalCount;
        _totalPages = totalPages;
        _hasNextPage = _currentPage < totalPages;
        _hasPreviousPage = _currentPage > 1;
        _isLoading = false;

        _applyFilters();
      });
    } catch (e, stackTrace) {
      debugPrint('Error loading paiements: $e');
      debugPrint('Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _errorMessage = apiErrorUserMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNextPage() async {
    if (_hasNextPage && !_isLoading) {
      setState(() {
        _currentPage++;
      });
      await _loadPaiements();
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredPaiements = _paiements.where((paiement) {
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
      await _loadPaiements(reset: true);
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
      await _loadPaiements(reset: true);
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
    });
    _loadPaiements(reset: true);
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
    return _searchQuery.isNotEmpty || _dateDebut != null || _dateFin != null;
  }

  String _getActiveFiltersText() {
    final filters = <String>[];

    if (_searchQuery.isNotEmpty) {
      filters.add('Recherche: "${_searchQuery}"');
    }
    if (_dateDebut != null || _dateFin != null) {
      filters.add('Période');
    }

    return filters.isNotEmpty ? 'Filtres actifs: ${filters.join(", ")}' : '';
  }

  void _openCommandeDetail(Map<String, dynamic> paiement) {
    final idCommande = resolveIdCommandeFromPaiement(paiement);
    if (idCommande == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune commande associée à ce paiement')),
      );
      return;
    }

    Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (context) => CommandeDetailScreen(idCommande: idCommande),
      ),
    ).then((changed) {
      if (changed == true && mounted) {
        _loadPaiements(reset: true);
      }
    });
  }

  Future<void> _imprimerFacture(Map<String, dynamic> paiement) async {
    final idCommande = resolveIdCommandeFromPaiement(paiement);
    if (idCommande == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune commande associée à ce paiement')),
      );
      return;
    }
    await imprimerFactureCommande(context, idCommande);
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openCommandeDetail(paiement),
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
              if (paiement['idCommande'] != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _imprimerFacture(paiement),
                      icon: const Icon(Icons.print_outlined, size: 18),
                      label: Text(
                        'Imprimer',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clientName = widget.client['nomComplet'] ?? 'Client';

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
                'Paiements - $clientName',
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

          // Statistiques
          if (!_isLoading)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Paiements',
                      _totalCount.toString(),
                      Icons.payment,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Page',
                      '$_currentPage/$_totalPages',
                      Icons.layers,
                      Colors.green,
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
                          onPressed: () => _loadPaiements(reset: true),
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
                    onRefresh: () => _loadPaiements(reset: true),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount:
                          _filteredPaiements.length + (_hasNextPage ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _filteredPaiements.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

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

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
