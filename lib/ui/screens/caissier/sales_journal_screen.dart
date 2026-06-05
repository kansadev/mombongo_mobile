import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mombongo/services/app_currency_preference.dart';
import '../../../services/service_locator.dart';

class SalesJournalScreen extends StatefulWidget {
  final int? idCaissier;
  final String? nomCaissier;

  const SalesJournalScreen({
    super.key,
    this.idCaissier,
    this.nomCaissier,
  });

  @override
  State<SalesJournalScreen> createState() => _SalesJournalScreenState();
}

class _SalesJournalScreenState extends State<SalesJournalScreen> {
  Map<String, dynamic>? _syntheseData;
  List<dynamic> _articles = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSiteSynthese = false;
  DateTime? _selectedDate;
  String _sortField = 'chiffreAffaires';
  String _sortOrder = 'desc';

  @override
  void initState() {
    super.initState();
    _loadJournalData();
  }

  void _sortArticles() {
    _articles.sort((a, b) {
      dynamic valueA;
      dynamic valueB;

      if (_sortField == 'derniereVente') {
        valueA = a['derniereVente']?.toString() ?? '';
        valueB = b['derniereVente']?.toString() ?? '';
        if (valueA.isEmpty && valueB.isEmpty) return 0;
        if (valueA.isEmpty) return _sortOrder == 'desc' ? 1 : -1;
        if (valueB.isEmpty) return _sortOrder == 'desc' ? -1 : 1;
        return _sortOrder == 'desc'
            ? valueB.compareTo(valueA)
            : valueA.compareTo(valueB);
      }

      valueA = _parseDouble(a[_sortField] ?? 0);
      valueB = _parseDouble(b[_sortField] ?? 0);
      return _sortOrder == 'desc'
          ? valueB.compareTo(valueA)
          : valueA.compareTo(valueB);
    });
  }

  void _toggleSort() {
    setState(() {
      if (_sortField == 'chiffreAffaires') {
        _sortField = 'derniereVente';
        _sortOrder = 'desc';
      } else if (_sortField == 'derniereVente' && _sortOrder == 'desc') {
        _sortOrder = 'asc';
      } else {
        _sortField = 'chiffreAffaires';
        _sortOrder = 'desc';
      }
      _sortArticles();
    });
  }

  String get _sortTooltip {
    if (_sortField == 'chiffreAffaires') {
      return 'Trié par CA (décroissant)';
    }
    return _sortOrder == 'desc'
        ? 'Trié par date (plus récent)'
        : 'Trié par date (plus ancien)';
  }

