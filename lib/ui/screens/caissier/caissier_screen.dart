import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/ui/screens/caissier/profil.dart';
import 'package:mombongo/ui/screens/caissier/pos/caisse_home_tab.dart';
import 'package:mombongo/ui/screens/caissier/pos/vente_screen.dart';
import 'package:mombongo/ui/screens/caissier/sales_journal_screen.dart';
import 'package:mombongo/ui/screens/caissier/stock_page.dart';
import 'package:mombongo/ui/screens/caissier/rapport_vente_caissier.dart';
import 'package:mombongo/ui/screens/caissier/paiements_screen.dart';
import 'package:mombongo/ui/screens/caissier/dettes_screen.dart';
import 'package:mombongo/ui/screens/finance/paiement_dashboard_screen.dart';
import 'package:mombongo/services/cart_service.dart';
import 'package:mombongo/ui/theme/pos_colors.dart';
import 'package:mombongo/ui/widgets/offline_status_banner.dart';
import 'package:mombongo/ui/widgets/pos/pos_bottom_nav.dart';
import 'package:provider/provider.dart';
import 'package:mombongo/utils/google_fonts_compat.dart';

/// Shell caissier : 4 onglets (Accueil, Vente, Plus, Profil).
/// Le parcours de vente est dans [VenteScreen] (catalogue → encaissement).
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
      CaisseHomeTab(onOpenVente: () => setState(() => _currentIndex = 1)),
      VenteScreen(onGoHome: () => setState(() => _currentIndex = 0)),
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
    return Scaffold(
      backgroundColor: PosColors.background,
      body: Column(
        children: [
          const OfflineStatusBanner(),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _tabs),
          ),
        ],
      ),
      bottomNavigationBar: Consumer<CartService>(
        builder: (context, cart, _) {
          final inCart = cart.totalQuantity;
          return PosBottomNav(
            currentIndex: _currentIndex,
            onSelect: (i) => setState(() => _currentIndex = i),
            items: [
              const PosNavItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                label: 'Accueil',
              ),
              PosNavItem(
                icon: Icons.shopping_cart_outlined,
                selectedIcon: Icons.shopping_cart_rounded,
                label: 'Vente',
                badge: inCart > 0 ? (inCart > 99 ? '99+' : '$inCart') : null,
              ),
              const PosNavItem(
                icon: Icons.grid_view_outlined,
                selectedIcon: Icons.grid_view_rounded,
                label: 'Plus',
              ),
              const PosNavItem(
                icon: Icons.person_outline,
                selectedIcon: Icons.person_rounded,
                label: 'Profil',
              ),
            ],
          );
        },
      ),
    );
  }
}

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
        Icons.dashboard_rounded,
        'Dashboard paiements',
        'Synthèse des encaissements',
        () => const PaiementDashboardScreen(),
      ),
      _PlusItem(
        Icons.payment_rounded,
        'Historique paiements',
        'Liste détaillée des paiements',
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
      backgroundColor: isDark
          ? const Color(0xFF0F1419)
          : const Color(0xFFF4F6FA),
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
                                    color: colorScheme.onSurface.withOpacity(
                                      isDark ? 0.65 : 0.55,
                                    ),
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
