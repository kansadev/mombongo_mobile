import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:intl/intl.dart';

class CaissierDashboardScreen extends StatefulWidget {
  const CaissierDashboardScreen({super.key});

  @override
  State<CaissierDashboardScreen> createState() =>
      _CaissierDashboardScreenState();
}

class _CaissierDashboardScreenState extends State<CaissierDashboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _dashboardData;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
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

      final dashboardData = await locator.apiService.getDashboardData(
        idSite: idSite,
        idSociete: int.tryParse(currentUser.idSociete),
      );

      if (!mounted) return;

      setState(() {
        _dashboardData = dashboardData;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement du dashboard: $e');
      if (!mounted) return;

      setState(() {
        debugPrint('Erreur lors du chargement du dashboard: $e');
        _errorMessage = 'Oups! Une erreur est survenue lors du chargement des données. Veuillez réessayer.';
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

  String _formatCurrency(double amount) {
    return locator.tauxService.formatPrice(amount);
  }

  String _formatNumber(double number) {
    final formatter = NumberFormat('#,##0.##', 'fr_CD');
    return formatter.format(number);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.secondary,
        title: Text(
          'Tableau de bord',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: GoogleFonts.poppins(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadDashboardData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Ventes du jour'),
                    _buildResponsiveGrid([
                      _buildStatCard(
                        Icons.receipt_long,
                        'Total ventes',
                        _parseInt(
                          _dashboardData?['ventes']?['nombreTotalVentes'],
                        ).toString(),
                        Colors.blue,
                      ),
                      _buildStatCard(
                        Icons.payments,
                        'Chiffre d\'affaires',
                        _formatCurrency(
                          _parseDouble(
                            _dashboardData?['ventes']?['chiffreAffaires'],
                          ),
                        ),
                        Colors.green,
                      ),
                      _buildStatCard(
                        Icons.local_shipping,
                        'Volume vendu',
                        _formatNumber(
                          _parseDouble(
                            _dashboardData?['ventes']?['quantiteTotaleVendue'],
                          ),
                        ),
                        Colors.orange,
                      ),
                      _buildStatCard(
                        Icons.shopping_bag,
                        'Panier moyen',
                        _formatCurrency(
                          _parseDouble(
                            _dashboardData?['ventes']?['panierMoyen'],
                          ),
                        ),
                        Colors.purple,
                      ),
                    ]),

                    const SizedBox(height: 25),
                    _buildSectionTitle('État des Stocks'),
                    _buildResponsiveGrid([
                      _buildStatCard(
                        Icons.inventory_2,
                        'Articles total',
                        _parseInt(
                          _dashboardData?['stocks']?['nombreArticlesTotal'],
                        ).toString(),
                        Colors.indigo,
                      ),
                      _buildStatCard(
                        Icons.check_circle,
                        'En stock',
                        _parseInt(
                          _dashboardData?['stocks']?['articlesEnStock'],
                        ).toString(),
                        Colors.teal,
                      ),
                      _buildStatCard(
                        Icons.warning_amber_rounded,
                        'Stock critique',
                        _parseInt(
                          _dashboardData?['stocks']?['stockCritique'],
                        ).toString(),
                        Colors.orange,
                      ),
                      _buildStatCard(
                        Icons.error_outline,
                        'Rupture',
                        _parseInt(
                          _dashboardData?['stocks']?['articlesEnRupture'],
                        ).toString(),
                        Colors.red,
                      ),
                    ]),

                    const SizedBox(height: 12),
                    _buildStatCard(
                      Icons.account_balance_wallet,
                      'Valeur totale du stock',
                      _formatCurrency(
                        _parseDouble(
                          _dashboardData?['stocks']?['valeurStockTotal'],
                        ),
                      ),
                      Colors.blueGrey,
                      isFullWidth: true,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey[900],
        ),
      ),
    );
  }

  Widget _buildResponsiveGrid(List<Widget> children) {
    // Utilisation d'un Wrap pour éviter de forcer une hauteur fixe comme GridView
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: children
          .map(
            (child) => SizedBox(
              width:
                  (MediaQuery.of(context).size.width / 2) -
                  26, // Calcul pour 2 colonnes
              child: child,
            ),
          )
          .toList(),
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String title,
    String value,
    Color color, {
    bool isFullWidth = false,
  }) {
    return Container(
      width: isFullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18, // Plus grand pour la lisibilité
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
