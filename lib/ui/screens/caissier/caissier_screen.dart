import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/ui/screens/caissier/profil.dart';
import 'package:mombongo/ui/screens/caissier/facturation_screen.dart';
import 'package:mombongo/ui/screens/caissier/sales_journal_screen.dart';
import 'package:mombongo/ui/screens/caissier/stock_page.dart';
import 'package:mombongo/ui/screens/caissier/rapport_vente_caissier.dart';
import 'package:mombongo/ui/screens/caissier/paiements_screen.dart';
import 'package:mombongo/ui/screens/caissier/dettes_screen.dart';
import 'package:mombongo/ui/widgets/offline_status_banner.dart';
import 'package:mombongo/utils/google_fonts_compat.dart';

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
      if (kDebugMode) {
        debugPrint('Préchargement catalogue: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          const OfflineStatusBanner(),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _tabs),
          ),
        ],
      ),
      bottomNavigationBar: Material(
        color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(isDark ? 0.45 : 0.12),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            height: 64,
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            indicatorColor: colorScheme.primary.withOpacity(isDark ? 0.28 : 0.16),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              NavigationDestination(
                icon: Icon(
                  Icons.home_outlined,
                  color: colorScheme.onSurface.withOpacity(0.55),
                ),
                selectedIcon: Icon(
                  Icons.home_rounded,
                  color: colorScheme.primary,
                ),
                label: 'Accueil',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.point_of_sale_outlined,
                  color: colorScheme.onSurface.withOpacity(0.55),
                ),
                selectedIcon: Icon(
                  Icons.point_of_sale,
                  color: colorScheme.primary,
                ),
                label: 'Vente',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.grid_view_outlined,
                  color: colorScheme.onSurface.withOpacity(0.55),
                ),
                selectedIcon: Icon(
                  Icons.grid_view_rounded,
                  color: colorScheme.primary,
                ),
                label: 'Plus',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.person_outline,
                  color: colorScheme.onSurface.withOpacity(0.55),
                ),
                selectedIcon: Icon(
                  Icons.person,
                  color: colorScheme.primary,
                ),
                label: 'Profil',
              ),
            ],
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
          ? const Color(0xFF0F1419)
          : const Color(0xFFF4F6FA),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadDashboard,
          color: colorScheme.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // En-tête avec salutation
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: isDark
                              ? Colors.white.withOpacity(0.72)
                              : const Color(0xFF5B6472),
                          fontWeight: FontWeight.w500,
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
                              : const Color(0xFF111827),
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Carte de solde
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

              // Actions rapides
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
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
                              : const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _QuickActionDashen(
                              icon: Icons.history_edu_rounded,
                              label: 'Journal',
                              color: const Color(0xFF3B82F6),
                              onTap: () => _open(context, SalesJournalScreen()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _QuickActionDashen(
                              icon: Icons.payment_rounded,
                              label: 'Paiements',
                              color: const Color(0xFF10B981),
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
                              color: const Color(0xFFEF4444),
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
        color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : const Color(0xFFE8ECF2),
        ),
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
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : const Color(0xFFE8ECF2),
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(isDark ? 0.22 : 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF111827),
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

  static const _accentColors = <Color>[
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFF97316),
    Color(0xFF8B5CF6),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = <_PlusItem>[
      _PlusItem(
        Icons.history_edu_rounded,
        'Journal des ventes',
        'Historique des ventes du jour',
        () => SalesJournalScreen(),
      ),
      _PlusItem(
        Icons.payment_rounded,
        'Paiements',
        'Suivi des encaissements',
        () => const PaiementsScreen(),
      ),
      _PlusItem(
        Icons.account_balance_wallet_rounded,
        'Dettes & acomptes',
        'Crédits et acomptes clients',
        () => const DettesScreen(),
      ),
      _PlusItem(
        Icons.inventory_2_rounded,
        'Stock',
        'Disponibilité des articles',
        () => const StockPage(),
      ),
      _PlusItem(
        Icons.assessment_rounded,
        'Rapports',
        'Synthèse de performance',
        () => const VentesPage(),
      ),
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1419) : const Color(0xFFF4F6FA),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          children: [
            Text(
              'Plus',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Accès rapide aux modules',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface.withOpacity(isDark ? 0.72 : 0.62),
              ),
            ),
            const SizedBox(height: 24),
            ...items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final accent = _accentColors[index % _accentColors.length];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
                  elevation: isDark ? 0 : 1.5,
                  shadowColor: Colors.black.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => item.builder()),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : const Color(0xFFE8ECF2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: accent.withOpacity(isDark ? 0.22 : 0.14),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(item.icon, color: accent, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.label,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.subtitle,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: colorScheme.onSurface
                                        .withOpacity(isDark ? 0.65 : 0.55),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: colorScheme.onSurface.withOpacity(0.45),
                          ),
                        ],
                      ),
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
  final String subtitle;
  final Widget Function() builder;

  _PlusItem(this.icon, this.label, this.subtitle, this.builder);
}
