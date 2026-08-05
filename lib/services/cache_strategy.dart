import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'database_service.dart';
import '../models/article.dart';
import '../models/article_data.dart';
import '../models/client.dart';
import '../models/site.dart';
import '../models/stock.dart';
import '../models/vente.dart';
import '../models/paiement.dart';

class CacheStrategy {
  final ApiService _apiService;
  final DatabaseService _dbService;

  CacheStrategy(this._apiService, this._dbService);

  Future<List<T>> fetchWithCache<T>({
    required Future<List<dynamic>> Function() apiCall,
    required List<T> Function(List<dynamic>) fromJsonList,
    required Future<void> Function(List<T>) saveToLocal,
    required List<T> Function() getFromLocal,
    String? cacheKey,
    bool forceRefresh = false,
  }) async {
    try {
      final isConnected = await _apiService.checkConnectivity();

      if (!isConnected || !forceRefresh) {
        final cachedData = getFromLocal();
        if (cachedData.isNotEmpty) {
          if (kDebugMode) {
            print('Returning cached data for ${T.toString()}');
          }
          return cachedData;
        }

        if (!isConnected) {
          throw Exception(
            'Pas de connexion internet et pas de données en cache',
          );
        }
      }

      if (kDebugMode) {
        print('Fetching fresh data from API for ${T.toString()}');
      }

      final apiData = await apiCall();
      final parsedData = fromJsonList(apiData);

      await saveToLocal(parsedData);

      if (cacheKey != null) {
        await _dbService.save(cacheKey, DateTime.now());
      }

      return parsedData;
    } catch (e) {
      final cachedData = getFromLocal();
      if (cachedData.isNotEmpty) {
        if (kDebugMode) {
          print('API failed, returning cached data for ${T.toString()}: $e');
        }
        return cachedData;
      }

      if (kDebugMode) {
        print('Both API and cache failed for ${T.toString()}: $e');
      }
      rethrow;
    }
  }

  Future<List<Article>> refreshArticlesBySociety(int societyId) async {
    return await getArticlesBySociete(societyId, forceRefresh: true);
  }

  Future<List<Article>> getArticles({bool forceRefresh = false}) async {
    return await fetchWithCache<Article>(
      apiCall: _apiService.getArticles,
      fromJsonList: (data) =>
          data.map((item) => Article.fromJson(item)).toList(),
      saveToLocal: _dbService.saveArticles,
      getFromLocal: _dbService.getArticles,
      cacheKey: 'articles_last_sync',
      forceRefresh: forceRefresh,
    );
  }

  Future<List<Article>> getArticlesBySociete(
    int idSociete, {
    int page = 1,
    int pageSize = 20,
    String? sortField,
    String? sortOrder = 'asc',
    String? search,
    bool? withStock,
    bool forceRefresh = false,
  }) async {
    return await fetchWithCache<Article>(
      apiCall: () => _apiService.getArticlesBySociete(
        idSociete,
        page: page,
        pageSize: pageSize,
        sortField: sortField,
        sortOrder: sortOrder,
        search: search,
        withStock: withStock,
      ),
      fromJsonList: (data) {
        try {
          return data.map((item) => Article.fromJson(item)).toList();
        } catch (e) {
          print('Error parsing articles for society $idSociete: $e');
          print('Data sample: ${data.take(2)}');
          rethrow;
        }
      },
      saveToLocal: (articles) =>
          _dbService.saveArticlesBySociety(idSociete, articles),
      getFromLocal: () => _dbService.getArticlesBySociety(idSociete),
      cacheKey: 'articles_society_$idSociete',
      forceRefresh: forceRefresh,
    );
  }

