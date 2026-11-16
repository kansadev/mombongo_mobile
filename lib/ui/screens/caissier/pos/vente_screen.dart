import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mombongo/models/article_data.dart';
import 'package:mombongo/services/cart_service.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/ui/screens/caissier/pos/encaissement_screen.dart';
import 'package:mombongo/ui/theme/pos_colors.dart';
import 'package:mombongo/ui/widgets/pos/pos_cart_actions.dart';
import 'package:mombongo/ui/widgets/pos/pos_cart_bar.dart';
import 'package:mombongo/ui/widgets/pos/pos_product_tile.dart';
import 'package:mombongo/utils/google_fonts_compat.dart';
import 'package:mombongo/utils/pos_money.dart';
import 'package:provider/provider.dart';

/// Filtre du catalogue.
enum _CatalogueFilter { all, products, services }

/// Onglet « Vente » du caissier : catalogue en grille, ajout en un toucher,
/// barre panier fixe menant à l'encaissement.
class VenteScreen extends StatefulWidget {
  const VenteScreen({super.key, this.onGoHome});

  /// Ramène le caissier à l'onglet Accueil (depuis « Vente validée »).
  final VoidCallback? onGoHome;

  @override
  State<VenteScreen> createState() => _VenteScreenState();
}

class _VenteScreenState extends State<VenteScreen> {
  static const String _articleFilterPrefKey = 'pref_article_filter_with_stock';
  static const int _pageSize = 20;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  _CatalogueFilter _filter = _CatalogueFilter.products;
  int _siteId = 0;

  /// Catalogue parcouru (sans recherche).
  List<ArticleData> _browse = [];
  int _browsePage = 1;
  bool _browseHasMore = true;
  int _browseRequestId = 0;

  /// Résultats de recherche (null = pas de recherche active).
  List<ArticleData>? _search;
  int _searchPage = 1;
  bool _searchHasMore = true;
  int _searchRequestId = 0;

  bool _loading = true;
  bool _loadingMore = false;

