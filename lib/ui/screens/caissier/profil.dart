import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mombongo/models/devise_model.dart';
import 'package:mombongo/models/taux.dart';
import 'package:mombongo/services/app_currency_preference.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/ui/screens/caissier/change_password_screen.dart';
import 'package:mombongo/ui/screens/edit_profile_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' as io;
import '../login_screen.dart';

class ProfilCaissierScreen extends StatefulWidget {
  const ProfilCaissierScreen({super.key});

  @override
  State<ProfilCaissierScreen> createState() => _ProfilCaissierScreenState();
}

class _ProfilCaissierScreenState extends State<ProfilCaissierScreen> {
  static const String _fastSalePrefKey = 'pref_fast_sale_enabled';
  static const String _articleFilterPrefKey = 'pref_article_filter_with_stock';
  static const String _receiptFooterPrefKey = 'pref_receipt_footer_message';
  static const String _receiptLogoPrefKey = 'pref_receipt_logo_path';
  bool _fastSaleEnabled = true;
  bool _articleFilterWithStock = true; // Par défaut: articles avec stock
  String _currencyCode = AppCurrencyPreference.defaultCode;
  String _tauxActuel = '1'; // show 1 by default until we fetch real rate
  String _nomDevise = '';
  String _receiptFooterMessage =
      ''; // Message personnalisé pour le pied de reçu
  String _receiptLogoPath = ''; // Chemin du logo pour le reçu
  List<dynamic> _devises = [];
  bool _isLoadingDevises = false;
  final ImagePicker _imagePicker = ImagePicker();

  List<DropdownMenuItem<String>> _buildCurrencyItems() {
    debugPrint(
      'Building currency items. Loading: $_isLoadingDevises, Devises: ${_devises.length}',
    );
    debugPrint('_devises content: $_devises');

    if (_isLoadingDevises) {
      return const [];
    }

    if (_devises.isEmpty) {
      // API returned no currencies (or we haven't loaded yet).
      // Don't pretend we know the defaults – caller should handle an empty
      // list (e.g. disable the dropdown or show a message).
      return const [];
    }

    final seenCodes = <String>{};
    final items = <DropdownMenuItem<String>>[];

    debugPrint('Processing ${_devises.length} devises...');

    for (final devise in _devises) {
      String code = '';
      String? nom;
      String symbole = '';

      debugPrint('Devise raw: $devise (type: ${devise.runtimeType})');

      if (devise is Map) {
        code = devise['code']?.toString().trim().toUpperCase() ?? '';
        nom = devise['nom']?.toString().trim();
        symbole = devise['symbole']?.toString().trim() ?? '';
        debugPrint('From Map - code: $code, nom: $nom, symbole: $symbole');
      } else if (devise is Devise) {
        code = devise.code.trim().toUpperCase();
        nom = devise.nom;
        symbole = devise.symbole ?? '';
        debugPrint('From Devise - code: $code, nom: $nom, symbole: $symbole');
      }

      if (code.isEmpty || !seenCodes.add(code)) {
        debugPrint('Skipping devise - code empty or duplicate: $code');
        continue;
      }

      final labelName = (nom == null || nom.isEmpty) ? code : nom;
      final labelSuffix = symbole.isNotEmpty ? ' $symbole' : '';

      items.add(
        DropdownMenuItem(
          value: code,
          child: Text('$labelName ($code$labelSuffix)'),
        ),
      );
    }

    if (items.isEmpty) {
      return const [
        DropdownMenuItem(
          value: AppCurrencyPreference.cdfCode,
          child: Text('Franc congolais (CDF)'),
        ),
        DropdownMenuItem(
          value: AppCurrencyPreference.usdCode,
          child: Text('Dollar americain (USD)'),
        ),
      ];
    }

    return items;
  }

