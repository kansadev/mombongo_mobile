import 'package:flutter/material.dart';
import 'package:mombongo/services/service_locator.dart';

class MiseAJourStockScreen extends StatefulWidget {
  const MiseAJourStockScreen({super.key});

  @override
  State<MiseAJourStockScreen> createState() => _MiseAJourStockScreenState();
}

class _MiseAJourStockScreenState extends State<MiseAJourStockScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late AnimationController _searchBarController;

  List<Map<String, dynamic>> _stocks = [];
  final Map<int, int> _modifications = {}; // Quantité à ajouter (pas le total)

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSearching = false;
  bool _isLoadingMore = false;
  bool _hasMorePages = true;
  int _currentPage = 1;
  final int _pageSize = 20;
  String _errorMessage = '';
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> get _filteredArticles {
    if (_searchQuery.isEmpty) return _stocks;
    return _stocks.where((stock) {
      final libelle = (stock['libelle'] ?? '').toString().toLowerCase();
      return libelle.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _searchBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scrollController.addListener(_onScroll);
    _loadArticles();
  }

  @override
  void dispose() {
    _searchBarController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final delta = 200.0; // Distance du bas avant de charger plus
    
    if (maxScroll - currentScroll <= delta && 
        !_isLoading && 
        !_isLoadingMore && 
        _hasMorePages && 
        _searchQuery.isEmpty) {
      _loadMoreArticles();
    }
  }

  Future<void> _loadArticles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _currentPage = 1;
      _hasMorePages = true;
      _stocks.clear();
    });
    try {
      final currentUser = locator.authRepository.currentUser;
      if (currentUser == null) throw Exception('Non authentifié');

      final userRole = currentUser.role.toUpperCase();
      List<Map<String, dynamic>> stocks;

      if (userRole == 'ADMIN' || userRole == 'ADMINISTRATEUR') {
        // Admin : site opérationnel (bascule profil)
        final idSite = int.tryParse(currentUser.idSite) ?? 0;
        if (idSite == 0) {
          throw Exception('ID site invalide — choisissez un site dans le profil');
        }

        final result = await locator.apiService.getStockArticles(
          idSite: idSite,
          page: _currentPage,
          pageSize: _pageSize,
        );
        stocks = result.cast<Map<String, dynamic>>();
      } else if (userRole == 'GESTIONNAIRE') {
        // Gestionnaire : récupère les stocks de son site uniquement
        final idSite = int.tryParse(currentUser.idSite) ?? 0;
        if (idSite == 0) throw Exception('ID site invalide');

        final result = await locator.apiService.getStockArticles(
          idSite: idSite,
          page: _currentPage,
          pageSize: _pageSize,
        );
        stocks = result.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Rôle non autorisé pour cette action');
      }

      if (mounted) {
        setState(() {
          _stocks = stocks;
          _isLoading = false;
          _hasMorePages = stocks.length >= _pageSize;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _loadMoreArticles() async {
    if (_isLoadingMore || !_hasMorePages) return;

    setState(() => _isLoadingMore = true);

    try {
      final currentUser = locator.authRepository.currentUser;
      if (currentUser == null) throw Exception('Non authentifié');

      final userRole = currentUser.role.toUpperCase();
      List<Map<String, dynamic>> newStocks;

      if (userRole == 'ADMIN' || userRole == 'ADMINISTRATEUR') {
        final idSite = int.tryParse(currentUser.idSite) ?? 0;
        if (idSite == 0) {
          throw Exception('ID site invalide — choisissez un site dans le profil');
        }

        final result = await locator.apiService.getStockArticles(
          idSite: idSite,
          page: _currentPage + 1,
          pageSize: _pageSize,
        );
        newStocks = result.cast<Map<String, dynamic>>();
      } else if (userRole == 'GESTIONNAIRE') {
        final idSite = int.tryParse(currentUser.idSite) ?? 0;
        if (idSite == 0) throw Exception('ID site invalide');

        final result = await locator.apiService.getStockArticles(
          idSite: idSite,
          page: _currentPage + 1,
          pageSize: _pageSize,
        );
        newStocks = result.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Rôle non autorisé pour cette action');
      }

      if (mounted) {
        setState(() {
          _stocks.addAll(newStocks);
          _currentPage++;
          _isLoadingMore = false;
          _hasMorePages = newStocks.length >= _pageSize;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Theme.of(context).colorScheme.onSecondary,
        elevation: 0,
        leading: _isSearching
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchBarController.reverse();
                  setState(() {
                    _isSearching = false;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
              )
            : null,
        title: _isSearching
            ? SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0.3, 0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _searchBarController,
                        curve: Curves.easeOut,
                      ),
                    ),
                child: FadeTransition(
                  opacity: _searchBarController,
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    autofocus: true,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Rechercher...',
                      hintStyle: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondary.withValues(alpha: 0.7),
                      ),
                      border: InputBorder.none,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              )
            : const Text(
                'Approvisionnement',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
        actions: [
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() => _isSearching = true);
                _searchBarController.forward();
              },
            ),
        ],
      ),
      body: _buildMainContent(),
      bottomNavigationBar: _modifications.isNotEmpty ? _buildSaveBar() : null,
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      );
    }
    if (_errorMessage.isNotEmpty) return _buildErrorView();
    if (_filteredArticles.isEmpty) {
      return Center(
        child: Text(
          'Aucun article',
          style: TextStyle(
            color: Theme.of(context).colorScheme.secondary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: _filteredArticles.length + (_hasMorePages ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _filteredArticles.length && _hasMorePages) {
          return _buildLoadingIndicator();
        }

        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 300 + (index * 50)),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: _buildArticleCard(_filteredArticles[index]),
        );
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Chargement...',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleCard(Map<String, dynamic> stock) {
    final idStock = _parseInt(stock['idStock']);
    final currentStock = _parseDouble(stock['quantiteStock']).toInt();
    final quantityToAdd = _modifications[idStock] ?? 0;
    final hasModification = _modifications.containsKey(idStock) && quantityToAdd > 0;
    final libelle = stock['libelle'] ?? 'N/A';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: hasModification
                ? Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.2)
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
            blurRadius: hasModification ? 15 : 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: hasModification
              ? Theme.of(context).colorScheme.tertiary
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        libelle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Stock actuel : $currentStock',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 13,
                        ),
                      ),
                      if (hasModification)
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.tertiary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          child: Text('Nouveau stock : ${currentStock + quantityToAdd}'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildQtyControl(idStock, quantityToAdd, hasModification),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQtyControl(int idStock, int quantityToAdd, bool hasModif) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: hasModif
            ? Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _qtyIconButton(Icons.remove, () {
            if (quantityToAdd > 0) {
              setState(() {
                final newValue = quantityToAdd - 1;
                if (newValue == 0) {
                  _modifications.remove(idStock);
                } else {
                  _modifications[idStock] = newValue;
                }
              });
            }
          }),
          SizedBox(
            width: 70,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: TextFormField(
                key: ValueKey('input_${idStock}_$quantityToAdd'),
                initialValue: quantityToAdd.toString(),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: hasModif
                      ? Theme.of(context).colorScheme.tertiary
                      : Theme.of(context).colorScheme.onSurface,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                  border: InputBorder.none,
                ),
                onFieldSubmitted: (value) {
                  final newValue = int.tryParse(value);
                  if (newValue != null && newValue >= 0) {
                    setState(() {
                      if (newValue == 0) {
                        _modifications.remove(idStock);
                      } else {
                        _modifications[idStock] = newValue;
                      }
                    });
                  }
                },
              ),
            ),
          ),
          _qtyIconButton(Icons.add, () {
            setState(() => _modifications[idStock] = quantityToAdd + 1);
          }),
        ],
      ),
    );
  }

  Widget _qtyIconButton(IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildSaveBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
            blurRadius: 15,
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _isSaving ? null : _saveModifications,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
          ),
          child: _isSaving
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.onPrimary,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'ENREGISTREMENT...',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    'ENREGISTRER ${_modifications.length} ARTICLE${_modifications.length > 1 ? "S" : ""}',
                    key: ValueKey(_modifications.length),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  // --- Helpers restants (Error View, Save logic identique à l'étape précédente) ---
  Widget _buildErrorView() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _errorMessage,
          style: TextStyle(
            color: Theme.of(context).colorScheme.secondary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        ElevatedButton(
          onPressed: _loadArticles,
          child: Text(
            'Réessayer',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onTertiary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _saveModifications() async {
    setState(() => _isSaving = true);

    try {
      final currentUser = locator.authRepository.currentUser;
      if (currentUser == null) throw Exception('Non authentifié');


      // Parcourir toutes les modifications et appeler l'API pour chaque stock
      for (var entry in _modifications.entries) {
        final idStock = entry.key;
        final quantityToAdd = entry.value;

        // Trouver le stock correspondant pour avoir toutes les infos
        final stock = _stocks.firstWhere(
          (s) => _parseInt(s['idStock']) == idStock,
          orElse: () => {},
        );

        if (stock.isEmpty) continue;

        final currentQuantity = _parseDouble(stock['quantiteStock']);
        final newQuantity = currentQuantity + quantityToAdd;

        // Préparer les données pour l'API avec les champs requis par /api/Stocks/{id}
        final updateData = {
          'idStock': idStock,
          'idArticle': stock['idArticle'],
          'idSite': stock['idSite'],
          'quantiteStock': newQuantity,
          'prixAchat': stock['prixAchat'] ?? 0,
          'prixVentHT': stock['prixVentHT'] ?? 0,
          'seuilAlerte': stock['seuilAlerte'] ?? 0,
          'numeroLot': stock['numeroLot'] ?? '',
          'dateExpiration': stock['dateExpiration'],
          'commentairePeremption': stock['commentairePeremption'] ?? '',
        };
        //debugPrint('Données à envoyer pour idStock $idStock: $updateData');

        // Appeler l'API pour mettre à jour le stock
        await locator.apiService.updateStock(idStock, updateData);

        /* // Créer un enregistrement d'approvisionnement
        final approvisionnementData = {
          'dateCreation': DateTime.now().toUtc().toIso8601String(),
          'dateLastModification': DateTime.now().toUtc().toIso8601String(),
          'statut': true,
          'idAppro': 0, // Auto-généré par l'API
          'idStock': idStock,
          'idSite': idSite,
          'quantiteAppro': quantityToAdd,
          'provenance': 'Approvisionnement direct', // À modifier selon le cas d'usage
          'dateAppro': DateTime.now().toUtc().toIso8601String(),
        };

        // Appeler l'API pour créer l'approvisionnement
        await locator.apiService.createApprovisionnement(approvisionnementData);
 */
        // Mettre à jour localement
        stock['quantiteStock'] = newQuantity;
        stock['dateModification'] = updateData['dateModification'];
      }

      if (mounted) {
        setState(() {
          _modifications.clear();
          _isSaving = false;
        });

        // Animation de succès
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Stock et approvisionnement mis à jour avec succès',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Erreur: ${e.toString()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Helper methods
  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
