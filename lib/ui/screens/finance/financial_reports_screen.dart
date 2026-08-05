import 'package:flutter/material.dart';
import 'package:mombongo/models/financial_data.dart';
import 'package:mombongo/ui/widgets/metric_card.dart';
import 'package:mombongo/ui/widgets/revenue_history_item.dart';
import 'package:intl/intl.dart';

class FinancialReportsScreen extends StatefulWidget {
  const FinancialReportsScreen({super.key});

  @override
  State<FinancialReportsScreen> createState() => _FinancialReportsScreenState();
}

class _FinancialReportsScreenState extends State<FinancialReportsScreen> {
  String selectedPeriod = 'Mois';
  bool _isLoading = false;
  DateTime? _lastUpdate;

  final List<FinancialMetric> metrics = [
    FinancialMetric(
      label: 'CA Total',
      value: '5 811 348 CDF',
      icon: Icons.monetization_on_outlined,
      color: Colors.green,
    ),
    FinancialMetric(
      label: 'Marge brute',
      value: '3 584 650 CDF',
      icon: Icons.trending_up_outlined,
      color: Colors.orange,
    ),
    FinancialMetric(
      label: 'Coûts opérationnels',
      value: '0 CDF',
      icon: Icons.flash_on_outlined,
      color: Colors.red,
    ),
    FinancialMetric(
      label: 'Bénéfice net',
      value: '3 584 650 CDF',
      icon: Icons.wallet_outlined,
      color: Colors.blue,
    ),
  ];

  final List<RevenueHistory> revenueHistories = [
    RevenueHistory(
      date: 'samedi 01 novembre 2025',
      amount: '1 459 000 CDF',
      period: 'Période',
    ),
    RevenueHistory(
      date: 'lundi 01 décembre 2025',
      amount: '33 640 CDF',
      period: 'Période',
    ),
    RevenueHistory(
      date: 'jeudi 01 janvier 2026',
      amount: '4 318 708 CDF',
      period: 'Période',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _lastUpdate = DateTime.now();
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });

    // Simuler un chargement
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() {
        _isLoading = false;
        _lastUpdate = DateTime.now();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        title: const Text(
          'Rapports Financiers',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Chargement des données...'),
                  ],
                ),
              )
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge de mise à jour
                    if (_lastUpdate != null) _buildUpdateBadge(),
                    const SizedBox(height: 16),
                    
                    // Sélecteur de période
                    _buildPeriodSelector(),
                    const SizedBox(height: 20),
                    
                    // Métriques
                    _buildMetricsCard(),
                    const SizedBox(height: 20),
                    
                    // Évolution des revenus
                    _buildRevenueEvolutionCard(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildUpdateBadge() {
    final dateFormat = DateFormat('dd/MM/yyyy à HH:mm');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Données mises à jour',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  dateFormat.format(_lastUpdate!),
                  style: TextStyle(
                    color: Colors.green[600],
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final periods = ['Jour', 'Semaine', 'Mois'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Période',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: periods.map((period) {
            final isSelected = selectedPeriod == period;
            return ChoiceChip(
              label: Text(period),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => selectedPeriod = period);
                }
              },
              selectedColor: const Color(0xFF2C3E50),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF2C3E50),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              backgroundColor: Colors.white,
              side: BorderSide(
                color: isSelected ? const Color(0xFF2C3E50) : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMetricsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Métriques financières',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.1,
          children: metrics.map((metric) {
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      metric.color.withOpacity(0.1),
                      metric.color.withOpacity(0.05),
                    ],
                  ),
                ),
                child: MetricCard(metric: metric),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRevenueEvolutionCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Évolution des revenus',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF3498DB).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF3498DB).withOpacity(0.3)),
              ),
              child: Text(
                '${revenueHistories.length} période(s)',
                style: const TextStyle(
                  color: Color(0xFF3498DB),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (revenueHistories.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(
                    Icons.trending_up_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Aucune donnée disponible',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...revenueHistories.asMap().entries.map((entry) {
            final index = entry.key;
            final history = entry.value;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < revenueHistories.length - 1 ? 12 : 0,
              ),
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: RevenueHistoryItem(history: history),
                ),
              ),
            );
          }),
      ],
    );
  }

}
