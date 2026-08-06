import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:mombongo/services/app_currency_preference.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/utils/api_error_message.dart';

class VenteSyntheseScreen extends StatefulWidget {
  const VenteSyntheseScreen({super.key});

  @override
  State<VenteSyntheseScreen> createState() => _VenteSyntheseScreenState();
}

class _VenteSyntheseScreenState extends State<VenteSyntheseScreen> {
  Map<String, dynamic>? _syntheseData;
  bool _isLoading = true;
  String? _errorMessage;

  // Filters
  DateTime? _dateDebut;
  DateTime? _dateFin;

  @override
  void initState() {
    super.initState();
    _loadSynthese();
  }

  Future<void> _loadSynthese() async {
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

      final idSociete = int.tryParse(currentUser.idSociete) ?? 0;

      final response = await locator.apiService.getVenteSyntheseParSite(
        idSociete: idSociete,
        dateDebut: _dateDebut,
        dateFin: _dateFin,
      );

      if (!mounted) return;

      setState(() {
        _syntheseData = response;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement de la synthese: $e');
      if (!mounted) return;

      setState(() {
        _errorMessage = apiErrorUserMessage(e);
        _isLoading = false;
      });
    }
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
    final code = AppCurrencyPreference.readCode(locator.databaseService);
    final formatter = AppCurrencyPreference.formatterFor(code);
    final symbol = AppCurrencyPreference.symbolFor(code);
    return '${formatter.format(amount)} $symbol';
  }

  String _formatCompactCurrency(double amount) {
    final code = AppCurrencyPreference.readCode(locator.databaseService);
    final symbol = AppCurrencyPreference.symbolFor(code);

    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M $symbol';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K $symbol';
    } else {
      final formatter = AppCurrencyPreference.formatterFor(code);
      return '${formatter.format(amount)} $symbol';
    }
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return '';
    
    // If already a DateTime
    if (dateValue is DateTime) {
      return DateFormat('dd MMM yyyy', 'fr_FR').format(dateValue);
    }
    
    // If it's a timestamp (int)
    if (dateValue is int) {
      try {
        final date = DateTime.fromMillisecondsSinceEpoch(dateValue);
        return DateFormat('dd MMM yyyy', 'fr_FR').format(date);
      } catch (e) {
        return dateValue.toString();
      }
    }
    
    // If it's a String
    if (dateValue is String) {
      if (dateValue.isEmpty) return '';
      try {
        final date = DateTime.parse(dateValue);
        return DateFormat('dd MMM yyyy', 'fr_FR').format(date);
      } catch (e) {
        return dateValue;
      }
    }
    
    return dateValue.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Synthèse des Ventes'),
        centerTitle: true,
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDateRange,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSynthese,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
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
                      onPressed: _loadSynthese,
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
                    _buildDateRangeInfo(),
                    const SizedBox(height: 16),
                    _buildTotauxGlobaux(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Synthese par Site'),
                    _buildSyntheseParSiteCharts(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildDateRangeInfo() {
    final periode = _syntheseData?['periodeAnalyse'] as Map<String, dynamic>?;
    
    // Try different field names for dates
    final dateDebut = periode?['dateDebut'] ?? periode?['premierVente'];
    final dateFin = periode?['dateFin'] ?? periode?['derniereVente'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.date_range, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              Text(
                'Periode d\'analyse',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (dateDebut != null || dateFin != null) ...[
            const SizedBox(height: 8),
            Text(
              'Du ${_formatDate(dateDebut)} au ${_formatDate(dateFin)}',
              style: TextStyle(color: Colors.blue.shade700, fontSize: 13),
            ),
          ],
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

  Widget _buildTotauxGlobaux() {
    final totaux = _syntheseData?['totauxGlobaux'] as Map<String, dynamic>?;
    if (totaux == null) return const SizedBox.shrink();

    final totalVentes = _parseInt(totaux['totalVentes']);
    final totalCA = _parseDouble(totaux['totalChiffreAffaires']);
    final totalQte = _parseInt(totaux['totalQuantiteVendue']);
    final panierMoyen = _parseDouble(totaux['panierMoyenGlobal']);
    final margeTotale = _parseDouble(totaux['margeTotaleGlobale']);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade600, Colors.indigo.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Totaux Globaux',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          // Main KPI - Chiffre d'affaires
          Text(
            _formatCurrency(totalCA),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'Chiffre d\'affaires',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 20),
          // Secondary KPIs with charts
          Row(
            children: [
              Expanded(
                child: _buildKpiColumn('Ventes', '$totalVentes', Icons.receipt),
              ),
              Expanded(
                child: _buildKpiColumn(
                  'Articles',
                  '$totalQte',
                  Icons.inventory,
                ),
              ),
              Expanded(
                child: _buildKpiColumn(
                  'Panier moy.',
                  _formatCurrency(panierMoyen),
                  Icons.shopping_basket,
                ),
              ),
              Expanded(
                child: _buildKpiColumn(
                  'Marge',
                  _formatCurrency(margeTotale),
                  Icons.trending_up,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildSyntheseParSiteCharts() {
    final syntheseParSite = _syntheseData?['syntheseParSite'] as List? ?? [];
    if (syntheseParSite.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('Aucune donnee disponible')),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bar chart for CA by site
            _buildBarChart(
              'Chiffre d\'affaires par site',
              syntheseParSite,
              'chiffreAffaires',
              const Color(0xFF3B82F6),
              isCurrency: true,
            ),
            const SizedBox(height: 32),
            // Bar chart for number of sales
            _buildBarChart(
              'Nombre de ventes par site',
              syntheseParSite,
              'nombreVentes',
              const Color(0xFF10B981),
            ),
            const SizedBox(height: 32),
            // Bar chart for quantity sold
            _buildBarChart(
              'Quantité vendue par site',
              syntheseParSite,
              'quantiteVendue',
              const Color(0xFFF59E0B),
            ),
            const SizedBox(height: 32),
            // Pie chart for distribution by site
            _buildPieChartDistribution(syntheseParSite),
            //const SizedBox(height: 32),
            // Site details table
            //_buildSiteDetailsTable(syntheseParSite),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(
    String title,
    List<dynamic> sites,
    String valueField,
    Color color, {
    bool isCurrency = false,
  }) {
    if (sites.isEmpty) return const SizedBox.shrink();

    // Convert site data to bar chart data
    final barData = sites.asMap().entries.map((entry) {
      final index = entry.key;
      final site = entry.value;
      final value = _parseDouble(site[valueField]);

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: value,
            color: color,
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();

    final maxValue = sites.fold(
      0.0,
      (sum, site) => sum + _parseDouble(site[valueField]),
    );
    final maxSiteValue = sites.fold(0.0, (max, site) {
      final value = _parseDouble(site[valueField]);
      return value > max ? value : max;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Color(0xFF2C3E50),
              ),
            ),
            if (isCurrency)
              Text(
                'Total: ${_formatCompactCurrency(maxValue)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 250,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: BarChart(
            BarChartData(
              barGroups: barData,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                drawHorizontalLine: true,
                horizontalInterval: maxSiteValue / 5,
                getDrawingVerticalLine: (value) {
                  return FlLine(color: Colors.grey[300]!, strokeWidth: 1);
                },
                getDrawingHorizontalLine: (value) {
                  return FlLine(color: Colors.grey[300]!, strokeWidth: 1);
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < sites.length) {
                        final siteName =
                            sites[index]['nomSite']?.toString() ?? 'Site';
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            siteName.length > 8
                                ? siteName.substring(0, 6) + '...'
                                : siteName,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF2C3E50),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 60,
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          isCurrency
                              ? _formatCompactCurrency(value)
                              : value >= 1000
                              ? '${(value / 1000).toStringAsFixed(1)}K'
                              : value.toStringAsFixed(0),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.grey[300]!),
              ),
              minY: 0,
              maxY: maxSiteValue * 1.2,
            ),
            duration: const Duration(milliseconds: 150),
            curve: Curves.linear,
          ),
        ),
        const SizedBox(height: 16),
        // Legend with site names and values
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: sites.map((site) {
            final value = _parseDouble(site[valueField]);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${site['nomSite']?.toString() ?? 'Site'}: ',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  Text(
                    isCurrency
                        ? _formatCompactCurrency(value)
                        : value.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLineChartTrends(List<dynamic> sites) {
    if (sites.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tendances par site',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Color(0xFF2C3E50),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                'Vue analytique',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _buildMultiLineChart(sites),
        ),
      ],
    );
  }

  Widget _buildMultiLineChart(List<dynamic> sites) {
    // Create data points using the same metrics as the details table
    final List<FlSpot> ventesSpots = sites.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        _parseInt(entry.value['nombreVentes']).toDouble(),
      );
    }).toList();

    final List<FlSpot> caSpots = sites.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        _parseDouble(entry.value['chiffreAffaires']) / 1000, // Convert to K for readability
      );
    }).toList();

    final List<FlSpot> qteSpots = sites.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        _parseInt(entry.value['quantiteVendue']).toDouble(),
      );
    }).toList();

    final List<FlSpot> panierSpots = sites.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        _parseDouble(entry.value['panierMoyen']),
      );
    }).toList();

