import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mombongo/ui/screens/profil_screen.dart';
import 'package:mombongo/ui/screens/stock/ImportExportScreen.dart';
import 'package:mombongo/ui/screens/stock/new_item.dart';
import 'package:mombongo/ui/screens/stock/update_article_screen.dart';
import 'package:mombongo/ui/screens/stock/approvisionnement.dart';
import 'package:mombongo/ui/screens/stock/approvisionnement_list_screen.dart';
import 'package:mombongo/ui/screens/stock/product_list_screen.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/ui/screens/stock/PeremptionScreen.dart';

class GestionStocksScreen extends StatefulWidget {
  const GestionStocksScreen({super.key});

  @override
  State<GestionStocksScreen> createState() => _GestionStocksScreenState();
}

class _GestionStocksScreenState extends State<GestionStocksScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _alertStocks = [];

  int _totalArticles = 0;
  int _articlesEnAlerte = 0;

  // Palette de couleurs Premium
  final Color _primaryViolet = const Color(0xFF1E2A3A); // Violet profond
  final Color _accentTurquoise = const Color(0xFF00BFA5); // Turquoise
  final Color _bgScaffold = const Color(
    0xFFF4F6F9,
  ); // Gris très clair pour le fond
  final Color _darkText = const Color(
    0xFF1E2A3A,
  ); // Bleu marine très foncé pour le texte

  @override
  void initState() {
    super.initState();
    _loadStockData();
  }

  Future<void> _loadStockData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentUser = locator.authRepository.currentUser;
      if (currentUser == null) throw Exception('Utilisateur non connecté');

      final idSite = int.tryParse(currentUser.idSite) ?? 0;
      if (idSite == 0) throw Exception('ID du site invalide');

      final allStocks = await locator.apiService.getStockArticles(
        idSite: idSite,
        pageSize: 1000,
        sortOrder: 'asc',
      );

      if (!mounted) return;

      int totalArticles = allStocks.length;
      int articlesEnAlerte = 0;
      List<dynamic> alertStocks = [];

      for (var stock in allStocks) {
        final withStock =
            stock['withStock'] == true ||
            stock['withStock'] == 1 ||
            stock['withStock'] == 'true';

        // Only consider articles with stock management as alerts
        if (!withStock) continue;

        final quantiteStock = _parseDouble(stock['quantiteStock']);
        final seuilAlerte = _parseDouble(stock['seuilAlerte']);

        if (quantiteStock <= seuilAlerte) {
          articlesEnAlerte++;
          alertStocks.add(stock);
        }
      }

      setState(() {
        _totalArticles = totalArticles;
        _articlesEnAlerte = articlesEnAlerte;
        _alertStocks = alertStocks;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Erreur lors du chargement: $e';
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
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final siteName = locator.authRepository.currentUser?.nomSite ?? '';
    return Scaffold(
      backgroundColor: _bgScaffold,
      appBar: AppBar(
        title: Column(
          children: [
            const Text(
              'Gestion des Stocks',
              style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
            ),
            if (siteName.isNotEmpty)
              Text(
                siteName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        centerTitle: true,
        backgroundColor: _primaryViolet,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilScreen()),
              );
              if (mounted) {
                setState(() {});
                _loadStockData();
              }
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
        color: _accentTurquoise,
        onRefresh: _loadStockData,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: _primaryViolet))
            : _errorMessage != null
            ? _buildErrorState()
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 24.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatistiquesSection(),
                    const SizedBox(height: 32),
                    _buildSectionTitle('Actions rapides'),
                    const SizedBox(height: 16),
                    _buildQuickActionsGrid(context),
                    const SizedBox(height: 32),
                    _buildSectionTitle('Articles en alerte'),
                    const SizedBox(height: 16),
                    _buildAlertsList(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: _darkText,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildStatistiquesSection() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Total articles',
            value: '$_totalArticles',
            icon: Icons.inventory_2_rounded,
            gradient: LinearGradient(
              colors: [_primaryViolet, _primaryViolet.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            title: 'En alerte',
            value: '$_articlesEnAlerte',
            icon: Icons.warning_rounded,
            gradient: const LinearGradient(
              colors: [Color(0xFFFF8A65), Color(0xFFFF5252)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Gradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.last.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 28,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildActionTile(
          context,
          label: 'Nouveau',
          icon: Icons.add_circle_rounded,
          color: _accentTurquoise,
          screen: const NouvelArticleScreen(),
        ),
        _buildActionTile(
          context,
          label: 'Mise à jour',
          icon: Icons.edit_document,
          color: Colors.blueAccent,
          screen: const UpdateArticleScreen(),
        ),
        _buildActionTile(
          context,
          label: 'Approvis.',
          icon: Icons.local_shipping_rounded,
          color: Colors.orangeAccent,
          screen: const MiseAJourStockScreen(),
        ),
        _buildActionTile(
          context,
          label: 'Import/Export',
          icon: Icons.import_export_rounded,
          color: Colors.teal,
          screen: const ImportExportScreen(),
        ),
        _buildActionTile(
          context,
          label: 'Liste Prod.',
          icon: Icons.format_list_bulleted_rounded,
          color: Colors.indigoAccent,
          screen: const ProductListScreen(),
        ),
        _buildActionTile(
          context,
          label: 'Péremption',
          icon: Icons.calendar_month_rounded,
          color: Colors.redAccent,
          screen: const PeremptionScreen(),
        ),
        if (kDebugMode)
          _buildActionTile(
            context,
            label: 'Historique Approvis.',
            icon: Icons.history_rounded,
            color: Colors.purpleAccent,
            screen: const ApprovisionnementListScreen(),
          ),
      ],
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required Widget screen,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => screen),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _darkText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertsList() {
    if (_alertStocks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                'Aucun article en alerte',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _alertStocks
          .map((stock) => _buildAlerteArticleItem(stock))
          .toList(),
    );
  }

  Widget _buildAlerteArticleItem(dynamic stock) {
    final double qte = _parseDouble(stock['quantiteStock']);
    final double seuil = _parseDouble(stock['seuilAlerte']);
    final double ratio = seuil > 0 ? (qte / seuil).clamp(0.0, 1.0) : 0;
    final bool isCritical = ratio <= 0.25;

    final statusColor = isCritical ? Colors.redAccent : Colors.orangeAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCritical ? Icons.error_rounded : Icons.warning_rounded,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  stock['libelle'] ?? 'Article sans nom',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: _darkText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _bgScaffold,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${qte.toInt()} / ${seuil.toInt()}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _darkText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Barre de progression moderne
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
        ],
      ),
    );
  }
}
