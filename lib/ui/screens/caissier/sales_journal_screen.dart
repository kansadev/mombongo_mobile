// lib/screens/sales_journal_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mombongo/services/app_currency_preference.dart';
import '../../../services/service_locator.dart';
import 'annuler_vente_screen.dart';

class SalesJournalScreen extends StatefulWidget {
  const SalesJournalScreen({super.key});

  @override
  State<SalesJournalScreen> createState() => _SalesJournalScreenState();
}

class _SalesJournalScreenState extends State<SalesJournalScreen> {
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _allVentes = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  DateTime? _selectedDate;
  double _montantTotal = 0.0;
  double _quantiteTotale = 0.0;
  String _sortOrder = 'desc';

  @override
  void initState() {
    super.initState();
    _loadJournalData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _currentPage < _totalPages) {
        _loadMoreData();
      }
    }
  }

  void _sortVentes() {
    _allVentes.sort((a, b) {
      final dateA = a['dateCreation']?.toString() ?? '';
      final dateB = b['dateCreation']?.toString() ?? '';
      if (dateA.isEmpty && dateB.isEmpty) return 0;
      if (dateA.isEmpty) return _sortOrder == 'desc' ? -1 : 1;
      if (dateB.isEmpty) return _sortOrder == 'desc' ? 1 : -1;
      return _sortOrder == 'desc'
          ? dateB.compareTo(dateA)
          : dateA.compareTo(dateB);
    });
  }

  void _toggleSort() {
    setState(() {
      _sortOrder = _sortOrder == 'desc' ? 'asc' : 'desc';
    });
    _sortVentes();
  }

  Future<void> _loadJournalData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = 1;
    });

    try {
      final currentUser = locator.authRepository.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      final idUtilisateur = int.tryParse(currentUser.idUtilisateur) ?? 0;
      if (idUtilisateur == 0) {
        throw Exception('ID utilisateur invalide');
      }

      final response = await locator.apiService.getJournalVenteParCaissier(
        idUtilisateur: idUtilisateur,
        page: 1,
        pageSize: 20,
      );

      if (!mounted) return;

      final data = response['data'] as List<dynamic>? ?? [];
      final pagination = response['pagination'] as Map<String, dynamic>? ?? {};

      double montantTotal = 0.0;
      double quantiteTotale = 0.0;

      for (var vente in data) {
        montantTotal += _parseDouble(vente['total'] ?? 0);
        quantiteTotale += _parseDouble(vente['quantite'] ?? 0);
      }

      setState(() {
        _allVentes = List.from(data);
        _totalPages = _parseInt(pagination['totalPages'] ?? 1);
        _totalCount = _parseInt(pagination['totalCount'] ?? 0);
        _montantTotal = montantTotal;
        _quantiteTotale = quantiteTotale;
        _isLoading = false;
      });
      _sortVentes();
    } catch (e) {
      debugPrint('Erreur lors du chargement du journal: $e');
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreData() async {
    if (!mounted || _isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final currentUser = locator.authRepository.currentUser;
      if (currentUser == null) return;

      final idUtilisateur = int.tryParse(currentUser.idUtilisateur) ?? 0;

      final response = await locator.apiService.getJournalVenteParCaissier(
        idUtilisateur: idUtilisateur,
        page: _currentPage + 1,
        pageSize: 20,
      );

      if (!mounted) return;

      final data = response['data'] as List<dynamic>? ?? [];
      final pagination = response['pagination'] as Map<String, dynamic>? ?? {};

      double montantTotalAdd = 0.0;
      double quantiteTotaleAdd = 0.0;

      for (var vente in data) {
        montantTotalAdd += _parseDouble(vente['total'] ?? 0);
        quantiteTotaleAdd += _parseDouble(vente['quantite'] ?? 0);
      }

      setState(() {
        _allVentes = [..._allVentes, ...data];
        _currentPage = _parseInt(pagination['page'] ?? 1);
        _totalPages = _parseInt(pagination['totalPages'] ?? 1);
        _totalCount = _parseInt(pagination['totalCount'] ?? 0);
        _montantTotal += montantTotalAdd;
        _quantiteTotale += quantiteTotaleAdd;
        _isLoadingMore = false;
      });
      _sortVentes();
    } catch (e) {
      debugPrint('Erreur lors du chargement supplémentaire: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _annulerVente(Map<String, dynamic> vente) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AnnulerVenteScreen(vente: vente)),
    );
    if (result == true && mounted) {
      _loadJournalData();
    }
  }

  double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  String _formatCurrency(double amount) {
    return locator.tauxService.formatPrice(amount);
  }

  String _formatCurrencyCompact(double amount) {
    final code = locator.tauxService.getDevisePreferee();
    final tauxVal =
        double.tryParse(locator.tauxService.getTauxActuel().tauxActuel) ?? 1.0;
    final converted = locator.tauxService.convertir(
      amount,
      'USD',
      code,
      tauxVal,
    );
    final symbol = AppCurrencyPreference.symbolFor(code);

    if (converted >= 1000000000) {
      return '${(converted / 1000000000).toStringAsFixed(1)}Md $symbol';
    } else if (converted >= 1000000) {
      return '${(converted / 1000000).toStringAsFixed(1)}M $symbol';
    } else if (converted >= 1000) {
      return '${(converted / 1000).toStringAsFixed(1)}k $symbol';
    } else {
      return locator.tauxService.formatPrice(amount);
    }
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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _loadJournalData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Journal des Ventes',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _toggleSort,
            icon: Icon(
              _sortOrder == 'desc' ? Icons.arrow_downward : Icons.arrow_upward,
              color: Colors.white,
            ),
            tooltip: _sortOrder == 'desc' ? 'Plus récent' : 'Plus ancien',
          ),
          IconButton(
            onPressed: _selectDate,
            icon: Icon(
              Icons.calendar_today,
              color: _selectedDate != null ? Colors.orange : Colors.white70,
            ),
            tooltip: 'Filtrer par date',
          ),
          if (_selectedDate != null)
            IconButton(
              onPressed: () {
                setState(() {
                  _selectedDate = null;
                });
                _loadJournalData();
              },
              icon: const Icon(Icons.clear, color: Colors.white70),
              tooltip: 'Effacer le filtre',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadJournalData,
        child: _isLoading && _allVentes.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Erreur',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(color: Colors.grey[600]),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _loadJournalData,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              )
            : CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Historique des ventes',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2C3E50),
                            ),
                          ),
                          Text(
                            '${_allVentes.length}/$_totalCount',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_allVentes.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Aucune vente trouvée',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final vente = _allVentes[index];
                          return _buildVenteCard(vente, index);
                        }, childCount: _allVentes.length),
                      ),
                    ),
                  if (_isLoadingMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              ),
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    String? fullValue,
    required IconData icon,
    required Color color,
  }) {
    return GestureDetector(
      onLongPress: fullValue != null
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '$label: $fullValue',
                    style: GoogleFonts.poppins(fontSize: 16),
                  ),
                  duration: const Duration(seconds: 3),
                  backgroundColor: color,
                ),
              );
            }
          : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVenteCard(Map<String, dynamic> vente, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onLongPress: () => _annulerVente(vente),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C3E50).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.shopping_bag,
                      color: Color(0xFF2C3E50),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vente['libelle']?.toString() ?? 'N/A',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2C3E50),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Cmd #${vente['idCommande']}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatCurrency(_parseDouble(vente['total'] ?? 0)),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                      Text(
                        '${vente['quantite']} × ${_formatCurrency(_parseDouble(vente['prixUnitaire'] ?? 0))}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text(
                      _formatDate(vente['dateCreation']?.toString()),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const Spacer(),
                    Expanded(
                      child: Text(
                        vente['nomSite']?.toString() ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _annulerVente(vente),
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
          ),
        ),
      ),
    );
  }
}
