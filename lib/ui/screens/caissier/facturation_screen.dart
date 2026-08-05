// lib/screens/facturation_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mombongo/services/app_currency_preference.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/services/cart_service.dart';
import 'package:mombongo/ui/screens/caissier/product_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'cart_screen.dart';
import 'package:hive/hive.dart';
import 'package:mombongo/models/article_data.dart';
import 'package:mombongo/ui/widgets/fastFacturation.dart';

part 'facturation_screen.g.dart';

enum _ArticleFilter { withStock, service }

class FacturationScreen extends StatefulWidget {
  const FacturationScreen({super.key});

  @override
  State<FacturationScreen> createState() => _FacturationScreenState();
}

class _FacturationScreenState extends State<FacturationScreen>
    with WidgetsBindingObserver {
  static const String _fastSalePrefKey = 'pref_fast_sale_enabled';
  static const String _articleFilterPrefKey = 'pref_article_filter_with_stock';
  static const int _pageSize = 20;

  List<ArticleData> articles = [];
  List<ArticleData> filteredArticles = [];
  String? currentSiteId;
  bool isLoading = true;
  bool _fastSaleEnabled = true;
  bool _articleFilterWithStock = true; // Par défaut: articles avec stock
  bool _isFastSaleSheetOpen = false;
  ArticleData? _focusedArticle;
  final GlobalKey<FastSaleBottomSheetState> _fastSaleSheetKey =
      GlobalKey<FastSaleBottomSheetState>();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isSearchExpanded = false;
  _ArticleFilter? _articleFilter;
  String _currencyCode = AppCurrencyPreference.defaultCode;

  // Pagination
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;

  // Pagination (recherche)
  int _searchPage = 1;
  bool _isLoadingMoreSearch = false;
  bool _hasMoreSearchData = true;

  int _browseRequestId = 0;
  int _searchRequestId = 0;

  late NumberFormat _currencyFormat;
  String get _currencySymbol => AppCurrencyPreference.symbolFor(_currencyCode);

  // Map pour stocker les contrôleurs de quantité par article ID
  final Map<int, TextEditingController> _quantityControllers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currencyFormat = AppCurrencyPreference.formatterFor(_currencyCode);
    _scrollController.addListener(_onScroll);
    _init();
  }

  Future<void> _init() async {
    await _loadPreferences();
    await _loadArticles();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceSearch?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Recharger les préférences quand l'application reprend le focus
      _loadPreferences();
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final previousFilter = _articleFilter;
      final savedFastSale = locator.databaseService.get<bool>(_fastSalePrefKey);
      final savedArticleFilter = locator.databaseService.get<bool>(
        _articleFilterPrefKey,
      );
      final savedCurrency = AppCurrencyPreference.readCode(
        locator.databaseService,
      );
      if (!mounted) return;
      setState(() {
        _fastSaleEnabled = savedFastSale ?? true;
        _articleFilterWithStock =
            savedArticleFilter ?? true; // Par défaut: articles avec stock
        _currencyCode = savedCurrency;
        _currencyFormat = AppCurrencyPreference.formatterFor(_currencyCode);
        // Définir le filtre par défaut en fonction de la préférence
        _articleFilter = _articleFilterWithStock
            ? _ArticleFilter.withStock
            : _ArticleFilter.service;
      });
      // Appliquer le filtre immédiatement
      filteredArticles = _applyFiltersTo(articles, _searchController.text);

      if (previousFilter != _articleFilter && currentSiteId != null) {
        final query = _searchController.text.trim();
        if (query.isEmpty) {
          await _loadArticles();
        } else {
          await _searchFromApi(query);
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fastSaleEnabled = true;
        _articleFilterWithStock = true; // Par défaut: articles avec stock
        _currencyCode = AppCurrencyPreference.defaultCode;
        _currencyFormat = AppCurrencyPreference.formatterFor(_currencyCode);
        // Par défaut: articles avec stock
        _articleFilter = _ArticleFilter.withStock;
      });
      // Appliquer le filtre même en cas d'erreur
      filteredArticles = _applyFiltersTo(articles, _searchController.text);
    }
  }

  bool? _withStockFilterForApi() {
    if (_articleFilter == _ArticleFilter.withStock) return true;
    if (_articleFilter == _ArticleFilter.service) return false;
    return null;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (position.extentAfter > 300) return;

    final query = _searchController.text.trim();
    if (query.isEmpty) {
      unawaited(_loadMoreArticles());
    } else {
      unawaited(_loadMoreSearchResults());
    }
  }

  Future<List<ArticleData>> _fetchArticlesPage({
    required int siteId,
    required int page,
    required int pageSize,
    required String? search,
    required bool? withStock,
  }) async {
    return locator.cacheStrategy.getStockArticlesBySiteCached(
      siteId,
      page: page,
      pageSize: pageSize,
      search: search,
      withStock: withStock,
      forceRefresh: false,
    );
  }

  Future<void> _openFastSaleSheet({ArticleData? focusArticle}) async {
    if (!_fastSaleEnabled) return;

    if (_isFastSaleSheetOpen) {
      if (focusArticle != null) {
        _fastSaleSheetKey.currentState?.focusArticle(focusArticle);
      }
      return;
    }

    setState(() {
      _isFastSaleSheetOpen = true;
      _focusedArticle = focusArticle;
    });

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FastSaleBottomSheet(
          key: _fastSaleSheetKey,
          currencyFormat: _currencyFormat,
          currencySymbol: _currencySymbol,
          initialFocusedArticle: _focusedArticle,
          onClose: () {
            if (!mounted) return;
            setState(() {
              _isFastSaleSheetOpen = false;
              _focusedArticle = null;
            });
          },
        );
      },
    );

    if (!mounted) return;
    setState(() {
      _isFastSaleSheetOpen = false;
      _focusedArticle = null;
    });
  }

  Future<void> _loadArticles() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
    });

    try {
      // Get current user's site ID
      final currentUser = locator.authRepository.currentUser;
      if (currentUser != null) {
        currentSiteId = currentUser.idSite.toString();
        final siteIdInt = int.tryParse(currentSiteId!) ?? 0;
        if (siteIdInt <= 0) {
          throw Exception('ID site invalide');
        }

        final requestId = ++_browseRequestId;
        _currentPage = 1;
        _hasMoreData = true;
        _isLoadingMore = false;

        final withStockFilter = _withStockFilterForApi();
        final firstPage = await _fetchArticlesPage(
          siteId: siteIdInt,
          page: 1,
          pageSize: _pageSize,
          search: null,
          withStock: withStockFilter,
        );

        if (!mounted || requestId != _browseRequestId) return;

        setState(() {
          articles = firstPage;
          filteredArticles = _applyFiltersTo(firstPage, _searchController.text);
          isLoading = false;
          _hasMoreData = firstPage.length == _pageSize;
        });
      } else {
        // Handle case where no user is logged in
        if (mounted) {
          setState(() {
            isLoading = false;
          });
          _showErrorDialog('Utilisateur non connecté');
        }
      }
    } catch (e) {
      debugPrint('Error loading articles: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        _showErrorDialog('Erreur lors du chargement: $e');
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Erreur'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _loadArticles(); // Retry
            },
            child: const Text('Réessayer'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  // Méthode pour obtenir ou créer un contrôleur de quantité persistant
  TextEditingController _getOrCreateController(int articleId, int quantity) {
    if (!_quantityControllers.containsKey(articleId)) {
      _quantityControllers[articleId] = TextEditingController(
        text: quantity.toString(),
      );
    } else {
      // Synchroniser le contrôleur existant avec la quantité actuelle
      final controller = _quantityControllers[articleId]!;
      if (controller.text != quantity.toString()) {
        controller.text = quantity.toString();
      }
    }
    return _quantityControllers[articleId]!;
  }

  Future<void> _loadMoreArticles() async {
    if (currentSiteId == null) return;
    if (isLoading || _isLoadingMore || !_hasMoreData) return;

    final siteIdInt = int.tryParse(currentSiteId!) ?? 0;
    if (siteIdInt <= 0) return;

    final requestId = _browseRequestId;
    final nextPage = _currentPage + 1;
    final withStockFilter = _withStockFilterForApi();

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final fetched = await _fetchArticlesPage(
        siteId: siteIdInt,
        page: nextPage,
        pageSize: _pageSize,
        search: null,
        withStock: withStockFilter,
      );

      if (!mounted || requestId != _browseRequestId) return;

      if (fetched.isEmpty) {
        setState(() {
          _hasMoreData = false;
          _isLoadingMore = false;
        });
        return;
      }

      final existingIds = articles.map((a) => a.idStock).toSet();
      final toAppend = fetched.where((a) => existingIds.add(a.idStock)).toList();

      final isSearchActive = _searchController.text.trim().isNotEmpty;
      setState(() {
        _currentPage = nextPage;
        articles = [...articles, ...toAppend];
        if (!isSearchActive) {
          filteredArticles = _applyFiltersTo(articles, _searchController.text);
        }
        _hasMoreData = fetched.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      debugPrint('Error loading more articles: $e');
      if (!mounted || requestId != _browseRequestId) return;
      setState(() {
        _isLoadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du chargement des articles: $e'),
        ),
      );
    }
  }

  Future<void> _loadMoreSearchResults() async {
    if (currentSiteId == null) return;
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    if (isLoading || _isLoadingMoreSearch || !_hasMoreSearchData) return;

    final siteIdInt = int.tryParse(currentSiteId!) ?? 0;
    if (siteIdInt <= 0) return;

    final requestId = _searchRequestId;
    final nextPage = _searchPage + 1;
    final withStockFilter = _withStockFilterForApi();

    setState(() {
      _isLoadingMoreSearch = true;
    });

    try {
      final fetched = await _fetchArticlesPage(
        siteId: siteIdInt,
        page: nextPage,
        pageSize: _pageSize,
        search: query,
        withStock: withStockFilter,
      );

      if (!mounted || requestId != _searchRequestId) return;
      if (_searchController.text.trim() != query) {
        setState(() {
          _isLoadingMoreSearch = false;
        });
        return;
      }

      if (fetched.isEmpty) {
        setState(() {
          _hasMoreSearchData = false;
          _isLoadingMoreSearch = false;
        });
        return;
      }

      final existingIds = filteredArticles.map((a) => a.idStock).toSet();
      final toAppend =
          fetched.where((a) => existingIds.add(a.idStock)).toList();

      setState(() {
        _searchPage = nextPage;
        filteredArticles = [...filteredArticles, ...toAppend];
        _hasMoreSearchData = fetched.length == _pageSize;
        _isLoadingMoreSearch = false;
      });
    } catch (e) {
      debugPrint('Error loading more search results: $e');
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _isLoadingMoreSearch = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la recherche: $e'),
        ),
      );
    }
  }

  void _filterArticles(String query) {
    // Débouncer la recherche pour éviter trop d'appels API
    _debounceSearch?.cancel();
    _debounceSearch = Timer(const Duration(milliseconds: 500), () {
      if (query.isEmpty) {
        // Si la recherche est vide, afficher tous les articles
        _searchRequestId++;
        setState(() {
          isLoading = false;
          _searchPage = 1;
          _hasMoreSearchData = true;
          _isLoadingMoreSearch = false;
          filteredArticles = _applyFiltersTo(articles, '');
        });
      } else {
        // Rechercher via l'API
        _searchFromApi(query);
      }
    });
  }

  Timer? _debounceSearch;

  Future<void> _searchFromApi(String query) async {
    if (currentSiteId == null) return;

    final siteIdInt = int.tryParse(currentSiteId!) ?? 0;
    if (siteIdInt <= 0) return;

    final requestId = ++_searchRequestId;
    final withStockFilter = _withStockFilterForApi();

    setState(() {
      isLoading = true;
      _searchPage = 1;
      _hasMoreSearchData = true;
      _isLoadingMoreSearch = false;
    });

    try {
      final searchedArticles = await _fetchArticlesPage(
        siteId: siteIdInt,
        page: 1,
        pageSize: _pageSize,
        search: query,
        withStock: withStockFilter,
      );

      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        filteredArticles = searchedArticles;
        isLoading = false;
        _hasMoreSearchData = searchedArticles.length == _pageSize;
      });
    } catch (e) {
      debugPrint('Error searching articles from API: $e');
      if (!mounted || requestId != _searchRequestId) return;

      setState(() {
        filteredArticles = _applyFiltersTo(articles, query);
        isLoading = false;
        _hasMoreSearchData = false;
        _isLoadingMoreSearch = false;
      });
    }
  }

  List<ArticleData> _applyFiltersTo(List<ArticleData> source, String query) {
    final q = query.trim().toLowerCase();

    return source.where((article) {
      if (_articleFilter == _ArticleFilter.withStock && !article.withStock) {
        return false;
      }
      if (_articleFilter == _ArticleFilter.service && article.withStock) {
        return false;
      }

      if (q.isEmpty) return true;

      return article.libelle.toLowerCase().contains(q) ||
          article.codeBarreQR.toLowerCase().contains(q);
    }).toList();
  }

  void _openSearch() {
    setState(() {
      _isSearchExpanded = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch() {
    // Annuler le debounce en cours
    _debounceSearch?.cancel();
    _searchRequestId++;

    setState(() {
      _isSearchExpanded = false;
      _searchController.clear();
      isLoading = false;
      _searchPage = 1;
      _hasMoreSearchData = true;
      _isLoadingMoreSearch = false;
      // Revenir à la liste complète
      filteredArticles = articles;
    });
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearchExpanded
            ? SizedBox(
                height: 40,
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: _filterArticles,
                  textInputAction: TextInputAction.search,
                  cursorColor: Colors.black87,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un article...',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    prefixIcon: const Icon(Icons.search, color: Colors.black54),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              )
            : Text(
                'Facturation',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Colors.white,
        actions: [
          if (!_fastSaleEnabled)
            Consumer<CartService>(
              builder: (context, cartService, child) {
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CartScreen(),
                      ),
                    );
                  },
                  child: Stack(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.shopping_cart,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CartScreen(),
                            ),
                          );
                        },
                      ),
                      if (cartService.totalQuantity > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Text(
                              cartService.totalQuantity.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          IconButton(
            tooltip: _isSearchExpanded ? 'Fermer la recherche' : 'Rechercher',
            icon: Icon(_isSearchExpanded ? Icons.close : Icons.search),
            onPressed: _isSearchExpanded ? _closeSearch : _openSearch,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Wrap(
                  alignment: WrapAlignment.start,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Article avec stock'),
                      selected: _articleFilter == _ArticleFilter.withStock,
                      onSelected: (selected) {
                        setState(() {
                          _articleFilter =
                              selected ? _ArticleFilter.withStock : null;
                        });

                        final query = _searchController.text.trim();
                        if (query.isEmpty) {
                          unawaited(_loadArticles());
                        } else {
                          unawaited(_searchFromApi(query));
                        }
                      },
                      selectedColor: Theme.of(context).colorScheme.secondary,
                      labelStyle: TextStyle(
                        color: _articleFilter == _ArticleFilter.withStock
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('Service'),
                      selected: _articleFilter == _ArticleFilter.service,
                      onSelected: (selected) {
                        setState(() {
                          _articleFilter = selected ? _ArticleFilter.service : null;
                        });

                        final query = _searchController.text.trim();
                        if (query.isEmpty) {
                          unawaited(_loadArticles());
                        } else {
                          unawaited(_searchFromApi(query));
                        }
                      },
                      selectedColor: Theme.of(context).colorScheme.secondary,
                      labelStyle: TextStyle(
                        color: _articleFilter == _ArticleFilter.service
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredArticles.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucun article disponible',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: filteredArticles.length +
                            ((_searchController.text.trim().isEmpty
                                        ? _isLoadingMore
                                        : _isLoadingMoreSearch)
                                    ? 1
                                    : 0),
                        itemBuilder: (context, index) {
                          if (index >= filteredArticles.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          final article = filteredArticles[index];
                          return _buildArticleCard(context, article);
                        },
                      ),
              ),
            ],
          ),
          if (_fastSaleEnabled) _buildFloatingCartBar(context),
        ],
      ),
    );
  }

  Widget _buildArticleCard(BuildContext context, ArticleData article) {
    // Déterminer si c'est un service (sans gestion de stock)
    final bool isService = !article.withStock;

    // Couleur de la carte selon le type
    final Color cardColor = isService ? Colors.purple.shade50 : Colors.white;
    final Color borderColor = isService ? Colors.purple : Colors.blue.shade100;
    final Color iconColor = isService ? Colors.purple : Colors.blue;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: isService ? 2 : 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isService ? Icons.miscellaneous_services : Icons.inventory_2,
            color: iconColor,
            size: 24,
          ),
        ),
        title: Text(
          article.libelle,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: isService ? Colors.purple.shade800 : Colors.black87,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (isService)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'SERVICE',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                  ),
                ),
              )
            else if (article.quantiteStock <= article.seuilAlerte) ...[
              Text(
                'Stock: ${article.quantiteStock} | Attention stock inférieur au seuil d\'alerte: ${article.seuilAlerte}',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.red),
              ),
              const SizedBox(height: 2),
            ],
            Text(
              'Prix TTC: ${locator.tauxService.formatPrice(article.prixVentTTC)}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.green[700],
              ),
            ),
            const SizedBox(height: 2),
            if (!isService)
              Text(
                'Quantité en stock: ${article.quantiteStock}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              )
            else
              const SizedBox(height: 0),
          ],
        ),
        trailing: _fastSaleEnabled
            ? Consumer<CartService>(
                builder: (context, cartService, child) {
                  final qty =
                      cartService.getItem(article.idArticle)?.quantity ?? 0;

                  // Créer un contrôleur persistant pour cet article
                  final controller = _getOrCreateController(
                    article.idArticle,
                    qty,
                  );

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: qty > 0
                            ? () {
                                final newQty = qty - 1;
                                if (newQty > 0) {
                                  cartService.updateQuantity(
                                    article.idArticle,
                                    newQty,
                                  );
                                } else {
                                  cartService.updateQuantity(
                                    article.idArticle,
                                    0,
                                  );
                                }
                                // Mettre à jour le contrôleur
                                controller.text = newQty.toString();
                              }
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      SizedBox(
                        width: 50,
                        child: TextField(
                          controller: controller,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                          onTap: () {
                            // Si la quantité est 0, effacer le champ pour permettre la saisie directe
                            if (controller.text == '0') {
                              controller.clear();
                            }
                          },
                          onChanged: (value) {
                            // Vérifier si c'est un service (sans limite de stock)
                            final bool isService = !article.withStock;

                            // Si le champ est vide, mettre la quantité à 0 dans le panier
                            if (value.isEmpty) {
                              cartService.updateQuantity(article.idArticle, 0);
                              controller.text = '0';
                              return;
                            }

                            final newQty = int.tryParse(value) ?? 0;

                            // Pour les services, pas de limite de quantité
                            // Pour les articles avec stock, vérifier la disponibilité
                            if (isService) {
                              // Services: quantité illimitée
                              final existingItem = cartService.getItem(
                                article.idArticle,
                              );
                              if (existingItem != null) {
                                cartService.updateQuantity(
                                  article.idArticle,
                                  newQty,
                                );
                              } else if (newQty > 0) {
                                cartService.addItem(article, quantity: newQty);
                              }
                              controller.text = newQty.toString();
                            } else if (newQty >= 0 &&
                                newQty <= article.quantiteStock) {
                              // Vérifier si l'article existe déjà dans le panier
                              final existingItem = cartService.getItem(
                                article.idArticle,
                              );
                              if (existingItem != null) {
                                // Mettre à jour la quantité existante
                                cartService.updateQuantity(
                                  article.idArticle,
                                  newQty,
                                );
                              } else if (newQty > 0) {
                                // Ajouter l'article avec la quantité spécifiée
                                cartService.addItem(article, quantity: newQty);
                              }
                              // Synchroniser le contrôleur avec la valeur entrée
                              controller.text = newQty.toString();
                            } else if (newQty > article.quantiteStock) {
                              // Si la quantité dépasse le stock, revenir à la quantité max
                              final existingItem = cartService.getItem(
                                article.idArticle,
                              );
                              if (existingItem != null) {
                                cartService.updateQuantity(
                                  article.idArticle,
                                  article.quantiteStock,
                                );
                              } else {
                                cartService.addItem(
                                  article,
                                  quantity: article.quantiteStock,
                                );
                              }
                              controller.text = article.quantiteStock
                                  .toString();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Quantité maximale: ${article.quantiteStock}',
                                  ),
                                  backgroundColor: Colors.orange,
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          // Vérifier si c'est un service (sans limite de stock)
                          final bool isService = !article.withStock;

                          if (!isService && article.quantiteStock <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${article.libelle} est en rupture de stock',
                                ),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          // Pour les services, pas de limite de quantité
                          if (!isService && qty >= article.quantiteStock) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Stock insuffisant. Stock disponible: ${article.quantiteStock}',
                                ),
                                backgroundColor: Colors.orange,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          if (qty == 0) {
                            cartService.addItem(article);
                            // Mettre à jour le contrôleur avec la quantité ajoutée (1 par défaut)
                            controller.text = '1';
                          } else {
                            final newQty = qty + 1;
                            cartService.updateQuantity(
                              article.idArticle,
                              newQty,
                            );
                            // Mettre à jour le contrôleur
                            controller.text = newQty.toString();
                          }
                        },
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  );
                },
              )
            : ElevatedButton.icon(
                label: const Text('Ajouter'),
                icon: const Icon(
                  Icons.add_shopping_cart_sharp,
                  color: Colors.white,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                ),
                onPressed: () {
                  final cartService = Provider.of<CartService>(
                    context,
                    listen: false,
                  );
                  if (article.quantiteStock <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${article.libelle} est en rupture de stock',
                        ),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                  final existingItem = cartService.getItem(article.idArticle);
                  final existingQty = existingItem?.quantity ?? 0;
                  if (existingQty >= article.quantiteStock) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Stock insuffisant pour ${article.libelle}. Stock disponible: ${article.quantiteStock}',
                        ),
                        backgroundColor: Colors.orange,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                    return;
                  }
                  cartService.addItem(article);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${article.libelle} ajouté au panier'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
        onTap: _fastSaleEnabled
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ProductDetailScreen(productData: article),
                  ),
                );
              },
      ),
    );
  }

  Widget _buildFloatingCartBar(BuildContext context) {
    return Consumer<CartService>(
      builder: (context, cartService, child) {
        if (cartService.isEmpty) return const SizedBox.shrink();
        return Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: GestureDetector(
            onTap: () => _openFastSaleSheet(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(60),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(50),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.shopping_cart_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${cartService.totalQuantity} article(s)',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Appuyez pour finaliser',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${locator.tauxService.formatPrice(cartService.total)}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: Colors.white70,
                    size: 30,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
