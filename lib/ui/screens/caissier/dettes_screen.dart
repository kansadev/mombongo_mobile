import 'package:flutter/material.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:intl/intl.dart';
import 'package:mombongo/ui/screens/caissier/dettes_statistiques_screen.dart';
import 'package:mombongo/ui/screens/caissier/dette_detail_screen.dart';
import 'package:mombongo/utils/google_fonts_compat.dart';
import 'package:mombongo/utils/api_error_message.dart';

class DettesScreen extends StatefulWidget {
  const DettesScreen({super.key});

  @override
  State<DettesScreen> createState() => _DettesScreenState();
}

class _DettesScreenState extends State<DettesScreen> {
  List<dynamic> _dettes = [];
  List<dynamic> _filteredDettes = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
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
  final Map<String, dynamic> _commandesCache = {};
  final Map<String, dynamic> _clientsCache = {};

  // Pagination
  int _currentPage = 1;
  int _totalPages = 1;
  int _pageSize = 15;
  bool _hasMorePages = true;
  final ScrollController _scrollController = ScrollController();

  final List<String> _statutFilters = [
    'TOUS',
    'PARTIEL',
    'COMPLET',
    'EN_ATTENTE',
    'ANNULE',
  ];

  @override
  void initState() {
    super.initState();
    _loadDettes();
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
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMorePages && !_isLoading) {
        _loadMoreDettes();
      }
    }
  }

  Future<void> _loadDettes() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _commandesCache.clear();
      _clientsCache.clear();
      _currentPage = 1;
      _totalPages = 1;
      _hasMorePages = true;
    });

    try {
      // Récupérer les informations de l'utilisateur connecté
      final currentUser = locator.authRepository.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      final idSociete = int.tryParse(currentUser.idSociete) ?? 0;
      final idSite = int.tryParse(currentUser.idSite) ?? 0;
      final userRole = currentUser.role.toUpperCase();
      final isGestionnaire = userRole == 'GESTIONNAIRE';
      final idUtilisateur = isGestionnaire
          ? null
          : int.tryParse(currentUser.idUtilisateur);

      if (idSociete == 0 || idSite == 0) {
        throw Exception('Informations utilisateur invalides');
      }

      debugPrint('=== CHARGEMENT DETTES ===');
      debugPrint('ID Société: $idSociete');
      debugPrint('ID Site: $idSite');
      debugPrint('ID Utilisateur: $idUtilisateur');

      final response = await locator.apiService.getAvanceAcompte(
        idSociete: idSociete,
        idSite: idSite,
        idUtilisateur: idUtilisateur,
        pageNumber: 1,
        pageSize: _pageSize,
      );

      // Handle response format: { "data": [...] } or { "avancesAcomptes": [...] }
      List<dynamic> allDettes = [];
      final responseData = response as dynamic;

      if (responseData is Map) {
        // Check for "data" key first (new format with pagination)
        if (responseData.containsKey('data')) {
          final data = responseData['data'];
          if (data is List) {
            allDettes = List<dynamic>.from(data);
          }
          // Extract pagination info
          _totalPages = responseData['totalPages'] as int? ?? 1;
          _hasMorePages = responseData['hasNextPage'] as bool? ?? false;
          _currentPage = responseData['pageNumber'] as int? ?? 1;
        }
        // Check for "avancesAcomptes" key (old format)
        else if (responseData.containsKey('avancesAcomptes')) {
          final data = responseData['avancesAcomptes'];
          if (data is List) {
            allDettes = List<dynamic>.from(data);
          }
        }
      } else if (responseData is List) {
        allDettes = List<dynamic>.from(responseData);
      }

      // Sort by date (most recent first)
      allDettes.sort((a, b) {
        final dateA = a['datePaiement']?.toString() ?? '';
        final dateB = b['datePaiement']?.toString() ?? '';
        if (dateA.isEmpty && dateB.isEmpty) return 0;
        if (dateA.isEmpty) return 1;
        if (dateB.isEmpty) return -1;
        return dateB.compareTo(dateA); // Descending order
      });

      debugPrint(
        'Dettes received from API: ${allDettes.length}, page $_currentPage/$_totalPages',
      );

      // Charger les détails des commandes et clients
      await _loadDetailsForDettes(allDettes);

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
        _errorMessage = apiErrorUserMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreDettes() async {
    if (!mounted || _isLoadingMore || !_hasMorePages) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final currentUser = locator.authRepository.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      final idSociete = int.tryParse(currentUser.idSociete) ?? 0;
      final idSite = int.tryParse(currentUser.idSite) ?? 0;
      final userRole = currentUser.role.toUpperCase();
      final isGestionnaire = userRole == 'GESTIONNAIRE';
      final idUtilisateur = isGestionnaire
          ? null
          : int.tryParse(currentUser.idUtilisateur);

      final nextPage = _currentPage + 1;
      final response = await locator.apiService.getAvanceAcompte(
        idSociete: idSociete,
        idSite: idSite,
        idUtilisateur: idUtilisateur,
        pageNumber: nextPage,
        pageSize: _pageSize,
      );

      List<dynamic> newDettes = [];
      final responseData = response as dynamic;

      if (responseData is Map) {
        if (responseData.containsKey('data')) {
          final data = responseData['data'];
          if (data is List) {
            newDettes = List<dynamic>.from(data);
          }
        } else if (responseData.containsKey('avancesAcomptes')) {
          final data = responseData['avancesAcomptes'];
          if (data is List) {
            newDettes = List<dynamic>.from(data);
          }
        }
      }

      if (newDettes.isEmpty) {
        setState(() {
          _hasMorePages = false;
          _isLoadingMore = false;
        });
        return;
      }

      await _loadDetailsForDettes(newDettes);

      if (!mounted) return;
      setState(() {
        _currentPage = nextPage;
        _dettes = [..._dettes, ...newDettes];
        _applyFilters();

        final totalPages = responseData is Map
            ? responseData['totalPages'] as int? ?? 1
            : 1;
        _totalPages = totalPages;
        _hasMorePages = nextPage < totalPages;
        _isLoadingMore = false;
      });

      debugPrint('Loaded more dettes: page $nextPage, total ${_dettes.length}');
    } catch (e) {
      debugPrint('Error loading more dettes: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadDetailsForDettes(List<dynamic> deudas) async {
    final loadPromises = <Future>[];

    for (final dette in deudas) {
      final idCommande = dette['idCommande'] as int?;
      final detteIdClient = dette['idClient'] as int?;

      if (idCommande != null &&
          !_commandesCache.containsKey(idCommande.toString())) {
        loadPromises.add(
          locator.apiService
              .getCommandeById(idCommande)
              .then((commande) {
                _commandesCache[idCommande.toString()] = commande;
                final idClientFromCommande = commande['idClient'] as int?;
                if (idClientFromCommande != null &&
                    !_clientsCache.containsKey(
                      idClientFromCommande.toString(),
                    )) {
                  return locator.apiService
                      .getClientById(idClientFromCommande)
                      .then((client) {
                        _clientsCache[idClientFromCommande.toString()] = client;
                      });
                }
              })
              .catchError((e) {
                debugPrint('Error loading commande $idCommande: $e');
              }),
        );
      }

      if (detteIdClient != null &&
          !_clientsCache.containsKey(detteIdClient.toString())) {
        loadPromises.add(
          locator.apiService
              .getClientById(detteIdClient)
              .then((client) {
                _clientsCache[detteIdClient.toString()] = client;
              })
              .catchError((e) {
                debugPrint('Error loading client $detteIdClient: $e');
              }),
        );
      }
    }

    if (loadPromises.isNotEmpty) {
      await Future.wait(loadPromises);
    }
    debugPrint('Final clients cache keys: ${_clientsCache.keys.toList()}');
  }

  void _applyFilters() {
    setState(() {
      _filteredDettes = _dettes.where((dette) {
        // Filtre par statut
        if (_selectedStatut != null) {
          final statut = dette['statut']?.toString() ?? '';
          if (statut != _selectedStatut) return false;
        }

        // Filtre par recherche
        if (_searchQuery.isNotEmpty) {
          final reference =
              dette['referencePaiemenet']?.toString() ??
              dette['referencePaiement']?.toString() ??
              '';
          final libelle = dette['libelle']?.toString() ?? '';
          final mode = dette['modePaiement']?.toString() ?? '';

          // Recherche par nom du client via le cache
          String clientName = '';
          final idCommandeFromDette = dette['idCommande']?.toString();
          final commandeFromCache = idCommandeFromDette != null
              ? _commandesCache[idCommandeFromDette] as Map<String, dynamic>?
              : null;
          final idClientFromNested =
              commandeFromCache?['client']?['idClient'] as int?;
          final idClientFromCommandeDirect =
              commandeFromCache?['idClient'] as int?;
          final idClientFromDette = dette['idClient'] as int?;
          final idClient =
              idClientFromDette ??
              idClientFromNested ??
              idClientFromCommandeDirect;
          if (idClient != null) {
            final clientFromCache =
                _clientsCache[idClient.toString()] as Map<String, dynamic>?;
            if (clientFromCache != null) {
              final nom = clientFromCache['nom']?.toString() ?? '';
              final prenom = clientFromCache['prenom']?.toString() ?? '';
              clientName = '$nom $prenom'.trim().toLowerCase();
            }
          }

          if (!reference.toLowerCase().contains(_searchQuery.toLowerCase()) &&
              !libelle.toLowerCase().contains(_searchQuery.toLowerCase()) &&
              !mode.toLowerCase().contains(_searchQuery.toLowerCase()) &&
              !clientName.contains(_searchQuery.toLowerCase())) {
            return false;
          }
        }

        // Filtre par date
        final datePaiement = dette['datePaiement']?.toString();
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
      _currentPage = 1;
      _hasMorePages = true;
    });
    _loadDettes();
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
            ? Container(
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                    _applyFilters();
                  },
                  textInputAction: TextInputAction.search,
                  cursorColor: Colors.white,
                  style: GoogleFonts.poppins(fontSize: 15, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Rechercher par référence, client...',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                    prefixIcon: Icon(Icons.search, color: Colors.white),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
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
                ),
              )
            : Text(
                'Dettes',
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
                            ).withValues(alpha: 0.1),
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
              color: const Color(0xFF2C3E50).withValues(alpha: 0.1),
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
                ? Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                  )
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
                        if (_searchQuery.isNotEmpty ||
                            _dateDebut != null ||
                            _dateFin != null ||
                            _selectedStatut != null)
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
                : _filteredDettes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune dette trouvée',
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
                    onRefresh: _loadDettes,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount:
                          _filteredDettes.length + (_hasMorePages ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _filteredDettes.length) {
                          return _buildLoadingIndicator();
                        }
                        final dette = Map<String, dynamic>.from(
                          _filteredDettes[index] as Map,
                        );
                        return _buildDetteCard(dette);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
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

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      child: _isLoadingMore
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2C3E50)),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildDetteCard(Map<String, dynamic> dette) {
    final montant = double.tryParse(dette['montant']?.toString() ?? '0') ?? 0;
    final mode = dette['modePaiement']?.toString() ?? '-';
    final statut = dette['statut']?.toString() ?? '-';
    final reference =
        dette['referencePaiemenet']?.toString() ??
        dette['referencePaiement']?.toString() ??
        '-';
    final date = _formatDate(dette['datePaiement']?.toString());
    final typeTransaction = dette['typeTransaction']?.toString() ?? '0';

    // Récupérer les détails de la commande
    final idCommande = dette['idCommande']?.toString();
    final commande = idCommande != null ? _commandesCache[idCommande] : null;
    final montantTotal =
        double.tryParse(commande?['montantTotal']?.toString() ?? '0') ?? 0;
    final montantPaye =
        double.tryParse(commande?['montantPaye']?.toString() ?? '0') ?? 0;
    final resteAPayer =
        double.tryParse(commande?['resteAPayer']?.toString() ?? '0') ?? 0;

    // Récupérer les détails du client depuis la commande
    final clientFromCommande = commande?['client'] as Map<String, dynamic>?;
    final idClientFromNested = clientFromCommande?['idClient'] as int?;
    final idClientFromCommandeDirect = commande?['idClient'] as int?;

    // Récupérer les détails complets du client depuis le cache (avec adresse)
    final idClient =
        dette['idClient'] as int? ??
        idClientFromNested ??
        idClientFromCommandeDirect;
    final clientFromCache = idClient != null
        ? _clientsCache[idClient.toString()] as Map<String, dynamic>?
        : null;

    // Utiliser les données du cache pour l'adresse complète, sinon celles de la commande
    final client = clientFromCache ?? clientFromCommande;
    final nomClient = client?['nom']?.toString() ?? '';
    final prenomClient = client?['prenom']?.toString() ?? '';
    final telephoneClient = client?['telephone']?.toString() ?? '';
    final emailClient = client?['email']?.toString() ?? '';
    final nomCompletClient = '$nomClient $prenomClient'.trim();

    // Adresse complète
    final province = clientFromCache?['province']?.toString() ?? '';
    final ville = clientFromCache?['ville']?.toString() ?? '';
    final commune = clientFromCache?['commune']?.toString() ?? '';
    final quartier = clientFromCache?['quartier']?.toString() ?? '';
    final avenue = clientFromCache?['avenue']?.toString() ?? '';
    final numero = clientFromCache?['numero']?.toString() ?? '';

    String adresseComplete = '';
    List<String> adresseParts = [];
    if (numero.isNotEmpty) adresseParts.add(numero);
    if (avenue.isNotEmpty) adresseParts.add(avenue);
    if (quartier.isNotEmpty) adresseParts.add(quartier);
    if (commune.isNotEmpty) adresseParts.add(commune);
    if (ville.isNotEmpty) adresseParts.add(ville);
    if (province.isNotEmpty) adresseParts.add(province);
    if (adresseParts.isEmpty && client != null) {
      adresseComplete = 'Non défini';
    } else {
      adresseComplete = adresseParts.join(', ');
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final clientFromCommande =
              commande?['client'] as Map<String, dynamic>?;
          final idClientFromCommande = clientFromCommande?['idClient'] as int?;
          final idClientFromDette = dette['idClient'] as int?;
          final idClient = idClientFromDette ?? idClientFromCommande;
          final clientFromCache = idClient != null
              ? _clientsCache[idClient.toString()]
              : null;
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetteDetailScreen(
                dette: dette,
                commande: idCommande != null
                    ? _commandesCache[idCommande]
                    : null,
                client: clientFromCache ?? clientFromCommande,
              ),
            ),
          );
          if (result == true && mounted) {
            _loadDettes();
          }
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
                        if (idCommande != null)
                          Text(
                            'Commande #$idCommande',
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
                      color: _getStatusColor(statut).withValues(alpha: 0.1),
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
                if (emailClient.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.email, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          emailClient,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (adresseComplete.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
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
                      if (typeTransaction == '1')
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
                            'Acompte',
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
}
