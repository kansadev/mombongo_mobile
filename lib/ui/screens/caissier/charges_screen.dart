import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/ui/screens/charge/create_charge_screen.dart';


class ChargesScreen extends StatefulWidget {
  const ChargesScreen({super.key});

  @override
  State<ChargesScreen> createState() => _ChargesScreenState();
}

class _ChargesScreenState extends State<ChargesScreen> {
  List<dynamic> _charges = [];
  List<dynamic> _typesCharge = [];
  Map<String, dynamic>? _synthese;
  bool _isLoading = true;
  String? _errorMessage;

  int _currentPage = 1;
  final int _pageSize = 15;
  bool _isLoadingMore = false;
  bool _hasMorePages = true;
  final ScrollController _scrollController = ScrollController();

  String? _selectedTypeCharge;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMorePages && !_isLoading) {
        _loadMoreCharges();
      }
    }
  }

  String _formatCurrency(double amount) {
    return locator.tauxService.formatPrice(amount);
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

  String _getTypeNom(String? code) {
    if (code == null) return 'Charge';
    final type = _typesCharge.firstWhere(
      (t) => t['code']?.toString() == code,
      orElse: () => {'nom': code.replaceAll('_', ' ')},
    );
    return type['nom']?.toString() ?? code.replaceAll('_', ' ');
  }

  Future<void> _loadData() async {
    await Future.wait([_loadTypesCharge(), _loadCharges()]);
  }

  Future<void> _loadTypesCharge() async {
    try {
      final types = await locator.apiService.getTypesCharge();
      if (!mounted) return;
      setState(() {
        _typesCharge = types;
      });
    } catch (e) {
      debugPrint('Error loading types charge: $e');
    }
  }

  Future<void> _loadCharges() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = 1;
      _hasMorePages = true;
    });

    try {
      final currentUser = locator.authRepository.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      final idUtilisateur = int.tryParse(currentUser.idUtilisateur) ?? 0;
      final idSite = int.tryParse(currentUser.idSite) ?? 0;
      final idSociete = int.tryParse(currentUser.idSociete) ?? 0;

      final response = await locator.apiService.getChargesOperationnelles(
        idUtilisateur: idUtilisateur,
        pageNumber: 1,
        pageSize: _pageSize,
        idSite: idSite,
        idSociete: idSociete,
        typeCharge: _selectedTypeCharge,
      );

      if (!mounted) return;

      setState(() {
        _charges = response['charges'] as List<dynamic>? ?? [];
        _synthese = response['synthese'] as Map<String, dynamic>?;
        _isLoading = false;
        _hasMorePages = _charges.length == _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreCharges() async {
    if (!mounted || _isLoadingMore || !_hasMorePages) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final currentUser = locator.authRepository.currentUser;
      if (currentUser == null) return;

      final idUtilisateur = int.tryParse(currentUser.idUtilisateur) ?? 0;
      final idSite = int.tryParse(currentUser.idSite) ?? 0;
      final idSociete = int.tryParse(currentUser.idSociete) ?? 0;

      final nextPage = _currentPage + 1;
      final response = await locator.apiService.getChargesOperationnelles(
        idUtilisateur: idUtilisateur,
        pageNumber: nextPage,
        pageSize: _pageSize,
        idSite: idSite,
        idSociete: idSociete,
        typeCharge: _selectedTypeCharge,
      );

      if (!mounted) return;

      final newCharges = response['charges'] as List<dynamic>? ?? [];
      if (newCharges.isEmpty) {
        setState(() {
          _hasMorePages = false;
          _isLoadingMore = false;
        });
        return;
      }

      setState(() {
        _currentPage = nextPage;
        _charges = [..._charges, ...newCharges];
        _hasMorePages = newCharges.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Color _getTypeChargeColor(String? type) {
    if (type == null) return Colors.grey;
    switch (type.toUpperCase()) {
      case 'SALAIRE':
      case 'SOCIAL':
      case 'PRIME':
      case 'INDEMNITE':
      case 'FORMATION':
        return Colors.blue;
      case 'LOYER':
        return Colors.purple;
      case 'ENERGIE':
        return Colors.orange;
      case 'TRANSPORT':
        return Colors.teal;
      case 'FOURNITURE':
        return Colors.brown;
      case 'MAINTENANCE':
        return Colors.indigo;
      case 'MARKETING':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeChargeIcon(String? type) {
    if (type == null) return Icons.receipt;
    switch (type.toUpperCase()) {
      case 'SALAIRE':
      case 'SOCIAL':
      case 'PRIME':
      case 'INDEMNITE':
      case 'FORMATION':
        return Icons.people;
      case 'LOYER':
        return Icons.home;
      case 'ENERGIE':
        return Icons.bolt;
      case 'TRANSPORT':
        return Icons.local_shipping;
      case 'FOURNITURE':
        return Icons.inventory;
      case 'MAINTENANCE':
        return Icons.build;
      case 'MARKETING':
        return Icons.campaign;
      default:
        return Icons.receipt;
    }
  }

  Future<void> _showCreateChargeDialog() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CreateChargeScreen(typesCharge: _typesCharge),
      ),
    );

    if (result == true && mounted) {
      _loadCharges();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Charges Opérationnelles',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: DropdownButtonFormField<String>(
              value: _selectedTypeCharge,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                labelText: 'Type de charge',
                labelStyle: GoogleFonts.poppins(fontSize: 14),
              ),
              hint: Text(
                'Tous les types',
                style: GoogleFonts.poppins(color: Colors.grey[500]),
              ),
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text('Tous les types', style: GoogleFonts.poppins()),
                ),
                ..._typesCharge.map((type) {
                  final code = type['code']?.toString() ?? '';
                  final nom = type['nom']?.toString() ?? '';
                  return DropdownMenuItem<String>(
                    value: code,
                    child: Text(nom, style: GoogleFonts.poppins()),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() => _selectedTypeCharge = value);
                _loadCharges();
              },
            ),
          ),
          if (_synthese != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF2C3E50), const Color(0xFF34495E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total période',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _formatCurrency(
                      (_synthese!['totalGeneral'] as num?)?.toDouble() ?? 0,
                    ),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Erreur: $_errorMessage',
                          style: GoogleFonts.poppins(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadCharges,
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  )
                : _charges.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune charge trouvée',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadCharges,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 80,
                      ),
                      itemCount: _charges.length + (_hasMorePages ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _charges.length) {
                          return _isLoadingMore
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : const SizedBox.shrink();
                        }
                        return _buildChargeCard(_charges[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateChargeDialog,
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          'Nouvelle charge',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildChargeCard(Map<String, dynamic> charge) {
    final typeCharge = charge['typeCharge']?.toString();
    final montant = double.tryParse(charge['montant']?.toString() ?? '0') ?? 0;
    final libelle = charge['libelle']?.toString() ?? '-';
    final description = charge['description']?.toString() ?? libelle;
    final dateCharge = _formatDate(charge['dateCharge']?.toString());
    final modePaiement = charge['modePaiement']?.toString() ?? '-';
    final statut = charge['statut']?.toString() ?? '-';
    final fournisseur = charge['fournisseur']?.toString() ?? '';
    final nomSite = charge['nomSite']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _getTypeChargeColor(typeCharge).withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getTypeChargeIcon(typeCharge),
                    color: _getTypeChargeColor(typeCharge),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getTypeNom(typeCharge),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: _getTypeChargeColor(typeCharge),
                        ),
                      ),
                      Text(
                        dateCharge,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statut == 'PAID' || statut == 'Payé'
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statut == 'PAID' ? 'Payé' : 'En attente',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statut == 'PAID' || statut == 'Payé'
                          ? Colors.green[700]
                          : Colors.orange[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (libelle.isNotEmpty && libelle != '-')
                  Text(
                    libelle,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (description.isNotEmpty && description != '-') ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (fournisseur.isNotEmpty)
                      _buildInfoChip(Icons.store, fournisseur),
                    _buildInfoChip(
                      _getModeIcon(modePaiement),
                      _getModeLabel(modePaiement),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (nomSite.isNotEmpty) ...[
                            Text(
                              nomSite,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      _formatCurrency(montant),
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _getTypeChargeColor(typeCharge),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  IconData _getModeIcon(String mode) {
    switch (mode.toUpperCase()) {
      case 'ESPECE':
        return Icons.money;
      case 'MOBILE_MONEY':
        return Icons.phone_android;
      case 'CARTE':
        return Icons.credit_card;
      case 'VIREMENT':
        return Icons.account_balance;
      default:
        return Icons.payment;
    }
  }

  String _getModeLabel(String mode) {
    switch (mode.toUpperCase()) {
      case 'ESPECE':
        return 'Espèces';
      case 'MOBILE_MONEY':
        return 'Mobile Money';
      case 'CARTE':
        return 'Carte';
      case 'VIREMENT':
        return 'Virement';
      default:
        return mode;
    }
  }
}
