import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:intl/intl.dart';
import 'package:mombongo/ui/screens/caissier/annuler_vente_screen.dart';
import 'package:mombongo/ui/screens/caissier/commande_detail_screen.dart';

enum _VuePaiements {
  /// Par défaut : masque annulés et remboursés
  sansAnnules,

  /// Uniquement annulés / remboursés
  annulesRembourses,

  /// Tout l'historique
  tous,
}

class PaiementsScreen extends StatefulWidget {
  const PaiementsScreen({super.key});

  @override
  State<PaiementsScreen> createState() => _PaiementsScreenState();
}

class _PaiementsScreenState extends State<PaiementsScreen> {
  bool _isLoading = true;
  bool _isLoadingMore = false;
  List<dynamic> _paiements = [];
  List<dynamic> _filteredPaiements = [];
  String _errorMessage = '';
  String _searchQuery = '';
  bool _showSearch = false;
  _VuePaiements _vuePaiements = _VuePaiements.sansAnnules;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// Caissier : /api/Paiements/caissier/{id} · Gestionnaire : /api/Paiements/site/{id}
  bool _serverPagination = false;
  int _currentPage = 1;
  int _totalPages = 1;
  final int _pageSize = 20;
  int _totalCount = 0;
  bool _hasMorePages = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadPaiements();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_serverPagination || !_scrollController.hasClients) return;
    if (_isLoadingMore || !_hasMorePages || _isLoading) return;

    final position = _scrollController.position;
    // Liste plus courte que l’écran : maxScrollExtent ≈ 0 → on ne peut pas défiler
    if (position.maxScrollExtent <= 0) return;

    if (position.pixels >= position.maxScrollExtent - 200) {
      _loadMorePaiements();
    }
  }

  int _parsePaginationInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString()) ?? fallback;
  }

  Future<void> _loadMorePaiements() async {
    if (!mounted || !_serverPagination || _isLoadingMore || !_hasMorePages) {
      return;
    }

    setState(() => _isLoadingMore = true);

    try {
      final currentUser = locator.authRepository.currentUser;
      if (currentUser == null) throw Exception('Utilisateur non connecté');

      final idUser = int.tryParse(currentUser.idUtilisateur) ?? 0;
      final idSite = int.tryParse(currentUser.idSite) ?? 0;
      final userRole = currentUser.role.toUpperCase();
      final isGestionnaire = userRole == 'GESTIONNAIRE';

      final nextPage = _currentPage + 1;

      final Map<String, dynamic> apiResponse;
      if (isGestionnaire) {
        if (idSite == 0) throw Exception('Site invalide');
        apiResponse = await locator.apiService.getPaiementsBySite(
          idSite,
          pageNumber: nextPage,
          pageSize: _pageSize,
        );
      } else {
        apiResponse = await locator.apiService.getPaiementsByCaissier(
          idUser,
          pageNumber: nextPage,
          pageSize: _pageSize,
        );
      }

      final data = apiResponse['data'];
      List<dynamic> newItems = [];
      if (data is List) {
        newItems = List<dynamic>.from(data);
      }

      if (!mounted) return;

      if (newItems.isEmpty) {
        setState(() {
          _hasMorePages = false;
          _isLoadingMore = false;
        });
        return;
      }

      newItems.sort((a, b) {
        final dateA = a['datePaiement']?.toString() ?? '';
        final dateB = b['datePaiement']?.toString() ?? '';
        if (dateA.isEmpty && dateB.isEmpty) return 0;
        if (dateA.isEmpty) return 1;
        if (dateB.isEmpty) return -1;
        return dateB.compareTo(dateA);
      });

      setState(() {
        _currentPage = nextPage;
        _paiements = [..._paiements, ...newItems];
        _totalPages = _parsePaginationInt(apiResponse['totalPages'], 1);
        _totalCount = _parsePaginationInt(apiResponse['totalCount'], _paiements.length);
        final hasNext = apiResponse['hasNextPage'];
        _hasMorePages = hasNext is bool
            ? hasNext
            : nextPage < _totalPages;
        _isLoadingMore = false;
      });
      _applyFilters();
    } catch (e) {
      debugPrint('Error loading more paiements: $e');
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
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
      final idUser = int.tryParse(currentUser.idUtilisateur) ?? 0;
      final idSite = int.tryParse(currentUser.idSite) ?? 0;

      List<dynamic> allPaiements;
      if (isGestionnaire) {
        if (idSite == 0) {
          throw Exception('Site invalide : impossible de charger les paiements');
        }
        _serverPagination = true;
        debugPrint('Loading Paiements by site for gestionnaire: $idSite (page 1)');
        _currentPage = 1;
        _totalPages = 1;
        _hasMorePages = true;

        final apiResponse = await locator.apiService.getPaiementsBySite(
          idSite,
          pageNumber: 1,
          pageSize: _pageSize,
        );

        final data = apiResponse['data'];
        allPaiements = data is List ? List<dynamic>.from(data) : [];

        _totalPages = _parsePaginationInt(apiResponse['totalPages'], 1);
        _totalCount = _parsePaginationInt(
          apiResponse['totalCount'],
          allPaiements.length,
        );
        final hasNext = apiResponse['hasNextPage'];
        _hasMorePages = hasNext is bool ? hasNext : _currentPage < _totalPages;
        _currentPage = _parsePaginationInt(apiResponse['pageNumber'], 1);
      } else {
        _serverPagination = true;
        debugPrint('Loading Paiements for caissier: $idUser (page 1)');
        _currentPage = 1;
        _totalPages = 1;
        _hasMorePages = true;

        final apiResponse = await locator.apiService.getPaiementsByCaissier(
          idUser,
          pageNumber: 1,
          pageSize: _pageSize,
        );

        final data = apiResponse['data'];
        allPaiements = data is List ? List<dynamic>.from(data) : [];

        _totalPages = _parsePaginationInt(apiResponse['totalPages'], 1);
        _totalCount = _parsePaginationInt(
          apiResponse['totalCount'],
          allPaiements.length,
        );
        final hasNext = apiResponse['hasNextPage'];
        _hasMorePages = hasNext is bool ? hasNext : _currentPage < _totalPages;
        _currentPage = _parsePaginationInt(apiResponse['pageNumber'], 1);
      }

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

  bool _isPaiementAnnuleOuRembourse(Map<String, dynamic> m) {
    final s = (m['statut']?.toString() ?? '').toUpperCase().trim();
    return s.contains('ANNULE') || s.contains('REMBOURS');
  }

  void _applyFilters() {
    setState(() {
      _filteredPaiements = _paiements.where((raw) {
        final map = raw is Map<String, dynamic>
            ? raw
            : Map<String, dynamic>.from(raw as Map);

        if (_searchQuery.isNotEmpty) {
          final reference =
              map['referencePaiemenet']?.toString() ??
              map['referencePaiement']?.toString() ??
              '';
          final mode = map['modePaiement']?.toString() ?? '';

          if (!reference.toLowerCase().contains(_searchQuery.toLowerCase()) &&
              !mode.toLowerCase().contains(_searchQuery.toLowerCase())) {
            return false;
          }
        }

        final annuleOuRem = _isPaiementAnnuleOuRembourse(map);
        switch (_vuePaiements) {
          case _VuePaiements.sansAnnules:
            if (annuleOuRem) return false;
            break;
          case _VuePaiements.annulesRembourses:
            if (!annuleOuRem) return false;
            break;
          case _VuePaiements.tous:
            break;
        }

        return true;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _vuePaiements = _VuePaiements.sansAnnules;
    });
    _applyFilters();
  }

  void _onVuePaiementsChanged(_VuePaiements vue) {
    setState(() => _vuePaiements = vue);
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
        _vuePaiements != _VuePaiements.sansAnnules;
  }

  String _getActiveFiltersText() {
    final filters = <String>[];

    if (_searchQuery.isNotEmpty) {
      filters.add('Recherche: "$_searchQuery"');
    }
    switch (_vuePaiements) {
      case _VuePaiements.sansAnnules:
        break;
      case _VuePaiements.annulesRembourses:
        filters.add('Vue: annulés / remboursés');
        break;
      case _VuePaiements.tous:
        filters.add('Vue: tous les paiements');
        break;
    }

    return filters.isNotEmpty ? 'Filtres actifs: ${filters.join(", ")}' : '';
  }

  Future<void> _annulerVenteFromPaiement(Map<String, dynamic> paiement) async {
    final commande = paiement['commande'] as Map<String, dynamic>?;
    final idCommande =
        int.tryParse(paiement['idCommande']?.toString() ?? '') ??
        int.tryParse(commande?['idCommande']?.toString() ?? '');
    if (idCommande == null || idCommande == 0) return;

    final venteForAnnulation = <String, dynamic>{
      'idCommande': idCommande,
      'libelle': commande?['libelle']?.toString() ?? 'Commande #$idCommande',
      'quantite':
          int.tryParse(commande?['quantite']?.toString() ?? '') ??
          int.tryParse(paiement['quantite']?.toString() ?? '') ??
          0,
      'total':
          double.tryParse(commande?['montantTotal']?.toString() ?? '') ??
          double.tryParse(paiement['montant']?.toString() ?? '') ??
          0.0,
      'prixUnitaire':
          double.tryParse(commande?['prixUnitaire']?.toString() ?? '') ??
          double.tryParse(paiement['montant']?.toString() ?? '') ??
          0.0,
    };

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnnulerVenteScreen(vente: venteForAnnulation),
      ),
    );

    if (result == true && mounted) {
      _loadPaiements();
    }
  }

  void _openCommandeDetail(Map<String, dynamic> paiement) {
    final commande = paiement['commande'] as Map<String, dynamic>?;
    final idFromPaiement = int.tryParse(
      paiement['idCommande']?.toString() ?? '',
    );
    final idFromCmd = int.tryParse(commande?['idCommande']?.toString() ?? '');
    final idCommande = idFromPaiement ?? idFromCmd ?? 0;

    if (idCommande == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune commande associée à ce paiement')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => CommandeDetailScreen(idCommande: idCommande),
      ),
    );
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
    final isAnnuleOuRembourse = _isPaiementAnnuleOuRembourse(paiement);

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

    return Opacity(
      opacity: isAnnuleOuRembourse ? 0.6 : 1.0,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 3,
        color: isAnnuleOuRembourse ? Colors.grey[200] : null,
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

                // Informations client
                if (nomCompletClient.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.person, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Text(
                          nomCompletClient,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                      if (telephoneClient.isNotEmpty) ...[
                        Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Flexible(
                          flex: 1,
                          child: Text(
                            telephoneClient,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
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
                if ((paiement['idCommande'] != null || commande != null) &&
                    !isAnnuleOuRembourse) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _annulerVenteFromPaiement(paiement),
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: Text(
                          'Annuler',
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red[400],
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationFooter() {
    final loaded = _paiements.length;
    final summary =
        '$_totalCount au total · pages $_currentPage/$_totalPages · $loaded chargé(s)';

    return Material(
      elevation: 6,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  summary,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_hasMorePages)
                TextButton.icon(
                  onPressed:
                      _isLoadingMore ? null : () => _loadMorePaiements(),
                  icon: _isLoadingMore
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: const Color(0xFF2C3E50),
                          ),
                        )
                      : const Icon(Icons.expand_more, size: 20),
                  label: Text(
                    _isLoadingMore ? 'Chargement…' : 'Charger la suite',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2C3E50),
                  ),
                ),
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
          // Indicateurs de filtres actifs (recherche / affichage)
          if (_hasActiveFilters)
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

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Affichage',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                SegmentedButton<_VuePaiements>(
                  segments: const [
                    ButtonSegment<_VuePaiements>(
                      value: _VuePaiements.sansAnnules,
                      label: Text('Non remboursés'),
                      tooltip:
                          'Paiements non annulés et non remboursés (par défaut)',
                    ),
                    ButtonSegment<_VuePaiements>(
                      value: _VuePaiements.annulesRembourses,
                      label: Text('Remboursés'),
                      tooltip: 'Uniquement les paiements annulés ou remboursés',
                    ),
                    ButtonSegment<_VuePaiements>(
                      value: _VuePaiements.tous,
                      label: Text('Tous'),
                      tooltip: 'Tout l’historique',
                    ),
                  ],
                  selected: {_vuePaiements},
                  onSelectionChanged: (Set<_VuePaiements> next) {
                    if (next.isEmpty) return;
                    _onVuePaiementsChanged(next.first);
                  },
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
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
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

          if (_serverPagination &&
              !_isLoading &&
              _errorMessage.isEmpty &&
              _paiements.isNotEmpty)
            _buildPaginationFooter(),
        ],
      ),
    );
  }
}
