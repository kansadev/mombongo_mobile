import 'package:flutter/material.dart';
import 'package:mombongo/services/app_currency_preference.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/ui/screens/caissier/paiements_screen.dart';
import 'package:mombongo/utils/api_error_message.dart';

class PaiementDashboardScreen extends StatefulWidget {
  const PaiementDashboardScreen({super.key});

  @override
  State<PaiementDashboardScreen> createState() =>
      _PaiementDashboardScreenState();
}

class _PaiementDashboardScreenState extends State<PaiementDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _paiementsData;
  String? _errorMessage;
  bool _dataChanged = false;
  /// Gestionnaire ou administrateur : vue manager (filtre caissier).
  bool _isManagerView = false;
  /// Admin : dashboard société (sans idSite).
  bool _isAdminSocieteView = false;
  bool _isLoadingCaissiers = false;
  List<Map<String, dynamic>> _caissiers = [];
  int? _selectedCaissierId;

  void _popWithResult() {
    Navigator.pop(context, _dataChanged);
  }

  Future<void> _openPaiementsHistorique() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (context) => PaiementsScreen(
          filterCaissierId: _isManagerView ? _selectedCaissierId : null,
        ),
      ),
    );
    if (changed == true && mounted) {
      setState(() => _dataChanged = true);
      await _loadPaiementsData();
    }
  }

  @override
  void initState() {
    super.initState();
    final currentUser = locator.authRepository.currentUser;
    final role = currentUser?.role.toUpperCase().trim() ?? '';
    _isAdminSocieteView = currentUser?.isAdministrateur == true;
    _isManagerView = role == 'GESTIONNAIRE' || _isAdminSocieteView;
    if (_isManagerView) {
      _loadCaissiers();
    }
    _loadPaiementsData();
  }

  Future<void> _loadCaissiers() async {
    setState(() => _isLoadingCaissiers = true);

    try {
      final currentUser = locator.authRepository.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      final idSite = int.tryParse(currentUser.idSite) ?? 0;
      if (idSite == 0) {
        // Admin sans site opérationnel : pas de filtre caissier.
        if (!mounted) return;
        setState(() {
          _caissiers = [];
          _isLoadingCaissiers = false;
        });
        return;
      }

      final utilisateurs =
          await locator.apiService.getAllUtilisateursBySite(idSite);
      final caissiers = utilisateurs
          .where(
            (u) => (u['role'] as String?)?.toUpperCase() == 'CAISSIER',
          )
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      caissiers.sort((a, b) {
        return _caissierDisplayName(a).compareTo(_caissierDisplayName(b));
      });

      if (!mounted) return;
      setState(() {
        _caissiers = caissiers;
        _isLoadingCaissiers = false;
      });
    } catch (e) {
      debugPrint('Erreur chargement caissiers: $e');
      if (!mounted) return;
      setState(() => _isLoadingCaissiers = false);
    }
  }

  String _caissierDisplayName(Map<String, dynamic> caissier) {
    final prenom = caissier['prenomUtilisateur']?.toString().trim() ?? '';
    final nom = caissier['nomUtilisateur']?.toString().trim() ?? '';
    final postNom = caissier['postNomUtilisateur']?.toString().trim() ?? '';
    final fullName = [prenom, nom, postNom].where((s) => s.isNotEmpty).join(' ');
    if (fullName.isNotEmpty) return fullName;
    return caissier['login']?.toString() ?? 'Caissier';
  }

  int? _resolveIdUtilisateur() {
    final currentUser = locator.authRepository.currentUser;
    if (currentUser == null) return null;

    final role = currentUser.role.toLowerCase();
    if (role.contains('caissier')) {
      return int.tryParse(currentUser.idUtilisateur);
    }
    if (_isManagerView) {
      return _selectedCaissierId;
    }
    return null;
  }

  void _onCaissierChanged(int? caissierId) {
    setState(() => _selectedCaissierId = caissierId);
    _loadPaiementsData();
  }

  Future<void> _loadPaiementsData() async {
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

      final idSociete = int.tryParse(currentUser.idSociete) ?? 0;
      final idUtilisateur = _resolveIdUtilisateur();
      // Admin : vue société (sans idSite). Gestionnaire / caissier : site courant.
      final int? idSite = _isAdminSocieteView
          ? null
          : (int.tryParse(currentUser.idSite) ?? 0);

      final data = await locator.apiService.getPaiementsDashboard(
        idSociete: idSociete,
        idSite: idSite == 0 ? null : idSite,
        idUtilisateur: idUtilisateur,
      );

      if (!mounted) return;

      setState(() {
        _paiementsData = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur chargement paiements: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = apiErrorUserMessage(e);
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    final code = AppCurrencyPreference.readCode(locator.databaseService);
    final formatter = AppCurrencyPreference.formatterFor(code);
    final symbol = AppCurrencyPreference.symbolFor(code);
    return '${formatter.format(amount)} $symbol';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pop(context, _dataChanged);
        }
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(
          _isAdminSocieteView
              ? 'Dashboard Paiements (Société)'
              : 'Dashboard Paiements',
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _popWithResult,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadPaiementsData,
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF2C3E50)),
                    SizedBox(height: 16),
                    Text('Chargement...'),
                  ],
                ),
              )
            : _errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red[700],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Erreur de chargement',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadPaiementsData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Réessayer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2C3E50),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : _buildContent(),
      ),
    ),
    );
  }

  Widget _buildContent() {
    final periode = _paiementsData?['periode'] as Map<String, dynamic>?;
    final filtres = _paiementsData?['filtres'] as Map<String, dynamic>?;
    final totalGeneral = _paiementsData?['totalGeneral'] as num? ?? 0;
    final totauxParType = _paiementsData?['totauxParType'] as List? ?? [];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isManagerView) ...[
            _buildCaissierFilter(),
            const SizedBox(height: 16),
          ],
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2C3E50), Color(0xFF1A252F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2C3E50).withOpacity(0.3),
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total paiements',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            _formatCurrency(totalGeneral.toDouble()),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            periode != null
                                ? '${_formatPeriode(periode['dateDebut']?.toString() ?? '')} - ${_formatPeriode(periode['dateFin']?.toString() ?? '')}'
                                : 'Aujourd\'hui',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Répartition par type',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          if (totauxParType.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      'Aucun paiement trouvé',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          else
            ...totauxParType.map((typeData) {
              final type = typeData['typeTransaction'] as String? ?? '-';
              final montant = typeData['montantTotal'] as num? ?? 0;
              final nombre = typeData['nombre'] as int? ?? 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _getColorForType(type).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getIconForType(type),
                      color: _getColorForType(type),
                      size: 24,
                    ),
                  ),
                  title: Text(
                    _getLabelForType(type),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      Icon(Icons.receipt, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        '$nombre paiement${nombre != 1 ? 's' : ''}',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatCurrency(montant.toDouble()),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getColorForType(type),
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${totalGeneral > 0 ? (montant / totalGeneral * 100).toStringAsFixed(1) : 0}%',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: _openPaiementsHistorique,
              icon: const Icon(Icons.list),
              label: const Text('Voir historique des paiements'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2C3E50),
                side: const BorderSide(color: Color(0xFF2C3E50)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCaissierFilter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_search, size: 20, color: Colors.grey[700]),
              const SizedBox(width: 8),
              const Text(
                'Filtrer par caissier',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_isLoadingCaissiers)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            DropdownButtonFormField<int?>(
              value: _selectedCaissierId,
              isExpanded: true,
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: const Color(0xFFF5F6FA),
              ),
              hint: const Text('Tous les caissiers'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Tous les caissiers'),
                ),
                ..._caissiers.map((caissier) {
                  final id = int.tryParse(
                    caissier['idUtilisateur']?.toString() ?? '',
                  );
                  if (id == null) return null;
                  return DropdownMenuItem<int?>(
                    value: id,
                    child: Text(_caissierDisplayName(caissier)),
                  );
                }).whereType<DropdownMenuItem<int?>>(),
              ],
              onChanged: _onCaissierChanged,
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF2C3E50)),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: const TextStyle(fontSize: 13, color: Color(0xFF2C3E50)),
          ),
        ],
      ),
    );
  }

  String _formatPeriode(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}';
    } catch (e) {
      return dateStr;
    }
  }

  Color _getColorForType(String type) {
    switch (type.toUpperCase()) {
      case 'VERSEMENT':
        return Colors.blue;
      case 'AVANCE_ACOMPTE':
        return Colors.orange;
      case 'SOLDE':
        return Colors.green;
      case 'REMBOURSEMENT':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForType(String type) {
    switch (type.toUpperCase()) {
      case 'VERSEMENT':
        return Icons.upload;
      case 'AVANCE_ACOMP TE':
        return Icons.add_circle;
      case 'SOLDE':
        return Icons.check_circle;
      case 'REMBOURSEMENT':
        return Icons.replay;
      default:
        return Icons.payment;
    }
  }

  String _getLabelForType(String type) {
    switch (type.toUpperCase()) {
      case 'VERSEMENT':
        return 'Versement';
      case 'AVANCE_ACOMP TE':
        return 'Acompte';
      case 'SOLDE':
        return 'Solde';
      case 'REMBOURSEMENT':
        return 'Remboursement';
      default:
        return type;
    }
  }
}
