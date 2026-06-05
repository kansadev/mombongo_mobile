import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mombongo/services/app_currency_preference.dart';
import 'package:mombongo/ui/screens/profil_screen.dart';
import '../../../services/service_locator.dart';
import '../../../models/site.dart';
import 'package:mombongo/ui/screens/caissier/sales_journal_screen.dart';

class CaissierPerformanceScreen extends StatefulWidget {
  const CaissierPerformanceScreen({super.key});

  @override
  State<CaissierPerformanceScreen> createState() =>
      _CaissierPerformanceScreenState();
}

class _CaissierPerformanceScreenState extends State<CaissierPerformanceScreen> {
  List<Site> _sites = [];
  Site? _selectedSite;
  Map<int, Map<String, dynamic>> _caissiersStats = {};
  Map<String, dynamic>? _resumeGlobal;
  List<Map<String, dynamic>> _performanceQuotidienne = [];
  bool _isLoadingSites = true;
  bool _isLoadingPerformance = false;
  DateTime? _dateDebut;
  DateTime? _dateFin;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  final Color primaryColor = const Color(0xFF2C3E50);
  final Color accentColor = const Color(0xFF3498DB);

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  // --- LOGIQUE ---

  Future<void> _loadSites() async {
    try {
      final currentUser = locator.authRepository.currentUser;
      if (currentUser == null) return;

      final idSociete = int.tryParse(currentUser.idSociete) ?? 0;
      final sites = await locator.apiService.getSitesBySociete(idSociete);

      if (mounted) {
        setState(() {
          _sites = sites;
          _isLoadingSites = false;

          // --- SÉLECTION PAR DÉFAUT DU PREMIER SITE ---
          if (_sites.isNotEmpty && _selectedSite == null) {
            _selectedSite = _sites.first;
          }
        });

        // Si un site a été sélectionné automatiquement, on lance le chargement des stats
        if (_selectedSite != null) {
          _loadPerformance();
        }
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement des sites: $e');
      if (mounted) {
        setState(() => _isLoadingSites = false);
        _showError("Erreur lors du chargement des sites");
      }
    }
  }

  Future<void> _loadPerformance() async {
    if (_selectedSite == null) return;
    setState(() {
      _isLoadingPerformance = true;
    });

    try {
      final response = await locator.apiService
          .getCaissierPerformanceStatistiques(
            idSite: int.tryParse(_selectedSite!.idSite) ?? 0,
            dateDebut: _dateDebut,
            dateFin: _dateFin,
          );

      if (!mounted) return;

      final performanceParCaissier =
          response['performanceParCaissier'] as List? ?? [];
      final Map<int, Map<String, dynamic>> newStats = {};
      for (var perf in performanceParCaissier) {
        final id = int.tryParse(perf['idCaissier']?.toString() ?? '0') ?? 0;
        newStats[id] = Map<String, dynamic>.from(perf);
      }

      setState(() {
        _caissiersStats = newStats;
        _resumeGlobal = response['resumeGlobal'];
        _performanceQuotidienne =
            (response['performanceQuotidienne'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
        _isLoadingPerformance = false;
      });
    } catch (e) {
      _showError("Erreur performance: $e");
      setState(() {
        _isLoadingPerformance = false;
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

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  double _num(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0.0;
  String _formatCdf(dynamic v) {
    final code = AppCurrencyPreference.readCode(locator.databaseService);
    final formatter = AppCurrencyPreference.formatterFor(code);
    final symbol = AppCurrencyPreference.symbolFor(code);
    return '${formatter.format(_num(v))} $symbol';
  }

  // --- WIDGETS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Analyse Performances',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          
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
        onRefresh: () async {
          await _loadSites();
          if (_selectedSite != null) await _loadPerformance();
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildFilters(),
                    if (_selectedSite != null) ...[
                      const SizedBox(height: 16),
                      _buildGlobalSummary(),
                      const SizedBox(height: 16),
                      _buildDailyChartSection(), // Nouvelle section
                      const SizedBox(height: 16),
                      _buildCashierListHeader(),
                    ],
                  ],
                ),
              ),
            ),
            if (_selectedSite != null) _buildCashierSliverList(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _isLoadingSites
                ? const LinearProgressIndicator()
                : DropdownButtonFormField<Site>(
                    isExpanded:
                        true, // <-- AJOUTER CECI : Force le contenu à prendre l'espace disponible
                    value: _selectedSite,
                    hint: const Text("Sélectionner un site"),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.storefront,
                        color: Colors.blue,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      // Optionnel : Réduire un peu le padding interne si l'écran est très petit
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                    items: _sites
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(
                              s.nomSite,
                              overflow: TextOverflow
                                  .ellipsis, // <-- AJOUTER CECI : Coupe le texte avec "..." s'il est trop long
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (s) {
                      setState(() {
                        _selectedSite = s;
                        _caissiersStats.clear();
                      });
                      _loadPerformance();
                    },
                  ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2022),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          _dateDebut = picked.start;
                          _dateFin = picked.end;
                        });
                        _loadPerformance();
                      }
                    },
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _dateDebut == null
                          ? "Toute la période"
                          : "${DateFormat('dd/MM').format(_dateDebut!)} - ${DateFormat('dd/MM').format(_dateFin!)}",
                    ),
                  ),
                ),
                if (_dateDebut != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _dateDebut = null;
                        _dateFin = null;
                      });
                      _loadPerformance();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalSummary() {
    if (_resumeGlobal == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _summaryItem(
                "CA Total",
                _formatCdf(_resumeGlobal!['chiffreAffairesTotal']),
                Icons.payments,
              ),
              _summaryItem(
                "Commandes",
                "${_resumeGlobal!['nombreCommandesTotal']}",
                Icons.receipt,
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _summaryItem(
                "Panier Moyen",
                _formatCdf(_resumeGlobal!['panierMoyenGlobal']),
                Icons.shopping_basket,
              ),
              _summaryItem(
                "Marge",
                _formatCdf(_resumeGlobal!['margeTotale']),
                Icons.trending_up,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(color: Colors.white70)),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDailyChartSection() {
    if (_performanceQuotidienne.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Évolution Journalière (CA)",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _performanceQuotidienne.length,
            itemBuilder: (context, index) {
              final day = _performanceQuotidienne[index];
              return Container(
                width: 120,
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('dd MMM').format(DateTime.parse(day['date'])),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _formatCdf(day['chiffreAffaires']),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCashierListHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Détails par Caissier",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              "${_caissiersStats.length} caissiers",
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: "Rechercher un caissier...",
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
        ),
      ],
    );
  }

  Widget _buildCashierSliverList() {
    final filteredEntries = _caissiersStats.entries
        .where(
          (e) => e.value['nomCaissier'].toString().toLowerCase().contains(
            _searchQuery,
          ),
        )
        .toList();

    if (_isLoadingPerformance)
      return const SliverToBoxAdapter(
        child: Center(child: CircularProgressIndicator()),
      );
    if (filteredEntries.isEmpty)
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: Text("Aucun résultat")),
        ),
      );

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final stats = filteredEntries[index].value;
          return _buildCashierCard(stats);
        }, childCount: filteredEntries.length),
      ),
    );
  }

  Widget _buildCashierCard(Map<String, dynamic> stats) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        backgroundColor: Colors.white,
        collapsedBackgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        leading: CircleAvatar(
          backgroundColor: accentColor.withOpacity(0.1),
          child: Text(
            stats['nomCaissier'][0].toUpperCase(),
            style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          stats['nomCaissier'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          "${stats['nombreCommandes']} commandes • ${_formatCdf(stats['chiffreAffaires'])}",
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                _miniStat(
                  "Articles",
                  "${stats['nombreArticlesVendus']}",
                  Icons.inventory,
                ),
                _miniStat(
                  "Marge",
                  _formatCdf(stats['margeTotale']),
                  Icons.trending_up,
                ),
                _miniStat(
                  "Panier Moy.",
                  _formatCdf(stats['panierMoyen']),
                  Icons.shopping_basket,
                ),
                _miniStat(
                  "Part CA",
                  "${_num(stats['pourcentageCA']).toStringAsFixed(1)}%",
                  Icons.pie_chart,
                ),
              ],
            ),
          ),
          // Button to view journal
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final idCaissier = int.tryParse(stats['idCaissier']?.toString() ?? '0') ?? 0;
                  final nomCaissier = stats['nomCaissier']?.toString() ?? 'Caissier';
                  if (idCaissier > 0) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SalesJournalScreen(
                          idCaissier: idCaissier,
                          nomCaissier: nomCaissier,
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.receipt_long, size: 18),
                label: const Text('Voir le journal des ventes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3498DB),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: accentColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
