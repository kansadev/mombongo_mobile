import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:mombongo/models/devise_model.dart';
import 'package:mombongo/models/taux.dart';
import 'package:mombongo/services/app_currency_preference.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/ui/screens/caissier/change_password_screen.dart';
import 'package:mombongo/ui/screens/caissier/profil/profil_infos_screen.dart';
import 'package:mombongo/ui/screens/caissier/profil/recus_settings_screen.dart';
import 'package:mombongo/ui/screens/edit_profile_screen.dart';
import 'package:mombongo/ui/theme/pos_colors.dart';
import 'package:mombongo/ui/widgets/pos/settings_tiles.dart';
import 'package:mombongo/utils/google_fonts_compat.dart';
import 'package:mombongo/utils/receipt/receipt_paper.dart';
import 'package:mombongo/utils/receipt/receipt_pdf_builder.dart';
import 'package:mombongo/utils/receipt/receipt_print_dialog.dart';
import '../login_screen.dart';

/// Profil du caissier : page centrale organisée en sections
/// (Compte, Caisse, Reçus, Données, Session).

class ProfilCaissierScreen extends StatefulWidget {
  const ProfilCaissierScreen({super.key});

  @override
  State<ProfilCaissierScreen> createState() => _ProfilCaissierScreenState();
}

