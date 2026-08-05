import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mombongo/services/app_currency_preference.dart';
import 'package:mombongo/services/service_locator.dart';

class VentesPage extends StatefulWidget {
  const VentesPage({super.key});

  @override
  State<VentesPage> createState() => _VentesPageState();
}

class _VentesPageState extends State<VentesPage> {
  String _selectedPeriod = "Aujourd'hui";
  bool _isLoading = true;
  String? _errorMessage;

  List<dynamic> _ventes = [];
  Map<String, dynamic>? _resume;
  String _nomSite = '';

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
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
      final idUtilisateur = int.tryParse(currentUser.idUtilisateur) ?? 0;

      _nomSite = currentUser.nomSite;

      // Calculer les dates selon la période sélectionnée
      DateTime? dateDebut;
      DateTime? dateFin;

      final now = DateTime.now();
      switch (_selectedPeriod) {
        case "Aujourd'hui":
          dateDebut = DateTime(now.year, now.month, now.day);
          dateFin = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'Cette semaine':
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          dateDebut = DateTime(
            startOfWeek.year,
            startOfWeek.month,
            startOfWeek.day,
          );
          dateFin = now;
          break;
        case 'Ce mois':
          dateDebut = DateTime(now.year, now.month, 1);
          dateFin = now;
          break;
      }

      // Charger les données depuis l'API
      final reportData = await locator.apiService.getCaissierPerformanceJournal(
        idSite: idSite,
        idUtilisateur: idUtilisateur,
        dateDebut: dateDebut,
        dateFin: dateFin,
      );

      if (!mounted) return;

      setState(() {
        _ventes = reportData['ventes'] ?? [];
        _resume = reportData['resume'] ?? {};
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement du rapport: $e');
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Erreur lors du chargement: $e';
        _isLoading = false;
      });
    }
  }

  void _onPeriodChanged(String period) {
    setState(() {
      _selectedPeriod = period;
    });
    _loadReportData();
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

  String _formatCurrency(double amount) {
    return locator.tauxService.formatPrice(amount);
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C3E50),
        title: const Text(
          'RAPPORT VENTES',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadReportData,
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Chargement du rapport...'),
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
                      onPressed: _loadReportData,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête avec le site
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2C3E50), Color(0xFF34495E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2C3E50).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.store,
                                color: Colors.white70,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _nomSite,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Période',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedPeriod,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Boutons de période avec style moderne
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildPeriodButton("Aujourd'hui", Icons.today),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildPeriodButton('Cette semaine', Icons.date_range),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildPeriodButton('Ce mois', Icons.calendar_month),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Statistiques principales avec meilleures cartes
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Montant Total',
                            _formatCurrency(_parseDouble(_resume?['totalMontant'])),
                            const Color(0xFF3498DB),
                            Icons.account_balance_wallet,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Ventes',
                            '${_resume?['nombreVentes'] ?? '0'}',
                            const Color(0xFFE74C3C),
                            Icons.receipt_long,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Articles',
                            _parseDouble(_resume?['totalQuantite']).toStringAsFixed(0),
                            const Color(0xFF2ECC71),
                            Icons.inventory_2,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Section Toutes les ventes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Historique des ventes',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3498DB).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_ventes.length} articles',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3498DB),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Liste des ventes
                    if (_ventes.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 64,
                                color: Color(0xFFBDC3C7),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Aucune vente enregistrée',
                                style: TextStyle(
                                  color: Color(0xFF7F8C8D),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'pour la période sélectionnée',
                                style: TextStyle(
                                  color: Color(0xFFBDC3C7),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._ventes.asMap().entries.map((entry) {
                        final index = entry.key;
                        final vente = entry.value;
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index < _ventes.length - 1 ? 12 : 0,
                          ),
                          child: _buildVenteCard(vente),
                        );
                      }),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildPeriodButton(String text, IconData icon) {
    final isSelected = _selectedPeriod == text;
    return ElevatedButton(
      onPressed: () => _onPeriodChanged(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? const Color(0xFF2C3E50)
            : Colors.white,
        foregroundColor: isSelected ? Colors.white : const Color(0xFF2C3E50),
        elevation: isSelected ? 2 : 0,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isSelected ? const Color(0xFF2C3E50) : Colors.grey[300]!,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    Color borderColor,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border(
                top: BorderSide(color: borderColor, width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: borderColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: borderColor, size: 20),
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: borderColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVenteCard(dynamic vente) {
    final libelle = vente['libelle'] ?? 'N/A';
    final quantite = _parseDouble(vente['quantite']);
    final prixUnitaire = _parseDouble(vente['prixUnitaire']);
    final total = _parseDouble(vente['total']);
    final dateCreation = vente['dateCreation'] ?? '';
    final prixAchat = _parseDouble(vente['prixAchat']);
    final marge = total - (prixAchat * quantite);
    final margePercent = prixAchat > 0 ? (marge / (prixAchat * quantite) * 100) : 0.0;
    
    // Déterminer la couleur selon la marge
    Color margeColor;
    String margeLabel;
    if (marge > 0) {
      margeColor = const Color(0xFF27AE60);
      margeLabel = '+${_formatCurrency(marge)} (+${margePercent.toStringAsFixed(1)}%)';
    } else if (marge < 0) {
      margeColor = const Color(0xFFE74C3C);
      margeLabel = '${_formatCurrency(marge)} (${margePercent.toStringAsFixed(1)}%)';
    } else {
      margeColor = const Color(0xFF95A5A6);
      margeLabel = '0 (0%)';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge de commande
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3498DB).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.receipt,
                            size: 14,
                            color: Color(0xFF3498DB),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '#${vente['idCommande'] ?? vente['idVente'] ?? vente['id'] ?? 'N/A'}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF3498DB),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Badge de marge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: margeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            marge > 0 ? Icons.trending_up : marge < 0 ? Icons.trending_down : Icons.trending_flat,
                            size: 12,
                            color: margeColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            margeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: margeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Nom de l'article
                Text(
                  libelle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                
                // Détails
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildDetailItem(
                          'Qté',
                          quantite.toStringAsFixed(0),
                          Icons.shopping_bag_outlined,
                        ),
                      ),
                      Container(
                        height: 30,
                        width: 1,
                        color: Colors.grey[300],
                      ),
                      Expanded(
                        child: _buildDetailItem(
                          'Prix',
                          _formatCurrency(prixUnitaire),
                          Icons.tag,
                        ),
                      ),
                      Container(
                        height: 30,
                        width: 1,
                        color: Colors.grey[300],
                      ),
                      Expanded(
                        child: _buildDetailItem(
                          'Total',
                          _formatCurrency(total),
                          Icons.account_balance_wallet,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                
                // Date
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(dateCreation),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[500],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
        ),
      ],
    );
  }

  Widget _buildVenteInfo(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
