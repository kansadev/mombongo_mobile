import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/ui/screens/caissier/profil.dart';
import 'package:mombongo/ui/screens/caissier/facturation_screen.dart';
import 'package:mombongo/ui/screens/caissier/sales_journal_screen.dart';
import 'package:mombongo/services/cart_service.dart';
import 'package:provider/provider.dart';
import 'package:mombongo/ui/screens/caissier/cart_screen.dart';
import 'package:mombongo/ui/screens/caissier/stock_page.dart';
import 'package:mombongo/ui/screens/caissier/rapport_vente_caissier.dart';
import 'package:mombongo/ui/screens/caissier/caissier_dashboard_screen.dart';
import 'package:mombongo/ui/screens/caissier/paiements_screen.dart';
import 'package:mombongo/ui/screens/caissier/dettes_screen.dart';
import 'package:mombongo/ui/screens/caissier/charges_screen.dart';
import 'package:flutter/services.dart';

class CaissierScreen extends StatefulWidget {
  const CaissierScreen({super.key});

  @override
  State<CaissierScreen> createState() => _CaissierScreenState();
}

class _CaissierScreenState extends State<CaissierScreen> with WidgetsBindingObserver {
  bool _isLoadingDashboard = true;
  Map<String, dynamic>? _dashboardData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDashboardData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadDashboardData();
    }
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoadingDashboard = true);

    try {
      final currentUser = locator.authRepository.currentUser;
      if (currentUser == null) throw Exception('Utilisateur non connecté');

      final idSite = int.tryParse(currentUser.idSite) ?? 0;
      final dashboardData = await locator.apiService.getDashboardData(
        idSite: idSite,
        idSociete: int.tryParse(currentUser.idSociete),
      );

      if (!mounted) return;
      setState(() {
        _dashboardData = dashboardData;
        _isLoadingDashboard = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingDashboard = false);
    }
  }

  double _parseDouble(dynamic value) =>
      double.tryParse(value?.toString() ?? '0') ?? 0.0;
  int _parseInt(dynamic value) => int.tryParse(value?.toString() ?? '0') ?? 0;

  String _formatCurrency(double amount) {
    return locator.tauxService.formatPrice(amount);
  }

  String _getUserInitials() {
    final name = locator.authRepository.currentUser?.nomComplet ?? '';
    if (name.isEmpty) return '??';
    List<String> parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.05), color.withOpacity(0.02)],
            ),
            border: Border.all(color: color.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: Colors.grey[400], size: 16),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        onLongPress: () {
          HapticFeedback.mediumImpact();
          if (onLongPress != null) {
            onLongPress();
          } else {
            _showQuickInfo(title);
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.9), color],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 32, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuickInfo(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Option rapide pour : $title'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2C3E50),
      ),
    );
  }

  Widget _buildCartBanner(CartService cartService) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.orange[400]!, Colors.orange[600]!],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.shopping_cart_checkout,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Panier actif',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${cartService.totalQuantity} articles',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CartScreen()),
              ),
              child: Text(
                'VOIR',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
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
        title: Text(
          'Caisse',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 24),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            tooltip: 'Charges',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ChargesScreen()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfilCaissierScreen(),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 15,
                  child: Text(
                    _getUserInitials(),
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF2C3E50),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Consumer<CartService>(
        builder: (context, cartService, child) {
          return RefreshIndicator(
            onRefresh: _loadDashboardData,
            color: const Color(0xFF2C3E50),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner Panier
                  if (cartService.items.isNotEmpty)
                    _buildCartBanner(cartService),

                  // Section Statistiques
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Aujourd\'hui',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2C3E50),
                              ),
                            ),
                            TextButton.icon(
                              icon: const Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                              ),
                              iconAlignment: IconAlignment.end,
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const CaissierDashboardScreen(),
                                ),
                              ),
                              label: Text(
                                'Voir tout',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(0xFF2C3E50),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _isLoadingDashboard
                            ? SizedBox(
                                height: 120,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF2C3E50),
                                  ),
                                ),
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: _buildStatCard(
                                      icon: Icons.trending_up,
                                      title: 'Ventes du jour',
                                      value: _dashboardData != null
                                          ? _formatCurrency(
                                              _parseDouble(
                                                _dashboardData!['ventes']?['chiffreAffaires'],
                                              ),
                                            )
                                          : _formatCurrency(0),
                                      color: Colors.green,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              SalesJournalScreen(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildStatCard(
                                      icon: Icons.inventory_2,
                                      title: 'Stock total',
                                      value: _dashboardData != null
                                          ? '${_parseInt(_dashboardData!['stocks']?['articlesEnStock'])}'
                                          : '0',
                                      color: Colors.blue,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const StockPage(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),

                  // Section Actions
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Actions rapides',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2C3E50),
                          ),
                        ),
                        const SizedBox(height: 16),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.85,
                          children: [
                            _buildActionCard(
                              icon: Icons.receipt_long,
                              title: 'Facturation',
                              subtitle: 'Nouvelle vente',
                              color: Colors.blue,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const FacturationScreen(),
                                ),
                              ),
                            ),
                            _buildActionCard(
                              icon: Icons.history_edu,
                              title: 'Journal',
                              subtitle: 'Historique',
                              color: Colors.green,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SalesJournalScreen(),
                                ),
                              ),
                            ),
                            _buildActionCard(
                              icon: Icons.payment,
                              title: 'Paiements',
                              subtitle: 'Gérer',
                              color: Colors.teal,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const PaiementsScreen(),
                                ),
                              ),
                            ),
                            _buildActionCard(
                              icon: Icons.account_balance_wallet,
                              title: 'Dettes',
                              subtitle: 'Suivi',
                              color: Colors.deepPurple,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const DettesScreen(),
                                ),
                              ),
                            ),
                            _buildActionCard(
                              icon: Icons.store_mall_directory,
                              title: 'Stock',
                              subtitle: 'Gestion',
                              color: Colors.orange,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const StockPage(),
                                ),
                              ),
                            ),
                            _buildActionCard(
                              icon: Icons.assessment,
                              title: 'Rapports',
                              subtitle: 'Analyse',
                              color: Colors.purple,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const VentesPage(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
