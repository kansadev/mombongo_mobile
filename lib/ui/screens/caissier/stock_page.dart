import 'package:flutter/material.dart';
import 'package:mombongo/services/app_currency_preference.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/utils/api_error_message.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  List<dynamic> _stockArticles = [];
  List<dynamic> _filteredArticles = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _showServices = false;
  bool _showAll = true;
  bool _showPerimes = false;
  bool _showEpuises = false;
  bool _showSearchBar = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadStockData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _filterArticles();
  }

  Future<void> _loadStockData() async {
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
        throw Exception('ID de site invalide');
      }

      // Charger les données depuis l'API
      final stockData = await locator.apiService.getStockArticles(
        idSite: idSite,
        pageSize: 1000,
        sortOrder: 'asc',
      );

      if (!mounted) return;

      setState(() {
        _stockArticles = stockData;
        _filteredArticles = stockData;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement du stock: $e');
      if (!mounted) return;

      setState(() {
        _errorMessage = apiErrorUserMessage(e);
        _isLoading = false;
      });
    }
  }

  void _filterArticles() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredArticles = _stockArticles.where((article) {
        // Filtre de recherche
        final libelle = (article['libelle'] ?? '').toString().toLowerCase();
        final codeBarre = (article['codeBarreQR'] ?? '')
            .toString()
            .toLowerCase();

        final matchesSearch =
            query.isEmpty ||
            libelle.contains(query) ||
            codeBarre.contains(query);

        if (!matchesSearch) return false;

        // Si "Tous" est sélectionné, afficher tous les articles
        if (_showAll) return true;

        // Filtre Services
        if (_showServices) {
          if (article['withStock'] != false) return false;
        }

        // Filtre Épuisés
        if (_showEpuises) {
          final quantiteStock = _parseInt(article['quantiteStock']);
          if (quantiteStock > 0) return false; // Pas épuisé
        }

        // Filtre Périmés
        if (_showPerimes) {
          // Pour l'instant, on considère qu'un article est périmé si sa date de péremption est passée
          // À adapter selon les données disponibles dans l'API
          // final datePeremption = article['datePeremption'];
          // if (datePeremption != null) {
          //   final date = DateTime.tryParse(datePeremption.toString());
          //   if (date != null && date.isAfter(DateTime.now())) {
          //     return false; // Pas encore périmé
          //   }
          // }
        }

        return true;
      }).toList();
    });
  }

  int _getTotalArticles() {
    return _filteredArticles.length;
  }

  int _getArticlesEnAlerte() {
    return _filteredArticles.where((article) {
      final quantiteStock = _parseInt(article['quantiteStock']);
      final seuilAlerte = _parseInt(article['seuilAlerte']);
      return quantiteStock <= seuilAlerte;
    }).length;
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed?.toInt() ?? 0;
    }
    return 0;
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

  bool _isStockLow(dynamic article) {
    final quantiteStock = _parseInt(article['quantiteStock']);
    final seuilAlerte = _parseInt(article['seuilAlerte']);
    return quantiteStock <= seuilAlerte;
  }

  Color _getStockColor(dynamic article) {
    final quantiteStock = _parseInt(article['quantiteStock']);
    final seuilAlerte = _parseInt(article['seuilAlerte']);

    if (quantiteStock <= 0) {
      return const Color(0xFFE74C3C); // Rouge - Stock épuisé
    } else if (quantiteStock <= seuilAlerte) {
      return const Color(0xFFF39C12); // Orange - Alerte
    } else {
      return const Color(0xFF2ECC71); // Vert - OK
    }
  }

  void _toggleSearchBar() {
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (_showSearchBar) {
        _searchFocusNode.requestFocus();
      } else {
        _searchController.clear();
        _searchFocusNode.unfocus();
        _filterArticles();
      }
    });
  }

  void _closeSearchBar() {
    setState(() {
      _showSearchBar = false;
      _searchController.clear();
      _searchFocusNode.unfocus();
      _filterArticles();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C3E50),
        title: _showSearchBar
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Rechercher un article...',
                  hintStyle: const TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white),
                    onPressed: _closeSearchBar,
                  ),
                ),
                onChanged: (value) {
                  _filterArticles();
                },
              )
            : const Text(
                'Articles en stock',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
        centerTitle: !_showSearchBar,
        actions: [
          if (!_showSearchBar)
            IconButton(
              onPressed: _toggleSearchBar,
              icon: const Icon(Icons.search),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStockData,
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Chargement du stock...'),
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
                      onPressed: _loadStockData,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Statistiques
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatCard(
                          _getTotalArticles().toString(),
                          'articles',
                          Icons.inventory_2,
                          Colors.blue,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          _getArticlesEnAlerte().toString(),
                          'en alerte',
                          Icons.warning_amber_rounded,
                          Colors.orange,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Filtres avec ChoiceChips
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Filtrer les articles :',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('Tous'),
                                selected: _showAll,
                                onSelected: (selected) {
                                  setState(() {
                                    _showAll = selected;
                                    if (_showAll) {
                                      _showServices = false;
                                      _showPerimes = false;
                                      _showEpuises = false;
                                    }
                                    _filterArticles();
                                  });
                                },
                                selectedColor: const Color(0xFF3498DB),
                                labelStyle: TextStyle(
                                  color: _showAll
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              ChoiceChip(
                                label: const Text('Services'),
                                selected: _showServices,
                                onSelected: (selected) {
                                  setState(() {
                                    _showServices = selected;
                                    if (_showServices) {
                                      _showAll = false;
                                    }
                                    _filterArticles();
                                  });
                                },
                                selectedColor: const Color(0xFF3498DB),
                                labelStyle: TextStyle(
                                  color: _showServices
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              ChoiceChip(
                                label: const Text('Épuisés'),
                                selected: _showEpuises,
                                onSelected: (selected) {
                                  setState(() {
                                    _showEpuises = selected;
                                    if (_showEpuises) {
                                      _showAll = false;
                                    }
                                    _filterArticles();
                                  });
                                },
                                selectedColor: const Color(0xFFE74C3C),
                                labelStyle: TextStyle(
                                  color: _showEpuises
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              ChoiceChip(
                                label: const Text('Périmés'),
                                selected: _showPerimes,
                                onSelected: (selected) {
                                  setState(() {
                                    _showPerimes = selected;
                                    if (_showPerimes) {
                                      _showAll = false;
                                    }
                                    _filterArticles();
                                  });
                                },
                                selectedColor: const Color(0xFFF39C12),
                                labelStyle: TextStyle(
                                  color: _showPerimes
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Liste des articles
                    if (_filteredArticles.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(40),
                        child: const Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Aucun article trouvé',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._filteredArticles.asMap().entries.map((entry) {
                        final index = entry.key;
                        final article = entry.value;
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index < _filteredArticles.length - 1
                                ? 12
                                : 0,
                          ),
                          child: _buildArticleCard(article),
                        );
                      }),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatCard(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF7F8C8D)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleCard(dynamic article) {
    final libelle = article['libelle'] ?? 'N/A';
    final quantiteStock = _parseInt(article['quantiteStock']);
    final prixVentHT = _parseDouble(article['prixVentHT']);
    final prixVentTTC = _parseDouble(article['prixVentTTC']);
    final seuilAlerte = _parseInt(article['seuilAlerte']);
    final codeBarreQR = article['codeBarreQR'] ?? '';
    final remise = _parseDouble(article['remise']);
    final tva = _parseDouble(article['tva']);
    final stockColor = _getStockColor(article);
    final isLowStock = _isStockLow(article);


    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLowStock ? stockColor.withOpacity(0.5) : Colors.grey[200]!,
          width: isLowStock ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête de la carte
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Indicateur de statut
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: stockColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                // Nom de l'article
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        libelle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      if (codeBarreQR.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Code: $codeBarreQR',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Badge d'alerte si nécessaire
                if (isLowStock)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: stockColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      quantiteStock <= 0 ? 'ÉPUISÉ' : 'ALERTE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: stockColor,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Informations de stock
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Stock',
                    quantiteStock.toString(),
                    Icons.inventory_2,
                    stockColor,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: _buildInfoItem(
                    'Seuil',
                    seuilAlerte.toString(),
                    Icons.warning_amber_rounded,
                    Colors.orange,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Informations de prix
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Prix HT',
                    '${locator.tauxService.formatPrice(prixVentHT)}',
                    Icons.attach_money,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: _buildInfoItem(
                    'Prix TTC',
                    '${locator.tauxService.formatPrice(prixVentTTC)}',
                    Icons.receipt,
                    Colors.green,
                  ),
                ),
              ],
            ),

            // Informations supplémentaires
            if (tva > 0 || remise > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (tva > 0)
                    Expanded(
                      child: _buildInfoItem(
                        'TVA',
                        '${tva.toStringAsFixed(0)}%',
                        Icons.percent,
                        Colors.purple,
                      ),
                    ),
                  const SizedBox(width: 5),
                  if (remise > 0)
                    Expanded(
                      child: _buildInfoItem(
                        'Remise',
                        '${remise.toStringAsFixed(0)}%',
                        Icons.discount,
                        Colors.teal,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
