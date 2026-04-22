import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/utilisateur.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';

class AuthRepository {
  final ApiService _apiService;
  final DatabaseService _dbService;

  AuthRepository(this._apiService, this._dbService) {
    _loadPersistedAuthData();
  }

  Utilisateur? _currentUser;
  bool _isAuthenticated = false;

  Utilisateur? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;

  void _loadPersistedAuthData() {
    final token = _dbService.getAuthToken();
    final user = _dbService.getCurrentUser();

    if (token != null && user != null) {
      _apiService.setTokens(token, _dbService.getRefreshToken() ?? '');
      // remove any currency information from the cached user
      _currentUser = Utilisateur(
        idUtilisateur: user.idUtilisateur,
        nomComplet: user.nomComplet,
        sexe: user.sexe,
        dateNonce: user.dateNonce,
        numeroTelephone: user.numeroTelephone,
        photo: user.photo,
        login: user.login,
        role: user.role,
        idSite: user.idSite,
        nomSite: user.nomSite,
        contact: user.contact,
        adresseSite: user.adresseSite,
        idSociete: user.idSociete,
        nomSociete: user.nomSociete,
        statut: user.statut,
        isConnected: user.isConnected,
        codeDevise: '',
        nomDevise: '',
        symboleDevise: '',
        tauxActuel: '0',
      );
      _isAuthenticated = true;

      if (kDebugMode) {
        print(
          'Loaded persisted auth data for user: ${user.nomComplet} (${user.login})',
        );
        print('Token: ${token.substring(0, 20)}...');
      }

      // Validate session in background
      _validatePersistedSession();
    } else if (kDebugMode) {
      print('No persisted auth data found');
    }
  }

  Future<void> _validatePersistedSession() async {
    try {
      final isValid = await validateSession();
      if (!isValid) {
        if (kDebugMode) {
          print('Persisted session is invalid, clearing auth data');
        }
        await logout();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error validating persisted session: $e');
      }
      // On validation error, clear auth data for security
      await logout();
    }
  }

