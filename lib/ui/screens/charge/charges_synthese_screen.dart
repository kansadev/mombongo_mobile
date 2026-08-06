import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/utils/api_error_message.dart';

class ChargesSyntheseScreen extends StatefulWidget {
  const ChargesSyntheseScreen({super.key});

  @override
  State<ChargesSyntheseScreen> createState() => _ChargesSyntheseScreenState();
}

class _ChargesSyntheseScreenState extends State<ChargesSyntheseScreen> {
  Map<String, dynamic>? _siteSynthese;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSynthese();
  }

  String _formatCurrency(num amount) {
    return locator.tauxService.formatPrice(amount.toDouble());
  }

  static const _months = [
    'jan',
    'fév',
    'mar',
    'avr',
    'mai',
    'jun',
    'jul',
    'aoû',
    'sep',
    'oct',
    'nov',
    'déc',
  ];

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(
        dateStr.replaceAll('+02:00', '').replaceAll('+01:00', ''),
      );
      final day = date.day.toString().padLeft(2, '0');
      final month = _months[date.month - 1];
      final year = date.year;
      return '$day $month $year';
    } catch (_) {
      return dateStr;
    }
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
        throw Exception('Utilisateur non connecté');
      }

      final idSite = int.tryParse(currentUser.idSite) ?? 0;
      if (idSite == 0) {
        throw Exception('ID site invalide');
      }

      final synthese = await locator.apiService.getSiteChargesSynthese(
        idSite: idSite,
      );

      if (!mounted) return;

      setState(() {
        _siteSynthese = synthese;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Synthèse des Charges',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Erreur: $_errorMessage',
                    style: GoogleFonts.poppins(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadSynthese,
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            )
          : _siteSynthese == null
          ? const Center(child: Text('Aucune donnée disponible'))
          : RefreshIndicator(
              onRefresh: _loadSynthese,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_siteSynthese!['periode'] != null) _buildPeriodCard(),
                    const SizedBox(height: 16),
                    _buildTotalCard(),
                    const SizedBox(height: 24),
                    Text(
                      'Catégories',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildCategoryItem(
                      'Charges Personnel',
                      _siteSynthese!['synthese']?['chargesPersonnel'] ?? 0,
                      Icons.people,
                    ),
                    _buildCategoryItem(
                      'Loyer',
                      _siteSynthese!['synthese']?['chargesLoyer'] ?? 0,
                      Icons.home,
                    ),
                    _buildCategoryItem(
                      'Énergie & Eau',
                      _siteSynthese!['synthese']?['chargesEnergieEau'] ?? 0,
                      Icons.bolt,
                    ),
                    _buildCategoryItem(
                      'Transport',
                      _siteSynthese!['synthese']?['chargesTransport'] ?? 0,
                      Icons.local_shipping,
                    ),
                    _buildCategoryItem(
                      'Fournitures',
                      _siteSynthese!['synthese']?['chargesFournitures'] ?? 0,
                      Icons.inventory,
                    ),
                    _buildCategoryItem(
                      'Maintenance',
                      _siteSynthese!['synthese']?['chargesMaintenance'] ?? 0,
                      Icons.build,
                    ),
                    _buildCategoryItem(
                      'Marketing',
                      _siteSynthese!['synthese']?['chargesMarketing'] ?? 0,
                      Icons.campaign,
                    ),
                    _buildCategoryItem(
                      'Charges Administratives',
                      _siteSynthese!['synthese']?['chargesAdministratives'] ??
                          0,
                      Icons.admin_panel_settings,
                    ),
                    _buildCategoryItem(
                      'Autres Charges',
                      _siteSynthese!['synthese']?['autresCharges'] ?? 0,
                      Icons.more_horiz,
                    ),
                    const SizedBox(height: 24),
                    _buildSummaryCard(),
                    if (_siteSynthese!['site'] != null) ...[
                      const SizedBox(height: 24),
                      _buildSiteInfoCard(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.date_range, color: Color(0xFF2C3E50)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Période',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    '${_formatDate(_siteSynthese!['periode']?['dateDebut'])} - ${_formatDate(_siteSynthese!['periode']?['dateFin'])}',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFF2C3E50),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total des Charges',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.white70),
            ),
            Text(
              _formatCurrency((_siteSynthese!['totalGeneral'] as num?) ?? 0),
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(String title, num amount, IconData icon) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2C3E50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF2C3E50), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              _formatCurrency(amount),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2C3E50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Résumé',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow(
              'Charges Fixes',
              _siteSynthese!['synthese']?['totalChargesFixes'] ?? 0,
            ),
            const Divider(),
            _buildSummaryRow(
              'Charges Variables',
              _siteSynthese!['synthese']?['totalChargesVariables'] ?? 0,
            ),
            const Divider(),
            _buildSummaryRow(
              'Charges Opérationnelles',
              _siteSynthese!['synthese']?['totalChargesOperationnelles'] ?? 0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, num amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins()),
          Text(
            _formatCurrency(amount),
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteInfoCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informations',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _siteSynthese!['site']?['nomSite'] ?? '',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              _siteSynthese!['site']?['nomSociete'] ?? '',
              style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
