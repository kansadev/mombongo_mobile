import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'database_service.dart';
import '../models/article.dart';
import '../models/client.dart';
import '../models/site.dart';
import '../models/stock.dart';
import '../models/vente.dart';
import '../models/paiement.dart';

class CacheStrategy {
  final ApiService _apiService;
  final DatabaseService _dbService;
  
  CacheStrategy(this._apiService, this._dbService);

  // Cache-first strategy for fetching data
  Future<List<T>> fetchWithCache<T>({
    required Future<List<dynamic>> Function() apiCall,
    required List<T> Function(List<dynamic>) fromJsonList,
    required Future<void> Function(List<T>) saveToLocal,
    required List<T> Function() getFromLocal,
    String? cacheKey,
    bool forceRefresh = false,
  }) async {
    try {
      // Check connectivity
      final isConnected = await _apiService.checkConnectivity();
      
      // If offline or force refresh not requested, try cache first
      if (!isConnected || !forceRefresh) {
        final cachedData = getFromLocal();
        if (cachedData.isNotEmpty) {
          if (kDebugMode) {
            print('Returning cached data for ${T.toString()}');
          }
          return cachedData;
        }
        
        // If no cache and offline, throw error
        if (!isConnected) {
          throw Exception('Pas de connexion internet et pas de données en cache');
        }
      }

      // Fetch from API
      if (kDebugMode) {
        print('Fetching fresh data from API for ${T.toString()}');
      }
      
      final apiData = await apiCall();
      final parsedData = fromJsonList(apiData);
      
      // Save to local storage
      await saveToLocal(parsedData);
      
      if (cacheKey != null) {
        await _dbService.save(cacheKey, DateTime.now());
      }
      
      return parsedData;
      
    } catch (e) {
      // Fallback to cache if API fails
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

  // Force refresh articles for a specific society
  Future<List<Article>> refreshArticlesBySociety(int societyId) async {
    return await getArticlesBySociete(societyId, forceRefresh: true);
  }

  // Articles cache strategy
  Future<List<Article>> getArticles({bool forceRefresh = false}) async {
    return await fetchWithCache<Article>(
      apiCall: _apiService.getArticles,
      fromJsonList: (data) => data.map((item) => Article.fromJson(item)).toList(),
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
      saveToLocal: (articles) => _dbService.saveArticlesBySociety(idSociete, articles),
      getFromLocal: () => _dbService.getArticlesBySociety(idSociete),
      cacheKey: 'articles_society_$idSociete',
      forceRefresh: forceRefresh,
    );
  }

  // Clients cache strategy
  Future<List<Client>> getClients({bool forceRefresh = false}) async {
    return await fetchWithCache<Client>(
      apiCall: _apiService.getClients,
      fromJsonList: (data) => data.map((item) => Client.fromJson(item)).toList(),
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
    // For search, we'll fetch all clients and filter locally
    final allClients = await getClients(forceRefresh: forceRefresh);
    
    return allClients.where((client) {
      bool matches = true;
      if (email != null) {
        matches &= client.email?.toLowerCase().contains(email.toLowerCase()) ?? false;
      }
      if (nom != null) {
        matches &= '${client.nom} ${client.prenom}'.toLowerCase().contains(nom.toLowerCase());
      }
      if (telephone != null) {
        matches &= client.telephone?.contains(telephone) ?? false;
      }
      return matches;
    }).toList();
  }

  // Stocks cache strategy
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

  Future<List<Stock>> getStocksBySite(int idSite, {bool forceRefresh = false}) async {
    return await fetchWithCache<Stock>(
      apiCall: () => _apiService.getStocksBySite(idSite),
      fromJsonList: (data) => data.map((item) => Stock.fromJson(item)).toList(),
      saveToLocal: _dbService.saveStocks,
      getFromLocal: _dbService.getStocks,
      forceRefresh: forceRefresh,
    );
  }

  // Ventes cache strategy
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

  // Paiements cache strategy
  Future<List<Paiement>> getPaiements({bool forceRefresh = false}) async {
    return await fetchWithCache<Paiement>(
      apiCall: _apiService.getPaiements,
      fromJsonList: (data) => data.map((item) => Paiement.fromJson(item)).toList(),
      saveToLocal: _dbService.savePaiements,
      getFromLocal: _dbService.getPaiements,
      cacheKey: 'paiements_last_sync',
      forceRefresh: forceRefresh,
    );
  }

  // Write operations with offline queue
  Future<T> createWithOfflineSupport<T>({
    required Future<Map<String, dynamic>> Function(Map<String, dynamic>) apiCall,
    required T Function(Map<String, dynamic>) fromJson,
    required Future<void> Function(T) saveToLocal,
    required Map<String, dynamic> data,
    String? offlineQueueKey,
  }) async {
    try {
      final isConnected = await _apiService.checkConnectivity();
      
      if (isConnected) {
        // Online - send to API
        final response = await apiCall(data);
        final item = fromJson(response);
        await saveToLocal(item);
        return item;
      } else {
        // Offline - save to offline queue
        if (offlineQueueKey != null) {
          final offlineQueue = _dbService.get<List>('offline_$offlineQueueKey') ?? [];
          offlineQueue.add({
            'data': data,
            'timestamp': DateTime.now().toIso8601String(),
            'operation': 'create',
          });
          await _dbService.save('offline_$offlineQueueKey', offlineQueue);
        }
        
        // Create local temporary item
        final tempItem = fromJson({...data, 'id': -DateTime.now().millisecondsSinceEpoch});
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

  // Sync offline operations when connection is restored
  Future<void> syncOfflineOperations() async {
    final isConnected = await _apiService.checkConnectivity();
    if (!isConnected) return;

    // Sync pending creations
    final offlineQueues = ['ventes', 'clients', 'paiements', 'stocks'];
    
    for (final queueKey in offlineQueues) {
      final queue = _dbService.get<List>('offline_$queueKey');
      if (queue != null && queue.isNotEmpty) {
        for (final operation in queue) {
          try {
            // TODO: Implement specific sync logic for each entity type
            if (kDebugMode) {
              print('Syncing offline operation for $queueKey: ${operation['data']}');
            }
            // Remove from queue after successful sync
          } catch (e) {
            if (kDebugMode) {
              print('Failed to sync offline operation: $e');
            }
          }
        }
        // Clear the queue
        await _dbService.save('offline_$queueKey', []);
      }
    }
  }

  // Check if data is stale (older than 1 hour)
  Future<bool> isDataStale(String cacheKey) async {
    final lastSync = _dbService.get<DateTime>(cacheKey);
    if (lastSync == null) return true;
    
    final oneHourAgo = DateTime.now().subtract(Duration(hours: 1));
    return lastSync.isBefore(oneHourAgo);
  }

  // Sites cache strategy
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

  Future<List<Site>> getSitesBySociete(int idSociete, {bool forceRefresh = false}) async {
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