  /// Catalogue stock du site : API si online, Hive si offline.
  Future<List<ArticleData>> getStockArticlesBySiteCached(
    int idSite, {
    int page = 1,
    int pageSize = 20,
    String? search,
    bool? withStock,
    bool forceRefresh = false,
    bool mergeIntoCache = true,
  }) async {
    final isConnected = await _apiService.checkConnectivity();

    if (!isConnected) {
      final cached = _filterCachedStockArticles(
        idSite: idSite,
        search: search,
        withStock: withStock,
      );
      if (cached.isEmpty) {
        throw Exception(
          'Pas de connexion et aucun catalogue en cache pour ce site',
        );
      }
      return _paginate(cached, page, pageSize);
    }

    try {
      final apiResponse = await _apiService.getStockArticles(
        idSite: idSite,
        page: page,
        pageSize: pageSize,
        sortOrder: 'asc',
        search: search,
        withStock: withStock,
      );

      final fetched = <ArticleData>[];
      for (final item in apiResponse) {
        try {
          if (item is Map<String, dynamic>) {
            fetched.add(ArticleData.fromJson(item));
          } else if (item is Map) {
            fetched.add(ArticleData.fromJson(item.cast<String, dynamic>()));
          }
        } catch (e) {
          if (kDebugMode) print('Erreur parsing ArticleData: $e');
        }
      }

      if (mergeIntoCache && fetched.isNotEmpty) {
        await _dbService.mergeStockArticlesBySite(idSite, fetched);
      }

      return fetched;
    } catch (e) {
      final cached = _filterCachedStockArticles(
        idSite: idSite,
        search: search,
        withStock: withStock,
      );
      if (cached.isNotEmpty) {
        if (kDebugMode) {
          print('API stock échouée, fallback cache: $e');
        }
        return _paginate(cached, page, pageSize);
      }
      rethrow;
    }
  }

  /// Précharge le catalogue du site pour usage offline.
  Future<int> preloadStockArticlesForSite(
    int idSite, {
    int pageSize = 200,
  }) async {
    final isConnected = await _apiService.checkConnectivity();
    if (!isConnected) {
      return _dbService.getStockArticlesBySite(idSite).length;
    }

    final all = <ArticleData>[];
    var page = 1;
    const maxPages = 25;

    while (page <= maxPages) {
      final batch = await _apiService.getStockArticles(
        idSite: idSite,
        page: page,
        pageSize: pageSize,
        sortOrder: 'asc',
        withStock: true,
      );

      if (batch.isEmpty) break;

      for (final item in batch) {
        try {
          if (item is Map<String, dynamic>) {
            all.add(ArticleData.fromJson(item));
          } else if (item is Map) {
            all.add(ArticleData.fromJson(item.cast<String, dynamic>()));
          }
        } catch (_) {}
      }

      if (batch.length < pageSize) break;
      page++;
    }

    if (all.isNotEmpty) {
      await _dbService.saveStockArticlesBySite(idSite, all);
    }

    if (kDebugMode) {
      print('Préchargement catalogue site $idSite: ${all.length} articles');
    }
    return all.length;
  }

