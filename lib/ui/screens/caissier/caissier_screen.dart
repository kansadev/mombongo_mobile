import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/ui/screens/caissier/profil.dart';
import 'package:mombongo/ui/screens/caissier/facturation_screen.dart';
import 'package:mombongo/ui/screens/caissier/sales_journal_screen.dart';
import 'package:mombongo/ui/screens/caissier/stock_page.dart';
import 'package:mombongo/ui/screens/caissier/rapport_vente_caissier.dart';
import 'package:mombongo/ui/screens/caissier/paiements_screen.dart';
import 'package:mombongo/ui/screens/caissier/dettes_screen.dart';
import 'package:mombongo/ui/widgets/offline_status_banner.dart';

/// Shell caissier : 4 onglets (Accueil, Vente, Plus, Profil).
/// Le panier reste dans [FacturationScreen].
class CaissierScreen extends StatefulWidget {
  const CaissierScreen({super.key});

  @override
  State<CaissierScreen> createState() => _CaissierScreenState();
}

class _CaissierScreenState extends State<CaissierScreen> {
  int _currentIndex = 0;

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      _CaissierHomeTab(onOpenVente: () => setState(() => _currentIndex = 1)),
      const FacturationScreen(),
      const _CaissierPlusTab(),
      const ProfilCaissierScreen(),
    ];
    _preloadCatalogue();
  }

  Future<void> _preloadCatalogue() async {
    try {
      final currentUser = locator.authRepository.currentUser;
      if (currentUser == null) return;
      final idSite = int.tryParse(currentUser.idSite) ?? 0;
      if (idSite <= 0) return;
      await locator.cacheStrategy.preloadStockArticlesForSite(idSite);
    } catch (e) {
      debugPrint('Préchargement catalogue: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          const OfflineStatusBanner(),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _tabs),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Material(
              elevation: 10,
              color: colorScheme.surface,
              child: NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (i) =>
                    setState(() => _currentIndex = i),
                backgroundColor: Colors.transparent,
                indicatorColor: colorScheme.secondary.withOpacity(0.2),
                labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'Accueil',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.point_of_sale_outlined),
                    selectedIcon: Icon(Icons.point_of_sale),
                    label: 'Vente',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.grid_view_outlined),
                    selectedIcon: Icon(Icons.grid_view_rounded),
                    label: 'Plus',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: 'Profil',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Accueil immersif - Style Dashen Super App
// ---------------------------------------------------------------------------

class _CaissierHomeTab extends StatefulWidget {
  final VoidCallback onOpenVente;

  const _CaissierHomeTab({required this.onOpenVente});

  @override
  State<_CaissierHomeTab> createState() => _CaissierHomeTabState();
}

class _CaissierHomeTabState extends State<_CaissierHomeTab> {
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;
  int _lastLocalRefreshMs = 0;
  StreamSubscription<bool>? _connectivitySub;
  bool _lastConnectivityOnline = true;
  int _lastServerReconcileMs = 0;

  @override
  void initState() {
    super.initState();
    locator.syncService.addListener(_handleSyncOrSaleChanged);
    _lastConnectivityOnline = locator.connectivityService.isOnline;
    _connectivitySub = locator.connectivityService.onStatusChanged.listen(
      (online) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        if (online && !_lastConnectivityOnline) {
          // Reconciliation uniquement lors du rétablissement de connexion.
          if (nowMs - _lastServerReconcileMs > 1000) {
            _lastServerReconcileMs = nowMs;
            _loadDashboard();
          }
        }
        _lastConnectivityOnline = online;
      },
    );
    _loadDashboard();
    _refreshDashboardFromLocalOptimistic();
  }

  Future<void> _loadDashboard() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = locator.authRepository.currentUser;
      if (user == null) throw Exception('Non connecté');
      final idSite = int.tryParse(user.idSite) ?? 0;
      final data = await locator.apiService.getDashboardData(
        idSite: idSite,
        idSociete: int.tryParse(user.idSociete),
      );
      if (!mounted) return;
      setState(() {
        _dashboardData = data;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _handleSyncOrSaleChanged() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastLocalRefreshMs < 500) return;
    _lastLocalRefreshMs = nowMs;
    _refreshDashboardFromLocalOptimistic();
  }

  void _refreshDashboardFromLocalOptimistic() {
    if (!mounted) return;
    try {
      final user = locator.authRepository.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      final idUtilisateur = int.tryParse(user.idUtilisateur) ?? 0;
      final idSite = int.tryParse(user.idSite) ?? 0;

      final ventes = locator.databaseService.getVentes().cast<dynamic>();
      double chiffreAffaires = 0.0;

      for (final v in ventes) {
        try {
          final vUtilisateur = (v as dynamic).idUtilisateur;
          final vDate = (v as dynamic).dateCommande;
          if (vUtilisateur != idUtilisateur) continue;
          if (vDate is DateTime &&
              vDate.year == now.year &&
              vDate.month == now.month &&
              vDate.day == now.day) {
            final montant = (v as dynamic).montantTotal;
            if (montant is num) chiffreAffaires += montant.toDouble();
          }
        } catch (_) {}
      }

      int articlesEnStock = 0;
      if (idSite > 0) {
        final stockArticles =
            locator.databaseService.getStockArticlesBySite(idSite).cast<dynamic>();
        articlesEnStock = stockArticles
            .where((a) {
              try {
                final q = (a as dynamic).quantiteStock;
                return q is num && q > 0;
              } catch (_) {
                return false;
              }
            })
            .length;
      }

      setState(() {
        _dashboardData = {
          'ventes': {'chiffreAffaires': chiffreAffaires},
          'stocks': {'articlesEnStock': articlesEnStock},
        };
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    locator.syncService.removeListener(_handleSyncOrSaleChanged);
    super.dispose();
  }

  double _parseDouble(dynamic value) =>
      double.tryParse(value?.toString() ?? '0') ?? 0.0;

  String _formatCurrency(double amount) =>
      locator.tauxService.formatPrice(amount);

  String get _firstName {
    final name = locator.authRepository.currentUser?.nomComplet ?? '';
    if (name.trim().isEmpty) return 'Caissier';
    return name.trim().split(' ').first;
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final ventes = _formatCurrency(
      _parseDouble(_dashboardData?['ventes']?['chiffreAffaires']),
    );
    final totalVentes = _parseDouble(
      _dashboardData?['ventes']?['chiffreAffaires'],
    );
    final budget = totalVentes > 0 ? totalVentes * 0.15 : 0.0;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF5F7FA),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadDashboard,
          color: isDark ? Colors.white : colorScheme.secondary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // En-tête avec salutation et date
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: isDark ? Colors.white60 : Colors.grey[600],
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _firstName,
                            style: GoogleFonts.poppins(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A1A2E),
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                     
                    ],
                  ),
                ),
              ),

              // Carte de solde - Style Dashen
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: _isLoading
                      ? _buildShimmerCard(isDark)
                      : _buildBalanceCard(
                          isDark,
                          colorScheme,
                          _firstName,
                          ventes,
                          budget,
                        ),
                ),
              ),

              // Actions rapides - Style Dashen
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Actions rapides',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _QuickActionDashen(
                              icon: Icons.history_edu_rounded,
                              label: 'Journal',
                              color: const Color(0xFF6C5CE7),
                              onTap: () => _open(context, SalesJournalScreen()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _QuickActionDashen(
                              icon: Icons.payment_rounded,
                              label: 'Paiements',
                              color: const Color(0xFF00B894),
                              onTap: () =>
                                  _open(context, const PaiementsScreen()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _QuickActionDashen(
                              icon: Icons.account_balance_wallet_rounded,
                              label: 'Dettes',
                              color: const Color(0xFFB42318),
                              onTap: () => _open(context, const DettesScreen()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _QuickActionDashen(
                              icon: Icons.inventory_2_rounded,
                              label: 'Stock',
                              color: const Color(0xFFF97316),
                              onTap: () => _open(context, const StockPage()),
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

  Widget _buildShimmerCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildBalanceCard(
    bool isDark,
    ColorScheme colorScheme,
    String firstName,
    String ventes,
    double budget,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1E293B),
                  const Color(0xFF2D3748),
                  const Color(0xFF1A202C),
                ]
              : [
                  const Color(0xFF1A1A2E),
                  const Color(0xFF16213E),
                  const Color(0xFF0F3460),
                ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1A2E).withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ventes du jour',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white60,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            ventes,
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 16),
          Divider(color: Colors.white.withOpacity(0.15), height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.pie_chart_outline_rounded,
                color: Colors.white54,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Budget',
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.white54),
              ),
              const SizedBox(width: 16),
              Text(
                budget > 0 ? _formatCurrency(budget) : '—',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                width: 80,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  widthFactor: 0.6,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF00B894),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

// Style Dashen - Actions rapides avec icônes arrondies
class _QuickActionDashen extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionDashen({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.grey.shade100,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Onglet Plus
// ---------------------------------------------------------------------------

class _CaissierPlusTab extends StatelessWidget {
  const _CaissierPlusTab();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final items = <_PlusItem>[
      _PlusItem(
        Icons.history_edu_rounded,
        'Journal des ventes',
        () => SalesJournalScreen(),
      ),
      _PlusItem(
        Icons.payment_rounded,
        'Paiements',
        () => const PaiementsScreen(),
      ),
      _PlusItem(
        Icons.account_balance_wallet_rounded,
        'Dettes & acomptes',
        () => const DettesScreen(),
      ),
      _PlusItem(Icons.inventory_2_rounded, 'Stock', () => const StockPage()),
      _PlusItem(Icons.assessment_rounded, 'Rapports', () => const VentesPage()),
    ];

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            Text(
              'Plus',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Accès rapide aux modules',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: colorScheme.onSurface.withOpacity(0.55),
              ),
            ),
            const SizedBox(height: 24),
            ...items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(14),
                  child: ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => item.builder()),
                      );
                    },
                    leading: Icon(item.icon, color: colorScheme.secondary),
                    title: Text(
                      item.label,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _PlusItem {
  final IconData icon;
  final String label;
  final Widget Function() builder;

  _PlusItem(this.icon, this.label, this.builder);
}