  Future<void> _loadJournalData() async {
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

      final role = currentUser.role.toLowerCase();
      final isGestionnaireSite =
          widget.idCaissier == null && role.contains('gestionnaire');

      final idUtilisateur = widget.idCaissier ??
          int.tryParse(currentUser.idUtilisateur) ??
          0;
      final idSite = int.tryParse(currentUser.idSite) ?? 0;
      final idSociete = int.tryParse(currentUser.idSociete) ?? 0;

      if (!isGestionnaireSite && idUtilisateur == 0) {
        throw Exception('ID utilisateur invalide');
      }
      if (isGestionnaireSite && idSite == 0) {
        throw Exception('ID site invalide');
      }

      DateTime? dateDebut;
      DateTime? dateFin;
      if (_selectedDate != null) {
        dateDebut = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
        );
        dateFin = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          23,
          59,
          59,
        );
      }

      final Map<String, dynamic> response;
      if (isGestionnaireSite) {
        response = await locator.apiService.getVenteSyntheseParArticle(
          idSociete: idSociete > 0 ? idSociete : null,
          idSite: idSite > 0 ? idSite : null,
          dateDebut: dateDebut,
          dateFin: dateFin,
        );
      } else {
        response =
            await locator.apiService.getVenteSyntheseParArticleCaissier(
          idUtilisateur,
          idSociete: idSociete > 0 ? idSociete : null,
          idSite: idSite > 0 ? idSite : null,
          dateDebut: dateDebut,
          dateFin: dateFin,
        );
      }

      if (!mounted) return;

      final articles = response['syntheseParArticle'] as List<dynamic>? ?? [];

      setState(() {
        _isSiteSynthese = isGestionnaireSite;
        _syntheseData = response;
        _articles = List.from(articles);
        _isLoading = false;
      });
      _sortArticles();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Erreur lors du chargement du journal: $e');
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
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

  String _formatCurrency(double amount) {
    return locator.tauxService.formatPrice(amount);
  }

  String _formatCurrencyCompact(double amount) {
    final code = locator.tauxService.getDevisePreferee();
    final tauxVal =
        double.tryParse(locator.tauxService.getTauxActuel().tauxActuel) ?? 1.0;
    final converted = locator.tauxService.convertir(
      amount,
      'USD',
      code,
      tauxVal,
    );
    final symbol = AppCurrencyPreference.symbolFor(code);

    if (converted >= 1000000000) {
      return '${(converted / 1000000000).toStringAsFixed(1)}Md $symbol';
    } else if (converted >= 1000000) {
      return '${(converted / 1000000).toStringAsFixed(1)}M $symbol';
    } else if (converted >= 1000) {
      return '${(converted / 1000).toStringAsFixed(1)}k $symbol';
    } else {
      return locator.tauxService.formatPrice(amount);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatSignedCurrency(double amount) {
    if (amount < 0) {
      return '-${_formatCurrency(-amount)}';
    }
    return _formatCurrency(amount);
  }

  void _showArticleDetails(Map<String, dynamic> article) {
    final libelle = article['libelle']?.toString() ?? 'Article';
    final idStock = _parseInt(article['idStock']);
    final nombreVentes = _parseInt(article['nombreVentes']);
    final quantiteVendue = _parseInt(article['quantiteVendue']);
    final chiffreAffaires = _parseDouble(article['chiffreAffaires']);
    final prixMoyen = _parseDouble(article['prixMoyen']);
    final prixMin = _parseDouble(article['prixMin']);
    final prixMax = _parseDouble(article['prixMax']);
    final margeTotale = _parseDouble(article['margeTotale']);
    final margeMoyenne = _parseDouble(article['margeMoyenne']);
    final tauxMarge = _parseDouble(article['tauxMarge']);
    final premierVente = article['premierVente']?.toString();
    final derniereVente = article['derniereVente']?.toString();
    final nombreSites = _parseInt(article['nombreSitesDistincts']);
    final nombreCaissiers = _parseInt(article['nombreCaissiersDistincts']);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF2C3E50,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.inventory_2_outlined,
                            color: Color(0xFF2C3E50),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                libelle,
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF2C3E50),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Stock #$idStock',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.shade600,
                          Colors.green.shade400,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chiffre d\'affaires',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatCurrency(chiffreAffaires),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      children: [
                        _buildDetailSection(
                          title: 'Ventes',
                          children: [
                            _buildDetailRow(
                              'Nombre de ventes',
                              '$nombreVentes',
                            ),
                            _buildDetailRow(
                              'Quantité vendue',
                              '$quantiteVendue',
                            ),
                            _buildDetailRow(
                              'Sites distincts',
                              '$nombreSites',
                            ),
                            _buildDetailRow(
                              'Caissiers distincts',
                              '$nombreCaissiers',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDetailSection(
                          title: 'Prix',
                          children: [
                            _buildDetailRow(
                              'Prix moyen',
                              _formatCurrency(prixMoyen),
                            ),
                            _buildDetailRow(
                              'Prix minimum',
                              _formatCurrency(prixMin),
                            ),
                            _buildDetailRow(
                              'Prix maximum',
                              _formatCurrency(prixMax),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDetailSection(
                          title: 'Marge',
                          children: [
                            _buildDetailRow(
                              'Taux de marge',
                              '${tauxMarge.toStringAsFixed(2)} %',
                              valueColor: tauxMarge >= 0
                                  ? Colors.green[700]
                                  : Colors.red[700],
                            ),
                            _buildDetailRow(
                              'Marge totale',
                              _formatSignedCurrency(margeTotale),
                              valueColor: margeTotale >= 0
                                  ? Colors.green[700]
                                  : Colors.red[700],
                            ),
                            _buildDetailRow(
                              'Marge moyenne',
                              _formatSignedCurrency(margeMoyenne),
                              valueColor: margeMoyenne >= 0
                                  ? Colors.green[700]
                                  : Colors.red[700],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDetailSection(
                          title: 'Période',
                          children: [
                            _buildDetailRow(
                              'Première vente',
                              _formatDate(premierVente),
                            ),
                            _buildDetailRow(
                              'Dernière vente',
                              _formatDate(derniereVente),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2C3E50),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? const Color(0xFF2C3E50),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _loadJournalData();
    }
  }

  Map<String, dynamic>? get _totauxGlobaux =>
      _syntheseData?['totauxGlobaux'] as Map<String, dynamic>?;

  Map<String, dynamic>? get _periodeAnalyse =>
      _syntheseData?['periodeAnalyse'] as Map<String, dynamic>?;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.nomCaissier != null
              ? 'Synthèse — ${widget.nomCaissier}'
              : _isSiteSynthese
                  ? 'Synthèse ventes — Site'
                  : 'Journal des Ventes',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _toggleSort,
            icon: Icon(
              _sortField == 'chiffreAffaires'
                  ? Icons.sort_by_alpha
                  : (_sortOrder == 'desc'
                        ? Icons.arrow_downward
                        : Icons.arrow_upward),
              color: Colors.white,
            ),
            tooltip: _sortTooltip,
          ),
          IconButton(
            onPressed: _selectDate,
            icon: Icon(
              Icons.calendar_today,
              color: _selectedDate != null ? Colors.orange : Colors.white70,
            ),
            tooltip: 'Filtrer par date',
          ),
          if (_selectedDate != null)
            IconButton(
              onPressed: () {
                setState(() {
                  _selectedDate = null;
                });
                _loadJournalData();
              },
              icon: const Icon(Icons.clear, color: Colors.white70),
              tooltip: 'Effacer le filtre',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadJournalData,
        child: _isLoading && _articles.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Erreur',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(color: Colors.grey[600]),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _loadJournalData,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              )
            : CustomScrollView(
                slivers: [
                  if (_periodeAnalyse != null)
                    SliverToBoxAdapter(child: _buildPeriodeInfo()),
                  if (_totauxGlobaux != null)
                    SliverToBoxAdapter(child: _buildTotauxSection()),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Synthèse par article',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2C3E50),
                            ),
                          ),
                          Text(
                            '${_articles.length} article${_articles.length > 1 ? 's' : ''}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_articles.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Aucune vente trouvée',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final article = _articles[index];
                          return _buildArticleCard(article, index);
                        }, childCount: _articles.length),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              ),
      ),
    );
  }

  Widget _buildPeriodeInfo() {
    final periode = _periodeAnalyse!;
    final dateDebut = periode['dateDebut']?.toString();
    final dateFin = periode['dateFin']?.toString();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.date_range, color: Colors.blue.shade700, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Du ${_formatDate(dateDebut)} au ${_formatDate(dateFin)}',
                style: GoogleFonts.poppins(
                  color: Colors.blue.shade700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotauxSection() {
    final totaux = _totauxGlobaux!;
    final totalCA = _parseDouble(totaux['totalChiffreAffaires']);
    final totalVentes = _parseInt(totaux['totalVentes']);
    final totalArticles = _parseInt(totaux['totalArticles']);
    final totalQte = _parseInt(totaux['totalQuantiteVendue']);
    final margeTotale = _parseDouble(totaux['margeTotaleGlobale']);
    final tauxMarge = _parseDouble(totaux['tauxMargeGlobal']);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          _buildStatCard(
            label: 'Chiffre d\'affaires',
            value: _formatCurrencyCompact(totalCA),
            fullValue: _formatCurrency(totalCA),
            icon: Icons.payments,
            color: Colors.green[700]!,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  label: 'Ventes',
                  value: '$totalVentes',
                  icon: Icons.receipt_long,
                  color: const Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  label: 'Articles',
                  value: '$totalArticles',
                  icon: Icons.category,
                  color: Colors.blue[700]!,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  label: 'Quantité',
                  value: '$totalQte',
                  icon: Icons.inventory_2,
                  color: Colors.orange[700]!,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  label: 'Marge (${tauxMarge.toStringAsFixed(1)}%)',
                  value: _formatCurrencyCompact(margeTotale),
                  fullValue: _formatCurrency(margeTotale),
                  icon: Icons.trending_up,
                  color: Colors.purple[700]!,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    String? fullValue,
    required IconData icon,
    required Color color,
  }) {
    return GestureDetector(
      onLongPress: fullValue != null
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '$label: $fullValue',
                    style: GoogleFonts.poppins(fontSize: 16),
                  ),
                  duration: const Duration(seconds: 3),
                  backgroundColor: color,
                ),
              );
            }
          : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
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

  Widget _buildArticleCard(Map<String, dynamic> article, int index) {
    final chiffreAffaires = _parseDouble(article['chiffreAffaires']);
    final quantiteVendue = _parseInt(article['quantiteVendue']);
    final nombreVentes = _parseInt(article['nombreVentes']);
    final prixMoyen = _parseDouble(article['prixMoyen']);
    final tauxMarge = _parseDouble(article['tauxMarge']);
    final margeTotale = _parseDouble(article['margeTotale']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showArticleDetails(article),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C3E50).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.shopping_bag,
                    color: Color(0xFF2C3E50),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article['libelle']?.toString() ?? 'N/A',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2C3E50),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$nombreVentes vente${nombreVentes > 1 ? 's' : ''} · $quantiteVendue unité${quantiteVendue > 1 ? 's' : ''}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatCurrency(chiffreAffaires),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                    Text(
                      'Moy. ${_formatCurrency(prixMoyen)}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildArticleMetric(
                          icon: tauxMarge >= 0
                              ? Icons.trending_up
                              : tauxMarge < 0
                              ? Icons.trending_down
                              : Icons.trending_flat,
                          label: 'Marge',
                          value: '${tauxMarge.toStringAsFixed(1)}%',
                          color: tauxMarge >= 0
                              ? Colors.green[700]!
                              : Colors.red[700]!,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildArticleMetric(
                          icon: Icons.account_balance_wallet,
                          label: 'Marge tot.',
                          value: margeTotale >= 0
                              ? _formatCurrencyCompact(margeTotale)
                              : '-${_formatCurrencyCompact(-margeTotale)}',
                          color: margeTotale >= 0
                              ? Colors.green[700]!
                              : Colors.red[700]!,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _formatDate(
                            article['derniereVente']?.toString(),
                          ),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildArticleMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.grey[500],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
