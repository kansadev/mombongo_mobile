import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mombongo/services/api_exception.dart';
import 'package:mombongo/utils/api_error_message.dart';

export 'api_exception.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mombongo/models/article_update_request.dart';
import '../models/site.dart';
import '../models/devise_model.dart';

class ApiService {
  // URLs des environnements
  static const String _baseUrlTest = 'https://test-mombongo.asdc-rdc.org';
  static const String _baseUrlDev = 'https://dev-mombongo.asdc-rdc.org';
  static const String _baseUrlProd = 'https://prod-mombongo.asdc-rdc.org';

  // Environment selection: 0 = Test, 1 = Dev, 2 = Prod
  static const int environment =
      2; // Modifier cette valeur pour changer d'environnement

  // Getter pour obtenir l'URL de base selon l'environnement
  String get baseUrl {
    switch (environment) {
      case 0:
        return _baseUrlTest;
      case 1:
        return _baseUrlDev;
      case 2:
        return _baseUrlProd;
      default:
        return _baseUrlTest;
    }
  }

  String? _authToken;
  String? _refreshToken;

  String? get authToken => _authToken;
  String? get refreshToken => _refreshToken;

  Future<bool> checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  void setTokens(String token, String refreshToken) {
    _authToken = token;
    _refreshToken = refreshToken;
  }

  void clearTokens() {
    _authToken = null;
    _refreshToken = null;
  }

  Map<String, String> _getHeaders({bool authenticated = true}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Accept-Encoding': 'gzip, deflate',
    };

    if (authenticated && _authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    if (kDebugMode) {
      print('API Headers: $headers');
      print('Base URL: $baseUrl');
    }

    return headers;
  }