  String get _query => _searchController.text.trim();
  List<ArticleData> get _visible => _search ?? _browse;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final withStock =
          locator.databaseService.get<bool>(_articleFilterPrefKey) ?? true;
      _filter = withStock
          ? _CatalogueFilter.products
          : _CatalogueFilter.services;
    } catch (_) {}
    final user = locator.authRepository.currentUser;
    _siteId = int.tryParse(user?.idSite ?? '') ?? 0;
    await _loadBrowse();
  }

  bool? get _withStockParam => switch (_filter) {
    _CatalogueFilter.all => null,
    _CatalogueFilter.products => true,
    _CatalogueFilter.services => false,
  };

  Future<List<ArticleData>> _fetch({required int page, String? search}) {
    // En ligne : API + fusion du cache ; hors ligne : catalogue Hive.
    return locator.cacheStrategy.getStockArticlesBySiteCached(
      _siteId,
      page: page,
      pageSize: _pageSize,
      search: search,
      withStock: _withStockParam,
    );
  }

  Future<void> _loadBrowse() async {
    if (_siteId <= 0) {
      setState(() {
        _browse = [];
        _loading = false;
        _browseHasMore = false;
      });
      return;
    }
    final requestId = ++_browseRequestId;
    setState(() => _loading = true);
    try {
      final first = await _fetch(page: 1);
      if (!mounted || requestId != _browseRequestId) return;
      setState(() {
        _browse = first;
        _browsePage = 1;
        _browseHasMore = first.length == _pageSize;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Vente : chargement du catalogue impossible ($e)');
      if (!mounted || requestId != _browseRequestId) return;
      setState(() {
        _browse = [];
        _browseHasMore = false;
        _loading = false;
      });
    }
  }

  Future<void> _runSearch(String query) async {
    if (query.isEmpty) {
      _searchRequestId++;
      setState(() {
        _search = null;
        _loading = false;
      });
      return;
    }
    final requestId = ++_searchRequestId;
    setState(() => _loading = true);
    try {
      final results = await _fetch(page: 1, search: query);
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _search = results;
        _searchPage = 1;
        _searchHasMore = results.length == _pageSize;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Vente : recherche impossible ($e)');
      if (!mounted || requestId != _searchRequestId) return;
      final q = query.toLowerCase();
      setState(() {
        _search = _browse
            .where(
              (a) =>
                  a.libelle.toLowerCase().contains(q) ||
                  a.codeBarreQR.toLowerCase().contains(q),
            )
            .toList();
        _searchHasMore = false;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _siteId <= 0) return;
    final searching = _search != null;
    if (searching ? !_searchHasMore : !_browseHasMore) return;

    final query = _query;
    final requestId = searching ? _searchRequestId : _browseRequestId;
    final nextPage = (searching ? _searchPage : _browsePage) + 1;
    setState(() => _loadingMore = true);

    try {
      final fetched = await _fetch(
        page: nextPage,
        search: searching ? query : null,
      );
      if (!mounted) return;
      final stillValid = searching
          ? requestId == _searchRequestId && query == _query
          : requestId == _browseRequestId;
      if (!stillValid) {
        setState(() => _loadingMore = false);
        return;
      }
      final current = searching ? _search! : _browse;
      final ids = current.map((a) => a.idStock).toSet();
      final merged = [...current, ...fetched.where((a) => ids.add(a.idStock))];
      setState(() {
        if (searching) {
          _search = merged;
          _searchPage = nextPage;
          _searchHasMore = fetched.length == _pageSize;
        } else {
          _browse = merged;
          _browsePage = nextPage;
          _browseHasMore = fetched.length == _pageSize;
        }
        _loadingMore = false;
      });
    } catch (e) {
      debugPrint('Vente : page suivante impossible ($e)');
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        if (searching) {
          _searchHasMore = false;
        } else {
          _browseHasMore = false;
        }
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 400) {
      unawaited(_loadMore());
    }
  }

  void _onQueryChanged(String value) {
    setState(() {}); // bouton « effacer »
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 450),
      () => _runSearch(value.trim()),
    );
  }

  /// Validation du champ (touche Entrée ou douchette) : si le texte correspond
  /// exactement au code-barres d'un article, il est ajouté au panier.
  void _onQuerySubmitted(String value) {
    final code = value.trim().toLowerCase();
    if (code.isEmpty) return;

    final candidates = <ArticleData>[..._visible, ..._browse];
    try {
      candidates.addAll(
        locator.databaseService.getStockArticlesBySite(_siteId),
      );
    } catch (_) {}

    ArticleData? match;
    for (final article in candidates) {
      if (article.codeBarreQR.trim().toLowerCase() == code) {
        match = article;
        break;
      }
    }

    if (match == null) {
      _debounce?.cancel();
      _runSearch(value.trim());
      return;
    }

    final cart = context.read<CartService>();
    final added = PosCartActions.change(context, cart, match, 1);
    _debounce?.cancel();
    _searchController.clear();
    _searchRequestId++;
    setState(() => _search = null);
    _searchFocus.requestFocus();
    if (added) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${match.libelle} ajouté'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
    }
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    _searchRequestId++;
    setState(() => _search = null);
  }

  void _setFilter(_CatalogueFilter filter) {
    if (filter == _filter) return;
    setState(() => _filter = filter);
    _loadBrowse();
    if (_query.isNotEmpty) _runSearch(_query);
  }

  Future<void> _openCheckout() async {
    final sold = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EncaissementScreen(onGoHome: widget.onGoHome),
      ),
    );
    if (sold == true && mounted) {
      // Stocks mis à jour après la vente.
      _clearSearch();
      await _loadBrowse();
    }
  }

  Future<void> _refresh() async {
    if (_query.isNotEmpty) {
      await _runSearch(_query);
    } else {
      await _loadBrowse();
    }
  }

  void _showDetails(ArticleData article) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: PosColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ArticleDetailsSheet(article: article),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildCatalogue()),
              ],
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Consumer<CartService>(
                builder: (context, cart, _) {
                  if (cart.isEmpty) return const SizedBox.shrink();
                  return PosCartBar(
                    lineCount: cart.itemCount,
                    quantity: cart.totalQuantity,
                    totalLabel: PosMoney.format(cart.total),
                    onCheckout: _openCheckout,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final rateLabel = _rateLabel();
    return Container(
      color: PosColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Nouvelle vente',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: PosColors.ink,
                  ),
                ),
              ),
              if (rateLabel != null)
                Text(
                  rateLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: PosColors.muted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            onChanged: _onQueryChanged,
            onSubmitted: _onQuerySubmitted,
            textInputAction: TextInputAction.search,
            style: GoogleFonts.poppins(fontSize: 14, color: PosColors.ink),
            decoration: InputDecoration(
              hintText: 'Article, service ou code-barres',
              hintStyle: GoogleFonts.poppins(
                fontSize: 14,
                color: PosColors.muted,
              ),
              prefixIcon: const Icon(Icons.search, color: PosColors.muted),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Effacer',
                      icon: const Icon(Icons.close, color: PosColors.muted),
                      onPressed: _clearSearch,
                    ),
              filled: true,
              fillColor: PosColors.background,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: PosColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: PosColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: PosColors.green,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'Tout',
                  selected: _filter == _CatalogueFilter.all,
                  onTap: () => _setFilter(_CatalogueFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Produits',
                  selected: _filter == _CatalogueFilter.products,
                  onTap: () => _setFilter(_CatalogueFilter.products),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Services',
                  selected: _filter == _CatalogueFilter.services,
                  onTap: () => _setFilter(_CatalogueFilter.services),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _rateLabel() {
    if (PosMoney.isUsd) return null;
    final rate = PosMoney.rate;
    if (rate <= 1) return null;
    final formatted = NumberFormat(
      '#,##0',
      'en_US',
    ).format(rate).replaceAll(',', ' ');
    return 'Taux 1\$ = ${formatted}fc';
  }

  Widget _buildCatalogue() {
    if (_loading && _visible.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final items = _visible;
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            const Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: PosColors.muted,
            ),
            const SizedBox(height: 12),
            Text(
              _query.isEmpty
                  ? 'Aucun article à afficher'
                  : 'Aucun résultat pour « $_query »',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, color: PosColors.muted),
            ),
          ],
        ),
      );
    }

    final width = MediaQuery.of(context).size.width;
    final columns = width >= 900 ? 4 : (width >= 600 ? 3 : 2);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: Consumer<CartService>(
        builder: (context, cart, _) {
          return GridView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 104),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 150,
            ),
            itemCount: items.length + (_loadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= items.length) {
                return const Center(child: CircularProgressIndicator());
              }
              final article = items[index];
              return PosProductTile(
                article: article,
                quantity: PosCartActions.quantityOf(cart, article),
                onAdd: () => PosCartActions.change(context, cart, article, 1),
                onRemove: () =>
                    PosCartActions.change(context, cart, article, -1),
                onLongPress: () => _showDetails(article),
              );
            },
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? PosColors.ink : PosColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? PosColors.ink : PosColors.line,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              color: selected ? Colors.white : PosColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _ArticleDetailsSheet extends StatelessWidget {
  const _ArticleDetailsSheet({required this.article});

  final ArticleData article;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: PosColors.muted,
                ),
              ),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: PosColors.ink,
              ),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              article.libelle,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: PosColors.ink,
              ),
            ),
            const SizedBox(height: 12),
            row('Prix de vente', PosMoney.format(article.prixVentTTC)),
            row('Type', article.withStock ? 'Produit' : 'Service'),
            if (article.withStock) ...[
              row('Stock disponible', '${article.quantiteStock}'),
              row('Seuil d\'alerte', '${article.seuilAlerte}'),
            ],
            if (article.codeBarreQR.trim().isNotEmpty)
              row('Code-barres', article.codeBarreQR),
          ],
        ),
      ),
    );
  }
}
