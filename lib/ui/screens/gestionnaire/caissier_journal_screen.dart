import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mombongo/services/app_currency_preference.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/ui/screens/profil_screen.dart';
import 'package:mombongo/utils/api_error_message.dart';

class CaissierJournalScreen extends StatefulWidget {
  final int idUtilisateur;
  final String nomCaissier;

  const CaissierJournalScreen({
    super.key,
    required this.idUtilisateur,
    required this.nomCaissier,
  });

  @override
  State<CaissierJournalScreen> createState() => _CaissierJournalScreenState();
}

class _CaissierJournalScreenState extends State<CaissierJournalScreen> {
  List<dynamic> _allSales = []; // Toutes les ventes chargées
  List<dynamic> _filteredSales = []; // Ventes filtrées par date
  bool _isLoading = true;
  String? _errorMessage;

  // Pagination
  int _currentPage = 1;
  int _pageSize = 20;
  int _totalPages = 1;
  int _totalCount = 0;
  bool _hasNextPage = false;
  bool _hasPreviousPage = false;

  // Filtres de date
  DateTime? _dateDebut;
  DateTime? _dateFin;
  final TextEditingController _dateDebutController = TextEditingController();
  final TextEditingController _dateFinController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  @override
  void dispose() {
    _dateDebutController.dispose();
    _dateFinController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSales({int page = 1}) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Charger toutes les pages de données pour le filtrage frontend
      List<dynamic> allSales = [];
      int currentPage = 1;
      bool hasMorePages = true;

      while (hasMorePages) {
        final response = await locator.apiService.getJournalVenteParCaissier(
          idUtilisateur: widget.idUtilisateur,
          page: currentPage,
          pageSize: 100, // Plus grand pageSize pour minimiser les requêtes
        );

        if (!mounted) return;

        final pageData = response['data'] as List? ?? [];
        debugPrint('=== PAGE $currentPage ===');
        debugPrint('Données reçues: ${pageData.length}');
        allSales.addAll(pageData);

        final pagination =
            response['pagination'] as Map<String, dynamic>? ?? {};
        hasMorePages = pagination['hasNextPage'] as bool? ?? false;
        debugPrint('Has next page: $hasMorePages');
        currentPage++;
      }

      if (!mounted) return;

      setState(() {
        _allSales = allSales;
        debugPrint('=== CHARGEMENT TERMINÉ ===');
        debugPrint('Total ventes chargées: ${_allSales.length}');
        if (_allSales.isNotEmpty) {
          debugPrint('Première vente: ${_allSales.first}');
        }
        _applyDateFilters(); // Appliquer les filtres de date
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement des ventes: $e');
      if (!mounted) return;

      setState(() {
        _errorMessage = apiErrorUserMessage(e);
        _isLoading = false;
      });
    }
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  // Extract initials from user's full name
  String _getUserInitials(String fullName) {
    if (fullName.isEmpty) return '??';

    final names = fullName.trim().split(' ');
    if (names.length >= 2) {
      return '${names[0][0].toUpperCase()}${names[names.length - 1][0].toUpperCase()}';
    } else if (names.isNotEmpty) {
      final name = names[0];
      if (name.length >= 2) {
        return '${name[0].toUpperCase()}${name[1].toUpperCase()}';
      } else {
        return name.toUpperCase();
      }
    }
    return '??';
  }

  String _formatCurrency(double amount) {
    return AppCurrencyPreference.formatCurrency(amount);
  }

  void _applyDateFilters() {
    debugPrint('=== DEBUG FILTRES ===');
    debugPrint('Total ventes chargées: ${_allSales.length}');
    debugPrint('Date début: $_dateDebut');
    debugPrint('Date fin: $_dateFin');

    setState(() {
      _filteredSales = _allSales.where((sale) {
        // Filtre par recherche
        if (_searchQuery.isNotEmpty) {
          final libelle = sale['libelle']?.toString().toLowerCase() ?? '';
          if (!libelle.contains(_searchQuery.toLowerCase())) {
            return false;
          }
        }

        final dateCreation = sale['dateCreation'];
        if (dateCreation == null) {
          debugPrint('Vente sans date: ${sale['libelle']}');
          return true; // Garder si pas de date
        }

        try {
          final saleDate = DateTime.parse(dateCreation.toString());
          debugPrint('Vente: ${sale['libelle']} - Date: $saleDate');

          // Appliquer les filtres de date
          if (_dateDebut != null && saleDate.isBefore(_dateDebut!)) {
            debugPrint('Filtrée: avant date début');
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
            if (saleDate.isAfter(dateFinEndOfDay)) {
              debugPrint('Filtrée: après date fin');
              return false;
            }
          }
          debugPrint('Conservée');
          return true;
        } catch (e) {
          debugPrint('Error parsing date: $e');
          return true; // Garder si erreur de parsing
        }
      }).toList();

      debugPrint('Ventes filtrées: ${_filteredSales.length}');
      // Mettre à jour la pagination pour les données filtrées
      _updatePagination();
    });
  }

  void _updatePagination() {
    final totalItems = _filteredSales.length;
    _totalCount = totalItems;
    _totalPages = (totalItems / _pageSize).ceil();
    _hasNextPage = _currentPage < _totalPages;
    _hasPreviousPage = _currentPage > 1;
  }

  List<dynamic> get _currentPageSales {
    final startIndex = (_currentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, _filteredSales.length);
    debugPrint('=== DEBUG PAGINATION ===');
    debugPrint('Page actuelle: $_currentPage');
    debugPrint('Index début: $startIndex');
    debugPrint('Index fin: $endIndex');
    debugPrint('Ventes filtrées totales: ${_filteredSales.length}');
    debugPrint('Ventes page actuelle: ${endIndex - startIndex}');

    if (_filteredSales.isEmpty) {
      debugPrint('AUCUNE VENTE FILTRÉE');
      return [];
    }

    return _filteredSales.sublist(startIndex, endIndex);
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
        _currentPage = 1; // Revenir à la première page
      });
      _applyDateFilters(); // Appliquer les filtres localement
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
        _currentPage = 1; // Revenir à la première page
      });
      _applyDateFilters(); // Appliquer les filtres localement
    }
  }

  void _clearFilters() {
    setState(() {
      _dateDebut = null;
      _dateFin = null;
      _dateDebutController.clear();
      _dateFinController.clear();
      _searchQuery = '';
      _searchController.clear();
      _currentPage = 1; // Revenir à la première page
    });
    _applyDateFilters(); // Réappliquer les filtres (sans filtres = toutes les données)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Journal - ${widget.nomCaissier}'),
        centerTitle: true,
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilScreen()),
              );
            },
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white,
              child: Text(
                _getUserInitials(
                  locator.authRepository.currentUser?.nomComplet ?? '',
                ),
                style: const TextStyle(
                  color: Color(0xFF2C3E50),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadSales(page: _currentPage),
        child: Column(
          children: [
            // Filtres
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Barre de recherche
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _currentPage = 1;
                      });
                      _applyDateFilters();
                    },
                    decoration: InputDecoration(
                      hintText: 'Rechercher un article...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _currentPage = 1;
                                });
                                _applyDateFilters();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.filter_list, color: Color(0xFF2C3E50)),
                      const SizedBox(width: 8),
                      Text(
                        'Filtrer par date',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2C3E50),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _clearFilters,
                        child: const Text('Effacer'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                      const SizedBox(width: 16),
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
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Contenu principal
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => _loadSales(),
                            child: const Text('Reessayer'),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Sales list
                        Expanded(
                          child: _currentPageSales.isEmpty
                              ? const Center(
                                  child: Text('Aucune vente trouvee'),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _currentPageSales.length,
                                  itemBuilder: (context, index) {
                                    return _buildSaleCard(
                                      _currentPageSales[index],
                                    );
                                  },
                                ),
                        ),

                        // Pagination
                        _buildPagination(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaleCard(Map<String, dynamic> sale) {
    final libelle = sale['libelle']?.toString() ?? 'Article';
    final quantite = _parseInt(sale['quantite']);
    final prixUnitaire = _parseDouble(sale['prixUnitaire']);
    final total = _parseDouble(sale['total']);
    final dateCreation = sale['dateCreation'];
    final nomSite = sale['nomSite']?.toString() ?? '';

    DateTime? parsedDate;
    if (dateCreation != null) {
      try {
        parsedDate = DateTime.parse(dateCreation.toString());
      } catch (e) {
        debugPrint('Error parsing date: $e');
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    libelle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _formatCurrency(total),
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip(
                  icon: Icons.shopping_cart,
                  label: 'Qte',
                  value: '$quantite',
                ),
                const SizedBox(width: 16),
                _buildInfoChip(
                  icon: Icons.attach_money,
                  label: 'Prix',
                  value: _formatCurrency(prixUnitaire),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (nomSite.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.store, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        nomSite,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                if (parsedDate != null)
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(parsedDate),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Page $_currentPage sur $_totalPages ($_totalCount ventes)',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _hasPreviousPage
                        ? () {
                            setState(() {
                              _currentPage--;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.arrow_back_ios),
                    iconSize: 20,
                    disabledColor: Colors.grey[300],
                  ),
                  IconButton(
                    onPressed: _hasNextPage
                        ? () {
                            setState(() {
                              _currentPage++;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.arrow_forward_ios),
                    iconSize: 20,
                    disabledColor: Colors.grey[300],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
