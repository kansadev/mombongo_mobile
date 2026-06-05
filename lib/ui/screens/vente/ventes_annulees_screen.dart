import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mombongo/services/app_currency_preference.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/ui/screens/caissier/commande_detail_screen.dart';
import 'package:mombongo/utils/commande_invoice_helper.dart';

class VentesAnnuleesScreen extends StatefulWidget {
  const VentesAnnuleesScreen({super.key});

  @override
  State<VentesAnnuleesScreen> createState() => _VentesAnnuleesScreenState();
}

class _VentesAnnuleesScreenState extends State<VentesAnnuleesScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _ventes = [];

  int _currentPage = 1;
  int _pageSize = 5;
  int _totalPages = 1;
  int _totalCount = 0;

  DateTime? _dateDebut;
  DateTime? _dateFin;
  final TextEditingController _dateDebutController = TextEditingController();
  final TextEditingController _dateFinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadVentesAnnulees();
  }

  @override
  void dispose() {
    _dateDebutController.dispose();
    _dateFinController.dispose();
    super.dispose();
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _formatCurrency(double amount) {
    final code = AppCurrencyPreference.readCode(locator.databaseService);
    final formatter = AppCurrencyPreference.formatterFor(code);
    final symbol = AppCurrencyPreference.symbolFor(code);
    return '${formatter.format(amount)} $symbol';
  }

  Future<void> _loadVentesAnnulees({int? page}) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      if (page != null) _currentPage = page;
    });

    try {
      final currentUser = locator.authRepository.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecte');
      }

      final idSite = int.tryParse(currentUser.idSite) ?? 0;
      if (idSite == 0) {
        throw Exception('ID du site invalide');
      }

      final userRole = currentUser.role.toUpperCase();
      final bool isGestionnaire = userRole == 'GESTIONNAIRE';
      final idUtilisateur = isGestionnaire
          ? null
          : int.tryParse(currentUser.idUtilisateur);

      final response = await locator.apiService.getVentesAnnulees(
        idSite: idSite,
        idUtilisateur: idUtilisateur,
        dateDebut: _dateDebut,
        dateFin: _dateFin,
        page: _currentPage,
        pageSize: _pageSize,
      );

      if (!mounted) return;

      final pagination = response['pagination'] as Map<String, dynamic>? ?? {};
      setState(() {
        _ventes = response['ventes'] as List? ?? [];
        _totalCount = _parseInt(pagination['totalCount']);
        _totalPages = _parseInt(pagination['totalPages']);
        if (_totalPages <= 0) _totalPages = 1;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = kReleaseMode
            ? 'Erreur lors du chargement des remboursements'
            : 'Erreur: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateDebut() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _dateDebut ?? DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _dateDebut = picked;
        _dateDebutController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
      _loadVentesAnnulees(page: 1);
    }
  }

  Future<void> _selectDateFin() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFin ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _dateFin = picked;
        _dateFinController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
      _loadVentesAnnulees(page: 1);
    }
  }

  int? _idCommandeFromVente(Map<String, dynamic> vente) {
    final id = int.tryParse(vente['idCommande']?.toString() ?? '') ?? 0;
    return id > 0 ? id : null;
  }

  void _openCommandeDetail(Map<String, dynamic> vente) {
    final idCommande = _idCommandeFromVente(vente);
    if (idCommande == null) return;

    Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (context) => CommandeDetailScreen(idCommande: idCommande),
      ),
    ).then((changed) {
      if (changed == true && mounted) {
        _loadVentesAnnulees(page: _currentPage);
      }
    });
  }

  Future<void> _imprimerFacture(Map<String, dynamic> vente) async {
    final idCommande = _idCommandeFromVente(vente);
    if (idCommande == null) return;
    await imprimerFactureCommande(context, idCommande);
  }

  void _clearFilters() {
    setState(() {
      _dateDebut = null;
      _dateFin = null;
      _dateDebutController.clear();
      _dateFinController.clear();
    });
    _loadVentesAnnulees(page: 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Remboursements'),
        centerTitle: true,
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadVentesAnnulees(page: _currentPage),
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _dateDebutController,
                          readOnly: true,
                          onTap: _selectDateDebut,
                          decoration: const InputDecoration(
                            labelText: 'Date debut',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _dateFinController,
                          readOnly: true,
                          onTap: _selectDateFin,
                          decoration: const InputDecoration(
                            labelText: 'Date fin',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _clearFilters,
                        child: const Text('Effacer'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(child: Text(_errorMessage!))
                  : _ventes.isEmpty
                  ? const Center(child: Text('Aucune vente annulee trouvee'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _ventes.length,
                      itemBuilder: (context, index) {
                        final vente = _ventes[index] as Map<String, dynamic>;
                        return _buildVenteCard(vente);
                      },
                    ),
            ),
            _buildPagination(),
          ],
        ),
      ),
    );
  }

  Widget _buildVenteCard(Map<String, dynamic> vente) {
    final dateCommandeRaw = vente['dateCommande']?.toString();
    DateTime? dateCommande;
    if (dateCommandeRaw != null) {
      try {
        dateCommande = DateTime.parse(dateCommandeRaw);
      } catch (_) {}
    }

    final client = vente['client'] as Map<String, dynamic>? ?? {};
    final utilisateur = vente['utilisateur'] as Map<String, dynamic>? ?? {};
    final paiements = vente['paiements'] as List? ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Commande #${vente['idCommande'] ?? '-'}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Chip(
                  label: Text(vente['statut']?.toString() ?? 'Annulee'),
                  backgroundColor: Colors.red.withOpacity(0.1),
                  labelStyle: const TextStyle(color: Colors.red),
                ),
              ],
            ),
            if (dateCommande != null)
              Text(
                DateFormat('dd/MM/yyyy HH:mm').format(dateCommande),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            const SizedBox(height: 8),
            Text(
              'Client: ${client['nom'] ?? ''} ${client['prenom'] ?? ''}'.trim(),
            ),
            Text(
              'Caissier: ${utilisateur['nom'] ?? ''} ${utilisateur['prenom'] ?? ''}'
                  .trim(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Total: ${_formatCurrency(_parseDouble(vente['montantTotal']))}',
                  ),
                ),
                Expanded(
                  child: Text(
                    'Rembourse: ${_formatCurrency(_parseDouble(vente['montantPaye']))}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Reste: ${_formatCurrency(_parseDouble(vente['resteAPayer']))}',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              'Paiements: ${paiements.length}',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _openCommandeDetail(vente),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Détail'),
                ),
                TextButton.icon(
                  onPressed: () => _imprimerFacture(vente),
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: const Text('Imprimer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination() {
    final canPrev = _currentPage > 1;
    final canNext = _currentPage < _totalPages;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Page $_currentPage/$_totalPages ($_totalCount)',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          Row(
            children: [
              IconButton(
                onPressed: canPrev
                    ? () => _loadVentesAnnulees(page: _currentPage - 1)
                    : null,
                icon: const Icon(Icons.arrow_back_ios),
              ),
              IconButton(
                onPressed: canNext
                    ? () => _loadVentesAnnulees(page: _currentPage + 1)
                    : null,
                icon: const Icon(Icons.arrow_forward_ios),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
