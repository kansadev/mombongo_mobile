// lib/screens/sales_journal_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mombongo/services/app_currency_preference.dart';
import '../../../services/service_locator.dart';

class SalesJournalScreen extends StatefulWidget {
  const SalesJournalScreen({super.key});

  @override
  State<SalesJournalScreen> createState() => _SalesJournalScreenState();
}

class _SalesJournalScreenState extends State<SalesJournalScreen> {
  List<dynamic> _ventes = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  DateTime? _selectedDate;
  double _montantTotal = 0.0;
  double _quantiteTotale = 0.0;

  @override
  void initState() {
    super.initState();
    _loadJournalData();
  }

  Future<void> _loadJournalData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentUser = locator.authRepository.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      final idSite = int.tryParse(currentUser.idSite) ?? 0;
      if (idSite == 0) {
        throw Exception('ID du site invalide');
      }

      final response = await locator.apiService.getJournalVenteParSite(
        idSite: idSite,
        page: _currentPage,
        pageSize: 20,
      );

      if (!mounted) return;

      final data = response['data'] as List<dynamic>? ?? [];
      final pagination = response['pagination'] as Map<String, dynamic>? ?? {};

      // Calculer les statistiques
      double montantTotal = 0.0;
      double quantiteTotale = 0.0;

      for (var vente in data) {
        montantTotal += _parseDouble(vente['total'] ?? 0);
        quantiteTotale += _parseDouble(vente['quantite'] ?? 0);
      }

      setState(() {
        _ventes = data;
        _totalPages = _parseInt(pagination['totalPages'] ?? 1);
        _totalCount = _parseInt(pagination['totalCount'] ?? 0);
        _montantTotal = montantTotal;
        _quantiteTotale = quantiteTotale;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement du journal: $e');
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
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
    // delegate to tauxService so the amount is converted and formatted
    return locator.tauxService.formatPrice(amount);
  }

  String _formatCurrencyCompact(double amount) {
    // convert first so compacting happens after applying the rate
    final code = locator.tauxService.getDevisePreferee();
    final tauxVal = double.tryParse(locator.tauxService.getTauxActuel().tauxActuel) ?? 1.0;
    final converted = locator.tauxService.convertir(amount, 'USD', code, tauxVal);
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
        backgroundColor: Theme.of(context).colorScheme.secondary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
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
      ),
      body: RefreshIndicator(
        onRefresh: _loadJournalData,
        child: _isLoading
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
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête avec statistiques
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[200]!),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Statistiques en grille responsive
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    label: 'Ventes',
                                    value: '$_totalCount',
                                    color: const Color(0xFF1E3C72),
                                    fontSize: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatCard(
                                    label: 'Montant Total',
                                    value: _formatCurrencyCompact(
                                      _montantTotal,
                                    ),
                                    fullValue: _formatCurrency(_montantTotal),
                                    color: Colors.green,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    label: 'Quantité Totale',
                                    value: _quantiteTotale.toStringAsFixed(2),
                                    color: const Color(0xFFFF9800),
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatCard(
                                    label: 'Date',
                                    value: _selectedDate != null
                                        ? DateFormat(
                                            'dd/MM/yyyy',
                                          ).format(_selectedDate!)
                                        : 'Toutes',
                                    color: const Color(0xFF1E3C72),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Tableau des ventes
                    Text(
                      'Détail des Ventes',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E3C72),
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_ventes.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            children: [
                              Icon(
                                Icons.receipt_long,
                                size: 60,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Aucune vente trouvée',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      // En-tête du tableau
                      Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF1E3C72),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(10),
                            topRight: Radius.circular(10),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Libellé',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Qté',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Prix',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Total',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Lignes du tableau
                      ...List.generate(_ventes.length, (index) {
                        final vente = _ventes[index];
                        return _buildTableRow(
                          productName: vente['libelle']?.toString() ?? 'N/A',
                          quantity: _parseDouble(
                            vente['quantite'] ?? 0,
                          ).toStringAsFixed(2),
                          price: _formatCurrency(
                            _parseDouble(vente['prixUnitaire'] ?? 0),
                          ),
                          total: _formatCurrency(
                            _parseDouble(vente['total'] ?? 0),
                          ),
                          isEven: index % 2 == 0,
                          isLast: index == _ventes.length - 1,
                        );
                      }),

                      // Ligne vide avec bordure arrondie en bas
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(10),
                            bottomRight: Radius.circular(10),
                          ),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        height: 1,
                      ),

                      // Pagination
                      if (_totalPages > 1) ...[
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: _currentPage > 1
                                  ? () {
                                      setState(() {
                                        _currentPage--;
                                      });
                                      _loadJournalData();
                                    }
                                  : null,
                            ),
                            Text(
                              'Page $_currentPage sur $_totalPages',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: _currentPage < _totalPages
                                  ? () {
                                      setState(() {
                                        _currentPage++;
                                      });
                                      _loadJournalData();
                                    }
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ],

                    const SizedBox(height: 30),

                    // Options supplémentaires
                    const SizedBox(height: 20),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[200]!),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Exporter les données',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    // TODO: Implémenter l'export
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'A venir dans la prochaine version',
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.download,
                                    color: Color(0xFF1E3C72),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Filtrer par date',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                IconButton(
                                  onPressed: _selectDate,
                                  icon: Icon(
                                    Icons.calendar_today,
                                    color: _selectedDate != null
                                        ? const Color(0xFF1E3C72)
                                        : Colors.grey[400],
                                  ),
                                ),
                                if (_selectedDate != null)
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _selectedDate = null;
                                      });
                                      _loadJournalData();
                                    },
                                    icon: const Icon(
                                      Icons.clear,
                                      color: Colors.red,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    String? fullValue,
    required Color color,
    required double fontSize,
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableRow({
    required String productName,
    required String quantity,
    required String price,
    required String total,
    required bool isEven,
    bool isLast = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isEven ? Colors.white : Colors.grey[50],
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : BorderSide(color: Colors.grey[200]!),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              productName,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              quantity,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              price,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              total,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Color(0xFF1E3C72),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
