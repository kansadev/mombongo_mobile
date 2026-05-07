import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mombongo/services/app_currency_preference.dart';
import 'package:mombongo/ui/screens/finance/rapports_financiers_screen.dart';
import 'package:mombongo/ui/screens/stock/stock_management_screen.dart';
import 'package:mombongo/ui/screens/vente/sale_report_screen.dart';
import 'package:mombongo/ui/screens/vente/vente_synthese_screen.dart';
import '../../services/service_locator.dart';
import 'profil_screen.dart';
import 'gestionnaire/caissier_performance_screen.dart';
import 'stock/mouvement_stock_screen.dart';
import 'charge/site_charges_screen.dart';
import 'caissier/dettes_screen.dart';
import 'caissier/paiements_screen.dart';
import 'finance/paiement_dashboard_screen.dart';
import 'gestionnaire/clients_site_screen.dart';

class GestionnaireScreen extends StatefulWidget {
  const GestionnaireScreen({super.key});

  @override
  State<GestionnaireScreen> createState() => _GestionnaireScreenState();
}

class _GestionnaireScreenState extends State<GestionnaireScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _dashboardData;

  // Bottom navigation
  int _currentIndex = 0;

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
        throw Exception('Utilisateur non connecte');
      }

      final idSite = int.tryParse(currentUser.idSite) ?? 0;
      if (idSite == 0) {
        throw Exception('ID du site invalide');
      }

      final dashboardData = await locator.apiService.getDashboardData(
        idSite: idSite,
        idSociete: int.tryParse(currentUser.idSociete),
      );

      // Charger les données de paiements
      final paiementsData = await locator.apiService.getPaiementsDashboard(
        idSociete: int.tryParse(currentUser.idSociete) ?? 0,
        idSite: idSite,
      );

      if (!mounted) return;

      // Fusionner les données
      final remboursementsData =
          dashboardData['remboursements'] ??
          dashboardData['remboursement'] ??
          <String, dynamic>{};
      dashboardData['remboursements'] = {
        'nombreCommandes': remboursementsData['nombreCommandes'] ?? 0,
        'montantTotal': remboursementsData['montantTotal'] ?? 0,
        'montantPaye': remboursementsData['montantPaye'] ?? 0,
        'resteAPayer': remboursementsData['resteAPayer'] ?? 0,
        'quantiteTotale': remboursementsData['quantiteTotale'] ?? 0,
      };

      if (paiementsData.isNotEmpty) {
        dashboardData['paiements'] = {
          'nombreTotalPaiements': paiementsData['totalGeneral'] ?? 0,
          'montantTotalPaiements': paiementsData['totalGeneral'] ?? 0.0,
          'paiementsParType':
              paiementsData['paiementsParType'] ??
              paiementsData['totauxParType'] ??
              [],
        };
      }

      setState(() {
        _dashboardData = dashboardData;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement du dashboard: $e');
      if (!mounted) return;

      // Analyser le type d'erreur pour afficher un message approprie
      String message;
      if (e.toString().contains('500')) {
        message =
            'Nous rencontrons un probleme technique. Veuillez reessayer plus tard.';
      } else if (e.toString().contains('502') || e.toString().contains('503')) {
        message =
            'Service temporairement indisponible. Veuillez reessayer plus tard.';
      } else if (e.toString().contains('Connection')) {
        message = 'Probleme de connexion. Verifiez votre connexion internet.';
      } else if (e.toString().contains('timeout')) {
        message = 'Delai de connexion depasse. Veuillez reessayer.';
      } else {
        // En release, on n'affiche pas les details de l'erreur serveur
        message = kReleaseMode
            ? 'Une erreur est survenue lors du chargement'
            : 'Erreur lors du chargement: $e';
      }

      setState(() {
        _errorMessage = message;
        _isLoading = false;
      });
    }
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
    final code = AppCurrencyPreference.readCode(locator.databaseService);
    final formatter = AppCurrencyPreference.formatterFor(code);
    final symbol = AppCurrencyPreference.symbolFor(code);
    return '${formatter.format(amount)} $symbol';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildDashboard(),
          const GestionStocksScreen(),
          const RapportsVenteScreen(),
          const CaissierPerformanceScreen(),
          const RapportsFinanciersScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF2C3E50),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Stock'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calculate_rounded),
            label: 'Vente',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale),
            label: 'Caisses',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance),
            label: 'Finance',
          ),
        ],
      ),
    );
  }

  // Dashboard (Accueil) widget
  Widget _buildDashboard() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Tableau de bord'),
        centerTitle: false,
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SiteChargesScreen(),
                ),
              );
            },
            icon: const Icon(Icons.receipt_long, color: Colors.white),
            tooltip: 'Charges du site',
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PaiementDashboardScreen(),
                ),
              );
            },
            icon: const Icon(Icons.dashboard, color: Colors.white),
            tooltip: 'Dashboard Paiements',
          ),
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
        onRefresh: _loadDashboardData,
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Chargement du dashboard...'),
                  ],
                ),
              )
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
                      onPressed: _loadDashboardData,
                      child: const Text('Reessayer'),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Actions rapides
                    const Text(
                      'Actions rapides',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickActionButton(
                            context: context,
                            title: 'Mouvements de stock',
                            icon: Icons.swap_horiz,
                            color: Colors.orange,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const StockMouvementsScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildQuickActionButton(
                            context: context,
                            title: 'Rapports de vente',
                            icon: Icons.receipt_long,
                            color: Colors.blue,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const RapportsVenteScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickActionButton(
                            context: context,
                            title: 'Synthese Ventes',
                            icon: Icons.analytics,
                            color: Colors.purple,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const VenteSyntheseScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildQuickActionButton(
                            context: context,
                            title: 'Clients',
                            icon: Icons.group,
                            color: Colors.teal,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ClientsSiteScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickActionButton(
                            context: context,
                            title: 'Dettes',
                            icon: Icons.money_off,
                            color: Colors.red,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const DettesScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildQuickActionButton(
                            context: context,
                            title: 'Paiements',
                            icon: Icons.payment,
                            color: Colors.indigo,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const PaiementsScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Stats Ventes
                    const Text(
                      'Ventes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            title: 'Chiffre d\'affaires',
                            value: _formatCurrency(
                              _parseDouble(
                                _dashboardData?['ventes']?['chiffreAffaires'],
                              ),
                            ),
                            icon: Icons.attach_money,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            title: 'Nombre de ventes',
                            value:
                                '${_parseInt(_dashboardData?['ventes']?['nombreTotalVentes'])}',
                            icon: Icons.shopping_cart,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            title: 'Quantite vendues',
                            value:
                                '${_parseDouble(_dashboardData?['ventes']?['quantiteTotaleVendue']).toStringAsFixed(0)} unites',
                            icon: Icons.inventory,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            title: 'Panier moyen',
                            value: _formatCurrency(
                              _parseDouble(
                                _dashboardData?['ventes']?['panierMoyen'],
                              ),
                            ),
                            icon: Icons.shopping_basket,
                            color: Colors.purple,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            title: 'Articles uniques',
                            value:
                                '${_parseInt(_dashboardData?['ventes']?['nombreArticlesUniques'])}',
                            icon: Icons.category,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Stats Stocks
                    const Text(
                      'Stocks',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            title: 'Articles en stock',
                            value:
                                '${_parseInt(_dashboardData?['stocks']?['articlesEnStock'])}',
                            icon: Icons.check_circle,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            title: 'En rupture',
                            value:
                                '${_parseInt(_dashboardData?['stocks']?['articlesEnRupture'])}',
                            icon: Icons.warning,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            title: 'Stock critique',
                            value:
                                '${_parseInt(_dashboardData?['stocks']?['stockCritique'])}',
                            icon: Icons.error_outline,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildStatCard(
                      title: 'Valeur totale du stock',
                      value: _formatCurrency(
                        _parseDouble(
                          _dashboardData?['stocks']?['valeurStockTotal'],
                        ),
                      ),
                      icon: Icons.account_balance_wallet,
                      color: Colors.indigo,
                    ),

                    const SizedBox(height: 24),

                    // Stats Remboursements
                    const Text(
                      'Remboursements',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            title: 'Commandes',
                            value:
                                '${_parseInt(_dashboardData?['remboursements']?['nombreCommandes'])}',
                            icon: Icons.receipt_long,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            title: 'Montant total',
                            value: _formatCurrency(
                              _parseDouble(
                                _dashboardData?['remboursements']?['montantTotal'],
                              ),
                            ),
                            icon: Icons.account_balance_wallet,
                            color: Colors.redAccent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            title: 'Montant paye',
                            value: _formatCurrency(
                              _parseDouble(
                                _dashboardData?['remboursements']?['montantPaye'],
                              ),
                            ),
                            icon: Icons.payments,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            title: 'Reste a payer',
                            value: _formatCurrency(
                              _parseDouble(
                                _dashboardData?['remboursements']?['resteAPayer'],
                              ),
                            ),
                            icon: Icons.money_off,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            title: 'Quantite totale',
                            value:
                                '${_parseDouble(_dashboardData?['remboursements']?['quantiteTotale']).toStringAsFixed(0)} unites',
                            icon: Icons.inventory_2,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Stats Paiements
                    const Text(
                      'Paiements',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            title: 'Total paiements',
                            value:
                                '${_parseInt(_dashboardData?['paiements']?['nombreTotalPaiements'])}',
                            icon: Icons.payment,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            title: 'Montant total',
                            value: _formatCurrency(
                              _parseDouble(
                                _dashboardData?['paiements']?['montantTotalPaiements'],
                              ),
                            ),
                            icon: Icons.monetization_on,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Stats Clients
                    const Text(
                      'Clients',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            title: 'Total clients',
                            value:
                                '${_parseInt(_dashboardData?['clients']?['nombreTotalClients'])}',
                            icon: Icons.people,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            title: 'Clients actifs',
                            value:
                                '${_parseInt(_dashboardData?['clients']?['clientsActifs'])}',
                            icon: Icons.person_outline,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Stats Caissiers
                    const Text(
                      'Caissiers',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            title: 'Caissiers actifs',
                            value:
                                '${_parseInt(_dashboardData?['caissiers']?['nombreCaissiersActifs'])}',
                            icon: Icons.person,
                            color: Colors.purple,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            title: 'Performance moyenne',
                            value:
                                '${_parseDouble(_dashboardData?['caissiers']?['performanceMoyenne']).toStringAsFixed(1)}%',
                            icon: Icons.trending_up,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3), width: 1),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: color,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
