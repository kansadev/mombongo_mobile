import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/service_locator.dart';
import '../../../models/site.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? _dashboardData;
  List<Site> _sites = [];
  Site? _selectedSite;
  bool _isLoading = true;
  DateTime? _dateDebut;
  DateTime? _dateFin;

  @override
  void initState() {
    super.initState();
    _loadSites();
    _loadDashboardData();
  }

  Future<void> _loadSites() async {
    try {
      final currentUser = locator.authRepository.currentUser;
      if (currentUser == null) return;

      final idSociete = int.tryParse(currentUser.idSociete) ?? 0;
      final sites = await locator.apiService.getSitesBySociete(idSociete);

      if (mounted) {
        setState(() {
          _sites = sites;
        });
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement des sites: $e');
    }
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
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
        dateDebut: _dateDebut,
        dateFin: _dateFin,
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
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du chargement du dashboard: $e'),
          backgroundColor: Colors.red,
        ),
      );
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

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateDebut != null && _dateFin != null
          ? DateTimeRange(start: _dateDebut!, end: _dateFin!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _dateDebut = picked.start;
        _dateFin = picked.end;
      });
      _loadDashboardData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final societe = _dashboardData?['societe'] as Map<String, dynamic>?;
    final resume = _dashboardData?['resume'] as Map<String, dynamic>?;
    final sites = _dashboardData?['sites'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Administrateur'),
        centerTitle: true,
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
       
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sélection du site (si on veut filtrer)
              if (_sites.isNotEmpty) ...[
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<Site>(
                            value: _selectedSite,
                            isDense: true,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Site',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              isDense: true,
                            ),
                            items: [
                              const DropdownMenuItem<Site>(
                                value: null,
                                child: Text(
                                  'Tous',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                              ..._sites.map((site) {
                                return DropdownMenuItem<Site>(
                                  value: site,
                                  child: Text(
                                    site.nomSite,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                );
                              }).toList(),
                            ],
                            onChanged: (Site? site) {
                              setState(() {
                                _selectedSite = site;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.calendar_today, size: 18),
                          onPressed: _selectDateRange,
                          tooltip: 'Période',
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                        ),
                        if (_dateDebut != null || _dateFin != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              setState(() {
                                _dateDebut = null;
                                _dateFin = null;
                              });
                              _loadDashboardData();
                            },
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Informations société
              if (societe != null)
                Card(
                  elevation: 2,
                  color: const Color(0xFF2C3E50),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.business, color: Colors.white, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                societe['nomSociete']?.toString() ?? 'N/A',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (societe['rccm'] != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'RCCM: ${societe['rccm']}',
                            style: TextStyle(color: Colors.white.withOpacity(0.9)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Résumé global
              if (resume != null) ...[
                const Text(
                  'Résumé Global',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        title: 'CA Total',
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
                        title: 'Ventes',
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
                        title: 'Valeur Stock',
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
                const SizedBox(height: 24),
              ],

              // Détails par site
              const Text(
                'Détails par Site',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (sites.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.store_mall_directory, size: 60, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun site trouvé',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...sites.map((siteData) {
                  final site = siteData['site'] as Map<String, dynamic>?;
                  final ventes = siteData['ventes'] as Map<String, dynamic>?;
                  final stocks = siteData['stocks'] as Map<String, dynamic>?;
                  final paiements = siteData['paiements'] as Map<String, dynamic>?;
                  final alertesStocks = siteData['alertesStocks'] as List<dynamic>? ?? [];

                  if (site == null) return const SizedBox.shrink();

                  // Filtrer par site sélectionné si nécessaire
                  if (_selectedSite != null) {
                    final siteId = int.tryParse(site['idSite']?.toString() ?? '0') ?? 0;
                    final selectedId = int.tryParse(_selectedSite!.idSite) ?? 0;
                    if (siteId != selectedId) return const SizedBox.shrink();
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    child: ExpansionTile(
                      leading: const Icon(Icons.store, color: Color(0xFF3498DB)),
                      title: Text(
                        site['nomSite']?.toString() ?? 'N/A',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        '${site['province'] ?? ''} - ${site['ville'] ?? ''}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Ventes
                              if (ventes != null) ...[
                                const Text(
                                  'Ventes',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildSiteStatCard(
                                        title: 'CA',
                                        value: NumberFormat.currency(
                                          symbol: 'CDF ',
                                          decimalDigits: 0,
                                        ).format(_parseDouble(ventes['chiffreAffaires'] ?? 0)),
                                        color: Colors.green,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildSiteStatCard(
                                        title: 'Ventes',
                                        value: _parseInt(ventes['nombreTotalVentes'] ?? 0).toString(),
                                        color: Colors.blue,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildSiteStatCard(
                                        title: 'Qté vendue',
                                        value: NumberFormat('#,##0.00').format(_parseDouble(ventes['quantiteTotaleVendue'] ?? 0)),
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Stocks
                              if (stocks != null) ...[
                                const Text(
                                  'Stocks',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildSiteStatCard(
                                        title: 'Articles',
                                        value: _parseInt(stocks['nombreArticlesTotal'] ?? 0).toString(),
                                        color: Colors.purple,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildSiteStatCard(
                                        title: 'En stock',
                                        value: _parseInt(stocks['articlesEnStock'] ?? 0).toString(),
                                        color: Colors.green,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildSiteStatCard(
                                        title: 'Valeur',
                                        value: NumberFormat.currency(
                                          symbol: 'CDF ',
                                          decimalDigits: 0,
                                        ).format(_parseDouble(stocks['valeurStockTotal'] ?? 0)),
                                        color: Colors.teal,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Paiements
                              if (paiements != null) ...[
                                const Text(
                                  'Paiements',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildSiteStatCard(
                                        title: 'Total',
                                        value: NumberFormat.currency(
                                          symbol: 'CDF ',
                                          decimalDigits: 0,
                                        ).format(_parseDouble(paiements['montantTotalPaiements'] ?? 0)),
                                        color: Colors.orange,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildSiteStatCard(
                                        title: 'Nombre',
                                        value: _parseInt(paiements['nombreTotalPaiements'] ?? 0).toString(),
                                        color: Colors.blue,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildSiteStatCard(
                                        title: 'Moyen',
                                        value: NumberFormat.currency(
                                          symbol: 'CDF ',
                                          decimalDigits: 0,
                                        ).format(_parseDouble(paiements['montantMoyenPaiement'] ?? 0)),
                                        color: Colors.purple,
                                      ),
                                    ),
                                  ],
                                ),
                                if (paiements['paiementsParMethode'] != null &&
                                    (paiements['paiementsParMethode'] as List).isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Par méthode',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...(paiements['paiementsParMethode'] as List).map((methode) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            methode['methode']?.toString() ?? 'N/A',
                                            style: const TextStyle(fontWeight: FontWeight.w500),
                                          ),
                                          Text(
                                            '${methode['nombre']} - ${NumberFormat.currency(symbol: 'CDF ', decimalDigits: 0).format(_parseDouble(methode['montant'] ?? 0))}',
                                            style: TextStyle(color: Colors.grey[600]),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ],
                                const SizedBox(height: 16),
                              ],

                              // Alertes stocks
                              if (alertesStocks.isNotEmpty) ...[
                                const Text(
                                  'Alertes Stocks',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...alertesStocks.map((alerte) {
                                  return Card(
                                    color: Colors.red[50],
                                    child: ListTile(
                                      leading: const Icon(Icons.warning, color: Colors.red),
                                      title: Text(alerte['libelle']?.toString() ?? 'N/A'),
                                      subtitle: Text('Stock: ${alerte['quantiteStock'] ?? 0} / Seuil: ${alerte['seuilAlerte']}'),
                                    ),
                                  );
                                }).toList(),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSiteStatCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