  Future<dynamic> _handleRequest(
    Future<http.Response> Function() request,
  ) async {
    try {
      final response = await request();

      if (kDebugMode) {
        print('API Response Status: ${response.statusCode}');
        print('API Response Body: ${response.body}');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) {
          return {'success': true};
        }
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        throw ApiException('Non autorisé', response.statusCode);
      } else if (response.statusCode == 404) {
        throw ApiException('Ressource non trouvée', response.statusCode);
      } else if (response.statusCode == 429) {
        throw ApiException('Trop de requêtes', response.statusCode);
      } else {
        dynamic parsedErrorBody;
        if (response.body.isEmpty) {
          parsedErrorBody = {'message': 'Erreur serveur'};
        } else {
          try {
            parsedErrorBody = json.decode(response.body);
          } catch (_) {
            parsedErrorBody = response.body;
          }
        }

        String errorMessage = 'Erreur inconnue';
        Map<String, dynamic>? errorDetails;

        if (parsedErrorBody is Map) {
          final mapBody = Map<String, dynamic>.from(parsedErrorBody);
          errorDetails = mapBody;
          final rawMessage =
              mapBody['title'] ?? mapBody['message'] ?? mapBody['error'];
          if (rawMessage != null && rawMessage.toString().trim().isNotEmpty) {
            errorMessage = rawMessage.toString();
          }
          final errors = mapBody['errors'];
          if (errors is List && errors.isNotEmpty) {
            final technicalDetail = errors
                .map((e) => e.toString())
                .where((e) => e.trim().isNotEmpty)
                .join(' | ');
            if (technicalDetail.isNotEmpty) {
              errorDetails = {
                ...mapBody,
                'technicalErrors': technicalDetail,
              };
            }
          }
        } else if (parsedErrorBody is String) {
          errorMessage = parsedErrorBody.trim().isEmpty
              ? 'Erreur serveur'
              : parsedErrorBody;
          errorDetails = {'message': parsedErrorBody};
        } else if (parsedErrorBody is List && parsedErrorBody.isNotEmpty) {
          errorMessage = parsedErrorBody.first.toString();
          errorDetails = {'errors': parsedErrorBody};
        } else {
          errorMessage = 'Erreur serveur';
          errorDetails = {'raw': parsedErrorBody?.toString() ?? ''};
        }

        throw ApiException(
          errorMessage,
          response.statusCode,
          details: errorDetails,
        );
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      // Always log API errors regardless of debug mode
      debugPrint('=== API REQUEST ERROR ===');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error message: $e');
      debugPrint('URI: ${(e is http.ClientException) ? e.uri : "Unknown"}');
      debugPrint('========================');

      // More specific error messages based on error type
      String errorMessage = 'Erreur de connexion';
      if (e.toString().contains('Failed host lookup') ||
          e.toString().contains('No address associated with hostname')) {
        errorMessage =
            'Serveur introuvable. Verifiez l\'URL ou votre connexion internet.';
      } else if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        errorMessage =
            'Connexion au serveur refusee. Le serveur est peut-etre hors ligne.';
      } else if (e.toString().contains('Timeout')) {
        errorMessage = 'Delai de connexion depasse. Reessayez plus tard.';
      }

      throw ApiException(errorMessage, 0);
    }
  }

  Future<T> _executeWithRetry<T>(
    Future<T> Function() action, {
    int maxAttempts = 3,
    Duration initialDelay = const Duration(milliseconds: 600),
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await action();
      } catch (e) {
        lastError = e;
        final canRetry = isRetryableApiError(e) && attempt < maxAttempts;
        if (kDebugMode) {
          debugPrint(
            'Tentative API $attempt/$maxAttempts échouée'
            '${canRetry ? ' — nouvel essai...' : ''}: $e',
          );
        }
        if (!canRetry) rethrow;
        await Future<void>.delayed(initialDelay * attempt);
      }
    }
    throw lastError ?? ApiException('Erreur inconnue', 0);
  }

  // Authentication endpoints
  Future<Map<String, dynamic>> authenticate({
    required String login,
    required String motDePasse,
  }) async {
    final url = Uri.parse('$baseUrl/api/Utilisateurs/authentifier');

    final body = json.encode({'login': login, 'motDePasse': motDePasse});

    return await _handleRequest(
      () => http.post(
        url,
        headers: _getHeaders(authenticated: false),
        body: body,
      ),
    );
  }

  Future<Map<String, dynamic>> changePasswordByUserId({
    required String idUtilisateur,
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    final url = Uri.parse(
      '$baseUrl/api/Utilisateurs/$idUtilisateur/change-password',
    );

    final body = json.encode({
      'currentPassword': currentPassword,
      'newPassword': newPassword,
      'confirmNewPassword': confirmNewPassword,
    });

    return await _handleRequest(
      () => http.put(url, headers: _getHeaders(), body: body),
    );
  }

  // Vente endpoints
  Future<Map<String, dynamic>> enregistrerVente(
    Map<String, dynamic> venteData,
  ) async {
    final url = Uri.parse('$baseUrl/api/Vente/enregistrer');
    final body = json.encode(venteData);

    return await _handleRequest(
      () => http.post(url, headers: _getHeaders(), body: body),
    );
  }

  Future<List<dynamic>> getVentes() async {
    final url = Uri.parse('$baseUrl/api/Vente');
    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );
    return response is List ? response : [];
  }

  // Article endpoints
  Future<List<dynamic>> getArticles() async {
    final url = Uri.parse('$baseUrl/api/Articles');
    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );
    return response is List ? response : [];
  }

  Future<List<dynamic>> getArticlesBySociete(
    int idSociete, {
    int page = 1,
    int pageSize = 20,
    String? sortField,
    String? sortOrder,
    String? search,
    bool? withStock,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'pageSize': pageSize.toString(),
      if (sortField != null) 'sortField': sortField,
      if (sortOrder != null) 'sortOrder': sortOrder,
      if (search != null) 'search': search,
      if (withStock != null) 'withStock': withStock.toString(),
    };

    final url = Uri.parse(
      '$baseUrl/api/Articles/societe/$idSociete',
    ).replace(queryParameters: queryParams);
    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );

    // L'API retourne un objet avec la structure {articles: [...], filtres: {...}, pagination: {...}}
    if (response is Map<String, dynamic> && response.containsKey('articles')) {
      final articles = response['articles'];
      return articles is List ? articles : [];
    }

    return response is List ? response : [];
  }

  // MÃ©thode spÃ©cifique pour rÃ©cupÃ©rer les articles avec withStock dans le chemin
  Future<List<dynamic>> getArticlesBySocieteWithStock(
    int idSociete,
    bool withStock,
  ) async {
    final url = Uri.parse(
      '$baseUrl/api/Articles/societe/$idSociete/with-stock/$withStock',
    );
    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );
    return response is List ? response : [];
  }

  Future<Map<String, dynamic>> getArticle(int id) async {
    final url = Uri.parse('$baseUrl/api/Articles/$id');
    return await _handleRequest(() => http.get(url, headers: _getHeaders()));
  }

  Future<Map<String, dynamic>> createArticle(
    Map<String, dynamic> articleData,
  ) async {
    final url = Uri.parse('$baseUrl/api/Articles');
    final body = json.encode(articleData);

    return await _handleRequest(
      () => http.post(url, headers: _getHeaders(), body: body),
    );
  }

  Future<Map<String, dynamic>> createArticleWithStock(
    Map<String, dynamic> articleData,
  ) async {
    final url = Uri.parse('$baseUrl/api/Articles/CreerArticleAvecStock');
    final body = json.encode(articleData);

    return await _handleRequest(
      () => http.post(url, headers: _getHeaders(), body: body),
    );
  }

  Future<Map<String, dynamic>> updateArticle(
    int id,
    Map<String, dynamic> articleData,
  ) async {
    final url = Uri.parse('$baseUrl/api/Articles/$id');
    final body = json.encode(articleData);

    return await _handleRequest(
      () => http.put(url, headers: _getHeaders(), body: body),
    );
  }

  Future<Map<String, dynamic>> deleteArticle(int id) async {
    final url = Uri.parse('$baseUrl/api/Articles/$id');

    return await _handleRequest(() => http.delete(url, headers: _getHeaders()));
  }

  // Mettre à jour un article par stock-site-article
  // This endpoint uses a strongly typed request object to ensure the
  // JSON payload matches the structure expected by the backend.  The
  // `ArticleUpdateRequest` class mirrors the following interface:
  //
  // {
  //   "idStock": 0,
  //   "idSite": 0,
  //   "idArticle": 0,
  //   "libelle": "string",
  //   "tva": 0,
  //   "perissable": true,
  //   "remise": 0,
  //   "withStock": true,
  //   "quantiteInitial": 0,
  //   "prixAchat": 0,
  //   "prixVenteHT": 0,
  //   "seuilAlerte": 0
  // }
  Future<Map<String, dynamic>> updateArticleByStockSiteArticle(
    ArticleUpdateRequest request, {
    int? idDevise,
  }) async {
    // Endpoint pour mise à jour de l'article
    final url = Uri.parse('$baseUrl/api/Articles/update-by-stock-site-article');

    // Envoyer les données directement sans wrapper "request"
    final body = json.encode({
      ...request.toJson(),
      if (idDevise != null) 'idDevise': idDevise,
    });

    debugPrint('updateArticleByStockSiteArticle body: $body');

    return await _handleRequest(
      () => http.put(url, headers: _getHeaders(), body: body),
    );
  }

  // Stock endpoints
  Future<List<dynamic>> getStocks() async {
    final url = Uri.parse('$baseUrl/api/Stocks');
    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );
    return response is List ? response : [];
  }

  Future<List<dynamic>> getStocksBySite(int idSite) async {
    final url = Uri.parse('$baseUrl/api/V_StockArticleSite/par-site/$idSite');
    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );
    return response is List ? response : [];
  }

  // Nouvelle méthode générique pour récupérer les stocks avec tous les filtres
  Future<List<dynamic>> getStockArticles({
    int? idSite,
    int? idArticle,
    String? nomSite,
    String? libelle,
    int? idSociete,
    String? search,
    bool? withStock,
    int page = 1,
    int pageSize = 20,
    String? sortField,
    String sortOrder = 'asc',
  }) async {
    // Construire l'URL de base
    String baseEndpoint = '$baseUrl/api/V_StockArticleSite';

    // Si idSite est fourni, utiliser le format /site/{idSite}
    if (idSite != null && idSite > 0) {
      baseEndpoint = '$baseUrl/api/V_StockArticleSite/site/$idSite';
    }

    final queryParams = <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
      'sortOrder': sortOrder,
      // Ne pas ajouter idSite comme query param si on utilise le path /site/{idSite}
      if (idArticle != null) 'idArticle': idArticle.toString(),
      if (nomSite != null && nomSite.isNotEmpty) 'nomSite': nomSite,
      if (libelle != null && libelle.isNotEmpty) 'libelle': libelle,
      if (idSociete != null) 'idSociete': idSociete.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
      if (withStock != null) 'withStock': withStock.toString(),
      if (sortField != null && sortField.isNotEmpty) 'sortField': sortField,
    };

    final url = Uri.parse(baseEndpoint).replace(queryParameters: queryParams);

    // Log URL complet pour debug
    debugPrint('getStockArticles URL: $url');

    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );

    // L'API peut retourner soit une liste directe, soit un objet avec 'stocks'
    if (response is Map<String, dynamic>) {
      final stocks = response['stocks'] as List<dynamic>?;
      if (stocks != null) {
        debugPrint('Found ${stocks.length} stocks in response');
        return stocks;
      }
    }
    // Fallback: si c'est une liste directe
    if (response is List) {
      return response;
    }
    return [];
  }

  // MÃ©thode pour rÃ©cupÃ©rer les articles pÃ©rissables
  Future<Map<String, dynamic>> getInventairePerissable({
    required int idSite,
    int page = 1,
    int pageSize = 20,
  }) async {
    final url =
        '$baseUrl/api/Peremption/inventaire-perissable/site/$idSite?Page=$page&PageSize=$pageSize';
    debugPrint('getInventairePerissable URL: $url');

    final uri = Uri.parse(url);
    final response = await _handleRequest(
      () => http.get(uri, headers: _getHeaders()),
    );

    if (response is Map<String, dynamic>) {
      return response;
    }
    return {};
  }

  // MÃ©thode pour compatibilitÃ© avec l'ancien code (retourne une liste simple)
  Future<List<dynamic>> getStockArticlesBySite(int idSite) async {
    debugPrint('getStockArticlesBySite called with idSite: $idSite');
    // Swagger utilise: /api/V_StockArticleSite/site/{idSite}
    final url =
        '$baseUrl/api/V_StockArticleSite/site/$idSite?page=1&pageSize=20&sortOrder=asc&withStock=true';
    debugPrint('getStockArticlesBySite URL: $url');

    final uri = Uri.parse(url);
    final response = await _handleRequest(
      () => http.get(uri, headers: _getHeaders()),
    );

    // L'API retourne un objet avec une propriÃ©tÃ© 'stocks'
    if (response is Map<String, dynamic>) {
      final stocks = response['stocks'] as List<dynamic>?;
      if (stocks != null) {
        debugPrint('Found ${stocks.length} stocks in response');
        return stocks;
      }
    }
    // Fallback: si c'est une liste directe
    if (response is List) {
      return response;
    }
    return [];
  }

  // MÃ©thode pour compatibilitÃ© avec pagination (retourne un Map avec pagination)
  Future<Map<String, dynamic>> getStockArticlesBySitePaginated(
    int idSite, {
    int page = 1,
    int pageSize = 20,
    String? search,
    bool? withStock,
    String sortOrder = 'asc',
    String? sortField,
  }) async {
    final stocks = await getStockArticles(
      idSite: idSite,
      page: page,
      pageSize: pageSize,
      search: search,
      withStock: withStock,
      sortOrder: sortOrder,
      sortField: sortField,
    );

    return {
      'filtres': {
        'idSite': idSite.toString(),
        'search': search,
        'withStock': withStock?.toString(),
      },
      'pagination': {
        'page': page.toString(),
        'pageSize': pageSize.toString(),
        'totalCount': stocks.length.toString(),
        'totalPages': ((stocks.length / pageSize).ceil()).toString(),
      },
      'stocks': stocks,
    };
  }

  Future<Map<String, dynamic>> getStock(int id) async {
    final url = Uri.parse('$baseUrl/api/Stocks/$id');
    return await _handleRequest(() => http.get(url, headers: _getHeaders()));
  }

  Future<Map<String, dynamic>> createStock(
    Map<String, dynamic> stockData,
  ) async {
    final url = Uri.parse('$baseUrl/api/Stocks');

    if (kDebugMode) {
      print('=== CREATE STOCK (API_SERVICE) - INPUT ===');
      print('Original stockData: $stockData');
    }

    // Extraire le stock object si wrapped
    Map<String, dynamic> stockObj;

    if (stockData.containsKey('stock')) {
      stockObj = Map<String, dynamic>.from(stockData['stock']);
      if (kDebugMode) {
        print('Data contains "stock" wrapper, extracted: $stockObj');
      }
    } else {
      stockObj = Map<String, dynamic>.from(stockData);
      if (kDebugMode) {
        print('Data is flat: $stockObj');
      }
    }

    // Ajouter idStock: 0 si absent (champ auto-gÃ©nÃ©rÃ©)
    if (!stockObj.containsKey('idStock')) {
      stockObj['idStock'] = 0;
      if (kDebugMode) {
        print('Added idStock: 0');
      }
    }

    // Ajouter les dates si absentes
    final now = DateTime.now().toUtc().toIso8601String();
    if (!stockObj.containsKey('dateCreation')) {
      stockObj['dateCreation'] = now;
      if (kDebugMode) {
        print('Added dateCreation: $now');
      }
    }
    if (!stockObj.containsKey('dateLastModification')) {
      stockObj['dateLastModification'] = now;
      if (kDebugMode) {
        print('Added dateLastModification: $now');
      }
    }

    // Assurer que statut est prÃ©sent
    if (!stockObj.containsKey('statut')) {
      stockObj['statut'] = true;
    }

    // Convertir les types
    if (stockObj.containsKey('idArticle')) {
      stockObj['idArticle'] = stockObj['idArticle'] is int
          ? stockObj['idArticle']
          : int.tryParse(stockObj['idArticle'].toString()) ?? 0;
    }
    if (stockObj.containsKey('idSite')) {
      stockObj['idSite'] = stockObj['idSite'] is int
          ? stockObj['idSite']
          : int.tryParse(stockObj['idSite'].toString()) ?? 0;
    }
    if (stockObj.containsKey('seuilAlerte')) {
      stockObj['seuilAlerte'] = stockObj['seuilAlerte'] is int
          ? stockObj['seuilAlerte']
          : (stockObj['seuilAlerte'] is double
                ? stockObj['seuilAlerte'].toInt()
                : int.tryParse(stockObj['seuilAlerte'].toString()) ?? 0);
    }

    // L'API attend les donnÃ©es Ã  plat (sans wrapper "stock")
    final cleanedData = stockObj;

    final body = json.encode(cleanedData);

    if (kDebugMode) {
      print('=== CREATE STOCK REQUEST ===');
      print('URL: $url');
      print('Cleaned Data: $cleanedData');
      print('Body: $body');
    }

    try {
      final httpResponse = await http.post(
        url,
        headers: _getHeaders(),
        body: body,
      );

      if (kDebugMode) {
        print('=== CREATE STOCK RAW RESPONSE ===');
        print('Status Code: ${httpResponse.statusCode}');
        print('Response Body: ${httpResponse.body}');
      }

      if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
        final response = json.decode(httpResponse.body);
        return response;
      } else {
        if (kDebugMode) {
          print('=== CREATE STOCK ERROR ===');
          print('Status: ${httpResponse.statusCode}');
          print('Body: ${httpResponse.body}');
        }
        throw ApiException(
          'Erreur ${httpResponse.statusCode}: ${httpResponse.body}',
          httpResponse.statusCode,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('=== CREATE STOCK EXCEPTION ===');
        print('Exception: $e');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateStock(
    int id,
    Map<String, dynamic> stockData,
  ) async {
    final url = Uri.parse('$baseUrl/api/Stocks/$id');

    if (kDebugMode) {
      print('=== UPDATE STOCK (API_SERVICE) - INPUT ===');
      print('Stock ID: $id');
      print('Original stockData: $stockData');
    }

    // S'assurer que les types sont corrects
    final cleanedData = Map<String, dynamic>.from(stockData);

    // Convertir les types numériques
    if (cleanedData.containsKey('idStock')) {
      cleanedData['idStock'] = cleanedData['idStock'] is int
          ? cleanedData['idStock']
          : int.tryParse(cleanedData['idStock'].toString()) ?? 0;
    }
    if (cleanedData.containsKey('idArticle')) {
      cleanedData['idArticle'] = cleanedData['idArticle'] is int
          ? cleanedData['idArticle']
          : int.tryParse(cleanedData['idArticle'].toString()) ?? 0;
    }
    if (cleanedData.containsKey('idSite')) {
      cleanedData['idSite'] = cleanedData['idSite'] is int
          ? cleanedData['idSite']
          : int.tryParse(cleanedData['idSite'].toString()) ?? 0;
    }
    if (cleanedData.containsKey('seuilAlerte')) {
      cleanedData['seuilAlerte'] = cleanedData['seuilAlerte'] is int
          ? cleanedData['seuilAlerte']
          : (cleanedData['seuilAlerte'] is double
                ? cleanedData['seuilAlerte'].toInt()
                : int.tryParse(cleanedData['seuilAlerte'].toString()) ?? 0);
    }

    final body = json.encode(cleanedData);

    if (kDebugMode) {
      print('=== UPDATE STOCK REQUEST ===');
      print('URL: $url');
      print('Cleaned Data: $cleanedData');
      print('Body: $body');
    }

    try {
      final httpResponse = await http.put(
        url,
        headers: _getHeaders(),
        body: body,
      );

      if (kDebugMode) {
        print('=== UPDATE STOCK RAW RESPONSE ===');
        print('Status Code: ${httpResponse.statusCode}');
        print('Response Body: ${httpResponse.body}');
      }

      if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
        // Status 204 (No Content) ne retourne pas de body
        if (httpResponse.statusCode == 204 || httpResponse.body.isEmpty) {
          if (kDebugMode) {
            print('Update successful with no content (204)');
          }
          return {'success': true, 'message': 'Stock mis à jour avec succès'};
        }

        final response = json.decode(httpResponse.body);
        if (kDebugMode) {
          print('Parsed response: $response');
        }
        return response as Map<String, dynamic>;
      } else {
        if (kDebugMode) {
          print('=== UPDATE STOCK ERROR ===');
          print('Status: ${httpResponse.statusCode}');
          print('Body: ${httpResponse.body}');
        }
        throw ApiException(
          'Erreur ${httpResponse.statusCode}: ${httpResponse.body}',
          httpResponse.statusCode,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('=== UPDATE STOCK EXCEPTION ===');
        print('Exception: $e');
      }
      rethrow;
    }
  }

  // Mouvements de stock endpoints
  Future<List<dynamic>> getMouvementsStockBySite(int idSite) async {
    final url = Uri.parse('$baseUrl/api/MouvementsStock/site/$idSite');
    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );
    return response is List ? response : [];
  }

  Future<Map<String, dynamic>> createMouvementStock(
    Map<String, dynamic> mouvementData,
  ) async {
    final url = Uri.parse('$baseUrl/api/MouvementsStock');

    if (kDebugMode) {
      print('=== CREATE MOUVEMENT STOCK (API_SERVICE) - INPUT ===');
      print('Original mouvementData: $mouvementData');
    }

    // Ajouter les dates si absentes
    final now = DateTime.now().toUtc().toIso8601String();
    if (!mouvementData.containsKey('dateCreation')) {
      mouvementData['dateCreation'] = now;
    }
    if (!mouvementData.containsKey('dateLastModification')) {
      mouvementData['dateLastModification'] = now;
    }
    if (!mouvementData.containsKey('dateMouvement')) {
      mouvementData['dateMouvement'] = now;
    }

    final body = json.encode(mouvementData);

    if (kDebugMode) {
      print('=== CREATE MOUVEMENT STOCK REQUEST ===');
      print('URL: $url');
      print('Body: $body');
    }

    try {
      final httpResponse = await http.post(
        url,
        headers: _getHeaders(),
        body: body,
      );

      if (kDebugMode) {
        print('=== CREATE MOUVEMENT STOCK RAW RESPONSE ===');
        print('Status Code: ${httpResponse.statusCode}');
        print('Response Body: ${httpResponse.body}');
      }

      if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
        final response = json.decode(httpResponse.body);
        return response as Map<String, dynamic>;
      } else {
        throw ApiException(
          'Erreur ${httpResponse.statusCode}: ${httpResponse.body}',
          httpResponse.statusCode,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('=== CREATE MOUVEMENT STOCK EXCEPTION ===');
        print('Exception: $e');
      }
      rethrow;
    }
  }

  // Journal de vente par site endpoints
  Future<Map<String, dynamic>> getJournalVenteParSite({
    required int idSite,
    int page = 1,
    int pageSize = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };

    final url = Uri.parse(
      '$baseUrl/api/V_JournalVenteParSite/site/$idSite',
    ).replace(queryParameters: queryParams);

    if (kDebugMode) {
      print('=== GET JOURNAL VENTE PAR SITE ===');
      print('URL: $url');
    }

    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );

    if (kDebugMode) {
      print('=== JOURNAL VENTE RESPONSE ===');
      print('Response: $response');
    }

    return response is Map<String, dynamic>
        ? response
        : {'data': [], 'pagination': {}};
  }

  // Rapports financiers par site endpoints
  Future<Map<String, dynamic>> getRapportsFinanciers({
    required int idSite,
    required int idSociete,
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async {
    final queryParams = <String, String>{
      'idSociete': idSociete.toString(),
      if (dateDebut != null) 'dateDebut': dateDebut.toIso8601String(),
      if (dateFin != null) 'dateFin': dateFin.toIso8601String(),
    };

    final url = Uri.parse(
      '$baseUrl/api/RapportsFinanciers/avec-charges/site/$idSite',
    ).replace(queryParameters: queryParams);

    if (kDebugMode) {
      print('=== GET RAPPORTS FINANCIERS ===');
      print('URL: $url');
    }

    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );

    if (kDebugMode) {
      print('=== RAPPORTS FINANCIERS RESPONSE ===');
      print('Response: $response');
    }

    return response is Map<String, dynamic> ? response : {};
  }

  // Journal de vente par caissier endpoints
  Future<Map<String, dynamic>> getJournalVenteParCaissier({
    required int idUtilisateur,
    int page = 1,
    int pageSize = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };

    final url = Uri.parse(
      '$baseUrl/api/V_JournalVenteParSite/caissier/$idUtilisateur',
    ).replace(queryParameters: queryParams);

    if (kDebugMode) {
      print('=== GET JOURNAL VENTE PAR CAISSIER ===');
      print('URL: $url');
    }

    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );

    if (kDebugMode) {
      print('=== JOURNAL VENTE PAR CAISSIER RESPONSE ===');
      print('Response: $response');
    }

    return response is Map<String, dynamic>
        ? response
        : {'data': [], 'pagination': {}};
  }

  // Synthese des ventes par site endpoints
  Future<Map<String, dynamic>> getVenteSyntheseParSite({
    int? idSociete,
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async {
    final queryParams = <String, String>{
      if (idSociete != null) 'idSociete': idSociete.toString(),
      if (dateDebut != null) 'dateDebut': dateDebut.toIso8601String(),
      if (dateFin != null) 'dateFin': dateFin.toIso8601String(),
    };

    final url = Uri.parse(
      '$baseUrl/api/V_JournalVenteParSite/synthese/site',
    ).replace(queryParameters: queryParams);

    if (kDebugMode) {
      print('=== GET VENTE SYNTHESE PAR SITE ===');
      print('URL: $url');
    }

    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );

    if (kDebugMode) {
      print('=== VENTE SYNTHESE RESPONSE ===');
      print('Response: $response');
    }

    return response is Map<String, dynamic> ? response : {};
  }

  // Synthese des ventes par article endpoints
  Future<Map<String, dynamic>> getVenteSyntheseParArticle({
    int? idSociete,
    int? idSite,
    int? idUtilisateur,
    int? idCaissier,
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async {
    final queryParams = <String, String>{
      if (idSociete != null) 'idSociete': idSociete.toString(),
      if (idSite != null) 'idSite': idSite.toString(),
      if (idUtilisateur != null) 'idUtilisateur': idUtilisateur.toString(),
      if (idCaissier != null) 'idCaissier': idCaissier.toString(),
      if (dateDebut != null) 'dateDebut': dateDebut.toIso8601String(),
      if (dateFin != null) 'dateFin': dateFin.toIso8601String(),
    };

    final url = Uri.parse(
      '$baseUrl/api/V_JournalVenteParSite/synthese/article',
    ).replace(queryParameters: queryParams);

    if (kDebugMode) {
      print('=== GET VENTE SYNTHESE PAR ARTICLE ===');
      print('URL: $url');
    }

    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );

    if (kDebugMode) {
      print('=== VENTE SYNTHESE PAR ARTICLE RESPONSE ===');
      print('Response: $response');
    }

    return response is Map<String, dynamic> ? response : {};
  }

  Future<Map<String, dynamic>> getVenteSyntheseParArticleCaissier(
    int idCaissier, {
    int? idSociete,
    int? idSite,
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async {
    final queryParams = <String, String>{
      if (idSociete != null) 'idSociete': idSociete.toString(),
      if (idSite != null) 'idSite': idSite.toString(),
      if (dateDebut != null) 'dateDebut': dateDebut.toIso8601String(),
      if (dateFin != null) 'dateFin': dateFin.toIso8601String(),
    };

    final url = Uri.parse(
      '$baseUrl/api/V_JournalVenteParSite/synthese/article/caissier/$idCaissier',
    ).replace(queryParameters: queryParams);

    if (kDebugMode) {
      print('=== GET VENTE SYNTHESE PAR ARTICLE CAISSIER ===');
      print('URL: $url');
    }

    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );

    if (kDebugMode) {
      print('=== VENTE SYNTHESE PAR ARTICLE CAISSIER RESPONSE ===');
      print('Response: $response');
    }

    return response is Map<String, dynamic> ? response : {};
  }

  // Client endpoints
  Future<List<dynamic>> getClients() async {
    final url = Uri.parse('$baseUrl/api/Clients');
    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );
    return response is List ? response : [];
  }

  Future<Map<String, dynamic>> getClient(int id) async {
    final url = Uri.parse('$baseUrl/api/Clients/$id');
    return await _handleRequest(() => http.get(url, headers: _getHeaders()));
  }

  Future<List<dynamic>> searchClients({
    String? email,
    String? nom,
    String? telephone,
    int pageNumber = 1,
    int pageSize = 20,
    int? maxPageSize,
  }) async {
    final queryParams = <String, String>{
      'PageNumber': pageNumber.toString(),
      'PageSize': pageSize.toString(),
      if (maxPageSize != null) 'MaxPageSize': maxPageSize.toString(),
      if (email != null && email.isNotEmpty) 'email': email,
      if (nom != null && nom.isNotEmpty) 'nom': nom,
      if (telephone != null && telephone.isNotEmpty) 'telephone': telephone,
    };

    final url = Uri.parse(
      '$baseUrl/api/Clients/search',
    ).replace(queryParameters: queryParams);
    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );

    // L'API retourne un objet avec une propriÃ©tÃ© 'data' contenant la liste des clients
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      final data = response['data'];
      if (data is List) {
        return data;
      }
    }

    // Fallback pour compatibilitÃ© avec d'anciennes versions
    return response is List ? response : [];
  }

  Future<Map<String, dynamic>> createClient(
    Map<String, dynamic> clientData,
  ) async {
    debugPrint('=== API_SERVICE.createClient ===');
    debugPrint('URL: $baseUrl/api/Clients');
    debugPrint('DonnÃ©es client envoyÃ©es: $clientData');
    debugPrint('DonnÃ©es JSON encodÃ©es: ${json.encode(clientData)}');

    final url = Uri.parse('$baseUrl/api/Clients');
    final body = json.encode(clientData);

    try {
      debugPrint('Envoi de la requÃªte POST...');
      final result = await _handleRequest(
        () => http.post(url, headers: _getHeaders(), body: body),
      );
      debugPrint('RÃ©ponse reÃ§ue: $result');
      debugPrint('Type de rÃ©ponse: ${result.runtimeType}');
      debugPrint('================================');
      return result;
    } catch (e, stackTrace) {
      debugPrint('=== ERREUR API_SERVICE.createClient ===');
      debugPrint('Erreur: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('=======================================');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateClient(
    int id,
    Map<String, dynamic> clientData,
  ) async {
    final url = Uri.parse('$baseUrl/api/Clients/$id');
    final body = json.encode(clientData);

    return await _handleRequest(
      () => http.put(url, headers: _getHeaders(), body: body),
    );
  }

  Future<void> deleteClient(int id) async {
    final url = Uri.parse('$baseUrl/api/Clients/$id');
    await _handleRequest(() => http.delete(url, headers: _getHeaders()));
  }

  Future<List<dynamic>> getClientsBySite(int idSite) async {
    final url = Uri.parse(
      '$baseUrl/api/V_ClientsParSite/site/$idSite?page=1&pageSize=100&sortOrder=asc',
    );

    try {
      final response = await _handleRequest(
        () => http.get(url, headers: _getHeaders()),
      );

      // La rÃ©ponse est un objet avec 'clients' comme tableau
      if (response is Map<String, dynamic>) {
        final clients = response['clients'];
        if (clients is List) {
          return clients;
        }
      } else if (response is List) {
        return response;
      }
      return [];
    } catch (e) {
      String message;
      final bool is404 = e.toString().contains('404');

      if (kDebugMode) {
        // --- MODE DEBUG (DÃ©veloppeur) ---
        // On affiche l'URL et l'erreur brute pour faciliter le debug
        debugPrint("erreur 4O4 $url");
        message = is404
            ? "Aucun Client trouvÃ©"
            : "Erreur technique ($url) : $e";
      } else {
        // --- MODE RELEASE (Utilisateur final) ---
        // On affiche des messages sobres et comprÃ©hensibles
        message = is404
            ? "Client non trouvÃ©"
            : "Impossible de rÃ©cupÃ©rer les donnÃ©es pour le moment.";
      }

      return Future.error(message);
    }
  }

  // Utilisateur endpoints
  Future<List<dynamic>> getUtilisateurs() async {
    final url = Uri.parse('$baseUrl/api/Utilisateurs');
    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );

    // L'API peut retourner un objet avec une propriÃ©tÃ© 'data' contenant la liste
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      final data = response['data'];
      if (data is List) {
        return data;
      } else if (data is Map<String, dynamic>) {
        // Si data est un objet unique, le convertir en liste
        return [data];
      }
    }

    // L'API peut retourner directement une liste
    if (response is List) {
      return response;
    } else if (response is Map<String, dynamic>) {
      // Si c'est un objet unique, le convertir en liste
      return [response];
    }

    return [];
  }

  Future<List<dynamic>> getAllUtilisateursBySite(int idSite) async {
    final url = Uri.parse('$baseUrl/api/V_Utilisateur/site/$idSite');
    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );

    // L'API peut retourner un objet avec une propriÃ©tÃ© 'data' contenant la liste
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      final data = response['data'];
      if (data is List) {
        return data;
      } else if (data is Map<String, dynamic>) {
        // Si data est un objet unique, le convertir en liste
        return [data];
      }
    }

    // L'API peut retourner directement une liste
    if (response is List) {
      return response;
    } else if (response is Map<String, dynamic>) {
      // Si c'est un objet unique, le convertir en liste
      return [response];
    }

    return [];
  }

  Future<Map<String, dynamic>> getUtilisateur(int id) async {
    final url = Uri.parse('$baseUrl/api/Utilisateurs/$id');
    return await _handleRequest(() => http.get(url, headers: _getHeaders()));
  }

  Future<Map<String, dynamic>> createUtilisateur(
    Map<String, dynamic> utilisateurData,
  ) async {
    final url = Uri.parse('$baseUrl/api/Utilisateurs');
    final body = json.encode(utilisateurData);
    return await _handleRequest(
      () => http.post(url, headers: _getHeaders(), body: body),
    );
  }

  Future<Map<String, dynamic>> updateUtilisateur(
    int id,
    Map<String, dynamic> utilisateurData,
  ) async {
    final url = Uri.parse('$baseUrl/api/Utilisateurs/$id');
    final body = json.encode(utilisateurData);
    return await _handleRequest(
      () => http.put(url, headers: _getHeaders(), body: body),
    );
  }

  Future<Map<String, dynamic>> updateUtilisateurStatut(
    int id,
    bool statut,
  ) async {
    final url = Uri.parse('$baseUrl/api/Utilisateurs/$id/statut');
    final body = json.encode(statut);
    return await _handleRequest(
      () => http.put(url, headers: _getHeaders(), body: body),
    );
  }

  Future<void> deleteUtilisateur(int id) async {
    final url = Uri.parse('$baseUrl/api/Utilisateurs/$id');
    await _handleRequest(() => http.delete(url, headers: _getHeaders()));
  }

  // Paiement endpoints
  Future<List<dynamic>> getPaiements() async {
    final url = Uri.parse('$baseUrl/api/V_Paiement');
    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );
    // Handle response format: { "data": [...] } or direct list
    if (response is Map && response.containsKey('data')) {
      final data = response['data'];
      return data is List ? data : [];
    }
    return response is List ? response : [];
  }

  /// GET /api/Paiements/caissier/{id} — pagination (PageNumber, PageSize, MaxPageSize).
  /// [sortDescending] : `true` (défaut) = date de paiement décroissante ; `false` = croissante.
  Future<Map<String, dynamic>> getPaiementsByCaissier(
    int idCaissier, {
    int pageNumber = 1,
    int pageSize = 20,
    int? maxPageSize,
    bool sortDescending = true,
  }) async {
    final queryParams = <String, String>{
      'PageNumber': pageNumber.toString(),
      'PageSize': pageSize.toString(),
      'SortDescending': sortDescending.toString(),
      if (maxPageSize != null) 'MaxPageSize': maxPageSize.toString(),
    };

    final url = Uri.parse(
      '$baseUrl/api/Paiements/caissier/$idCaissier',
    ).replace(queryParameters: queryParams);

    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );

    if (response is Map) {
      final map = Map<String, dynamic>.from(response);
      // Compat : anciennes réponses { paiements: [...] }
      if (!map.containsKey('data') && map.containsKey('paiements')) {
        map['data'] = map['paiements'];
      }
      return map;
    }
    if (response is List) {
      return {
        'data': response,
        'pageNumber': pageNumber,
        'pageSize': pageSize,
        'totalCount': response.length,
        'totalPages': 1,
        'hasPreviousPage': false,
        'hasNextPage': false,
      };
    }
    return {
      'data': <dynamic>[],
      'pageNumber': pageNumber,
      'pageSize': pageSize,
      'totalCount': 0,
      'totalPages': 0,
      'hasPreviousPage': false,
      'hasNextPage': false,
    };
  }

  /// GET /api/Paiements/site/{id} — paiements du site (gestionnaire).
  /// [sortDescending] : `true` (défaut) = date de paiement décroissante ; `false` = croissante.
  Future<Map<String, dynamic>> getPaiementsBySite(
    int idSite, {
    int pageNumber = 1,
    int pageSize = 20,
    int? maxPageSize,
    bool sortDescending = true,
  }) async {
    final queryParams = <String, String>{
      'PageNumber': pageNumber.toString(),
      'PageSize': pageSize.toString(),
      'SortDescending': sortDescending.toString(),
      if (maxPageSize != null) 'MaxPageSize': maxPageSize.toString(),
    };

    final url = Uri.parse(
      '$baseUrl/api/Paiements/site/$idSite',
    ).replace(queryParameters: queryParams);

    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );

    if (response is Map) {
      final map = Map<String, dynamic>.from(response);
      if (!map.containsKey('data') && map.containsKey('paiements')) {
        map['data'] = map['paiements'];
      }
      return map;
    }
    if (response is List) {
      return {
        'data': response,
        'pageNumber': pageNumber,
        'pageSize': pageSize,
        'totalCount': response.length,
        'totalPages': 1,
        'hasPreviousPage': false,
        'hasNextPage': false,
      };
    }
    return {
      'data': <dynamic>[],
      'pageNumber': pageNumber,
      'pageSize': pageSize,
      'totalCount': 0,
      'totalPages': 0,
      'hasPreviousPage': false,
      'hasNextPage': false,
    };
  }

  Future<Map<String, dynamic>> getAvanceAcompte({
    required int idSociete,
    required int idSite,
    int? idUtilisateur,
    int pageNumber = 1,
    int pageSize = 15,
    int? maxPageSize,
  }) async {
    final queryParams = <String, String>{
      'idSociete': idSociete.toString(),
      'idSite': idSite.toString(),
      'pageNumber': pageNumber.toString(),
      'pageSize': pageSize.toString(),
      if (idUtilisateur != null) 'idUtilisateur': idUtilisateur.toString(),
      if (maxPageSize != null) 'maxPageSize': maxPageSize.toString(),
    };

    final url = Uri.parse(
      '$baseUrl/api/Paiements/avance-acompte',
    ).replace(queryParameters: queryParams);

    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );

    return response is Map<String, dynamic>
        ? response
        : {'avancesAcomptes': [], 'data': []};
  }

  Future<Map<String, dynamic>> getStatistiquesPaiements({
    int? idSociete,
    int? idSite,
    int? idUtilisateur,
  }) async {
    String url = '$baseUrl/api/Paiements/statistiques';
    List<String> queryParams = [];

    if (idSociete != null) queryParams.add('idSociete=$idSociete');
    if (idSite != null) queryParams.add('idSite=$idSite');
    if (idUtilisateur != null) queryParams.add('idUtilisateur=$idUtilisateur');

    if (queryParams.isNotEmpty) {
      url += '?${queryParams.join('&')}';
    }

    final uri = Uri.parse(url);
    final response = await _handleRequest(
      () => http.get(uri, headers: _getHeaders()),
    );

    return response is Map ? Map<String, dynamic>.from(response) : {};
  }

  Future<Map<String, dynamic>> getCommandeById(int idCommande) async {
    final url = Uri.parse('$baseUrl/api/Commande/$idCommande');
    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );

    return response is Map ? Map<String, dynamic>.from(response) : {};
  }

  Future<Map<String, dynamic>> getCommandeDetail(int idCommande) async {
    final url = Uri.parse('$baseUrl/api/Commande/$idCommande/detail');
    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );

    return response is Map ? Map<String, dynamic>.from(response) : {};
  }

  Future<Map<String, dynamic>> annulerVente({
    required int idCommande,
    required String motif,
    String? referenceRemboursement,
    String? modeRemboursement,
    double? montantRembourse,
    required int idUtilisateurAnnulation,
    bool RembourserStock = true,
    bool annulerPaiement = true,
    String? commentaire,
  }) async {
    final url = Uri.parse('$baseUrl/api/Vente/annuler');
    final body = json.encode({
      'idCommande': idCommande,
      'motif': motif,
      if (referenceRemboursement != null)
        'referenceRemboursement': referenceRemboursement,
      if (modeRemboursement != null) 'modeRemboursement': modeRemboursement,
      if (montantRembourse != null) 'montantRembourse': montantRembourse,
      'idUtilisateurAnnulation': idUtilisateurAnnulation,
      'rembourserStock': RembourserStock,
      'annulerPaiement': annulerPaiement,
      if (commentaire != null) 'commentaire': commentaire,
    });

    return await _handleRequest(
      () => http.post(url, headers: _getHeaders(), body: body),
    );
  }

  Future<Map<String, dynamic>> retirerProduitVente({
    required int idCommande,
    required int idStock,
    required int idUtilisateur,
  }) async {
    final url = Uri.parse('$baseUrl/api/Vente/retirer-produit');
    final body = json.encode({
      'idCommande': idCommande,
      'idStock': idStock,
      'idUtilisateur': idUtilisateur,
    });

    return _executeWithRetry<Map<String, dynamic>>(
      () async {
        if (kDebugMode) {
          debugPrint('=== POST /api/Vente/retirer-produit ===');
          debugPrint('Body: $body');
        }
        final response = await _handleRequest(
          () => http.post(url, headers: _getHeaders(), body: body),
        );
        final map = response is Map<String, dynamic>
            ? response
            : <String, dynamic>{'success': true};
        if (kDebugMode) {
          debugPrint('=== RESPONSE retirer-produit ===');
          debugPrint(jsonEncode(map));
        }
        return map;
      },
    );
  }

  Future<Map<String, dynamic>> reduireQuantiteProduitVente({
    required int idCommande,
    required int idStock,
    required int nouvelleQuantite,
    required int idUtilisateur,
  }) async {
    final url = Uri.parse('$baseUrl/api/Vente/reduire-quantite');
    final body = json.encode({
      'idCommande': idCommande,
      'idStock': idStock,
      'nouvelleQuantite': nouvelleQuantite,
      'idUtilisateur': idUtilisateur,
    });

    return _executeWithRetry<Map<String, dynamic>>(
      () async {
        if (kDebugMode) {
          debugPrint('=== POST /api/Vente/reduire-quantite ===');
          debugPrint('Body: $body');
        }
        final response = await _handleRequest(
          () => http.post(url, headers: _getHeaders(), body: body),
        );
        final map = response is Map<String, dynamic>
            ? response
            : <String, dynamic>{'success': true};
        if (kDebugMode) {
          debugPrint('=== RESPONSE reduire-quantite ===');
          debugPrint(jsonEncode(map));
        }
        return map;
      },
    );
  }

  Future<Map<String, dynamic>> getVentesAnnulees({
    required int idSite,
    int? idUtilisateur,
    DateTime? dateDebut,
    DateTime? dateFin,
    int page = 1,
    int pageSize = 5,
  }) async {
    final queryParams = <String, String>{
      'idSite': idSite.toString(),
      'page': page.toString(),
      'pageSize': pageSize.toString(),
      if (idUtilisateur != null) 'idUtilisateur': idUtilisateur.toString(),
      if (dateDebut != null) 'dateDebut': dateDebut.toIso8601String(),
      if (dateFin != null) 'dateFin': dateFin.toIso8601String(),
    };

    final url = Uri.parse(
      '$baseUrl/api/Vente/annulees',
    ).replace(queryParameters: queryParams);

    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );

    return response is Map<String, dynamic>
        ? response
        : <String, dynamic>{
            'filtres': {'idSite': idSite},
            'pagination': {
              'page': page,
              'pageSize': pageSize,
              'totalCount': 0,
              'totalPages': 1,
            },
            'ventes': <dynamic>[],
          };
  }

  Future<Map<String, dynamic>> getClientById(int idClient) async {
    final url = Uri.parse('$baseUrl/api/Clients/$idClient');
    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );

    return response is Map ? Map<String, dynamic>.from(response) : {};
  }

  Future<List<dynamic>> getPaiementsBySociete(int idSociete) async {
    final url = Uri.parse('$baseUrl/api/Paiements/societe/$idSociete');
    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );
    if (response is Map && response.containsKey('data')) {
      return List<dynamic>.from(response['data']);
    }
    return response is List ? response : [];
  }

  Future<Map<String, dynamic>> getPaiementsByClient(
    int idClient, {
    int pageNumber = 1,
    int pageSize = 15,
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async {
    final queryParams = <String, String>{
      'pageNumber': pageNumber.toString(),
      'pageSize': pageSize.toString(),
      if (dateDebut != null) 'dateDebut': dateDebut.toIso8601String(),
      if (dateFin != null) 'dateFin': dateFin.toIso8601String(),
    };

    final url = Uri.parse(
      '$baseUrl/api/Paiements/client/$idClient',
    ).replace(queryParameters: queryParams);

    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );

    if (response is Map && response.containsKey('data')) {
      return Map<String, dynamic>.from(response);
    }
    return <String, dynamic>{
      'data': response is List ? response : [],
      'pageNumber': 1,
      'pageSize': pageSize,
      'totalCount': 0,
      'totalPages': 1,
    };
  }

  Future<Map<String, dynamic>> getPaiementsDashboard({
    required int idSociete,
    int? idSite,
    int? idUtilisateur,
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async {
    final queryParams = <String, String>{
      'idSociete': idSociete.toString(),
      if (idSite != null) 'idSite': idSite.toString(),
      if (idUtilisateur != null) 'idUtilisateur': idUtilisateur.toString(),
      if (dateDebut != null) 'dateDebut': dateDebut.toIso8601String(),
      if (dateFin != null) 'dateFin': dateFin.toIso8601String(),
    };

    final url = Uri.parse(
      '$baseUrl/api/Paiements/dashboard',
    ).replace(queryParameters: queryParams);

    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );

    return response is Map<String, dynamic> ? response : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createPaiement(
    Map<String, dynamic> paiementData,
  ) async {
    final url = Uri.parse('$baseUrl/api/Paiements');
    final body = json.encode(paiementData);

    return await _handleRequest(
      () => http.post(url, headers: _getHeaders(), body: body),
    );
  }

  // Site endpoints
  Future<List<dynamic>> getSites() async {
    final url = Uri.parse('$baseUrl/api/Sites');
    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );
    return response is List ? response : [];
  }

  Future<Map<String, dynamic>> getSite(int id) async {
    final url = Uri.parse('$baseUrl/api/Sites/$id');
    return await _handleRequest(() => http.get(url, headers: _getHeaders()));
  }

  Future<List<Site>> getSitesBySociete(int idSociete) async {
    debugPrint('=== API getSitesBySociete ===');
    debugPrint('Requesting sites for company ID: $idSociete');
    debugPrint('URL: $baseUrl/api/Sites/societe/$idSociete');

    final url = Uri.parse('$baseUrl/api/Sites/societe/$idSociete');
    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );

    debugPrint('API Response type: ${response.runtimeType}');
    debugPrint('API Response content: $response');

    if (response is List) {
      debugPrint('Mapping ${response.length} sites');
      try {
        final sites = response.map((item) => Site.fromJson(item)).toList();
        debugPrint('Successfully mapped ${sites.length} sites');
        return sites;
      } catch (e) {
        debugPrint('Error mapping sites: $e');
        rethrow;
      }
    }
    debugPrint('Response is not a list, returning empty list');
    return [];
  }

  Future<List<Map<String, dynamic>>> getRoles() async {
    debugPrint('=== API getRoles ===');
    debugPrint('URL: $baseUrl/api/Roles');

    final url = Uri.parse('$baseUrl/api/Roles');
    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );

    debugPrint('API Response type: ${response.runtimeType}');

    if (response is List) {
      debugPrint('Mapping ${response.length} roles');
      try {
        final roles = response
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        debugPrint('Successfully mapped ${roles.length} roles');
        return roles;
      } catch (e) {
        debugPrint('Error mapping roles: $e');
        rethrow;
      }
    }
    debugPrint('Response is not a list, returning empty list');
    return [];
  }

  Future<Site> createSite(Map<String, dynamic> siteData) async {
    final url = Uri.parse('$baseUrl/api/Sites');

    if (kDebugMode) {
      debugPrint('=== CREATE SITE - INPUT DATA ===');
      debugPrint('Original siteData: $siteData');
    }

    // Extract the site object if wrapped
    Map<String, dynamic> siteObj;

    if (siteData.containsKey('site')) {
      siteObj = Map<String, dynamic>.from(siteData['site']);
      if (kDebugMode) {
        debugPrint('Data contains "site" wrapper, extracted: $siteObj');
      }
    } else {
      siteObj = Map<String, dynamic>.from(siteData);
      if (kDebugMode) {
        debugPrint('Data is flat: $siteObj');
      }
    }

    // Remove idSite if it's 0 (auto-generated field)
    if (siteObj.containsKey('idSite') && siteObj['idSite'] == 0) {
      siteObj.remove('idSite');
      if (kDebugMode) {
        print('Removed idSite (was 0, auto-generated)');
      }
    }

    // Add dateCreation and dateLastModification if not present
    final now = DateTime.now().toUtc().toIso8601String();
    if (!siteObj.containsKey('dateCreation') ||
        siteObj['dateCreation'] == null) {
      siteObj['dateCreation'] = now;
      if (kDebugMode) {
        print('Added dateCreation: $now');
      }
    }
    if (!siteObj.containsKey('dateLastModification') ||
        siteObj['dateLastModification'] == null) {
      siteObj['dateLastModification'] = now;
      if (kDebugMode) {
        print('Added dateLastModification: $now');
      }
    }

    // Ensure statut is present (default to true)
    if (!siteObj.containsKey('statut')) {
      siteObj['statut'] = true;
      if (kDebugMode) {
        print('Added default statut: true');
      }
    }

    // Convert idSociete to int if it's a string
    if (siteObj.containsKey('idSociete')) {
      final idSocieteValue = siteObj['idSociete'];
      if (idSocieteValue is String) {
        siteObj['idSociete'] = int.tryParse(idSocieteValue) ?? 0;
      } else if (idSocieteValue is num) {
        siteObj['idSociete'] = idSocieteValue.toInt();
      }
      if (kDebugMode) {
        print(
          'idSociete converted: ${siteObj['idSociete']} (type: ${siteObj['idSociete'].runtimeType})',
        );
      }
    }

    // API expects flat structure (no "site" wrapper)
    final cleanedData = siteObj;

    final body = json.encode(cleanedData);

    if (kDebugMode) {
      print('=== CREATE SITE REQUEST ===');
      print('URL: $url');
      print('Headers: ${_getHeaders()}');
      print('Body: $body');
    }

    try {
      final httpResponse = await http.post(
        url,
        headers: _getHeaders(),
        body: body,
      );

      if (kDebugMode) {
        print('=== CREATE SITE RAW RESPONSE ===');
        print('Status Code: ${httpResponse.statusCode}');
        print('Response Headers: ${httpResponse.headers}');
        print('Response Body: ${httpResponse.body}');
      }

      if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
        final response = json.decode(httpResponse.body);

        if (kDebugMode) {
          print('=== CREATE SITE PARSED RESPONSE ===');
          print('Parsed response type: ${response.runtimeType}');
          print('Parsed response: $response');
        }

        // Extract site from response if wrapped
        if (response is Map<String, dynamic> && response.containsKey('site')) {
          if (kDebugMode) {
            print(
              'Response contains "site" key, extracting: ${response['site']}',
            );
          }
          return Site.fromJson(response['site']);
        }

        if (kDebugMode) {
          print('Response does not contain "site" key, using as-is');
        }

        return Site.fromJson(response);
      } else {
        if (kDebugMode) {
          print('=== CREATE SITE ERROR ===');
          print('Status: ${httpResponse.statusCode}');
          print('Body: ${httpResponse.body}');
        }
        throw ApiException(
          'Erreur ${httpResponse.statusCode}: ${httpResponse.body}',
          httpResponse.statusCode,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('=== CREATE SITE EXCEPTION ===');
        print('Exception type: ${e.runtimeType}');
        print('Exception: $e');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateSite(
    int id,
    Map<String, dynamic> siteData,
  ) async {
    final url = Uri.parse('$baseUrl/api/Sites/$id');
    final body = json.encode(siteData);

    if (kDebugMode) {
      print('=== UPDATE SITE ===');
      print('Site ID: $id');
      print('Data: $siteData');
    }

    return await _handleRequest(
      () => http.put(url, headers: _getHeaders(), body: body),
    );
  }

  Future<void> deleteSite(int id) async {
    final url = Uri.parse('$baseUrl/api/Sites/$id');

    if (kDebugMode) {
      print('=== DELETE SITE ===');
      print('Site ID: $id');
    }

    await _handleRequest(() => http.delete(url, headers: _getHeaders()));
  }

  // Role endpoints
  Future<Map<String, dynamic>> getRole(int id) async {
    final url = Uri.parse('$baseUrl/api/Roles/$id');
    return await _handleRequest(() => http.get(url, headers: _getHeaders()));
  }

  // Caissier Performance endpoints
  Future<Map<String, dynamic>> getDashboardData({
    required int idSite,
    int? idSociete,
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async {
    final queryParams = <String, String>{};

    if (idSociete != null) {
      queryParams['idSociete'] = idSociete.toString();
    }
    if (dateDebut != null) {
      queryParams['dateDebut'] = dateDebut.toIso8601String();
    }
    if (dateFin != null) {
      queryParams['dateFin'] = dateFin.toIso8601String();
    }

    final url = Uri.parse(
      '$baseUrl/api/Dashboard/site/$idSite',
    ).replace(queryParameters: queryParams);
    return await _handleRequest(() => http.get(url, headers: _getHeaders()));
  }

  Future<Map<String, dynamic>> getDashboardDataBySociete({
    required int idSociete,
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async {
    final queryParams = <String, String>{};

    if (dateDebut != null) {
      queryParams['dateDebut'] = dateDebut.toIso8601String();
    }
    if (dateFin != null) {
      queryParams['dateFin'] = dateFin.toIso8601String();
    }

    final url = Uri.parse(
      '$baseUrl/api/Dashboard/societe/$idSociete',
    ).replace(queryParameters: queryParams);
    return await _handleRequest(() => http.get(url, headers: _getHeaders()));
  }

  /*   Future<Map<String, dynamic>> getJournalVenteParSite({
    required int idSite,
    int page = 1,
    int pageSize = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };

    final url = Uri.parse(
      '$baseUrl/api/V_JournalVenteParSite/site/$idSite',
    ).replace(queryParameters: queryParams);
    return await _handleRequest(() => http.get(url, headers: _getHeaders()));
  } */

  Future<Map<String, dynamic>> getCaissierPerformanceJournal({
    int? idSite,
    int? idUtilisateur,
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async {
    final queryParams = <String, String>{};

    if (idSite != null) {
      queryParams['idSite'] = idSite.toString();
    }
    if (idUtilisateur != null) {
      queryParams['idUtilisateur'] = idUtilisateur.toString();
    }
    if (dateDebut != null) {
      queryParams['dateDebut'] = dateDebut.toIso8601String();
    }
    if (dateFin != null) {
      queryParams['dateFin'] = dateFin.toIso8601String();
    }

    final url = Uri.parse(
      '$baseUrl/api/CaissierPerformance/journal',
    ).replace(queryParameters: queryParams);
    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );
    return response is Map<String, dynamic> ? response : {};
  }

  Future<Map<String, dynamic>> getCaissierPerformanceJournalPaged({
    int? idSite,
    int? idUtilisateur,
    DateTime? dateDebut,
    DateTime? dateFin,
    int page = 1,
    int pageSize = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };

    if (idSite != null) {
      queryParams['idSite'] = idSite.toString();
    }
    if (idUtilisateur != null) {
      queryParams['idUtilisateur'] = idUtilisateur.toString();
    }
    if (dateDebut != null) {
      queryParams['dateDebut'] = dateDebut.toIso8601String();
    }
    if (dateFin != null) {
      queryParams['dateFin'] = dateFin.toIso8601String();
    }

    final url = Uri.parse(
      '$baseUrl/api/CaissierPerformance/journal-paged',
    ).replace(queryParameters: queryParams);
    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );
    return response is Map<String, dynamic> ? response : {};
  }

  Future<Map<String, dynamic>> getCaissierPerformanceStatistiques({
    int? idSite,
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async {
    final queryParams = <String, String>{};

    if (idSite != null) {
      queryParams['idSite'] = idSite.toString();
    }
    if (dateDebut != null) {
      queryParams['dateDebut'] = dateDebut.toIso8601String();
    }
    if (dateFin != null) {
      queryParams['dateFin'] = dateFin.toIso8601String();
    }

    final url = Uri.parse(
      '$baseUrl/api/CaissierPerformance/statistiques',
    ).replace(queryParameters: queryParams);
    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );
    return response is Map<String, dynamic> ? response : {};
  }

  // Devise endpoints avec modèles Devise
  Future<DeviseSiteResponse> getDevisesBySite(
    int idSite, {
    bool actives = true,
  }) async {
    try {
      final queryParams = actives ? '?actives=true' : '';
      final url = Uri.parse('$baseUrl/api/Devise/site/$idSite$queryParams');
      final response = await _handleRequest(
        () => http.get(url, headers: _getHeaders()),
      );

      if (response is Map<String, dynamic>) {
        return DeviseSiteResponse.fromJson(response);
      }
      return DeviseSiteResponse(site: '', totalDevises: 0, devises: []);
    } catch (e) {
      return DeviseSiteResponse(site: '', totalDevises: 0, devises: []);
    }
  }

  // Approvisionnement endpoints
  // POST /api/Approvisionnement - Créer un nouvel approvisionnement
  Future<Map<String, dynamic>> createApprovisionnement(
    Map<String, dynamic> approvisionnementData,
  ) async {
    debugPrint('=== API createApprovisionnement ===');
    debugPrint('URL: $baseUrl/api/Approvisionnement');
    debugPrint('Données approvisionnement: $approvisionnementData');

    final url = Uri.parse('$baseUrl/api/Approvisionnement');
    final body = json.encode(approvisionnementData);

    return await _handleRequest(
      () => http.post(url, headers: _getHeaders(), body: body),
    );
  }

  // PUT /api/Approvisionnement/{id} - Mettre à jour un approvisionnement
  Future<Map<String, dynamic>> updateApprovisionnement(
    int id,
    Map<String, dynamic> approvisionnementData,
  ) async {
    debugPrint('=== API updateApprovisionnement ===');
    debugPrint('URL: $baseUrl/api/Approvisionnement/$id');
    debugPrint('Données approvisionnement: $approvisionnementData');

    final url = Uri.parse('$baseUrl/api/Approvisionnement/$id');
    final body = json.encode(approvisionnementData);

    return await _handleRequest(
      () => http.put(url, headers: _getHeaders(), body: body),
    );
  }

  // GET /api/Approvisionnement/site/{idSite} - Récupérer les approvisionnements par site avec pagination
  Future<Map<String, dynamic>> getApprovisionnementsBySite(
    int idSite, {
    int pageNumber = 1,
    int pageSize = 20,
    int? maxPageSize,
  }) async {
    debugPrint('=== API getApprovisionnementsBySite ===');
    debugPrint('URL: $baseUrl/api/Approvisionnement/site/$idSite');

    final queryParams = <String, String>{
      'PageNumber': pageNumber.toString(),
      'PageSize': pageSize.toString(),
      if (maxPageSize != null) 'MaxPageSize': maxPageSize.toString(),
    };

    final url = Uri.parse(
      '$baseUrl/api/Approvisionnement/site/$idSite',
    ).replace(queryParameters: queryParams);

    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );

    // L'API retourne un objet avec la structure { data: [...], pageNumber: 0, pageSize: 0, totalCount: 0, ... }
    if (response is Map<String, dynamic>) {
      return response;
    }
    return {
      'data': [],
      'pageNumber': pageNumber,
      'pageSize': pageSize,
      'totalCount': 0,
      'totalPages': 0,
      'hasPreviousPage': false,
      'hasNextPage': false,
    };
  }

  Future<List<Devise>> getDevisesBySociete(int idSociete, bool actives) async {
    try {
      final queryParams = actives ? '?actives=true' : '';
      final url = Uri.parse(
        '$baseUrl/api/Devise/societe/$idSociete$queryParams',
      );
      final response = await _handleRequest(
        () => http.get(url, headers: _getHeaders()),
      );

      if (response is Map<String, dynamic>) {
        final devisesList = response['devises'] as List<dynamic>? ?? [];
        return devisesList
            .map((d) => Devise.fromJson(d as Map<String, dynamic>))
            .toList();
      }
      if (response is List) {
        return response
            .map((d) => Devise.fromJson(d as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> updateDeviseStatut(int id, bool statut) async {
    final url = Uri.parse('$baseUrl/api/Devise/$id/statut');
    final body = json.encode(statut);
    return await _handleRequest(
      () => http.put(url, headers: _getHeaders(), body: body),
    );
  }

  Future<Map<String, dynamic>> updateDeviseTaux(int id, double taux) async {
    final url = Uri.parse('$baseUrl/api/Devise/$id/taux');
    final body = json.encode(taux);
    return await _handleRequest(
      () => http.put(url, headers: _getHeaders(), body: body),
    );
  }

  // Alias methods for compatibility
  Future<Map<String, dynamic>> updateStatut(int id, bool statut) async {
    return updateDeviseStatut(id, statut);
  }

  Future<Map<String, dynamic>> updateTaux(
    int id,
    double taux,
    String text,
  ) async {
    return updateDeviseTaux(id, taux);
  }

  Future<Devise> createDevise(Devise devise) async {
    final url = Uri.parse('$baseUrl/api/Devise');
    final body = json.encode(devise.toJson());
    final response = await _handleRequest(
      () => http.post(url, headers: _getHeaders(), body: body),
    );
    return Devise.fromJson(response as Map<String, dynamic>);
  }

  Future<Devise> updateDevise(int id, Devise devise) async {
    final url = Uri.parse('$baseUrl/api/Devise/$id');
    final body = json.encode(devise.toJson());
    final response = await _handleRequest(
      () => http.put(url, headers: _getHeaders(), body: body),
    );
    return Devise.fromJson(response as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getChargesOperationnelles({
    required int idUtilisateur,
    int pageNumber = 1,
    int pageSize = 15,
    int? maxPageSize,
    int? idSite,
    int? idSociete,
    String? dateDebut,
    String? dateFin,
    String? typeCharge,
    String? statut,
    String? fournisseur,
  }) async {
    final queryParams = <String, String>{
      'idUtilisateur': idUtilisateur.toString(),
      'pageNumber': pageNumber.toString(),
      'pageSize': pageSize.toString(),
      if (maxPageSize != null) 'maxPageSize': maxPageSize.toString(),
      if (idSite != null) 'idSite': idSite.toString(),
      if (idSociete != null) 'idSociete': idSociete.toString(),
      if (dateDebut != null) 'dateDebut': dateDebut,
      if (dateFin != null) 'dateFin': dateFin,
      if (typeCharge != null) 'typeCharge': typeCharge,
      if (statut != null) 'statut': statut,
      if (fournisseur != null) 'fournisseur': fournisseur,
    };

    final url = Uri.parse(
      '$baseUrl/api/ChargesOperationnelles/utilisateur/$idUtilisateur',
    ).replace(queryParameters: queryParams);

    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );

    return response is Map<String, dynamic>
        ? response
        : {'charges': [], 'synthese': {}, 'filtres': {}};
  }

  Future<Map<String, dynamic>> getSiteCharges({
    required int idSite,
    int pageNumber = 1,
    int pageSize = 15,
    int? maxPageSize,
    int? idSociete,
    String? dateDebut,
    String? dateFin,
    String? typeCharge,
    String? statut,
    String? fournisseur,
  }) async {
    final queryParams = <String, String>{
      'pageNumber': pageNumber.toString(),
      'pageSize': pageSize.toString(),
      if (maxPageSize != null) 'maxPageSize': maxPageSize.toString(),
      if (idSociete != null) 'idSociete': idSociete.toString(),
      if (dateDebut != null) 'dateDebut': dateDebut,
      if (dateFin != null) 'dateFin': dateFin,
      if (typeCharge != null) 'typeCharge': typeCharge,
      if (statut != null) 'statut': statut,
      if (fournisseur != null) 'fournisseur': fournisseur,
    };

    final url = Uri.parse(
      '$baseUrl/api/ChargesOperationnelles/site/$idSite/paginated',
    ).replace(queryParameters: queryParams);

    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );

    return response is Map<String, dynamic>
        ? response
        : {'charges': [], 'synthese': {}, 'filtres': {}};
  }

  Future<List<dynamic>> getTypesCharge() async {
    final url = Uri.parse('$baseUrl/api/ChargesOperationnelles/types');
    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );
    return response is List ? response : [];
  }

  Future<Map<String, dynamic>> createCharge(
    Map<String, dynamic> chargeData,
  ) async {
    final url = Uri.parse('$baseUrl/api/ChargesOperationnelles');
    final body = json.encode(chargeData);
    final response = await _handleRequest(
      () => http.post(url, headers: _getHeaders(), body: body),
    );
    return response is Map<String, dynamic>
        ? response
        : {'success': false, 'message': 'Invalid response'};
  }

  Future<Map<String, dynamic>> updateCharge(
    int idCharge,
    Map<String, dynamic> chargeData,
  ) async {
    final url = Uri.parse('$baseUrl/api/ChargesOperationnelles/$idCharge');
    final body = json.encode(chargeData);
    final response = await _handleRequest(
      () => http.put(url, headers: _getHeaders(), body: body),
    );
    return response is Map<String, dynamic>
        ? response
        : {'success': false, 'message': 'Invalid response'};
  }

  Future<bool> deleteCharge(int idCharge) async {
    final url = Uri.parse('$baseUrl/api/ChargesOperationnelles/$idCharge');
    final response = await _handleRequest(
      () => http.delete(url, headers: _getHeaders()),
    );
    if (response is Map<String, dynamic>) {
      return response['success'] == true || response.isEmpty;
    }
    return response is Map<String, dynamic> && response.isEmpty;
  }

  Future<Map<String, dynamic>> getSiteChargesSynthese({
    required int idSite,
    String? dateDebut,
    String? dateFin,
  }) async {
    final queryParams = <String, String>{
      if (dateDebut != null) 'dateDebut': dateDebut,
      if (dateFin != null) 'dateFin': dateFin,
    };

    final url = Uri.parse(
      '$baseUrl/api/ChargesOperationnelles/synthese/site/$idSite',
    ).replace(queryParameters: queryParams);

    final response = await _handleRequest(
      () => http.get(url, headers: _getHeaders()),
    );

    return response is Map<String, dynamic>
        ? response
        : {'synthese': {}, 'totalGeneral': 0.0};
  }
}

