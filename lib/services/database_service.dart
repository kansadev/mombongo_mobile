import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/utilisateur.dart';
import '../models/article.dart';
import '../models/client.dart';
import '../models/ligne_commande.dart';
import '../models/vente.dart';
import '../models/stock.dart';
import '../models/paiement.dart';
import '../models/site.dart';
import '../models/taux.dart';
import '../models/article_data.dart';

class DatabaseService {
  static const String _boxName = 'mombongo_db';
  static const String _authBoxName = 'auth_data';
  static const String offlineVentesQueueKey = 'offline_ventes';
  
  late Box<dynamic> _mainBox;
  late Box<dynamic> _authBox;

  Future<void> init() async {
    try {
      // Initialize Hive
      await Hive.initFlutter();
      
      // Register adapters
      _registerAdapters();
      
      // Open boxes
      _mainBox = await Hive.openBox(_boxName);
      try {
        _authBox = await Hive.openBox(_authBoxName);
      } catch (e) {
        if (kDebugMode) {
          print('Auth cache incompatible, resetting auth_data: $e');
        }
        await Hive.deleteBoxFromDisk(_authBoxName);
        _authBox = await Hive.openBox(_authBoxName);
      }
      
      if (kDebugMode) {
        print('Database initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing database: $e');
      }
      rethrow;
    }
  }

