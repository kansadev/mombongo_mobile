import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'api_service.dart';
import 'database_service.dart';
import 'cache_strategy.dart';
import 'auth_repository.dart';
import 'package:mombongo/models/article_data.dart';
import 'cart_service.dart';
import 'taux_service.dart';

class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  late ApiService _apiService;
  late DatabaseService _databaseService;
  late CacheStrategy _cacheStrategy;
  late AuthRepository _authRepository;
  late TauxService _tauxService;

  bool _isInitialized = false;

  ApiService get apiService => _apiService;
  DatabaseService get databaseService => _databaseService;
  CacheStrategy get cacheStrategy => _cacheStrategy;
  AuthRepository get authRepository => _authRepository;
  TauxService get tauxService => _tauxService;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Register Hive adapters
      if (!Hive.isAdapterRegistered(21)) {
        Hive.registerAdapter(ArticleDataAdapter());
      }
      if (!Hive.isAdapterRegistered(20)) {
        Hive.registerAdapter(CartItemAdapter());
      }
      
      // Initialize database first
      _databaseService = DatabaseService();
      await _databaseService.init();
      
      // Clear old cache that might cause conflicts
      await _databaseService.clearOldArticleCache();
      
      // Initialize API service
      _apiService = ApiService();
      
      // Initialize cache strategy
      _cacheStrategy = CacheStrategy(_apiService, _databaseService);
      
      // Initialize auth repository
      _authRepository = AuthRepository(_apiService, _databaseService);
      
      // Initialize taux service
      _tauxService = TauxService(_databaseService);
      
      _isInitialized = true;
      
      if (kDebugMode) {
        print('All services initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing services: $e');
      }
      rethrow;
    }
  }

  Future<void> dispose() async {
    if (_isInitialized) {
      await _databaseService.close();
      _isInitialized = false;
      
      if (kDebugMode) {
        print('Services disposed');
      }
    }
  }
}

// Global instance
final locator = ServiceLocator();
