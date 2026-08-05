import 'package:flutter/material.dart';
import 'package:mombongo/ui/screens/stock/stock_management_screen.dart';
import 'package:mombongo/ui/screens/stock/mouvement_stock_screen.dart';
import 'package:mombongo/ui/screens/vente/point_of_sale_screen.dart';
import 'package:mombongo/ui/screens/vente/vente_synthese_screen.dart';
import 'package:mombongo/ui/screens/caissier/dettes_screen.dart';
import '../../../services/service_locator.dart';
import '../profil_screen.dart';
import '../gestionnaire/caissier_performance_screen.dart';
import '../gestionnaire/clients_site_screen.dart';
import '../gestionnaire/utilisateurs_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_paiements_dashboard_screen.dart';
import '../login_screen.dart';
import 'package:intl/intl.dart';
import 'package:mombongo/ui/widgets/site_switcher_panel.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
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

      final idSociete = int.tryParse(currentUser.idSociete) ?? 0;
      if (idSociete == 0) {
        throw Exception('ID de la société invalide');
      }

      final dashboardData = await locator.apiService.getDashboardDataBySociete(
        idSociete: idSociete,
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

  @override
  Widget build(BuildContext context) {
    final resume = _dashboardData?['resume'] as Map<String, dynamic>?;
    final societe = _dashboardData?['societe'] as Map<String, dynamic>?;
    final currentUser = locator.authRepository.currentUser;
    final siteLabel = (currentUser?.nomSite.isNotEmpty == true)
        ? currentUser!.nomSite
        : 'Aucun site';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(societe?['nomSociete']?.toString() ?? 'Dashboard Admin'),
            Text(
              'Site : $siteLabel',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        centerTitle: false,
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Changer de site',
            icon: const Icon(Icons.storefront_outlined),
            onPressed: () async {
              final changed = await SiteSwitcherPanel.show(context);
              if (changed && mounted) setState(() {});
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF2C3E50),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.admin_panel_settings, color: Color(0xFF2C3E50), size: 28),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    currentUser?.nomComplet ?? 'Admin',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Site : $siteLabel',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            _buildDrawerItem(
              context: context,
              icon: Icons.dashboard,
              title: 'Dashboard',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
                );
              },
            ),
            _buildDrawerItem(
              context: context,
              icon: Icons.payment,
              title: 'Dashboard paiements',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminPaiementsDashboardScreen(),
                  ),
                );
              },
            ),
            _buildDrawerItem(
              context: context,
              icon: Icons.store,
              title: 'Points de Vente',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PointsDeVenteScreen()),
                );
              },
            ),
            _buildDrawerItem(
              context: context,
              icon: Icons.inventory,
              title: 'Gestion des Stocks',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GestionStocksScreen()),
                );
              },
            ),
            _buildDrawerItem(
              context: context,
              icon: Icons.swap_horiz,
              title: 'Mouvements de stock',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StockMouvementsScreen(),
                  ),
                );
              },
            ),
            _buildDrawerItem(
              context: context,
              icon: Icons.insights,
              title: 'Synthèse des ventes',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VenteSyntheseScreen(),
                  ),
                );
              },
            ),
            _buildDrawerItem(
              context: context,
              icon: Icons.account_balance_wallet_outlined,
              title: 'Dettes',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const DettesScreen(filterByOperationalSite: true),
                  ),
                );
              },
            ),
            _buildDrawerItem(
              context: context,
              icon: Icons.people,
              title: 'Ventes par Caissier',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CaissierPerformanceScreen()),
                );
              },
            ),
            _buildDrawerItem(
              context: context,
              icon: Icons.people_outline,
              title: 'Clients du jour',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ClientsSiteScreen()),
                );
              },
            ),
            _buildDrawerItem(
              context: context,
              icon: Icons.manage_accounts,
              title: 'Gestion utilisateurs',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UtilisateursScreen()),
                );
              },
            ),
            const Divider(),
            _buildDrawerItem(
              context: context,
              icon: Icons.swap_horiz,
              title: 'Changer de site',
              onTap: () async {
                Navigator.pop(context);
                final changed = await SiteSwitcherPanel.show(context);
                if (changed && mounted) setState(() {});
              },
            ),
            _buildDrawerItem(
              context: context,
              icon: Icons.person,
              title: 'Profil',
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilScreen()),
                );
                if (mounted) setState(() {});
              },
            ),
            _buildDrawerItem(
              context: context,
              icon: Icons.logout,
              title: 'Déconnexion',
              onTap: () {
                Navigator.pop(context);
                locator.authRepository.logout();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
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
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red[700]),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadDashboardData,
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
                        // Bandeau changement de site (toujours visible)
                        Material(
                          color: const Color(0xFF3498DB).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              final changed =
                                  await SiteSwitcherPanel.show(context);
                              if (changed && mounted) setState(() {});
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.storefront,
                                    color: Color(0xFF2C3E50),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Site opérationnel',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        Text(
                                          siteLabel,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2C3E50),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      final changed =
                                          await SiteSwitcherPanel.show(context);
                                      if (changed && mounted) {
                                        setState(() {});
                                      }
                                    },
                                    child: const Text('Changer'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Statistiques globales
                        if (resume != null) ...[
                          const Text(
                            'Vue d\'ensemble',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  title: 'Chiffre d\'affaires',
                                  value: NumberFormat.currency(
                                    symbol: 'CDF ',
                                    decimalDigits: 0,
                                  ).format(_parseDouble(resume['chiffreAffairesTotal'] ?? 0)),
                                  icon: Icons.monetization_on,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  title: 'Total ventes',
                                  value: _parseInt(resume['nombreTotalVentes'] ?? 0).toString(),
                                  icon: Icons.shopping_cart,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  title: 'Paiements',
                                  value: NumberFormat.currency(
                                    symbol: 'CDF ',
                                    decimalDigits: 0,
                                  ).format(_parseDouble(resume['montantTotalPaiements'] ?? 0)),
                                  icon: Icons.payment,
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  title: 'Valeur stock',
                                  value: NumberFormat.currency(
                                    symbol: 'CDF ',
                                    decimalDigits: 0,
                                  ).format(_parseDouble(resume['valeurStockTotal'] ?? 0)),
                                  icon: Icons.inventory,
                                  color: Colors.purple,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  title: 'Sites actifs',
                                  value: _parseInt(resume['sitesActifs'] ?? 0).toString(),
                                  icon: Icons.store,
                                  color: Colors.teal,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  title: 'Alertes stocks',
                                  value: _parseInt(resume['alertesStocksTotal'] ?? 0).toString(),
                                  icon: Icons.warning,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                        ],

                        // Actions rapides
                        const Text(
                          'Actions rapides',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final crossAxisCount = 2;
                            final spacing = 12.0;
                            final actionCards = [
                              _buildActionCard(
                                title: 'Dashboard détaillé',
                                icon: Icons.dashboard,
                                color: const Color(0xFF3498DB),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
                                  );
                                },
                              ),
                              _buildActionCard(
                                title: 'Paiements du site',
                                icon: Icons.payment,
                                color: Colors.blueAccent,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const AdminPaiementsDashboardScreen(),
                                    ),
                                  );
                                },
                              ),
                              _buildActionCard(
                                title: 'Points de Vente',
                                icon: Icons.store,
                                color: Colors.green,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const PointsDeVenteScreen()),
                                  );
                                },
                              ),
                              _buildActionCard(
                                title: 'Gestion Stocks',
                                icon: Icons.inventory,
                                color: Colors.orange,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const GestionStocksScreen()),
                                  );
                                },
                              ),
                              _buildActionCard(
                                title: 'Mouvements stock',
                                icon: Icons.swap_horiz,
                                color: Colors.deepOrange,
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
                              _buildActionCard(
                                title: 'Synthèse ventes',
                                icon: Icons.insights,
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
                              _buildActionCard(
                                title: 'Dettes',
                                icon: Icons.account_balance_wallet_outlined,
                                color: Colors.brown,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const DettesScreen(
                                        filterByOperationalSite: true,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              _buildActionCard(
                                title: 'Performances Caissiers',
                                icon: Icons.people,
                                color: Colors.teal,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const CaissierPerformanceScreen()),
                                  );
                                },
                              ),
                              _buildActionCard(
                                title: 'Gestion Utilisateurs',
                                icon: Icons.manage_accounts,
                                color: Colors.indigo,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const UtilisateursScreen()),
                                  );
                                },
                              ),
                            ];

                            final isOdd = actionCards.length % crossAxisCount != 0;
                            final lastIndex = actionCards.length - 1;

                            return Column(
                              children: [
                                // Grille normale pour toutes les cartes sauf la dernière si impaire
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: spacing,
                                    mainAxisSpacing: spacing,
                                    childAspectRatio: 2.0,
                                  ),
                                  itemCount: isOdd ? actionCards.length - 1 : actionCards.length,
                                  itemBuilder: (context, index) {
                                    return actionCards[index];
                                  },
                                ),
                                // Dernière carte en pleine largeur si impaire
                                if (isOdd) ...[
                                  SizedBox(height: spacing),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 80,
                                    child: actionCards[lastIndex],
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color,
                color.withOpacity(0.7),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 26),
              const SizedBox(height: 6),
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2C3E50)),
      title: Text(title),
      onTap: onTap,
    );
  }
}
