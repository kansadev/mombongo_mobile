import 'package:flutter/material.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:intl/intl.dart';
import 'package:mombongo/utils/api_error_message.dart';

class PeremptionScreen extends StatefulWidget {
  const PeremptionScreen({super.key});

  @override
  State<PeremptionScreen> createState() => _PeremptionScreenState();
}

class _PeremptionScreenState extends State<PeremptionScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _perissableItems = [];
  String _searchQuery = '';
  bool _showSearchBar = false;

  @override
  void initState() {
    super.initState();
    _loadPerissableItems();
  }

  Future<void> _loadPerissableItems() async {
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
        throw Exception('ID du site invalide');
      }

      final response = await locator.apiService.getInventairePerissable(
        idSite: idSite,
        pageSize: 100,
      );

      if (!mounted) return;

      setState(() {
        _perissableItems = response['data'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement des articles périssables: $e');
      if (!mounted) return;

      setState(() {
        _errorMessage = apiErrorUserMessage(e);
        _isLoading = false;
      });
    }
  }

  void _filterItems(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  List<dynamic> get _filteredItems {
    if (_searchQuery.isEmpty) {
      return _perissableItems;
    }
    final query = _searchQuery.toLowerCase();
    return _perissableItems.where((item) {
      final article = (item['article'] ?? '').toString().toLowerCase();
      final numeroLot = (item['numeroLot'] ?? '').toString().toLowerCase();
      return article.contains(query) || numeroLot.contains(query);
    }).toList();
  }

  void _toggleSearchBar() {
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (!_showSearchBar) {
        _searchQuery = '';
      }
    });
  }

  Color _getExpirationColor(int joursRestants) {
    if (joursRestants <= 7) {
      return Colors.red;
    } else if (joursRestants <= 30) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  String _getExpirationText(int joursRestants) {
    if (joursRestants <= 0) {
      return 'Expiré';
    } else if (joursRestants == 1) {
      return 'Expire demain';
    } else if (joursRestants <= 7) {
      return '$joursRestants jours restants';
    } else if (joursRestants <= 30) {
      return '$joursRestants jours';
    } else {
      return '$joursRestants jours';
    }
  }

  String _formatDuree(int joursRestants) {
    if (joursRestants <= 0) {
      return 'Expiré';
    }
    
    final years = joursRestants ~/ 365;
    final remainingAfterYears = joursRestants % 365;
    final months = remainingAfterYears ~/ 30;
    final remainingAfterMonths = remainingAfterYears % 30;
    final weeks = remainingAfterMonths ~/ 7;
    final days = remainingAfterMonths % 7;
    
    final parts = <String>[];
    
    if (years > 0) {
      parts.add('$years an${years > 1 ? 's' : ''}');
    }
    if (months > 0) {
      parts.add('$months mois');
    }
    if (weeks > 0) {
      parts.add('$weeks sem${weeks > 1 ? 's' : ''}');
    }
    if (days > 0 || parts.isEmpty) {
      parts.add('$days jour${days > 1 ? 's' : ''}');
    }
    
    return parts.join(', ');
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

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C3E50),
        title: _showSearchBar
            ? TextField(
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Rechercher un article...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: _filterItems,
              )
            : const Text(
                'Articles Périssables',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
        centerTitle: true,
        actions: [
          if (_showSearchBar)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _toggleSearchBar,
              tooltip: 'Fermer la recherche',
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _toggleSearchBar,
              tooltip: 'Rechercher',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPerissableItems,
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Chargement des articles...'),
                  ],
                ),
              )
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
                      onPressed: _loadPerissableItems,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              )
            : _filteredItems.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isEmpty
                          ? 'Aucun article périssable'
                          : 'Aucun article trouvé',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_searchQuery.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _toggleSearchBar,
                        child: const Text('Effacer la recherche'),
                      ),
                    ],
                  ],
                ),
              )
            : Column(
                children: [
                  // Statistiques
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildQuickStat(
                          'Total',
                          '${_filteredItems.length}',
                          Icons.inventory,
                          Colors.blue,
                        ),
                        _buildQuickStat(
                          'Expirés',
                          '${_filteredItems.where((i) => _parseInt(i['joursRestants']) <= 0).length}',
                          Icons.cancel,
                          Colors.red,
                        ),
                        _buildQuickStat(
                          '< 7 jours',
                          '${_filteredItems.where((i) => _parseInt(i['joursRestants']) > 0 && _parseInt(i['joursRestants']) <= 7).length}',
                          Icons.warning,
                          Colors.orange,
                        ),
                      ],
                    ),
                  ),
                  // Liste
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildPerissableCard(item),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildQuickStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildPerissableCard(dynamic item) {
    final article = item['article'] ?? 'N/A';
    final numeroLot = item['numeroLot'] ?? '';
    final quantiteLot = _parseInt(item['quantiteLot']);
    final dateExpiration = item['dateExpiration'] ?? '';
    final joursRestants = _parseInt(item['joursRestants']);
    final expirationColor = _getExpirationColor(joursRestants);
    final expirationText = _getExpirationText(joursRestants);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icône de statut
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: expirationColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: expirationColor, width: 2),
                      ),
                      child: Center(
                        child: Icon(
                          joursRestants <= 0
                              ? Icons.cancel
                              : joursRestants <= 7
                                  ? Icons.warning
                                  : Icons.check_circle,
                          color: expirationColor,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Infos principales
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            article,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C3E50),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (numeroLot.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.tag, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  'Lot: $numeroLot',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Badge de jours restants
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: expirationColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: expirationColor),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$joursRestants',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: expirationColor,
                            ),
                          ),
                          Text(
                            'jours',
                            style: TextStyle(
                              fontSize: 10,
                              color: expirationColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Détails
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildDetailItem(
                          'Quantité',
                          '$quantiteLot',
                          Icons.inventory_2,
                        ),
                      ),
                      Container(
                        height: 30,
                        width: 1,
                        color: Colors.grey[300],
                      ),
                      Expanded(
                        child: _buildDetailItem(
                          'Expiration',
                          _formatDuree(joursRestants),
                          Icons.timer,
                        ),
                      ),
                      Container(
                        height: 30,
                        width: 1,
                        color: Colors.grey[300],
                      ),
                      Expanded(
                        child: _buildDetailItem(
                          'Statut',
                          expirationText,
                          Icons.info_outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[500],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
