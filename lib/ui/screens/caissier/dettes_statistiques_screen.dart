import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:mombongo/utils/api_error_message.dart';

class DettesStatistiquesScreen extends StatefulWidget {
  const DettesStatistiquesScreen({super.key});

  @override
  State<DettesStatistiquesScreen> createState() =>
      _DettesStatistiquesScreenState();
}

class _DettesStatistiquesScreenState extends State<DettesStatistiquesScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _statistiques;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadStatistiques();
  }

  Future<void> _loadStatistiques() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final currentUser = locator.authRepository.currentUser;
      if (currentUser == null) throw Exception('Utilisateur non connecté');

      final idSite = int.tryParse(currentUser.idSite) ?? 0;
      final idSociete = int.tryParse(currentUser.idSociete) ?? 0;
      final userRole = currentUser.role.toUpperCase();
      final isGestionnaire = userRole == 'GESTIONNAIRE';
      final idUser = isGestionnaire
          ? null
          : int.tryParse(currentUser.idUtilisateur);

      final stats = await locator.apiService.getStatistiquesPaiements(
        idSociete: idSociete,
        idSite: idSite,
        idUtilisateur: idUser,
      );

      debugPrint('Statistiques loaded: $stats');

      if (!mounted) return;
      setState(() {
        _statistiques = stats;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Error loading statistiques: $e');
      debugPrint('Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _errorMessage = apiErrorUserMessage(e);
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    return locator.tauxService.formatPrice(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Statistiques des Dettes',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Erreur: $_errorMessage',
                    style: GoogleFonts.poppins(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadStatistiques,
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            )
          : _statistiques == null
          ? Center(
              child: Text(
                'Aucune donnée disponible',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadStatistiques,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryCards(),
                    const SizedBox(height: 24),
                    _buildTypeChart(),
                    const SizedBox(height: 24),
                    _buildModeChart(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCards() {
    final totalPaiements = _statistiques!['totalPaiements'] ?? 0;
    final montantTotal = _parseDouble(_statistiques!['montantTotal'] ?? 0);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Total Paiements',
                totalPaiements.toString(),
                Icons.payment,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSummaryCard(
                'Montant Total',
                _formatCurrency(montantTotal),
                Icons.account_balance_wallet,
                Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Icon(Icons.more_vert, color: Colors.grey[400]),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChart() {
    final parType = _statistiques!['parType'] as Map<String, dynamic>? ?? {};

    if (parType.isEmpty) {
      return _buildEmptyCard('Aucune donnée par type');
    }

    final data = parType.entries.map((entry) {
      final typeData = entry.value as Map<String, dynamic>;
      return ChartData(
        entry.key,
        _parseDouble(typeData['montantTotal'] ?? 0),
        _parseDouble(typeData['nombre'] ?? 0),
        _getTypeColor(entry.key),
      );
    }).toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Répartition par Type',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: data.asMap().entries.map((entry) {
                    final chartData = entry.value;
                    final value = chartData.value;
                    final color = chartData.color;

                    return PieChartSectionData(
                      color: color,
                      value: value,
                      title: '${chartData.label}\n${_formatCurrency(value)}',
                      radius: 80,
                      titleStyle: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      badgeWidget: _Badge(
                        chartData.count.toString(),
                        size: 22,
                        borderColor: color,
                      ),
                      badgePositionPercentageOffset: .98,
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...data.map((chartData) => _buildLegendItem(chartData)),
          ],
        ),
      ),
    );
  }

  Widget _buildModeChart() {
    final parMode = _statistiques!['parMode'] as Map<String, dynamic>? ?? {};

    if (parMode.isEmpty) {
      return _buildEmptyCard('Aucune donnée par mode');
    }

    final data = parMode.entries.map((entry) {
      final modeData = entry.value as Map<String, dynamic>;
      return ChartData(
        entry.key,
        _parseDouble(modeData['montantTotal'] ?? 0),
        _parseDouble(modeData['nombre'] ?? 0),
        _getModeColor(entry.key),
      );
    }).toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Répartition par Mode de Paiement',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY:
                      data.map((d) => d.value).reduce((a, b) => a > b ? a : b) *
                      1.2,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.grey[800]!,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final chartData = data[group.x.toInt()];
                        return BarTooltipItem(
                          '${chartData.label}\n${_formatCurrency(chartData.value)}',
                          GoogleFonts.poppins(
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
                          if (value.toInt() >= data.length)
                            return const SizedBox();
                          final chartData = data[value.toInt()];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              chartData.label,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            _formatCurrency(value).split(',')[0],
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.grey[600],
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
                  borderData: FlBorderData(show: false),
                  barGroups: data.asMap().entries.map((entry) {
                    final chartData = entry.value;

                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: chartData.value,
                          color: chartData.color,
                          width: 20,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...data.map((chartData) => _buildLegendItem(chartData)),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(ChartData chartData) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: chartData.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${chartData.label} (${chartData.count})',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
            ),
          ),
          Text(
            _formatCurrency(chartData.value),
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: chartData.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.pie_chart, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'avanceacompte':
        return Colors.orange;
      case 'solde':
        return Colors.red;
      case 'complet':
        return Colors.green;
      case 'versement':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getModeColor(String mode) {
    switch (mode.toLowerCase()) {
      case 'espèces':
      case 'espece':
        return Colors.green;
      case 'mobile money':
      case 'mobile':
        return Colors.blue;
      case 'carte':
        return Colors.purple;
      case 'virement':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

class ChartData {
  final String label;
  final double value;
  final double count;
  final Color color;

  ChartData(this.label, this.value, this.count, this.color);
}

class _Badge extends StatelessWidget {
  final String text;
  final double size;
  final Color borderColor;

  const _Badge(this.text, {required this.size, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: borderColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      padding: const EdgeInsets.all(4),
      child: Center(
        child: FittedBox(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
