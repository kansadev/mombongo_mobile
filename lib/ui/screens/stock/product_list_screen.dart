import 'package:flutter/material.dart';
import 'package:mombongo/services/app_currency_preference.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/ui/screens/stock/edit_article_screen.dart';
import 'package:mombongo/utils/api_error_message.dart';
// import 'package:mombongo/ui/screens/stock/update_article_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _products = [];
  List<dynamic> _filteredProducts = [];
  String _searchQuery = '';
  bool _showSearchBar = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
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

      final allProducts = await locator.apiService.getStockArticles(
        idSite: idSite,
        pageSize: 1000,
        sortOrder: 'asc',
      );

      if (!mounted) return;

      setState(() {
        _products = allProducts;
        _filteredProducts = allProducts;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement des produits: $e');
      if (!mounted) return;

      setState(() {
        _errorMessage = apiErrorUserMessage(e);
        _isLoading = false;
      });
    }
  }

  void _filterProducts(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredProducts = _products;
      } else {
        _filteredProducts = _products.where((product) {
          final libelle = (product['libelle'] ?? '').toString().toLowerCase();
          final codeBarreQR = (product['codeBarreQR'] ?? '')
              .toString()
              .toLowerCase();
          final searchLower = query.toLowerCase();
          return libelle.contains(searchLower) ||
              codeBarreQR.contains(searchLower);
        }).toList();
      }
    });
  }

  void _toggleSearchBar() {
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (!_showSearchBar) {
        _searchQuery = '';
        _filteredProducts = _products;
      }
    });
  }

  void _closeSearchBar() {
    setState(() {
      _showSearchBar = false;
      _searchQuery = '';
      _filteredProducts = _products;
    });
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
    final code = AppCurrencyPreference.readCode(locator.databaseService);
    final formatter = AppCurrencyPreference.formatterFor(code);
    final symbol = AppCurrencyPreference.symbolFor(code);
    return '${formatter.format(amount)} $symbol';
  }

  Color _getStockColor(dynamic product) {
    final quantiteStock = _parseDouble(product['quantiteStock']);
    final seuilAlerte = _parseDouble(product['seuilAlerte']);

    if (quantiteStock <= 0) {
      return Colors.red;
    } else if (quantiteStock <= seuilAlerte) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C3E50),
        title: _showSearchBar
            ? TextField(
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Rechercher un produit...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                ),
                onChanged: _filterProducts,
              )
            : const Text(
                'Liste des Produits',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
        centerTitle: true,
        actions: [
          if (_showSearchBar)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _closeSearchBar,
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
        onRefresh: _loadProducts,
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Chargement des produits...'),
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
                      onPressed: _loadProducts,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              )
            : _filteredProducts.isEmpty
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
                          ? 'Aucun produit en stock'
                          : 'Aucun produit trouvé',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_searchQuery.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _closeSearchBar,
                        child: const Text('Effacer la recherche'),
                      ),
                    ],
                  ],
                ),
              )
            : Column(
                children: [
                  // Statistiques rapides
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Colors.grey[50],
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildQuickStat(
                          'Total',
                          '${_filteredProducts.length}',
                          Icons.inventory,
                          Colors.blue,
                        ),
                        _buildQuickStat(
                          'En stock',
                          '${_filteredProducts.where((p) => _parseDouble(p['quantiteStock']) > 0).length}',
                          Icons.check_circle,
                          Colors.green,
                        ),
                        _buildQuickStat(
                          'En alerte',
                          '${_filteredProducts.where((p) {
                            final qty = _parseDouble(p['quantiteStock']);
                            final seuil = _parseDouble(p['seuilAlerte']);
                            return qty > 0 && qty <= seuil;
                          }).length}',
                          Icons.warning,
                          Colors.orange,
                        ),
                        _buildQuickStat(
                          'Services',
                          '${_filteredProducts.where((p) => p['withStock'] == false || p['withStock'] == 'false').length}',
                          Icons.miscellaneous_services,
                          Colors.purple,
                        ),
                      ],
                    ),
                  ),
                  // Liste des produits
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildProductCard(product),
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

  Widget _buildProductCard(dynamic product) {
    final libelle = product['libelle'] ?? 'N/A';
    final quantiteStock = _parseDouble(product['quantiteStock']);
    final prixAchat = _parseDouble(product['prixAchat']);
    final prixVentHT = _parseDouble(product['prixVentHT']);
    final prixVentTTC = _parseDouble(product['prixVentTTC']);
    final seuilAlerte = _parseDouble(product['seuilAlerte']);
    final codeBarreQR = product['codeBarreQR'] ?? '';
    final stockColor = _getStockColor(product);
    final isLowStock = quantiteStock > 0 && quantiteStock <= seuilAlerte;
    final isOutOfStock = quantiteStock <= 0;
    
    // Vérifier si c'est un service (withStock = false)
    final isService = product['withStock'] == false || product['withStock'] == 'false';
    
    // Design différent pour les services
    if (isService) {
      return _buildServiceCard(product, libelle, prixVentHT, prixVentTTC, codeBarreQR);
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: stockColor.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge de statut
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: stockColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: stockColor, width: 2),
                  ),
                  child: Center(
                    child: Icon(
                      isOutOfStock
                          ? Icons.cancel
                          : isLowStock
                          ? Icons.warning
                          : Icons.check_circle,
                      color: stockColor,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Informations principales
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
                      const SizedBox(height: 8),
                      // Stock
                      Row(
                        children: [
                          Icon(Icons.inventory_2, size: 16, color: stockColor),
                          const SizedBox(width: 4),
                          Text(
                            'Stock: ${quantiteStock.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: stockColor,
                            ),
                          ),
                          if (seuilAlerte > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              '(Seuil: ${seuilAlerte.toStringAsFixed(0)})',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // Prix
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildPriceInfo(
                    'Prix d\'achat',
                    _formatCurrency(prixAchat),
                    Icons.shopping_bag,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPriceInfo(
                    'Prix HT',
                    _formatCurrency(prixVentHT),
                    Icons.receipt,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPriceInfo(
                    'Prix TTC',
                    _formatCurrency(prixVentTTC),
                    Icons.attach_money,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            // Marge
            if (prixAchat > 0 && prixVentHT > prixAchat) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.trending_up, size: 16, color: Colors.green[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Marge: ${_formatCurrency(prixVentHT - prixAchat)} (${((prixVentHT - prixAchat) / prixAchat * 100).toStringAsFixed(1)}%)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Boutons d'actions
            Row(
              children: [
                // Bouton de modification
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditArticleScreen(
                            article: product,
                          ),
                        ),
                      );
                      // Recharger automatiquement si modification réussie
                      if (result == true) {
                        _loadProducts();
                      }
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Modifier'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C3E50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Bouton de suppression
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmDeleteProduct(product),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Supprimer'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceInfo(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }



  Future<void> _confirmDeleteProduct(Map<String, dynamic> product) async {
    final libelle = product['libelle'] ?? 'cet article';
    final idArticle = product['idArticle'];

    if (idArticle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID de l\'article non trouvé'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Récupérer l'ID de l'article
    int articleId;
    if (idArticle is int) {
      articleId = idArticle;
    } else if (idArticle is String) {
      articleId = int.tryParse(idArticle) ?? 0;
    } else {
      articleId = 0;
    }

    if (articleId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID de l\'article invalide'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Afficher une boîte de dialogue de confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: Text(
            'Êtes-vous sûr de vouloir supprimer "$libelle" ? Cette action est irréversible.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ANNULER'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('SUPPRIMER'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteProduct(articleId);
    }
  }

  Future<void> _deleteProduct(int articleId) async {
    try {
      setState(() {
        _isLoading = true;
      });

      await locator.apiService.deleteArticle(articleId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Article supprimé avec succès'),
          backgroundColor: Colors.green,
        ),
      );

      // Recharger la liste
      _loadProducts();
    } catch (e) {
      debugPrint('Erreur lors de la suppression: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorUserMessage(e)), backgroundColor: Colors.red),
      );
    }
  }

  // Méthode pour construire la carte d'un service (withStock = false)
  Widget _buildServiceCard(
    dynamic product,
    String libelle,
    double prixVentHT,
    double prixVentTTC,
    String codeBarreQR,
  ) {
    final prixAchat = _parseDouble(product['prixAchat']);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.purple.withOpacity(0.3), width: 1),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditArticleScreen(
                article: product,
              ),
            ),
          );
          if (result == true) {
            _loadProducts();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge Service
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.purple, width: 2),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.miscellaneous_services,
                        color: Colors.purple,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Informations principales
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                libelle,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C3E50),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'SERVICE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple,
                                ),
                              ),
                            ),
                          ],
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
                ],
              ),
              const Divider(height: 24),
              // Prix - Pas de stock pour les services, seulement prix TTC
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: _buildPriceInfo(
                      'Prix TTC',
                      _formatCurrency(prixVentTTC),
                      Icons.attach_money,
                      Colors.purple,
                    ),
                  ),
                ],
              ),
              // Pas de marge pour les services (pas de prix d'achat)
              const SizedBox(height: 16),
              // Boutons d'actions
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditArticleScreen(
                              article: product,
                            ),
                          ),
                        );
                        if (result == true) {
                          _loadProducts();
                        }
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Modifier'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C3E50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
