import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mombongo/services/app_currency_preference.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/ui/screens/profil_screen.dart';

class RapportsVenteScreen extends StatefulWidget {
  const RapportsVenteScreen({super.key});

  @override
  State<RapportsVenteScreen> createState() => _RapportsVenteScreenState();
}

class _RapportsVenteScreenState extends State<RapportsVenteScreen> {
  List<dynamic> _sales = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Pagination
  int _currentPage = 1;
  int _pageSize = 20;
  int _totalPages = 1;
  int _totalCount = 0;
  bool _hasNextPage = false;
  bool _hasPreviousPage = false;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales({int page = 1}) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
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

      final response = await locator.apiService.getJournalVenteParSite(
        idSite: idSite,
        page: page,
        pageSize: _pageSize,
      );

      if (!mounted) return;

      final pagination = response['pagination'] as Map<String, dynamic>? ?? {};

      setState(() {
        _sales = response['data'] as List? ?? [];
        _currentPage = pagination['page'] as int? ?? 1;
        _pageSize = pagination['pageSize'] as int? ?? 20;
        _totalCount = pagination['totalCount'] as int? ?? 0;
        _totalPages = pagination['totalPages'] as int? ?? 1;
        _hasNextPage = pagination['hasNextPage'] as bool? ?? false;
        _hasPreviousPage = pagination['hasPreviousPage'] as bool? ?? false;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement des ventes: $e');
      if (!mounted) return;

      setState(() {
        if (kDebugMode) {
          _errorMessage = 'Erreur lors du chargement des ventes: $e';
        } else {
          _errorMessage =
              'Une erreur est survenue lors du chargement des ventes. Veuillez reessayer.';
        }
        _isLoading = false;
      });
    }
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

  String _formatCurrency(double amount) {
    final code = AppCurrencyPreference.readCode(locator.databaseService);
    final formatter = AppCurrencyPreference.formatterFor(code);
    final symbol = AppCurrencyPreference.symbolFor(code);
    return '${formatter.format(amount)} $symbol';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Rapports de vente'),
        centerTitle: true,
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilScreen()),
              );
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
        onRefresh: () => _loadSales(page: _currentPage),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _loadSales(),
                      child: const Text('Reessayer'),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  // Sales list
                  Expanded(
                    child: _sales.isEmpty
                        ? const Center(child: Text('Aucune vente trouvee'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _sales.length,
                            itemBuilder: (context, index) {
                              return _buildSaleCard(_sales[index]);
                            },
                          ),
                  ),

                  // Pagination
                  _buildPagination(),
                ],
              ),
      ),
    );
  }

  Widget _buildSaleCard(Map<String, dynamic> sale) {
    final libelle = sale['libelle']?.toString() ?? 'Article';
    final quantite = _parseInt(sale['quantite']);
    final prixUnitaire = _parseDouble(sale['prixUnitaire']);
    final total = _parseDouble(sale['total']);
    final dateCreation = sale['dateCreation'];
    final nomCaissier = sale['nomCaissier']?.toString() ?? 'Caissier';

    DateTime? parsedDate;
    if (dateCreation != null) {
      try {
        parsedDate = DateTime.parse(dateCreation.toString());
      } catch (e) {
        debugPrint('Error parsing date: $e');
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    libelle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _formatCurrency(total),
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip(
                  icon: Icons.shopping_cart,
                  label: 'Qte',
                  value: '$quantite',
                ),
                const SizedBox(width: 16),
                _buildInfoChip(
                  icon: Icons.attach_money,
                  label: 'Prix',
                  value: _formatCurrency(prixUnitaire),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.person, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      nomCaissier,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                if (parsedDate != null)
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(parsedDate),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Page $_currentPage / $_totalPages\n$_totalCount ventes',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          Row(
            children: [
              IconButton(
                onPressed: _hasPreviousPage
                    ? () => _loadSales(page: _currentPage - 1)
                    : null,
                icon: const Icon(Icons.arrow_back_ios),
                iconSize: 20,
                disabledColor: Colors.grey[300],
              ),
              IconButton(
                onPressed: _hasNextPage
                    ? () => _loadSales(page: _currentPage + 1)
                    : null,
                icon: const Icon(Icons.arrow_forward_ios),
                iconSize: 20,
                disabledColor: Colors.grey[300],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
