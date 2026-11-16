import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mombongo/services/caisse_du_jour_service.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/ui/screens/caissier/dettes_screen.dart';
import 'package:mombongo/ui/screens/caissier/paiements_screen.dart';
import 'package:mombongo/ui/screens/caissier/sales_journal_screen.dart';
import 'package:mombongo/ui/screens/caissier/stock_page.dart';
import 'package:mombongo/ui/screens/finance/paiement_dashboard_screen.dart';
import 'package:mombongo/ui/theme/pos_colors.dart';
import 'package:mombongo/utils/google_fonts_compat.dart';
import 'package:mombongo/utils/pos_money.dart';

/// Accueil du caissier : caisse du jour, accès rapide à la vente,
/// raccourcis et dernières opérations.
class CaisseHomeTab extends StatefulWidget {
  const CaisseHomeTab({super.key, required this.onOpenVente});

  final VoidCallback onOpenVente;

  @override
  State<CaisseHomeTab> createState() => _CaisseHomeTabState();
}

class _CaisseHomeTabState extends State<CaisseHomeTab> {
  CaisseDuJour _caisse = CaisseDuJour.empty;
  int? _dettesCount;
  bool _loading = true;
  DateTime? _updatedAt;

  Timer? _debounce;
  StreamSubscription<bool>? _connectivitySub;
  bool _wasOnline = true;
  int _loadId = 0;

  @override
  void initState() {
    super.initState();
    locator.syncService.addListener(_scheduleRefresh);
    _wasOnline = locator.connectivityService.isOnline;
    _connectivitySub = locator.connectivityService.onStatusChanged.listen((
      online,
    ) {
      if (online && !_wasOnline) _scheduleRefresh();
      _wasOnline = online;
    });
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _connectivitySub?.cancel();
    locator.syncService.removeListener(_scheduleRefresh);
    super.dispose();
  }

  /// Après une vente ou une synchronisation : rechargement groupé.
  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), _load);
  }

  Future<void> _load() async {
    final loadId = ++_loadId;
    if (mounted) setState(() => _loading = true);
    final results = await Future.wait<Object?>([
      CaisseDuJourService.load(),
      CaisseDuJourService.loadDettesCount(),
    ]);
    if (!mounted || loadId != _loadId) return;
    setState(() {
      _caisse = results[0] as CaisseDuJour;
      _dettesCount = results[1] as int?;
      _loading = false;
      _updatedAt = DateTime.now();
    });
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  String get _firstName {
    final name = locator.authRepository.currentUser?.nomComplet.trim() ?? '';
    return name.isEmpty ? 'Caissier' : name.split(' ').first;
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  @override
  Widget build(BuildContext context) {
    final siteName = locator.authRepository.currentUser?.nomSite ?? '';

    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              _Header(
                greeting: '$_greeting, $_firstName',
                title: siteName.isEmpty ? 'Ma caisse' : 'Caisse · $siteName',
              ),
              const SizedBox(height: 18),
              _CaisseCard(
                caisse: _caisse,
                loading: _loading,
                updatedAt: _updatedAt,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: widget.onOpenVente,
                  icon: const Icon(Icons.add_rounded, size: 24),
                  label: Text(
                    'Nouvelle vente',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PosColors.green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _Shortcut(
                      icon: Icons.receipt_long_outlined,
                      label: 'Journal',
                      onTap: () => _open(SalesJournalScreen()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Shortcut(
                      icon: Icons.insights_outlined,
                      label: 'Paiements',
                      onTap: () => _open(const PaiementDashboardScreen()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Shortcut(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Dettes',
                      badge: (_dettesCount ?? 0) > 0 ? '$_dettesCount' : null,
                      onTap: () => _open(const DettesScreen()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Shortcut(
                      icon: Icons.inventory_2_outlined,
                      label: 'Stock',
                      onTap: () => _open(const StockPage()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Dernières opérations',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: PosColors.ink,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _open(const PaiementsScreen()),
                    style: TextButton.styleFrom(
                      foregroundColor: PosColors.green,
                    ),
                    child: const Text('Tout voir'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _RecentList(operations: _caisse.recent, loading: _loading),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.greeting, required this.title});

  final String greeting;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: PosColors.muted,
                ),
              ),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: PosColors.ink,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ListenableBuilder(
          listenable: locator.syncService,
          builder: (context, _) {
            final online = locator.syncService.isOnline;
            final pending = locator.syncService.pendingCount;
            final label = !online
                ? 'Hors ligne'
                : (pending > 0 ? '$pending en attente' : 'En ligne');
            final ok = online && pending == 0;
            final fg = ok ? PosColors.green : PosColors.amber;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: ok ? PosColors.greenSoft : PosColors.amberSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: fg,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: fg,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CaisseCard extends StatelessWidget {
  const _CaisseCard({
    required this.caisse,
    required this.loading,
    required this.updatedAt,
  });

  final CaisseDuJour caisse;
  final bool loading;
  final DateTime? updatedAt;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd/MM').format(DateTime.now());
    final subtitle = !caisse.fromServer && updatedAt != null
        ? '$date · ventes locales uniquement'
        : (updatedAt == null
              ? date
              : '$date · maj ${DateFormat('HH:mm').format(updatedAt!)}');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PosColors.ink,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Encaissé aujourd\'hui',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: PosColors.onInkMuted,
                  ),
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: PosColors.onInkMuted,
                  ),
                )
              else
                Flexible(
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: PosColors.onInkMuted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              PosMoney.format(caisse.total),
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ModeTile(label: 'Espèces', amount: caisse.especes),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ModeTile(label: 'Mobile', amount: caisse.mobile),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ModeTile(
                  label: 'Carte / chèque',
                  amount: caisse.autres,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${caisse.count} ${caisse.count > 1 ? 'encaissements' : 'encaissement'}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: PosColors.onInkMuted,
                  ),
                ),
              ),
              if (caisse.count > 0)
                Flexible(
                  child: Text(
                    'Moyenne ${PosMoney.format(caisse.average)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: PosColors.onInkMuted,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({required this.label, required this.amount});

  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: PosColors.onInkMuted,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              PosMoney.format(amount),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PosColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PosColors.line),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 22, color: PosColors.ink),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: PosColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Positioned(
                  top: -6,
                  right: 2,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: PosColors.terracotta,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      badge!,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentList extends StatelessWidget {
  const _RecentList({required this.operations, required this.loading});

  final List<CaisseOperation> operations;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (operations.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: PosColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PosColors.line),
        ),
        child: Text(
          loading ? 'Chargement…' : 'Aucun encaissement aujourd\'hui',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 13, color: PosColors.muted),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PosColors.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < operations.length; i++)
            _OperationRow(
              op: operations[i],
              showDivider: i < operations.length - 1,
            ),
        ],
      ),
    );
  }
}

class _OperationRow extends StatelessWidget {
  const _OperationRow({required this.op, required this.showDivider});

  final CaisseOperation op;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(op.date);
    final title = op.clientName.isEmpty
        ? op.reference
        : '${op.reference} · ${op.clientName}';
    final details = [
      time,
      if (op.modePaiement.isNotEmpty) op.modePaiement,
      if (op.isAcompte) 'Acompte',
      if (op.isPending) 'En attente de sync',
    ].join(' · ');
    final detailColor = op.isPending
        ? PosColors.amber
        : (op.isAcompte ? PosColors.terracotta : PosColors.muted);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: PosColors.lineSoft))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: PosColors.ink,
                  ),
                ),
                Text(
                  details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 12, color: detailColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            PosMoney.format(op.montant),
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: PosColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
