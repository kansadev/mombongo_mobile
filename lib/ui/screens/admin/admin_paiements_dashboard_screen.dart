import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mombongo/services/app_currency_preference.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/utils/api_error_message.dart';

/// Dashboard paiements du site opérationnel (même vue que le gestionnaire).
class AdminPaiementsDashboardScreen extends StatefulWidget {
  const AdminPaiementsDashboardScreen({super.key});

  @override
  State<AdminPaiementsDashboardScreen> createState() =>
      _AdminPaiementsDashboardScreenState();
}

class _AdminPaiementsDashboardScreenState
    extends State<AdminPaiementsDashboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _dashboardData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
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
      if (idSite == 0) {
        throw Exception(
          'Aucun site opérationnel — choisissez un site dans le profil',
        );
      }

      final data = await locator.apiService.getDashboardData(
        idSite: idSite,
        idSociete: int.tryParse(currentUser.idSociete),
      );

      if (!mounted) return;
      setState(() {
        _dashboardData = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = apiErrorUserMessage(e);
        _isLoading = false;
      });
    }
  }

  double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _formatCurrency(double amount) {
    return AppCurrencyPreference.formatCurrency(amount);
  }

  @override
  Widget build(BuildContext context) {
    final user = locator.authRepository.currentUser;
    final paiements = _dashboardData?['paiements'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Paiements — ${user?.nomSite ?? 'Site'}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 80),
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Center(
                        child: ElevatedButton(
                          onPressed: _loadData,
                          child: const Text('Réessayer'),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Text(
                        'Site opérationnel',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        user?.nomSite ?? '—',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Paiements',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              title: 'Total paiements',
                              value:
                                  '${_parseInt(paiements?['nombreTotalPaiements'])}',
                              icon: Icons.payment,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              title: 'Montant total',
                              value: _formatCurrency(
                                _parseDouble(
                                  paiements?['montantTotalPaiements'],
                                ),
                              ),
                              icon: Icons.monetization_on,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Changez de site dans Profil pour voir un autre point de vente.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