class _ProfilCaissierScreenState extends State<ProfilCaissierScreen> {
  static const String _articleFilterPrefKey = 'pref_article_filter_with_stock';
  bool _articleFilterWithStock = true; // Par défaut: articles avec stock
  String _currencyCode = AppCurrencyPreference.defaultCode;
  String _tauxActuel = '1'; // show 1 by default until we fetch real rate
  String _nomDevise = '';
  List<dynamic> _devises = [];
  bool _isLoadingDevises = false;

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

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadDevises();
    locator.syncService.addListener(_handleSyncStateChanged);
  }

  @override
  void dispose() {
    locator.syncService.removeListener(_handleSyncStateChanged);
    super.dispose();
  }

  void _handleSyncStateChanged() {
    if (mounted) setState(() {});
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
      final savedArticleFilter = locator.databaseService.get<bool>(
        _articleFilterPrefKey,
      );
      final savedCurrency = AppCurrencyPreference.readCode(
        locator.databaseService,
      );
      if (!mounted) return;
      setState(() {
        _articleFilterWithStock =
            savedArticleFilter ?? true; // Par défaut: articles avec stock
        _currencyCode = savedCurrency;
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
        _articleFilterWithStock = true; // Par défaut: articles avec stock
        _currencyCode = AppCurrencyPreference.defaultCode;
      });
      // rate info will update when devises are loaded later (see above)
    }
  }

  Future<void> _setArticleFilterWithStock(bool value) async {
    setState(() {
      _articleFilterWithStock = value;
    });
    try {
      await locator.databaseService.save<bool>(_articleFilterPrefKey, value);
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

  // -------------------------------------------------------------------------
  // Interface
  // -------------------------------------------------------------------------

  /// Libellé de la devise choisie (nom renvoyé par l'API si disponible).
  String get _currencyLabel {
    for (final item in _buildCurrencyItems()) {
      if (item.value == _currencyCode && item.child is Text) {
        return (item.child as Text).data ?? _currencyCode;
      }
    }
    return AppCurrencyPreference.displayNameFor(_currencyCode);
  }

  String get _receiptSummary {
    final db = locator.databaseService;
    final paper = ReceiptPaperPreference.read(db);
    final copies = ReceiptPrintFlow.defaultCopies();
    String logo = '';
    String footer = '';
    try {
      logo = db.get<String>(ReceiptBranding.logoPrefKey) ?? '';
      footer = db.get<String>(ReceiptBranding.footerPrefKey) ?? '';
    } catch (_) {}
    final hasLogo = logo.isNotEmpty && io.File(logo).existsSync();
    return [
      paper.label,
      '$copies ${copies > 1 ? 'copies' : 'copie'}',
      hasLogo ? 'logo' : 'sans logo',
      if (footer.trim().isNotEmpty) 'message',
    ].join(' · ');
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }

  Future<void> _openCurrencyPicker() async {
    final items = _buildCurrencyItems();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune devise disponible pour ce site')),
      );
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: PosColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Text(
                'Devise d\'affichage',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: PosColors.ink,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Utilisée pour la facturation, les calculs et la comptabilité.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: PosColors.muted,
                ),
              ),
            ),
            for (final item in items)
              ListTile(
                title: item.child,
                trailing: item.value == _currencyCode
                    ? const Icon(Icons.check_circle, color: PosColors.green)
                    : null,
                onTap: () => Navigator.pop(ctx, item.value),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null && selected != _currencyCode) {
      await _setCurrencyCode(selected);
    }
  }

  Future<void> _syncNow() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await locator.syncService.syncNow();
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.remaining == 0 && result.synced == 0 && result.failed == 0
              ? (locator.syncService.isOnline
                    ? 'Aucune donnée à synchroniser'
                    : 'Synchronisation impossible hors ligne')
              : result.failed == 0
              ? '${result.synced} vente(s) synchronisée(s)'
              : '${result.synced} synchronisée(s), ${result.failed} échec(s), ${result.remaining} restante(s)',
        ),
      ),
    );
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    // Profil ou réglages de reçu éventuellement modifiés.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = locator.authRepository.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Aucune donnée utilisateur disponible')),
      );
    }

    final online = locator.syncService.isOnline;
    final pending = locator.syncService.pendingCount;
    final syncLabel = !online
        ? 'Hors ligne · reprise automatique au retour du réseau'
        : (pending > 0
              ? '$pending vente(s) en attente de synchronisation'
              : 'À jour · aucune vente en attente');
    final rate = _currencyCode == AppCurrencyPreference.usdCode
        ? ''
        : ' · 1 USD = $_tauxActuel CDF${_nomDevise.isNotEmpty ? ' ($_nomDevise)' : ''}';

    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Text(
              'Profil',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: PosColors.ink,
              ),
            ),
            const SizedBox(height: 14),
            _IdentityCard(
              initials: _initials(user.nomComplet),
              name: user.nomComplet,
              line1: [
                user.role,
                user.nomSite,
              ].where((v) => v.trim().isNotEmpty).join(' · '),
              line2: user.nomSociete,
              onEdit: () => _push(const EditProfileScreen()),
            ),
            const SizedBox(height: 18),
            SettingsSection(
              title: 'Compte',
              children: [
                SettingsTile(
                  icon: Icons.person_outline,
                  title: 'Mes informations',
                  subtitle: 'Coordonnées, site et société',
                  onTap: () => _push(const ProfilInfosScreen()),
                ),
                SettingsTile(
                  icon: Icons.lock_outline,
                  title: 'Mot de passe',
                  subtitle: 'Modifier votre mot de passe',
                  onTap: () => _push(const ChangePasswordScreen()),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SettingsSection(
              title: 'Caisse',
              children: [
                SettingsTile(
                  icon: Icons.inventory_2_outlined,
                  title: 'Catalogue par défaut',
                  subtitle: 'Filtre affiché à l\'ouverture de la vente',
                  below: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Produits')),
                      ButtonSegment(value: false, label: Text('Services')),
                    ],
                    selected: {_articleFilterWithStock},
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                    onSelectionChanged: (s) =>
                        _setArticleFilterWithStock(s.first),
                  ),
                ),
                SettingsTile(
                  icon: Icons.currency_exchange,
                  title: 'Devise d\'affichage',
                  subtitle: _isLoadingDevises
                      ? 'Chargement…'
                      : '$_currencyLabel$rate',
                  onTap: _isLoadingDevises ? null : _openCurrencyPicker,
                ),
              ],
            ),
            const SizedBox(height: 18),
            SettingsSection(
              title: 'Reçus',
              children: [
                SettingsTile(
                  icon: Icons.print_outlined,
                  title: 'Reçus & impression',
                  subtitle: _receiptSummary,
                  onTap: () => _push(const RecusSettingsScreen()),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SettingsSection(
              title: 'Données',
              children: [
                SettingsTile(
                  icon: online ? Icons.sync : Icons.cloud_off_outlined,
                  title: 'Synchronisation',
                  subtitle: syncLabel,
                  subtitleColor: online && pending == 0
                      ? PosColors.green
                      : PosColors.amber,
                  trailing: OutlinedButton(
                    onPressed: _syncNow,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PosColors.green,
                      side: const BorderSide(color: PosColors.green),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Synchroniser'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => _handleLogout(context),
                icon: const Icon(Icons.logout),
                label: const Text('Se déconnecter'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: PosColors.terracotta,
                  backgroundColor: PosColors.surface,
                  side: const BorderSide(color: PosColors.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Mombongo · développé par Kansa Business',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 11, color: PosColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: PosColors.terracotta,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await locator.authRepository.logout();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.initials,
    required this.name,
    required this.line1,
    required this.line2,
    required this.onEdit,
  });

  final String initials;
  final String name;
  final String line1;
  final String line2;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PosColors.ink,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: PosColors.green,
            child: Text(
              initials,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (line1.isNotEmpty)
                  Text(
                    line1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: PosColors.onInkMuted,
                    ),
                  ),
                if (line2.isNotEmpty)
                  Text(
                    line2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: PosColors.onInkMuted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onEdit,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Modifier'),
          ),
        ],
      ),
    );
  }
}