    final List<FlSpot> margeSpots = sites.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        _parseDouble(entry.value['margeTotale']) / 1000, // Convert to K for readability
      );
    }).toList();

    // Calculate maxY for proper scaling
    double maxY = 0;
    for (final spots in [caSpots, ventesSpots, qteSpots, panierSpots, margeSpots]) {
      for (final spot in spots) {
        if (spot.y > maxY) maxY = spot.y;
      }
    }
    // Add 20% padding to maxY
    maxY = maxY > 0 ? maxY * 1.2 : 10;

    return AspectRatio(
      aspectRatio: 2.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return LineChart(
              LineChartData(
                lineBarsData: [
                  // CA Line - Blue gradient (same as table header color)
                  LineChartBarData(
                    spots: caSpots,
                    isCurved: true,
                    barWidth: 4,
                    shadow: const Shadow(
                      blurRadius: 8,
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF3B82F6).withOpacity(0.4),
                          const Color(0xFF3B82F6).withOpacity(0.2),
                          const Color(0xFF3B82F6).withOpacity(0.1),
                        ],
                      ),
                    ),
                    dotData: const FlDotData(show: false),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF3B82F6),
                        Color(0xFF60A5FA),
                        Color(0xFF93C5FD),
                      ],
                      stops: [0.1, 0.4, 0.9],
                    ),
                  ),
                  // Ventes Line - Purple gradient
                  LineChartBarData(
                    spots: ventesSpots,
                    isCurved: true,
                    barWidth: 4,
                    shadow: const Shadow(
                      blurRadius: 8,
                    ),
                    dotData: const FlDotData(show: false),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF8B5CF6),
                        Color(0xFFA78BFA),
                        Color(0xFFC4B5FD),
                      ],
                      stops: [0.1, 0.4, 0.9],
                    ),
                  ),
                  // Quantité Line - Orange gradient
                  LineChartBarData(
                    spots: qteSpots,
                    isCurved: true,
                    barWidth: 4,
                    shadow: const Shadow(
                      blurRadius: 8,
                    ),
                    dotData: const FlDotData(show: false),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFF59E0B),
                        Color(0xFFFBBf24),
                        Color(0xFFFCD34D),
                      ],
                      stops: [0.1, 0.4, 0.9],
                    ),
                  ),
                  // Panier Moyen Line - Green gradient (same as table header color)
                  LineChartBarData(
                    spots: panierSpots,
                    isCurved: true,
                    barWidth: 4,
                    shadow: const Shadow(
                      blurRadius: 8,
                    ),
                    dotData: const FlDotData(show: false),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF10B981),
                        Color(0xFF34D399),
                        Color(0xFF6EE7B7),
                      ],
                      stops: [0.1, 0.4, 0.9],
                    ),
                  ),
                  // Marge Totale Line - Red gradient
                  LineChartBarData(
                    spots: margeSpots,
                    isCurved: true,
                    barWidth: 4,
                    shadow: const Shadow(
                      blurRadius: 8,
                    ),
                    dotData: const FlDotData(show: false),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFEF4444),
                        Color(0xFFF87171),
                        Color(0xFFFCA5A5),
                      ],
                      stops: [0.1, 0.4, 0.9],
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  enabled: true,
                  handleBuiltInTouches: false,
                  touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                    // Handle touch events like in line_chart.dart
                  },
                  mouseCursorResolver: (FlTouchEvent event, LineTouchResponse? response) {
                    return SystemMouseCursors.click;
                  },
                  getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                    return spotIndexes.map((index) {
                      return TouchedSpotIndicatorData(
                        const FlLine(color: Colors.pink),
                        FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                            radius: 8,
                            color: lerpGradient(
                              barData.gradient!.colors,
                              barData.gradient!.stops!,
                              percent / 100,
                            ),
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          ),
                        ),
                      );
                    }).toList();
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => Colors.grey[800]!,
                    tooltipBorderRadius: BorderRadius.circular(8),
                    getTooltipItems: (List<LineBarSpot> lineBarsSpot) {
                      return lineBarsSpot.map((lineBarSpot) {
                        final siteIndex = lineBarSpot.x.toInt();
                        if (siteIndex >= 0 && siteIndex < sites.length) {
                          final site = sites[siteIndex];
                          String label = '';
                          String value = '';
                          
                          if (lineBarSpot.barIndex == 0) {
                            label = 'CA';
                            value = _formatCurrency(_parseDouble(site['chiffreAffaires']));
                          } else if (lineBarSpot.barIndex == 1) {
                            label = 'Ventes';
                            value = '${_parseInt(site['nombreVentes'])}';
                          } else if (lineBarSpot.barIndex == 2) {
                            label = 'Qté';
                            value = '${_parseInt(site['quantiteVendue'])}';
                          } else if (lineBarSpot.barIndex == 3) {
                            label = 'Panier';
                            value = _formatCurrency(_parseDouble(site['panierMoyen']));
                          } else {
                            label = 'Marge';
                            value = _formatCurrency(_parseDouble(site['margeTotale']));
                          }
                          
                          return LineTooltipItem(
                            '$label: $value',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }
                        return null;
                      }).toList();
                    },
                  ),
                ),
                minY: 0,
                maxY: maxY,
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    axisNameWidget: Text('Valeurs'),
                    axisNameSize: 24,
                    sideTitles: SideTitles(
                      showTitles: false,
                      reservedSize: 0,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < sites.length) {
                          final siteName = sites[index]['nomSite']?.toString() ?? 'Site';
                          final style = TextStyle(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF10B981),
                            fontSize: 18 * constraints.maxWidth / 500,
                          );
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              siteName.length > 6 ? siteName.substring(0, 4) + '..' : siteName,
                              style: style,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      reservedSize: 30,
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    axisNameWidget: Text('Sites'),
                    sideTitles: SideTitles(
                      showTitles: false,
                      reservedSize: 0,
                    ),
                  ),
                  topTitles: const AxisTitles(
                    axisNameWidget: Text(
                      'Tendances par site',
                      textAlign: TextAlign.left,
                    ),
                    axisNameSize: 24,
                    sideTitles: SideTitles(
                      showTitles: false,
                      reservedSize: 0,
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey),
                ),
              ),
              duration: const Duration(milliseconds: 150),
              curve: Curves.linear,
            );
          },
        ),
      ),
    );
  }

  Widget _buildPieChartDistribution(List<dynamic> sites) {
    if (sites.isEmpty) return const SizedBox.shrink();

    // Calculate total CA for percentage
    double totalCA = 0;
    for (final site in sites) {
      totalCA += _parseDouble(site['chiffreAffaires']);
    }

    // Colors for pie chart sections
    final colors = [
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
      const Color(0xFF06B6D4),
      const Color(0xFFEC4899),
      const Color(0xFF84CC16),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Distribution par site',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Color(0xFF2C3E50),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(
                'Total: ${_formatCompactCurrency(totalCA)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: sites.asMap().entries.map((entry) {
                      final index = entry.key;
                      final site = entry.value;
                      final value = _parseDouble(site['chiffreAffaires']);
                      final percentage = totalCA > 0 ? (value / totalCA * 100) : 0;
                      final siteName = site['nomSite']?.toString() ?? 'Site';

                      return PieChartSectionData(
                        color: colors[index % colors.length],
                        value: value,
                        title: '${percentage.toStringAsFixed(1)}%',
                        radius: 50,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Legend
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: sites.asMap().entries.map((entry) {
                    final index = entry.key;
                    final site = entry.value;
                    final siteName = site['nomSite']?.toString() ?? 'Site';
                    final value = _parseDouble(site['chiffreAffaires']);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: colors[index % colors.length],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              siteName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _formatCompactCurrency(value),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: colors[index % colors.length],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Lerps between a [LinearGradient] colors, based on [t]
  Color lerpGradient(List<Color> colors, List<double> stops, double t) {
    if (colors.isEmpty) {
      throw ArgumentError('"colors" is empty.');
    } else if (colors.length == 1) {
      return colors[0];
    }

    if (stops.length != colors.length) {
      stops = [];
      colors.asMap().forEach((index, color) {
        final percent = 1.0 / (colors.length - 1);
        stops.add(percent * index);
      });
    }

    for (var s = 0; s < stops.length - 1; s++) {
      final leftStop = stops[s];
      final rightStop = stops[s + 1];
      final leftColor = colors[s];
      final rightColor = colors[s + 1];
      if (t <= leftStop) {
        return leftColor;
      } else if (t < rightStop) {
        final sectionT = (t - leftStop) / (rightStop - leftStop);
        return Color.lerp(leftColor, rightColor, sectionT)!;
      }
    }
    return colors.last;
  }

  Widget _buildSiteDetailsTable(List<dynamic> sites) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Détails par site',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Color(0xFF2C3E50),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                '${sites.length} site${sites.length > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20,
              headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
              dividerThickness: 1,
              horizontalMargin: 16,
              headingRowHeight: 56,
              dataRowHeight: 48,
              columns: const [
                DataColumn(
                  label: Text(
                    'Site',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Ventes',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    'CA',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    'Qté',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    'Panier moy.',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    'Marge',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  numeric: true,
                ),
              ],
              rows: sites.asMap().entries.map((entry) {
                final index = entry.key;
                final site = entry.value;
                final rowColor = index % 2 == 0
                    ? Colors.white
                    : Colors.grey[50];

                return DataRow(
                  color: WidgetStateProperty.all(rowColor),
                  cells: [
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          site['nomSite']?.toString() ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${_parseInt(site['nombreVentes'])}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        _formatCurrency(
                          _parseDouble(site['chiffreAffaires']),
                        ).split(' ')[0],
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${_parseInt(site['quantiteVendue'])}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        _formatCurrency(
                          _parseDouble(site['panierMoyen']),
                        ).split(' ')[0],
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        _formatCurrency(
                          _parseDouble(site['margeTotale']),
                        ).split(' ')[0],
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
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
      _loadSynthese();
    }
  }
}