  List<ArticleData> _filterCachedStockArticles({
    required int idSite,
    String? search,
    bool? withStock,
  }) {
    var list = _dbService.getStockArticlesBySite(idSite);
    if (withStock == true) {
      list = list.where((a) => a.quantiteStock > 0).toList();
    }
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      list = list
          .where(
            (a) =>
                a.libelle.toLowerCase().contains(q) ||
                a.codeBarreQR.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  List<ArticleData> _paginate(
    List<ArticleData> source,
    int page,
    int pageSize,
  ) {
    final start = (page - 1) * pageSize;
    if (start >= source.length) return [];
    final end = (start + pageSize).clamp(0, source.length);
    return source.sublist(start, end);
  }

  Future<List<Client>> getClients({bool forceRefresh = false}) async {
    return await fetchWithCache<Client>(
      apiCall: _apiService.getClients,
      fromJsonList: (data) =>
          data.map((item) => Client.fromJson(item)).toList(),
      saveToLocal: _dbService.saveClients,
      getFromLocal: _dbService.getClients,
      cacheKey: 'clients_last_sync',
      forceRefresh: forceRefresh,
    );
  }

  Future<List<Client>> searchClients({
    String? email,
    String? nom,
    String? telephone,
    bool forceRefresh = false,
  }) async {
    final allClients = await getClients(forceRefresh: forceRefresh);

    return allClients.where((client) {
      bool matches = true;
      if (email != null) {
        matches &=
            client.email?.toLowerCase().contains(email.toLowerCase()) ?? false;
      }
      if (nom != null) {
        matches &= '${client.nom} ${client.prenom}'.toLowerCase().contains(
              nom.toLowerCase(),
            );
      }
      if (telephone != null) {
        matches &= client.telephone?.contains(telephone) ?? false;
      }
      return matches;
    }).toList();
  }

  Future<List<Stock>> getStocks({bool forceRefresh = false}) async {
    return await fetchWithCache<Stock>(
      apiCall: _apiService.getStocks,
      fromJsonList: (data) => data.map((item) => Stock.fromJson(item)).toList(),
      saveToLocal: _dbService.saveStocks,
      getFromLocal: _dbService.getStocks,
      cacheKey: 'stocks_last_sync',
      forceRefresh: forceRefresh,
    );
  }

  Future<List<Stock>> getStocksBySite(
    int idSite, {
    bool forceRefresh = false,
  }) async {
    return await fetchWithCache<Stock>(
      apiCall: () => _apiService.getStocksBySite(idSite),
      fromJsonList: (data) => data.map((item) => Stock.fromJson(item)).toList(),
      saveToLocal: _dbService.saveStocks,
      getFromLocal: _dbService.getStocks,
      forceRefresh: forceRefresh,
    );
  }

  Future<List<Vente>> getVentes({bool forceRefresh = false}) async {
    return await fetchWithCache<Vente>(
      apiCall: _apiService.getVentes,
      fromJsonList: (data) => data.map((item) => Vente.fromJson(item)).toList(),
      saveToLocal: _dbService.saveVentes,
      getFromLocal: _dbService.getVentes,
      cacheKey: 'ventes_last_sync',
      forceRefresh: forceRefresh,
    );
  }

  Future<List<Paiement>> getPaiements({bool forceRefresh = false}) async {
    return await fetchWithCache<Paiement>(
      apiCall: _apiService.getPaiements,
      fromJsonList: (data) =>
          data.map((item) => Paiement.fromJson(item)).toList(),
      saveToLocal: _dbService.savePaiements,
      getFromLocal: _dbService.getPaiements,
      cacheKey: 'paiements_last_sync',
      forceRefresh: forceRefresh,
    );
  }

  Future<T> createWithOfflineSupport<T>({
    required Future<Map<String, dynamic>> Function(Map<String, dynamic>)
        apiCall,
    required T Function(Map<String, dynamic>) fromJson,
    required Future<void> Function(T) saveToLocal,
    required Map<String, dynamic> data,
    String? offlineQueueKey,
  }) async {
    try {
      final isConnected = await _apiService.checkConnectivity();

      if (isConnected) {
        final response = await apiCall(data);
        final item = fromJson(response);
        await saveToLocal(item);
        return item;
      } else {
        if (offlineQueueKey != null) {
          final offlineQueue =
              _dbService.get<List>('offline_$offlineQueueKey') ?? [];
          offlineQueue.add({
            'data': data,
            'timestamp': DateTime.now().toIso8601String(),
            'operation': 'create',
          });
          await _dbService.save('offline_$offlineQueueKey', offlineQueue);
        }

        final tempItem = fromJson({
          ...data,
          'id': -DateTime.now().millisecondsSinceEpoch,
        });
        await saveToLocal(tempItem);
        return tempItem;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in createWithOfflineSupport: $e');
      }
      rethrow;
    }
  }

  /// Sync générique : conserve les items en échec (ne clear plus aveuglément).
  Future<void> syncOfflineOperations() async {
    final isConnected = await _apiService.checkConnectivity();
    if (!isConnected) return;

    final offlineQueues = ['clients', 'paiements', 'stocks'];

    for (final queueKey in offlineQueues) {
      final queue = List.from(_dbService.get<List>('offline_$queueKey') ?? []);
      if (queue.isEmpty) continue;

      // Sans logique métier spécifique : on conserve la file intacte
      // (les ventes sont gérées par VenteRepository.syncOfflineVentes).
      await _dbService.save('offline_$queueKey', queue);
    }
  }

  Future<bool> isDataStale(String cacheKey) async {
    final lastSync = _dbService.get<DateTime>(cacheKey);
    if (lastSync == null) return true;

    final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
    return lastSync.isBefore(oneHourAgo);
  }

  Future<List<Site>> getSites({bool forceRefresh = false}) async {
    return await fetchWithCache<Site>(
      apiCall: _apiService.getSites,
      fromJsonList: (data) => data.map((item) => Site.fromJson(item)).toList(),
      saveToLocal: _dbService.saveSites,
      getFromLocal: _dbService.getSites,
      cacheKey: 'sites_last_sync',
      forceRefresh: forceRefresh,
    );
  }

  Future<List<Site>> getSitesBySociete(
    int idSociete, {
    bool forceRefresh = false,
  }) async {
    final sites = await fetchWithCache<Site>(
      apiCall: () => _apiService.getSitesBySociete(idSociete),
      fromJsonList: (data) => data.map((item) => Site.fromJson(item)).toList(),
      saveToLocal: _dbService.saveSites,
      getFromLocal: _dbService.getSites,
      forceRefresh: forceRefresh,
    );
    return sites.cast<Site>();
  }
}
