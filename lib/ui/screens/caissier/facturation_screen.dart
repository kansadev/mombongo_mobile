// lib/screens/facturation_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mombongo/services/app_currency_preference.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/services/cart_service.dart';
import 'package:mombongo/ui/screens/caissier/product_detail_screen.dart';
import 'package:mombongo/utils/google_fonts_compat.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'cart_screen.dart';
import 'package:hive/hive.dart';
import 'package:mombongo/models/article_data.dart';
import 'package:mombongo/ui/widgets/fastFacturation.dart';
import 'package:mombongo/utils/invoice_receipt_helper.dart';

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
  bool _articleFilterWithStock = true;
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
  int _searchPage = 1;
  bool _isLoadingMoreSearch = false;
  bool _hasMoreSearchData = true;
  int _browseRequestId = 0;
  int _searchRequestId = 0;

  late NumberFormat _currencyFormat;
  String get _currencySymbol => AppCurrencyPreference.symbolFor(_currencyCode);

  // Contrôleurs de quantité
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
        _articleFilterWithStock = savedArticleFilter ?? true;
        _currencyCode = savedCurrency;
        _currencyFormat = AppCurrencyPreference.formatterFor(_currencyCode);
        _articleFilter = _articleFilterWithStock
            ? _ArticleFilter.withStock
            : _ArticleFilter.service;
      });

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
        _articleFilterWithStock = true;
        _currencyCode = AppCurrencyPreference.defaultCode;
        _currencyFormat = AppCurrencyPreference.formatterFor(_currencyCode);
        _articleFilter = _ArticleFilter.withStock;
      });
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
    // Online → API + merge cache ; offline → catalogue Hive (produits + services).
    return locator.cacheStrategy.getStockArticlesBySiteCached(
      siteId,
      page: page,
      pageSize: pageSize,
      search: search,
      withStock: withStock,
    );
  }

  Future<bool> _collectServiceDescriptionsBeforeConfirm(
    BuildContext context,
    CartService cartService,
  ) async {
    await collectOptionalServiceDescriptions(context, cartService);
    return true;
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
          beforeConfirmSale: _collectServiceDescriptionsBeforeConfirm,
          onClose: () {
            if (!mounted) return;
            setState(() {
              _isFastSaleSheetOpen = false;
              _focusedArticle = null;
            });
          },
          onSaleCompleted: _refreshAfterSale,
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
        if (mounted) {
          setState(() {
            articles = [];
            filteredArticles = [];
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading articles: $e');
      if (!mounted) return;
      // Pas de dialog hors ligne / erreur réseau sur la facturation :
      // on affiche simplement une liste vide (le cache est géré en amont).
      setState(() {
        articles = [];
        filteredArticles = [];
        isLoading = false;
        _hasMoreData = false;
      });
    }
  }

  Future<void> _refreshAfterSale() async {
    if (!mounted) return;

    final cartService = Provider.of<CartService>(context, listen: false);
    final soldItems = cartService.items.toList();

    for (final item in soldItems) {
      final articleId = item.article.idArticle;
      final quantitySold = item.quantity;

      final articleIndex = articles.indexWhere((a) => a.idArticle == articleId);
      if (articleIndex != -1) {
        final article = articles[articleIndex];
        final newStock = article.quantiteStock - quantitySold;
        articles[articleIndex] = ArticleData(
          idStock: article.idStock,
          idArticle: article.idArticle,
          libelle: article.libelle,
          quantiteStock: newStock < 0 ? 0 : newStock,
          prixAchat: article.prixAchat,
          prixVentHT: article.prixVentHT,
          prixVentTTC: article.prixVentTTC,
          seuilAlerte: article.seuilAlerte,
          tva: article.tva,
          codeBarreQR: article.codeBarreQR,
          remise: article.remise,
          idSite: article.idSite,
          nomSite: article.nomSite,
          idSociete: article.idSociete,
          withStock: article.withStock,
        );
      }

      if (_quantityControllers.containsKey(articleId)) {
        _quantityControllers[articleId]!.text = '0';
      }
    }

    if (!mounted) return;
    setState(() {
      filteredArticles = _applyFiltersTo(articles, _searchController.text);
    });

    await _loadArticles();
  }

  TextEditingController _getOrCreateController(int articleId, int quantity) {
    if (!_quantityControllers.containsKey(articleId)) {
      _quantityControllers[articleId] = TextEditingController(
        text: quantity.toString(),
      );
    } else {
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
      final toAppend = fetched
          .where((a) => existingIds.add(a.idStock))
          .toList();

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
        _hasMoreData = false;
      });
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
      final toAppend = fetched
          .where((a) => existingIds.add(a.idStock))
          .toList();

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
        _hasMoreSearchData = false;
      });
    }
  }

  void _filterArticles(String query) {
    _debounceSearch?.cancel();
    _debounceSearch = Timer(const Duration(milliseconds: 500), () {
      if (query.isEmpty) {
        _searchRequestId++;
        setState(() {
          isLoading = false;
          _searchPage = 1;
          _hasMoreSearchData = true;
          _isLoadingMoreSearch = false;
          filteredArticles = _applyFiltersTo(articles, '');
        });
      } else {
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
    _debounceSearch?.cancel();
    _searchRequestId++;

    setState(() {
      _isSearchExpanded = false;
      _searchController.clear();
      isLoading = false;
      _searchPage = 1;
      _hasMoreSearchData = true;
      _isLoadingMoreSearch = false;
      filteredArticles = articles;
    });
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearchExpanded
            ? Container(
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: _filterArticles,
                  textInputAction: TextInputAction.search,
                  cursorColor: Theme.of(context).colorScheme.secondary,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un article ou service...',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              )
            : Text(
                'Facturation',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              ),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Colors.white,
        elevation: 0,
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
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        const Icon(Icons.shopping_cart_outlined),
                        if (cartService.totalQuantity > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              child: Text(
                                cartService.totalQuantity.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: _isSearchExpanded ? 'Fermer' : 'Rechercher',
              icon: Icon(_isSearchExpanded ? Icons.close : Icons.search),
              onPressed: _isSearchExpanded ? _closeSearch : _openSearch,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildFilterChips(),
              Expanded(
                child: isLoading
                    ? _buildLoadingState()
                    : filteredArticles.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount:
                            filteredArticles.length +
                            ((_searchController.text.trim().isEmpty
                                    ? _isLoadingMore
                                    : _isLoadingMoreSearch)
                                ? 1
                                : 0),
                        itemBuilder: (context, index) {
                          if (index >= filteredArticles.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          final article = filteredArticles[index];
                          return _buildModernArticleCard(context, article);
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

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_list, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    label: '📦 Stock',
                    isSelected: _articleFilter == _ArticleFilter.withStock,
                    onSelected: () {
                      setState(() {
                        _articleFilter = _ArticleFilter.withStock;
                      });
                      final query = _searchController.text.trim();
                      if (query.isEmpty) {
                        unawaited(_loadArticles());
                      } else {
                        unawaited(_searchFromApi(query));
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: '⚙️ Services',
                    isSelected: _articleFilter == _ArticleFilter.service,
                    onSelected: () {
                      setState(() {
                        _articleFilter = _ArticleFilter.service;
                      });
                      final query = _searchController.text.trim();
                      if (query.isEmpty) {
                        unawaited(_loadArticles());
                      } else {
                        unawaited(_searchFromApi(query));
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.secondary
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.secondary
                : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildModernArticleCard(BuildContext context, ArticleData article) {
    final bool isService = !article.withStock;
    final bool isLowStock = !isService && article.quantiteStock <= 5;
    final bool isOutOfStock = !isService && article.quantiteStock <= 0;

    // Définition du thème Teal adapté selon le type (Produit ou Service)
    final Color primaryColor = Colors.teal.shade600;
    final Color lightBackgroundColor = Colors.teal.shade50;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withValues(alpha: 0.08), // Ombre subtile teintée
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _fastSaleEnabled && !isService
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ProductDetailScreen(productData: article),
                      ),
                    );
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- EN-TÊTE ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icône avec dégradé élégant
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isService
                                ? [Colors.teal.shade300, Colors.teal.shade400]
                                : [Colors.teal.shade500, Colors.teal.shade700],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          isService
                              ? Icons.design_services_outlined
                              : Icons.inventory_2_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Titre et Badge
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              article.libelle,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: Colors.blueGrey.shade800,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (isService) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: lightBackgroundColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.teal.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  'Service',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // --- INFORMATIONS PRIX ET STOCK ---
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Prix
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Prix TTC',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.blueGrey.shade400,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              locator.tauxService.formatPrice(
                                article.prixVentTTC,
                              ),
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),

                        // Stock (si ce n'est pas un service)
                        if (!isService) ...[
                          Container(
                            width: 1,
                            height: 35,
                            color: Colors.grey.shade300,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Stock disponible',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.blueGrey.shade400,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  if (isLowStock && !isOutOfStock)
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      size: 16,
                                      color: Colors.orange.shade700,
                                    ),
                                  if (isOutOfStock)
                                    Icon(
                                      Icons.error_outline_rounded,
                                      size: 16,
                                      color: Colors.red.shade700,
                                    ),
                                  if (isLowStock || isOutOfStock)
                                    const SizedBox(width: 4),
                                  Text(
                                    '${article.quantiteStock} unités',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isOutOfStock
                                          ? Colors.red.shade700
                                          : isLowStock
                                          ? Colors.orange.shade700
                                          : Colors.blueGrey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // --- ACTIONS (Sélecteur de quantité) ---
                  _buildQuantitySelector(
                    context,
                    article,
                    isService,
                    isOutOfStock,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuantitySelector(
    BuildContext context,
    ArticleData article,
    bool isService,
    bool isOutOfStock,
  ) {
    if (_fastSaleEnabled) {
      return Consumer<CartService>(
        builder: (context, cartService, child) {
          final qty = cartService.getItem(article.idArticle)?.quantity ?? 0;
          final controller = _getOrCreateController(article.idArticle, qty);

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: isOutOfStock
                        ? null
                        : () {
                            if (qty > 0) {
                              final newQty = qty - 1;
                              cartService.updateQuantity(
                                article.idArticle,
                                newQty,
                              );
                              controller.text = newQty.toString();
                            }
                          },
                    icon: Icon(
                      Icons.remove,
                      color: qty > 0 && !isOutOfStock
                          ? Colors.red.shade400
                          : Colors.grey.shade400,
                    ),
                    label: const SizedBox.shrink(),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(40, 40),
                    ),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: controller,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                    ),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.secondary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    onTap: () {
                      if (controller.text == '0') controller.clear();
                    },
                    onChanged: (value) {
                      if (value.isEmpty) {
                        cartService.updateQuantity(article.idArticle, 0);
                        controller.text = '0';
                        return;
                      }

                      final newQty = int.tryParse(value) ?? 0;

                      if (isService) {
                        final existingItem = cartService.getItem(
                          article.idArticle,
                        );
                        if (existingItem != null) {
                          cartService.updateQuantity(article.idArticle, newQty);
                        } else if (newQty > 0) {
                          cartService.addItem(article, quantity: newQty);
                        }
                        controller.text = newQty.toString();
                      } else if (newQty >= 0 &&
                          newQty <= article.quantiteStock) {
                        final existingItem = cartService.getItem(
                          article.idArticle,
                        );
                        if (existingItem != null) {
                          cartService.updateQuantity(article.idArticle, newQty);
                        } else if (newQty > 0) {
                          cartService.addItem(article, quantity: newQty);
                        }
                        controller.text = newQty.toString();
                      } else if (newQty > article.quantiteStock) {
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
                        controller.text = article.quantiteStock.toString();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Stock max: ${article.quantiteStock}',
                              style: GoogleFonts.poppins(),
                            ),
                            backgroundColor: Colors.orange,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: isOutOfStock
                        ? null
                        : () {
                            final newQty = qty + 1;
                            if (newQty <= article.quantiteStock || isService) {
                              final existingItem = cartService.getItem(
                                article.idArticle,
                              );
                              if (existingItem != null) {
                                cartService.updateQuantity(
                                  article.idArticle,
                                  newQty,
                                );
                              } else if (isService) {
                                cartService.addItem(article, quantity: newQty);
                              } else {
                                cartService.addItem(article, quantity: newQty);
                              }
                              controller.text = newQty.toString();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Stock épuisé',
                                    style: GoogleFonts.poppins(),
                                  ),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            }
                          },
                    icon: Icon(
                      Icons.add,
                      color: isOutOfStock
                          ? Colors.grey.shade400
                          : Colors.green.shade400,
                    ),
                    label: const SizedBox.shrink(),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(40, 40),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: isOutOfStock
              ? null
              : () {
                  final cartService = Provider.of<CartService>(
                    context,
                    listen: false,
                  );
                  cartService.addItem(article);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${article.libelle} ajouté au panier',
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
          icon: const Icon(Icons.add_shopping_cart, size: 20),
          label: Text(
            'Ajouter au panier',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.secondary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Chargement des articles...',
            style: GoogleFonts.poppins(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun article disponible',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Essayez de modifier vos filtres',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingCartBar(BuildContext context) {
    return Consumer<CartService>(
      builder: (context, cartService, child) {
        if (cartService.isEmpty) return const SizedBox.shrink();

        final Color accentColor = Colors.teal.shade700;

        return Positioned(
          left: 32, // Plus de marge sur les côtés pour l'effet flottant
          right: 32,
          bottom: 20,
          child: GestureDetector(
            onTap: () => _openFastSaleSheet(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white, // Fond blanc pour le minimalisme
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.teal.shade200, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 14,
                        color: accentColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${cartService.totalQuantity} ARTICLES',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: accentColor.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        locator.tauxService.formatPrice(cartService.total),
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.blueGrey.shade900,
                        ),
                      ),
                      // Une flèche plus subtile
                      Icon(
                        Icons.arrow_upward_rounded,
                        size: 16,
                        color: accentColor,
                      ),
                    ],
                  ),

                  const SizedBox(height: 2),

                  Text(
                    'Finaliser la commande',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.blueGrey.shade300,
                      fontWeight: FontWeight.w500,
                    ),
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