  String? _resolveSelectedCurrency(List<DropdownMenuItem<String>> items) {
    if (items.any((item) => item.value == _currencyCode)) {
      return _currencyCode;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadDevises();
  }

  Future<void> _loadDevises() async {
    final currentUser = locator.authRepository.currentUser;
    if (currentUser == null) return;

    setState(() => _isLoadingDevises = true);

    try {
      final idSite = int.tryParse(currentUser.idSite) ?? 0;
      if (idSite > 0) {
        final response = await locator.apiService.getDevisesBySite(
          idSite,
          actives: true,
        );
        if (mounted) {
          setState(() {
            _devises = response.devises;
            _isLoadingDevises = false;
          });
          debugPrint('Devises loaded: ${_devises.length}');
          // once we have the list we can refresh our rate info
          _updateTauxInfo();
        }
      } else {
        final idSociete = int.tryParse(currentUser.idSociete) ?? 0;
        if (idSociete > 0) {
          final devises = await locator.apiService.getDevisesBySociete(
            idSociete,
            true,
          );
          if (mounted) {
            setState(() {
              // just use what the API returned; if it's empty the dropdown
              // will also be empty and the UI can react accordingly.
              _devises = devises;
              _isLoadingDevises = false;
            });
            _updateTauxInfo();
          }
        } else if (mounted) {
          setState(() => _isLoadingDevises = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDevises = false);
      }
    }
  }

  /// Update the displayed rate/name using the cached list of devises.
  ///
  /// The API already returns the taux inside each devise entry, so we only
  /// need to look it up locally rather than making another request. This
  /// method is invoked after the list is fetched and whenever the selected
  /// currency code changes.
  void _updateTauxInfo() {
    try {
      dynamic found;
      // iterate manually to avoid typing issues and handle both Map and Devise
      for (final d in _devises) {
        String? code;
        if (d is Map) {
          code = d['code']?.toString().trim().toUpperCase();
        } else if (d is Devise) {
          code = d.code.trim().toUpperCase();
        }
        if (code == _currencyCode) {
          found = d;
          break;
        }
      }

      if (!mounted || found == null) return;

      String tauxVal = '1';
      String nom = '';
      if (found is Map) {
        tauxVal = found['tauxActuel']?.toString() ?? '1';
        nom = found['nom']?.toString() ?? '';
      } else if (found is Devise) {
        tauxVal = found.tauxActuel;
        nom = found.nom;
      }
      setState(() {
        _tauxActuel = tauxVal.isEmpty ? '1' : tauxVal;
        _nomDevise = nom;
      });
    } catch (e, st) {
      debugPrint('[caissier _updateTauxInfo] failed: $e\n$st');
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final savedFastSale = locator.databaseService.get<bool>(_fastSalePrefKey);
      final savedArticleFilter = locator.databaseService.get<bool>(
        _articleFilterPrefKey,
      );
      final savedCurrency = AppCurrencyPreference.readCode(
        locator.databaseService,
      );
      final savedReceiptFooter = locator.databaseService.get<String>(
        _receiptFooterPrefKey,
      );
      final savedReceiptLogo = locator.databaseService.get<String>(
        _receiptLogoPrefKey,
      );
      if (!mounted) return;
      setState(() {
        _fastSaleEnabled = savedFastSale ?? true;
        _articleFilterWithStock =
            savedArticleFilter ?? true; // Par défaut: articles avec stock
        _currencyCode = savedCurrency;
        _receiptFooterMessage = savedReceiptFooter ?? '';
        _receiptLogoPath = savedReceiptLogo ?? '';
      });
      // keep service in sync so other pages can read the preferred code
      // without hitting AppCurrencyPreference directly.
      locator.tauxService.sauvegarderDevisePreferee(_currencyCode);
      // rate info may already be available if the devise list finished
      // loading before preferences; update in that case.
      if (_devises.isNotEmpty) {
        _updateTauxInfo();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fastSaleEnabled = true;
        _articleFilterWithStock = true; // Par défaut: articles avec stock
        _currencyCode = AppCurrencyPreference.defaultCode;
      });
      // rate info will update when devises are loaded later (see above)
    }
  }

  Future<void> _setFastSaleEnabled(bool value) async {
    setState(() {
      _fastSaleEnabled = value;
    });
    try {
      await locator.databaseService.save<bool>(_fastSalePrefKey, value);
    } catch (_) {}
  }

  Future<void> _setArticleFilterWithStock(bool value) async {
    setState(() {
      _articleFilterWithStock = value;
    });
    try {
      await locator.databaseService.save<bool>(_articleFilterPrefKey, value);
    } catch (_) {}
  }

  Future<void> _setReceiptFooterMessage(String value) async {
    setState(() {
      _receiptFooterMessage = value;
    });
    try {
      await locator.databaseService.save<String>(_receiptFooterPrefKey, value);
    } catch (_) {}
  }

  Future<void> _pickReceiptLogo() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 300,
        maxHeight: 150,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          _receiptLogoPath = image.path;
        });
        await locator.databaseService.save<String>(
          _receiptLogoPrefKey,
          image.path,
        );
      }
    } catch (e) {
      debugPrint('Erreur lors de la sélection du logo: $e');
    }
  }

  Future<void> _removeReceiptLogo() async {
    setState(() {
      _receiptLogoPath = '';
    });
    try {
      await locator.databaseService.save<String>(_receiptLogoPrefKey, '');
    } catch (_) {}
  }

  Future<void> _setCurrencyCode(String value) async {
    final normalized = AppCurrencyPreference.normalizeCode(value);

    // Trouver la devise sélectionnée pour obtenir son taux et son nom
    String? selectedNomDevise;
    String? selectedTauxActuel;
    String? selectedSymbole;

    for (final devise in _devises) {
      if (devise is Map) {
        final code = devise['code']?.toString().trim().toUpperCase();
        if (code == normalized) {
          selectedNomDevise = devise['nom']?.toString().trim();
          selectedTauxActuel = devise['tauxActuel']?.toString();
          selectedSymbole = devise['symbole']?.toString().trim();
          break;
        }
      } else if (devise is Devise) {
        if (devise.code.trim().toUpperCase() == normalized) {
          selectedNomDevise = devise.nom;
          selectedTauxActuel = devise.tauxActuel;
          selectedSymbole = devise.symbole ?? '';
          break;
        }
      }
    }

    setState(() {
      _currencyCode = normalized;
      // keep the existing _tauxActuel when the new currency didn't provide a
      // specific rate (e.g. CDF); otherwise we would erase the real USD→CDF
      // value and break conversions.
      if (selectedTauxActuel != null && selectedTauxActuel.isNotEmpty) {
        _tauxActuel = selectedTauxActuel;
      }
      if (selectedNomDevise != null) {
        _nomDevise = selectedNomDevise;
      }
    });

    try {
      await AppCurrencyPreference.saveCode(locator.databaseService, normalized);
      // keep service sync for convenience
      await locator.tauxService.sauvegarderDevisePreferee(normalized);

      // only update the cached rate if we actually found one from the API (or
      // if the chosen currency is USD).  Choosing CDF should *not* overwrite the
      // previously saved USD→CDF rate with a bogus "1" value.
      if (selectedTauxActuel != null &&
          selectedTauxActuel.isNotEmpty &&
          selectedTauxActuel != '0') {
        final taux = Taux(
          codeDevise: normalized,
          nomDevise: selectedNomDevise ?? '',
          symboleDevise: selectedSymbole ?? '',
          tauxActuel: selectedTauxActuel,
        );
        await locator.tauxService.sauvegarderTaux(taux);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = locator.authRepository.currentUser;

    return Scaffold(
      body: currentUser == null
          ? const Center(child: Text('Aucune donnee utilisateur disponible'))
          : CustomScrollView(
              slivers: [
                // Header avec gradient
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      'Mon Profil',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    centerTitle: true,
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).colorScheme.secondary,
                            Theme.of(context).colorScheme.tertiary,
                          ],
                        ),
                      ),
                      child: SafeArea(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 40),
                              // Avatar avec bordure
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Colors.white,
                                  child: Text(
                                    _getInitials(currentUser.nomComplet),
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2C3E50),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Contenu
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Informations personnelles
                      _buildSectionTitle('Informations personnelles'),
                      const SizedBox(height: 12),
                      _buildInfoCard(
                        icon: Icons.person,
                        iconColor: Colors.blue,
                        children: [
                          _buildInfoTile(
                            icon: Icons.badge,
                            label: 'Nom complet',
                            value: currentUser.nomComplet,
                          ),
                          _buildDivider(),
                          _buildInfoTile(
                            icon: Icons.email,
                            label: 'Email / Login',
                            value: currentUser.login,
                          ),
                          _buildDivider(),
                          _buildInfoTile(
                            icon: Icons.phone,
                            label: 'Téléphone',
                            value: currentUser.numeroTelephone,
                          ),
                          _buildDivider(),
                          _buildInfoTile(
                            icon: Icons.cake,
                            label: 'Date de naissance',
                            value:
                                '${DateFormat('dd/MM/yyyy').format(currentUser.dateNonce)} (${_calculateAge(currentUser.dateNonce)} ans)',
                          ),
                          _buildDivider(),
                          _buildInfoTile(
                            icon: currentUser.sexe == 'M'
                                ? Icons.male
                                : Icons.female,
                            label: 'Sexe',
                            value: currentUser.sexe == 'M'
                                ? 'Masculin'
                                : 'Féminin',
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Informations professionnelles
                      _buildSectionTitle('Informations professionnelles'),
                      const SizedBox(height: 12),
                      _buildInfoCard(
                        icon: Icons.business,
                        iconColor: Colors.green,
                        children: [
                          _buildInfoTile(
                            icon: Icons.work,
                            label: 'Rôle',
                            value: currentUser.role,
                          ),
                          _buildDivider(),
                          _buildInfoTile(
                            icon: Icons.store,
                            label: 'Site',
                            value: currentUser.nomSite,
                          ),
                          _buildDivider(),
                          _buildInfoTile(
                            icon: Icons.corporate_fare,
                            label: 'Société',
                            value: currentUser.nomSociete,
                          ),
                          if (currentUser.adresseSite.isNotEmpty) ...[
                            _buildDivider(),
                            _buildInfoTile(
                              icon: Icons.location_on,
                              label: 'Adresse',
                              value: currentUser.adresseSite,
                            ),
                          ],
                          if (currentUser.contact.isNotEmpty) ...[
                            _buildDivider(),
                            _buildInfoTile(
                              icon: Icons.contact_phone,
                              label: 'Contact site',
                              value: currentUser.contact,
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 24),

                      _buildSectionTitle('Préférences'),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            SwitchListTile(
                              title: const Text(
                                'Vente rapide',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                              subtitle: Text(
                                'Alternative au panier (vente en une seule étape)',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                              value: _fastSaleEnabled,
                              activeColor: Theme.of(
                                context,
                              ).colorScheme.tertiary,
                              onChanged: _setFastSaleEnabled,
                            ),
                            Divider(height: 1, color: Colors.grey[200]),
                            SwitchListTile(
                              title: const Text(
                                'Articles avec stock',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                              subtitle: Text(
                                'Afficher par défaut les articles avec stock',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                              value: _articleFilterWithStock,
                              activeThumbColor: Theme.of(
                                context,
                              ).colorScheme.tertiary,
                              onChanged: _setArticleFilterWithStock,
                            ),
                            Divider(height: 1, color: Colors.grey[200]),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                12,
                                16,
                                16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Devise',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2C3E50),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Builder(
                                    builder: (_) {
                                      final currencyItems =
                                          _buildCurrencyItems();
                                      final selectedCurrency =
                                          _resolveSelectedCurrency(
                                            currencyItems,
                                          );

                                      return DropdownButtonFormField<String>(
                                        value: selectedCurrency,
                                        hint: Text(
                                          _isLoadingDevises
                                              ? 'Chargement...'
                                              : 'Sélectionner une devise',
                                        ),
                                        decoration: InputDecoration(
                                          prefixIcon: const Icon(
                                            Icons.payments_outlined,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 12,
                                              ),
                                        ),
                                        items: currencyItems,
                                        onChanged: _isLoadingDevises
                                            ? null
                                            : (value) {
                                                if (value == null) return;
                                                _setCurrencyCode(value);
                                              },
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Afficher le taux de change actuel
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade100),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.currency_exchange,
                                    color: Colors.blue.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Taux de change actuel',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                        Text(
                                          // always show rate relative to USD; if the selected
                                          // currency is CDF the user already understands the
                                          // conversion, so displaying "1 CDF = 2850 CDF" would
                                          // be misleading.
                                          '1 USD = $_tauxActuel CDF ($_nomDevise)',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2C3E50),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Cette devise sera utilisée pour la facturation, les calculs et la comptabilité.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildActionCard(
                              icon: Icons.edit,
                              title: 'Modifier le profil',
                              subtitle: 'Mettre à jour vos informations',
                              color: Colors.blue,
                              onTap: () => _showEditProfileDialog(context),
                            ),

                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Logo du reçu
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.image,
                                          color: Colors.purple.shade700,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Logo de l\'entreprise',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF2C3E50),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Ce logo apparaîtra dans l\'en-tête du reçu (préférer image noir et blanc)',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    if (_receiptLogoPath.isNotEmpty) ...[
                                      Container(
                                        height: 80,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.file(
                                            io.File(_receiptLogoPath),
                                            fit: BoxFit.contain,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return Center(
                                                    child: Icon(
                                                      Icons.broken_image,
                                                      color: Colors.grey[400],
                                                      size: 40,
                                                    ),
                                                  );
                                                },
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: _pickReceiptLogo,
                                              icon: const Icon(
                                                Icons.edit,
                                                size: 18,
                                              ),
                                              label: const Text('Modifier'),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: _removeReceiptLogo,
                                              icon: const Icon(
                                                Icons.delete,
                                                size: 18,
                                              ),
                                              label: const Text('Supprimer'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ] else ...[
                                      InkWell(
                                        onTap: _pickReceiptLogo,
                                        child: Container(
                                          height: 80,
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                              style: BorderStyle.solid,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            color: Colors.grey.shade50,
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.add_photo_alternate,
                                                color: Colors.grey[400],
                                                size: 32,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Cliquez pour ajouter un logo',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    Divider(color: Colors.grey[200]),
                                    const SizedBox(height: 16),
                                    // Message du pied de reçu
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.receipt_long,
                                          color: Colors.green.shade700,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Message du reçu',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF2C3E50),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Ce message apparaîtra au bas du reçu',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      initialValue: _receiptFooterMessage,
                                      maxLines: 3,
                                      decoration: InputDecoration(
                                        hintText:
                                            'Ex: Ce reçu fait office de preuve de paiement. Conservez-le soigneusement.',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        contentPadding: const EdgeInsets.all(
                                          12,
                                        ),
                                      ),
                                      onChanged: _setReceiptFooterMessage,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildActionCard(
                              icon: Icons.lock,
                              title: 'Changer le mot de passe',
                              subtitle: 'Mettre à jour votre mot de passe',
                              color: Colors.orange,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ChangePasswordScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildActionCard(
                              icon: Icons.logout,
                              title: 'Déconnexion',
                              subtitle: 'Se déconnecter de votre compte',
                              color: Colors.red,
                              onTap: () => _handleLogout(context),
                            ),
                            const SizedBox(height: 32),
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    'Développer par',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Kansa Business',
                                    style: TextStyle(
                                      color: Colors.grey[800],
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ),

                  // Footer
                ),
              ],
            ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;

    // v�rifier si l'anniversaire n'est pas encore pass� cette ann�e
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }

    return age;
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF2C3E50),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // En-tête de la carte
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Container()),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 24, thickness: 1, color: Colors.grey[200]);
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditProfileDialog(BuildContext context) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );

    if (!mounted) return;
    if (updated == true) {
      setState(() {});
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Déconnexion'),
          content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Déconnexion'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await locator.authRepository.logout();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }
}