  void _registerAdapters() {
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(UtilisateurAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(ArticleAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(ClientAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(LigneCommandeAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(VenteAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(StockAdapter());
    if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(PaiementAdapter());
    if (!Hive.isAdapterRegistered(7)) Hive.registerAdapter(SiteAdapter());
    if (!Hive.isAdapterRegistered(8)) Hive.registerAdapter(TauxAdapter());
  }

  // Generic CRUD operations
  Future<void> save<T>(String key, T value) async {
    await _mainBox.put(key, value);
  }

  T? get<T>(String key) {
    final value = _mainBox.get(key);
    if (value is T) {
      return value;
    }
    return null;
  }

  Future<void> delete(String key) async {
    await _mainBox.delete(key);
  }

  List<T> getAll<T>() {
    return _mainBox.values.whereType<T>().toList();
  }

  Future<void> clearAll() async {
    await _mainBox.clear();
  }
  
  Future<void> clearOldArticleCache() async {
    // Clear old cache that might be causing conflicts
    await _mainBox.delete('articles');
    print('Cleared old article cache');
  }

  // Authentication data
  Future<void> saveAuthToken(String token) async {
    await _authBox.put('auth_token', token);
  }

  String? getAuthToken() {
    final token = _authBox.get('auth_token');
    if (token is String) {
      return token;
    }
    return null;
  }

  Future<void> saveRefreshToken(String refreshToken) async {
    await _authBox.put('refresh_token', refreshToken);
  }

  String? getRefreshToken() {
    final refreshToken = _authBox.get('refresh_token');
    if (refreshToken is String) {
      return refreshToken;
    }
    return null;
  }

  Future<void> saveCurrentUser(Utilisateur user) async {
    await _authBox.put('current_user', user);
  }

  Utilisateur? getCurrentUser() {
    try {
      final user = _authBox.get('current_user');
      if (user is Utilisateur) {
        return user;
      }
      if (user != null) {
        _authBox.delete('current_user');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Invalid cached current_user detected, clearing it: $e');
      }
      _authBox.delete('current_user');
      return null;
    }
  }

  Future<void> clearAuthData() async {
    await _authBox.delete('auth_token');
    await _authBox.delete('refresh_token');
    await _authBox.delete('current_user');
  }

  // Specific data operations
  Future<void> saveArticles(List<Article> articles) async {
    await _mainBox.put('articles', articles);
  }

  List<Article> getArticles() {
    return (_mainBox.get('articles') as List?)?.cast<Article>() ?? [];
  }

  // Society-specific article operations
  Future<void> saveArticlesBySociety(int societyId, List<Article> articles) async {
    await _mainBox.put('articles_society_$societyId', articles);
  }

  List<Article> getArticlesBySociety(int societyId) {
    try {
      final data = _mainBox.get('articles_society_$societyId');
      
      // Debug logging
      print('Cache data type for society $societyId: ${data?.runtimeType}');
      
      // Handle case where cached data might be DateTime or other types
      if (data is List) {
        return data.cast<Article>();
      } else if (data is DateTime) {
        print('Warning: Found DateTime in article cache for society $societyId, clearing cache');
        _mainBox.delete('articles_society_$societyId');
        return [];
      } else {
        print('Warning: Unexpected cache data type ${data?.runtimeType} for society $societyId, clearing cache');
        _mainBox.delete('articles_society_$societyId');
        return [];
      }
    } catch (e) {
      print('Error retrieving articles from cache for society $societyId: $e');
      // Clear problematic cache entry
      _mainBox.delete('articles_society_$societyId');
      return [];
    }
  }

  Future<void> saveClients(List<Client> clients) async {
    await _mainBox.put('clients', clients);
  }

  List<Client> getClients() {
    return (_mainBox.get('clients') as List?)?.cast<Client>() ?? [];
  }

  Future<void> saveStocks(List<Stock> stocks) async {
    await _mainBox.put('stocks', stocks);
  }

  List<Stock> getStocks() {
    return (_mainBox.get('stocks') as List?)?.cast<Stock>() ?? [];
  }

  Future<void> saveVentes(List<Vente> ventes) async {
    await _mainBox.put('ventes', ventes);
  }

  List<Vente> getVentes() {
    return (_mainBox.get('ventes') as List?)?.cast<Vente>() ?? [];
  }

  Future<void> savePaiements(List<Paiement> paiements) async {
    await _mainBox.put('paiements', paiements);
  }

  List<Paiement> getPaiements() {
    return (_mainBox.get('paiements') as List?)?.cast<Paiement>() ?? [];
  }

  Future<void> saveSites(List<Site> sites) async {
    await _mainBox.put('sites', sites);
  }

  List<Site> getSites() {
    return (_mainBox.get('sites') as List?)?.cast<Site>() ?? [];
  }

  // --- Cache catalogue stock par site (ArticleData) ---

  String _stockArticlesKey(int idSite) => 'stock_articles_site_$idSite';

  Future<void> saveStockArticlesBySite(
    int idSite,
    List<ArticleData> articles,
  ) async {
    await _mainBox.put(_stockArticlesKey(idSite), articles);
    await _mainBox.put(
      '${_stockArticlesKey(idSite)}_last_sync',
      DateTime.now().toIso8601String(),
    );
  }

  List<ArticleData> getStockArticlesBySite(int idSite) {
    try {
      final data = _mainBox.get(_stockArticlesKey(idSite));
      if (data is List) {
        return data.whereType<ArticleData>().toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Erreur lecture cache stock site $idSite: $e');
      }
      return [];
    }
  }

  /// Fusionne les articles reçus (pagination) dans le cache du site.
  Future<void> mergeStockArticlesBySite(
    int idSite,
    List<ArticleData> incoming,
  ) async {
    final existing = getStockArticlesBySite(idSite);
    final byStockId = <int, ArticleData>{
      for (final a in existing) a.idStock: a,
    };
    for (final a in incoming) {
      byStockId[a.idStock] = a;
    }
    await saveStockArticlesBySite(idSite, byStockId.values.toList());
  }

  Future<void> decrementStockLocally({
    required int idSite,
    required int idStock,
    required int quantity,
  }) async {
    final articles = getStockArticlesBySite(idSite);
    if (articles.isEmpty) return;

    final updated = articles.map((a) {
      if (a.idStock != idStock) return a;
      final newQty = (a.quantiteStock - quantity).clamp(0, a.quantiteStock).toInt();
      return a.copyWith(quantiteStock: newQty);
    }).toList();

    await saveStockArticlesBySite(idSite, updated);
  }

  // --- File d'attente ventes offline ---

  List<Map<String, dynamic>> getOfflineVentesQueue() {
    try {
      final raw = _mainBox.get(offlineVentesQueueKey);
      if (raw is! List) return [];
      return raw.map((item) {
        if (item is Map<String, dynamic>) return item;
        if (item is Map) {
          return Map<String, dynamic>.from(item);
        }
        return <String, dynamic>{};
      }).where((m) => m.isNotEmpty).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Erreur lecture queue offline_ventes: $e');
      }
      return [];
    }
  }

  Future<void> saveOfflineVentesQueue(List<Map<String, dynamic>> queue) async {
    await _mainBox.put(offlineVentesQueueKey, queue);
  }

  Future<void> enqueueOfflineVente(Map<String, dynamic> entry) async {
    final queue = getOfflineVentesQueue();
    queue.add(entry);
    await saveOfflineVentesQueue(queue);
  }

  int get pendingOfflineVentesCount => getOfflineVentesQueue().length;

  Future<void> close() async {
    await _mainBox.close();
    await _authBox.close();
  }
}
