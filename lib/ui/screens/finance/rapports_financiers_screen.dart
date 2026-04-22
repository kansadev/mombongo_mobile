import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mombongo/services/app_currency_preference.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/ui/screens/caissier/dettes_screen.dart';
import 'package:mombongo/ui/screens/profil_screen.dart';

class RapportsFinanciersScreen extends StatefulWidget {
  const RapportsFinanciersScreen({super.key});

  @override
  State<RapportsFinanciersScreen> createState() =>
      _RapportsFinanciersScreenState();
}

class _RapportsFinanciersScreenState extends State<RapportsFinanciersScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _rapportData;
  bool _isLoading = true;
  String? _errorMessage;

  // Animation
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;

  // Date range
  DateTime? _dateDebut;
  DateTime? _dateFin;

  @override
  void initState() {
    super.initState();

    // Initialize animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOut,
    );
    _animationController!.forward();

    // Default to current month
    final now = DateTime.now();
    _dateDebut = DateTime(now.year, now.month, 1);
    _dateFin = now;
    _loadRapports();
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
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
        throw Exception('Utilisateur non connecté');
      }

      final idSite = int.tryParse(currentUser.idSite) ?? 0;
      final idSociete = int.tryParse(currentUser.idSociete) ?? 0;

      if (idSite == 0 || idSociete == 0) {
        throw Exception('ID du site ou de la société invalide');
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

  void _navigateToDetteScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DettesScreen()),
    ).then((_) => _loadRapports()); // Refresh on return
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: Text(
          'Rapports Financiers',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          // Nouveau bouton Dettes
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.receipt_long),
              tooltip: 'Gestion des dettes',
              onPressed: _navigateToDetteScreen,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Changer la période',
            onPressed: _selectDateRange,
          ),
          PopupMenuButton<String>(
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
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'profile', child: Text('Mon profil')),
            ],
            onSelected: (value) {
              if (value == 'profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRapports,
        color: const Color(0xFF2C3E50),
        child: _isLoading
            ? _buildLoadingState()
            : _errorMessage != null
            ? _buildErrorState()
            : FadeTransition(
                opacity: _fadeAnimation ?? AlwaysStoppedAnimation(1.0),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
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

                      // Visualisations
                      _buildSectionTitle('Visualisations'),
                      _buildVisualizations(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2C3E50)),
          ),
          const SizedBox(height: 16),
          Text(
            'Chargement des rapports...',
            style: GoogleFonts.poppins(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.red.shade700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadRapports,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2C3E50),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.date_range, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _dateDebut != null && _dateFin != null
                  ? 'Période: ${DateFormat('dd MMM yyyy').format(_dateDebut!)} - ${DateFormat('dd MMM yyyy').format(_dateFin!)}'
                  : 'Période: Tout',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF2C3E50), const Color(0xFF34495E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.store, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  site['nomSite']?.toString() ?? 'Site',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: const Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${site['ville'] ?? ''} ${site['commune'] ?? ''}'.trim(),
                  style: GoogleFonts.poppins(
                    color: Colors.grey.shade600,
                    fontSize: 12,
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
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: const Color(0xFF2C3E50),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade600, Colors.green.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CA Total',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.trending_up,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatCurrency(total),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat('Ventes', '$nombreVentes', Colors.white),
              ),
              Container(width: 1, height: 40, color: Colors.white30),
              Expanded(
                child: _buildMiniStat(
                  'Panier moyen',
                  _formatCurrency(panierMoyen),
                  Colors.white,
                ),
              ),
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
    final beneficeApresCharges = _parseDouble(marges['beneficeApresCharges']);
    final tauxMargeApresCharges = _parseDouble(marges['tauxMargeApresCharges']);
    final impactCharges = _parseDouble(marges['impactCharges']);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    label: 'Bénéfice net',
                    value: _formatCurrency(beneficeApresCharges),
                    percentage: '${tauxMargeApresCharges.toStringAsFixed(1)}%',
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            if (impactCharges > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Impact des charges',
                              style: GoogleFonts.poppins(
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '-${_formatCurrency(impactCharges)}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCoutsCard() {
    final couts = _rapportData?['couts'] as Map<String, dynamic>?;
    if (couts == null) return const SizedBox.shrink();

    final coutAchat = _parseDouble(couts['coutAchatMarchandises']);
    final coutOperationnel = _parseDouble(couts['coutOperationnelles']);
    final totalCouts = _parseDouble(couts['totalCouts']);

    final detailCharges = couts['detailCharges'] as Map<String, dynamic>?;
    final chargesParType =
        detailCharges?['chargesParType'] as Map<String, dynamic>?;
    final statistiques =
        detailCharges?['statistiques'] as Map<String, dynamic>?;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    label: 'Charges',
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
                gradient: LinearGradient(
                  colors: [Colors.red.shade50, Colors.red.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Coûts',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    _formatCurrency(totalCouts),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
            if (chargesParType != null &&
                chargesParType.entries.any(
                  (e) => (e.value as num).toDouble() > 0,
                )) ...[
              const SizedBox(height: 20),
              Text(
                'Détail des charges',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: const Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 12),
              ...chargesParType.entries
                  .where((e) => (e.value as num).toDouble() > 0)
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.red.shade400,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _formatChargeType(e.key.toString()),
                              style: GoogleFonts.poppins(fontSize: 13),
                            ),
                          ),
                          Text(
                            _formatCurrency((e.value as num).toDouble()),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
            if (statistiques != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'Nombre total',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${statistiques['nombreTotalCharges'] ?? 0}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: const Color(0xFF2C3E50),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.shade300,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'Montant moyen',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatCurrency(
                              (statistiques['montantMoyenParCharge'] as num?)
                                      ?.toDouble() ??
                                  0,
                            ),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: const Color(0xFF2C3E50),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatChargeType(String type) {
    final types = {
      'personnel': '👥 Personnel',
      'loyer': '🏢 Loyer',
      'energieEau': '💡 Énergie/Eau',
      'transport': '🚚 Transport',
      'fournitures': '📋 Fournitures',
      'maintenance': '🔧 Maintenance',
      'marketing': '📢 Marketing',
      'administratives': '📄 Administratives',
      'autres': '📌 Autres',
    };
    return types[type] ?? type;
  }

  Widget _buildIndicateursCard() {
    final indicateurs =
        _rapportData?['indicateursFinanciers'] as Map<String, dynamic>?;
    if (indicateurs == null) return const SizedBox.shrink();

    final beneficeNet = _parseDouble(indicateurs['beneficeNet']);
    final roi = _parseDouble(indicateurs['roi']);
    final rotationStocks = _parseDouble(indicateurs['rotationStocks']);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Indicateurs Financiers',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: const Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildIndicateurCard(
                    label: 'Bénéfice net',
                    value: _formatCurrency(beneficeNet),
                    color: Colors.green,
                    icon: Icons.trending_up,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildIndicateurCard(
                    label: 'ROI',
                    value: '${roi.toStringAsFixed(1)}%',
                    color: Colors.purple,
                    icon: Icons.percent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildIndicateurCard(
                    label: 'Rotation stocks',
                    value: rotationStocks.toStringAsFixed(1),
                    color: Colors.blue,
                    icon: Icons.inventory,
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
    final autre = (total - margeBrute - totalCouts).clamp(0.0, double.infinity);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Répartition des revenus',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: const Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: [
                    if (margeBrute > 0)
                      PieChartSectionData(
                        color: Colors.green,
                        value: margeBrute,
                        title:
                            '${((margeBrute / total) * 100).toStringAsFixed(0)}%',
                        radius: 50,
                        titleStyle: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    if (totalCouts > 0)
                      PieChartSectionData(
                        color: Colors.red,
                        value: totalCouts,
                        title:
                            '${((totalCouts / total) * 100).toStringAsFixed(0)}%',
                        radius: 50,
                        titleStyle: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    if (autre > 0)
                      PieChartSectionData(
                        color: Colors.grey,
                        value: autre,
                        title: '${((autre / total) * 100).toStringAsFixed(0)}%',
                        radius: 50,
                        titleStyle: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildLegendItem('Marge brute', Colors.green),
                _buildLegendItem('Coûts', Colors.red),
                _buildLegendItem('Autre', Colors.grey),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 120,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Marge brute',
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        Text(
                          _formatCurrency(margeBrute),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Coûts', style: GoogleFonts.poppins(fontSize: 12)),
                        Text(
                          _formatCurrency(totalCouts),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Autre', style: GoogleFonts.poppins(fontSize: 12)),
                        Text(
                          _formatCurrency(autre),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
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

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: color.withOpacity(0.9),
            fontSize: 11,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          if (percentage != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                percentage,
                style: GoogleFonts.poppins(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
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
            gradient: LinearGradient(
              colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: color, width: 2.5),
          ),
          child: Center(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade700),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildIndicateurCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700),
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF2C3E50)),
          ),
          child: child!,
        );
      },
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
