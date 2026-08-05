import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:mombongo/services/app_currency_preference.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/ui/screens/profil_screen.dart';

class RapportsFinanciersScreen extends StatefulWidget {
  const RapportsFinanciersScreen({super.key});

  @override
  State<RapportsFinanciersScreen> createState() => _RapportsFinanciersScreenState();
}

class _RapportsFinanciersScreenState extends State<RapportsFinanciersScreen> {
  Map<String, dynamic>? _rapportData;
  bool _isLoading = true;
  String? _errorMessage;
  
  // Date range
  DateTime? _dateDebut;
  DateTime? _dateFin;

  @override
  void initState() {
    super.initState();
    // Default to current month
    final now = DateTime.now();
    _dateDebut = DateTime(now.year, now.month, 1);
    _dateFin = now;
    _loadRapports();
  }

  Future<void> _loadRapports() async {
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
      final idSociete = int.tryParse(currentUser.idSociete) ?? 0;

      if (idSite == 0 || idSociete == 0) {
        throw Exception('ID du site ou de la societe invalide');
      }

      final rapport = await locator.apiService.getRapportsFinanciers(
        idSite: idSite,
        idSociete: idSociete,
        dateDebut: _dateDebut,
        dateFin: _dateFin,
      );

      if (!mounted) return;

      setState(() {
        _rapportData = rapport;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement des rapports: $e');
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Erreur lors du chargement des rapports: $e';
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
    return AppCurrencyPreference.formatCurrency(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Rapports Financiers'),
        centerTitle: true,
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDateRange,
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
        onRefresh: _loadRapports,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
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
                          onPressed: _loadRapports,
                          child: const Text('Reessayer'),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date range info
                        _buildDateRangeInfo(),
                        const SizedBox(height: 16),
                        
                        // Site info
                        _buildSiteInfo(),
                        const SizedBox(height: 24),
                        
                        // Chiffre d'affaires section
                        _buildSectionTitle('Chiffre d\'affaires'),
                        _buildChiffreAffairesCard(),
                        const SizedBox(height: 24),
                        
                        // Marges section
                        _buildSectionTitle('Marges'),
                        _buildMargesCard(),
                        const SizedBox(height: 24),
                        
                        // Coûts section
                        _buildSectionTitle('Coûts'),
                        _buildCoutsCard(),
                        const SizedBox(height: 24),
                        
                        // Indicateurs financiers
                        _buildSectionTitle('Indicateurs Financiers'),
                        _buildIndicateursCard(),
                        const SizedBox(height: 24),
                        
                        // Visualizations
                        _buildSectionTitle('Visualisations'),
                        _buildVisualizations(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildDateRangeInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.date_range, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Text(
            _dateDebut != null && _dateFin != null
                ? 'Du ${DateFormat('dd/MM/yyyy').format(_dateDebut!)} au ${DateFormat('dd/MM/yyyy').format(_dateFin!)}'
                : 'Periode: Tout',
            style: TextStyle(
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteInfo() {
    final site = _rapportData?['site'] as Map<String, dynamic>?;
    if (site == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2C3E50).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.store, color: Color(0xFF2C3E50)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  site['nomSite']?.toString() ?? 'Site',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${site['ville'] ?? ''}, ${site['commune'] ?? ''}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Color(0xFF2C3E50),
        ),
      ),
    );
  }

  Widget _buildChiffreAffairesCard() {
    final ca = _rapportData?['chiffreAffaires'] as Map<String, dynamic>?;
    if (ca == null) return const SizedBox.shrink();
    
    final total = _parseDouble(ca['total']);
    final nombreVentes = _parseInt(ca['nombreVentes']);
    final panierMoyen = _parseDouble(ca['panierMoyen']);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade600, Colors.green.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Chiffre d\'affaires',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(total),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniStat('Ventes', '$nombreVentes'),
              Container(width: 1, height: 30, color: Colors.white30),
              _buildMiniStat('Panier moy.', _formatCurrency(panierMoyen)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMargesCard() {
    final marges = _rapportData?['marges'] as Map<String, dynamic>?;
    if (marges == null) return const SizedBox.shrink();
    
    final margeBrute = _parseDouble(marges['margeBrute']);
    final tauxMargeBrute = _parseDouble(marges['tauxMargeBrute']);
    final margeNette = _parseDouble(marges['margeNette']);
    final tauxMargeNet = _parseDouble(marges['tauxMargeNet']);
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    label: 'Marge brute',
                    value: _formatCurrency(margeBrute),
                    percentage: '${tauxMargeBrute.toStringAsFixed(1)}%',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    label: 'Marge nette',
                    value: _formatCurrency(margeNette),
                    percentage: '${tauxMargeNet.toStringAsFixed(1)}%',
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Gauge/Semi-circle chart for margins
            _buildGaugeChart(
              margeBrute: margeBrute,
              margeNette: margeNette,
              tauxMargeBrute: tauxMargeBrute,
              tauxMargeNet: tauxMargeNet,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGaugeChart({
    required double margeBrute,
    required double margeNette,
    required double tauxMargeBrute,
    required double tauxMargeNet,
  }) {
    final total = margeBrute + margeNette;
    if (total <= 0) {
      return const Center(child: Text('Aucune donnee disponible'));
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'Taux de marge',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          // Camembert pour les marges
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 50,
                sections: [
                  PieChartSectionData(
                    color: Colors.blue,
                    value: margeBrute,
                    title: '${tauxMargeBrute.toStringAsFixed(1)}%',
                    titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    radius: 60,
                  ),
                  PieChartSectionData(
                    color: Colors.green,
                    value: margeNette,
                    title: '${tauxMargeNet.toStringAsFixed(1)}%',
                    titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    radius: 60,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem('Marge brute', Colors.blue),
              _buildLegendItem('Marge nette', Colors.green),
            ],
          ),
          const SizedBox(height: 16),
          // Comparative bars
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Brute', style: TextStyle(fontSize: 12)),
                        Text('${tauxMargeBrute.toStringAsFixed(1)}%', 
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (tauxMargeBrute / 100).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Nette', style: TextStyle(fontSize: 12)),
                        Text('${tauxMargeNet.toStringAsFixed(1)}%', 
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (tauxMargeNet / 100).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoutsCard() {
    final couts = _rapportData?['couts'] as Map<String, dynamic>?;
    if (couts == null) return const SizedBox.shrink();
    
    final coutAchat = _parseDouble(couts['coutAchatMarchandises']);
    final coutOperationnel = _parseDouble(couts['coutOperationnel']);
    final totalCouts = _parseDouble(couts['totalCouts']);
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    label: 'Achats',
                    value: _formatCurrency(coutAchat),
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    label: 'Operationnels',
                    value: _formatCurrency(coutOperationnel),
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Coûts',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _formatCurrency(totalCouts),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicateursCard() {
    final indicateurs = _rapportData?['indicateursFinanciers'] as Map<String, dynamic>?;
    if (indicateurs == null) return const SizedBox.shrink();
    
    final beneficeNet = _parseDouble(indicateurs['beneficeNet']);
    final roi = _parseDouble(indicateurs['roi']);
    final rotationStocks = _parseDouble(indicateurs['rotationStocks']);
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildIndicateurCircle(
                    label: 'Bénéfice net',
                    value: _formatCurrency(beneficeNet),
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildIndicateurCircle(
                    label: 'ROI',
                    value: '${roi.toStringAsFixed(1)}%',
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildIndicateurCircle(
                    label: 'Rotation stocks',
                    value: rotationStocks.toStringAsFixed(1),
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualizations() {
    final marges = _rapportData?['marges'] as Map<String, dynamic>?;
    final couts = _rapportData?['couts'] as Map<String, dynamic>?;
    final ca = _rapportData?['chiffreAffaires'] as Map<String, dynamic>?;
    
    if (marges == null || couts == null || ca == null) {
      return const SizedBox.shrink();
    }
    
    final margeBrute = _parseDouble(marges['margeBrute']);
    final totalCouts = _parseDouble(couts['totalCouts']);
    final total = _parseDouble(ca['total']);
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Repartition des revenus',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            // Histogramme pour la repartition des revenus
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: total > 0 ? total * 1.2 : 100,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.blueGrey,
                      tooltipPadding: const EdgeInsets.all(8),
                      tooltipMargin: 8,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          _formatCurrency(rod.toY),
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          switch (value.toInt()) {
                            case 0:
                              return const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text('Marge', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              );
                            case 1:
                              return const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text('Coûts', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              );
                            case 2:
                              return const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text('Autre', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              );
                            default:
                              return const Text('');
                          }
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const Text('');
                          return Text(
                            _formatCurrency(value),
                            style: const TextStyle(fontSize: 9),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barRods: [
                        BarChartRodData(
                          toY: margeBrute,
                          color: Colors.green,
                          width: 60,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(6),
                          ),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 1,
                      barRods: [
                        BarChartRodData(
                          toY: totalCouts,
                          color: Colors.red,
                          width: 60,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(6),
                          ),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 2,
                      barRods: [
                        BarChartRodData(
                          toY: total - margeBrute - totalCouts,
                          color: Colors.grey,
                          width: 60,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ],
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade300,
                        strokeWidth: 1,
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem('Marge', Colors.green),
                _buildLegendItem('Coûts', Colors.red),
                _buildLegendItem('Autre', Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    String? percentage,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: color,
            ),
          ),
          if (percentage != null) ...[
            const SizedBox(height: 4),
            Text(
              percentage,
              style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBarChart(String title, List<_BarData> data) {
    final maxValue = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        ...data.map((bar) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 60,
                child: Text(
                  bar.label,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Expanded(
                child: Container(
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: maxValue > 0 ? (bar.value / maxValue).clamp(0.0, 1.0) : 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: bar.color,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 50,
                child: Text(
                  '${bar.value.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildIndicateurCircle({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.1),
            border: Border.all(color: color, width: 3),
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPieChart(List<_PieSlice> slices) {
    final total = slices.fold(0.0, (sum, slice) => sum + slice.value);
    if (total == 0) return const SizedBox.shrink();
    
    return SizedBox(
      height: 150,
      child: CustomPaint(
        size: const Size(150, 150),
        painter: _PieChartPainter(slices: slices, total: total),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2022),
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
      _loadRapports();
    }
  }
}

class _BarData {
  final String label;
  final double value;
  final Color color;
  
  _BarData(this.label, this.value, this.color);
}

class _PieSlice {
  final String label;
  final double value;
  final Color color;
  
  _PieSlice(this.label, this.value, this.color);
}

class _PieChartPainter extends CustomPainter {
  final List<_PieSlice> slices;
  final double total;
  
  _PieChartPainter({required this.slices, required this.total});
  
  @override
  void paint(Canvas canvas, Size size) {
    if (slices.isEmpty || total == 0) return;
    
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    
    double startAngle = -90 * 3.14159 / 180;
    
    for (final slice in slices) {
      final sweepAngle = (slice.value / total) * 2 * 3.14159;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.fill;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
      
      startAngle += sweepAngle;
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