  Future<AuthResult> login(String login, String password) async {
    try {
      final isConnected = await _apiService.checkConnectivity();

      if (!isConnected) {
        // Try to authenticate with cached credentials
        final cachedUser = _dbService.getCurrentUser();
        final cachedToken = _dbService.getAuthToken();

        if (cachedUser != null &&
            cachedUser.login == login &&
            cachedToken != null) {
          _apiService.setTokens(
            cachedToken,
            _dbService.getRefreshToken() ?? '',
          );
          _currentUser = cachedUser;
          _isAuthenticated = true;

          if (kDebugMode) {
            print('Offline authentication successful for: $login');
          }

          return AuthResult.success(cachedUser);
        } else {
          return AuthResult.failure(
            'Pas de connexion internet et pas d\'identifiants en cache',
          );
        }
      }

      // Online authentication
      final response = await _apiService.authenticate(
        login: login,
        motDePasse: password,
      );

      if (response.containsKey('token')) {
        final token = response['token'] as String;
        final refreshToken = response['refreshToken'] as String?;
        final rawUserData =
            response['user']
                as Map<String, dynamic>; // 'user' au lieu de 'utilisateur'
        final userData = _normalizeUserData(rawUserData);
        final user = Utilisateur.fromJson(userData);

        // Save authentication data
        await _persistAuthData(token, refreshToken ?? '', user);

        _apiService.setTokens(token, refreshToken ?? '');
        _currentUser = user;
        _isAuthenticated = true;

        if (kDebugMode) {
          print(
            'Authentication successful for: ${user.nomComplet} (${user.login})',
          );
        }

        return AuthResult.success(user);
      } else {
        return AuthResult.failure(
          'Réponse d\'authentification invalide: token manquant',
        );
      }
    } on ApiException catch (e) {
      if (kDebugMode) {
        print('Authentication API error: ${e.message}');
      }

      String errorMessage = e.message.toLowerCase();
      
      if (errorMessage.contains('non autorisé') ||
          errorMessage.contains('non autorise') ||
          errorMessage.contains('unauthorized') ||
          errorMessage.contains('401') ||
          errorMessage.contains('forbidden') ||
          errorMessage.contains('access denied')) {
        return AuthResult.failure('Login ou mot de passe incorrect');
      }
      
      if (errorMessage.contains('not found') || 
          errorMessage.contains('404') ||
          errorMessage.contains('utilisateur')) {
        return AuthResult.failure('Utilisateur introuvable');
      }
      
      if (errorMessage.contains('locked') || 
          errorMessage.contains('desactive') ||
          errorMessage.contains('inactive') ||
          errorMessage.contains('bloque')) {
        return AuthResult.failure('Compte désactivé. Contactez l\'administrateur');
      }
      
      if (errorMessage.contains('expired') || 
          errorMessage.contains('expiré')) {
        return AuthResult.failure('Session expirée. Veuillez vous reconnecter');
      }
      
      return AuthResult.failure('Erreur de connexion. Veuillez réessayer');
    } catch (e, stackTrace) {
      debugPrint('=== AUTHENTICATION ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('============================');

      String errorMessage = e.toString().toLowerCase();
      
      if (errorMessage.contains('socketexception') ||
          errorMessage.contains('failed host lookup') ||
          errorMessage.contains('no address associated') ||
          errorMessage.contains('connection refused') ||
          errorMessage.contains('host unreachable')) {
        return AuthResult.failure('Serveur inaccessible. Vérifiez votre connexion internet');
      }
      
      if (errorMessage.contains('timeout') ||
          errorMessage.contains('timed out')) {
        return AuthResult.failure('Délai d\'attente dépassé. Réessayez plus tard');
      }
      
      if (errorMessage.contains('formatException') ||
          errorMessage.contains('invalid') ||
          errorMessage.contains('type error')) {
        return AuthResult.failure('Erreur de données. Veuillez contacter le support');
      }
      
      return AuthResult.failure('Erreur de connexion. Veuillez réessayer');
    }
  }

  Future<void> _persistAuthData(
    String token,
    String refreshToken,
    Utilisateur user,
  ) async {
    await _dbService.saveAuthToken(token);
    await _dbService.saveRefreshToken(refreshToken);
    await _dbService.saveCurrentUser(user);
  }

  Future<AuthResult> updateCurrentUserProfile({
    required String nomComplet,
    required String login,
    required String numeroTelephone,
  }) async {
    try {
      if (!_isAuthenticated || _currentUser == null) {
        return AuthResult.failure('Utilisateur non authentifie');
      }

      final idUtilisateur = int.tryParse(_currentUser!.idUtilisateur) ?? 0;
      if (idUtilisateur <= 0) {
        return AuthResult.failure('Identifiant utilisateur invalide');
      }

      final details = await _apiService.getUtilisateur(idUtilisateur);
      final nameParts = _splitNomComplet(nomComplet);
      final nowIso = DateTime.now().toUtc().toIso8601String();

      final payload = <String, dynamic>{
        'province': _asString(details['province']),
        'ville': _asString(details['ville']),
        'commune': _asString(details['commune']),
        'quartier': _asString(details['quartier']),
        'avenue': _asString(details['avenue']),
        'numero': _asString(details['numero']),
        'dateCreation': _asIsoDate(details['dateCreation']) ?? nowIso,
        'dateLastModification': nowIso,
        'statut': _asBool(details['statut'], fallback: _currentUser!.statut),
        'idUtilisateur': _asInt(
          details['idUtilisateur'],
          fallback: idUtilisateur,
        ),
        'nomUtilisateur': nameParts['nomUtilisateur'],
        'postNomUtilisateur': nameParts['postNomUtilisateur'],
        'prenomUtilisateur': nameParts['prenomUtilisateur'],
        'sexe': _asString(details['sexe'], fallback: _currentUser!.sexe),
        'dateNaissance':
            _asIsoDate(details['dateNaissance']) ??
            _currentUser!.dateNonce.toUtc().toIso8601String(),
        'numeroTelephone': numeroTelephone.trim(),
        'email': _asString(details['email'], fallback: _currentUser!.login),
        'login': login.trim(),
        'motDePasse': _asString(details['motDePasse']),
        'photo': _asString(
          details['photo'],
          fallback: _currentUser!.photo ?? '',
        ),
        'isConnected': _asBool(
          details['isConnected'],
          fallback: _currentUser!.isConnected,
        ),
        'idSite': _asInt(
          details['idSite'],
          fallback: int.tryParse(_currentUser!.idSite) ?? 0,
        ),
        'idRole': _asInt(details['idRole']),
      };

      await _apiService.updateUtilisateur(idUtilisateur, payload);

      final updatedUser = Utilisateur(
        idUtilisateur: _currentUser!.idUtilisateur,
        nomComplet: nomComplet.trim(),
        sexe: _asString(payload['sexe'], fallback: _currentUser!.sexe),
        dateNonce: DateTime.parse(
          payload['dateNaissance'] as String,
        ).toLocal(),
        numeroTelephone: numeroTelephone.trim(),
        photo: _asString(payload['photo']).isEmpty
            ? null
            : _asString(payload['photo']),
        login: login.trim(),
        role: _currentUser!.role,
        idSite: _currentUser!.idSite,
        nomSite: _currentUser!.nomSite,
        contact: _currentUser!.contact,
        adresseSite: _currentUser!.adresseSite,
        idSociete: _currentUser!.idSociete,
        nomSociete: _currentUser!.nomSociete,
        statut: _asBool(payload['statut'], fallback: _currentUser!.statut),
        isConnected: _asBool(
          payload['isConnected'],
          fallback: _currentUser!.isConnected,
        ),
        // currency fields are deliberately cleared; they are managed
        // independently by the currency/taux service.
        codeDevise: '',
        nomDevise: '',
        symboleDevise: '',
        tauxActuel: '0',
      );

      _currentUser = updatedUser;
      await _dbService.saveCurrentUser(updatedUser);

      return AuthResult.success(updatedUser);
    } on ApiException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('Erreur lors de la mise a jour du profil: $e');
    }
  }

  /// Met à jour l'utilisateur courant en mémoire et dans la base de données locale
  Future<void> updateCurrentUser(Utilisateur user) async {
    _currentUser = user;
    await _dbService.saveCurrentUser(user);
  }

  Map<String, String> _splitNomComplet(String nomComplet) {
    final cleaned = nomComplet.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) {
      return {
        'nomUtilisateur': '',
        'postNomUtilisateur': '',
        'prenomUtilisateur': '',
      };
    }

    final parts = cleaned.split(' ');
    if (parts.length == 1) {
      return {
        'nomUtilisateur': parts[0],
        'postNomUtilisateur': '',
        'prenomUtilisateur': '',
      };
    }
    if (parts.length == 2) {
      return {
        'nomUtilisateur': parts[0],
        'postNomUtilisateur': '',
        'prenomUtilisateur': parts[1],
      };
    }

    return {
      'nomUtilisateur': parts[0],
      'postNomUtilisateur': parts.sublist(1, parts.length - 1).join(' '),
      'prenomUtilisateur': parts.last,
    };
  }

  String _asString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    return value.toString();
  }

  Map<String, dynamic> _normalizeUserData(Map<String, dynamic> userData) {
    final normalized = Map<String, dynamic>.from(userData);
    final normalizedDate =
        _asIsoDate(userData['dateNonce'] ?? userData['dateNaissance']) ??
        DateTime.now().toUtc().toIso8601String();
    final normalizedPhoto = _asString(userData['photo']);

    normalized['idUtilisateur'] = _asString(userData['idUtilisateur']);
    normalized['nomComplet'] = _asString(userData['nomComplet']);
    normalized['sexe'] = _asString(userData['sexe']);
    normalized['dateNonce'] = normalizedDate;
    normalized['numeroTelephone'] = _asString(userData['numeroTelephone']);
    normalized['photo'] = normalizedPhoto.isEmpty ? null : normalizedPhoto;
    normalized['login'] = _asString(userData['login']);
    normalized['role'] = _asString(userData['role']);
    normalized['idSite'] = _asString(userData['idSite']);
    normalized['nomSite'] = _asString(userData['nomSite']);
    normalized['contact'] = _asString(userData['contact']);
    normalized['adresseSite'] = _asString(userData['adresseSite']);
    normalized['idSociete'] = _asString(userData['idSociete']);
    normalized['nomSociete'] = _asString(userData['nomSociete']);
    normalized['statut'] = _asBool(userData['statut']);
    normalized['isConnected'] = _asBool(userData['isConnected']);
    // Currency-related fields are no longer stored on the user.
    normalized['codeDevise'] = '';
    normalized['nomDevise'] = '';
    normalized['symboleDevise'] = '';
    normalized['tauxActuel'] = '0';

    return normalized;
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  bool _asBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return fallback;
  }

  String? _asIsoDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed.toUtc().toIso8601String();
    }
    return null;
  }

  Future<AuthResult> changePassword(
    String oldPassword,
    String newPassword,
  ) async {
    return changePasswordWithConfirm(
      currentPassword: oldPassword,
      newPassword: newPassword,
      confirmNewPassword: newPassword,
    );
  }

  Future<AuthResult> changePasswordWithConfirm({
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    try {
      if (!_isAuthenticated) {
        return AuthResult.failure('Utilisateur non authentifie');
      }

      final currentUserId = _currentUser?.idUtilisateur;
      if (currentUserId == null || currentUserId.isEmpty) {
        return AuthResult.failure('Identifiant utilisateur introuvable');
      }

      await _apiService.changePasswordByUserId(
        idUtilisateur: currentUserId,
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmNewPassword: confirmNewPassword,
      );

      return AuthResult.success(_currentUser!);
    } on ApiException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure(
        'Erreur lors du changement de mot de passe: $e',
      );
    }
  }

  Future<void> logout() async {
    try {
      _currentUser = null;
      _isAuthenticated = false;

      _apiService.clearTokens();
      await _dbService.clearAuthData();

      if (kDebugMode) {
        print('User logged out successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during logout: $e');
      }
    }
  }

  Future<bool> refreshToken() async {
    try {
      // TODO: Implement refresh token logic
      // This would involve calling a refresh endpoint with the refresh token
      // and updating the auth tokens

      if (kDebugMode) {
        print('Token refresh not yet implemented');
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Token refresh failed: $e');
      }
      return false;
    }
  }

  // Validate if current session is still valid
  Future<bool> validateSession() async {
    if (!_isAuthenticated || _currentUser == null) {
      return false;
    }

    // Check if we have a valid token
    final token = _dbService.getAuthToken();
    if (token == null || token.isEmpty) {
      if (kDebugMode) {
        print('No auth token found');
      }
      return false;
    }

    // Check if token is expired by decoding JWT
    try {
      // Decode JWT token to check expiration
      final parts = token.split('.');
      if (parts.length != 3) {
        if (kDebugMode) {
          print('Invalid JWT token format');
        }
        return false;
      }

      // Decode the payload (second part)
      final payload = parts[1];
      // Add padding if needed
      final normalizedPayload = base64.normalize(payload);
      final payloadString = utf8.decode(base64.decode(normalizedPayload));
      final payloadMap = json.decode(payloadString) as Map<String, dynamic>;

      // Check expiration
      if (payloadMap.containsKey('exp')) {
        final exp = payloadMap['exp'] as int;
        final expirationDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        final now = DateTime.now();

        if (now.isAfter(expirationDate)) {
          if (kDebugMode) {
            print('Token expired at: $expirationDate');
          }
          return false;
        }

        if (kDebugMode) {
          print('Token is valid until: $expirationDate');
        }
        return true;
      } else {
        // No expiration field, assume token is valid
        if (kDebugMode) {
          print('Token has no expiration field, assuming valid');
        }
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Token validation error: $e');
      }
      // On error, assume token is invalid for security
      return false;
    }
  }
}

class AuthResult {
  final bool isSuccess;
  final Utilisateur? user;
  final String? errorMessage;

  AuthResult._(this.isSuccess, this.user, this.errorMessage);

  factory AuthResult.success(Utilisateur user) {
    return AuthResult._(true, user, null);
  }

  factory AuthResult.failure(String errorMessage) {
    return AuthResult._(false, null, errorMessage);
  }

  @override
  String toString() {
    return isSuccess
        ? 'AuthResult(success: true, user: ${user?.login})'
        : 'AuthResult(success: false, error: $errorMessage)';
  }
}


