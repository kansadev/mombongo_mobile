import 'package:flutter/material.dart';
import 'package:mombongo/models/devise_model.dart';
import 'package:mombongo/models/taux.dart';
import 'package:mombongo/ui/screens/caissier/change_password_screen.dart';
import 'package:mombongo/ui/screens/edit_profile_screen.dart';
import 'package:mombongo/ui/screens/gestionnaire/devise_list_screen.dart';
import '../../services/app_currency_preference.dart';
import '../../services/service_locator.dart';

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  String _currencyCode = AppCurrencyPreference.defaultCode;
  String _tauxActuel = '2850.50';
  String _nomDevise = 'Dollar Americain';
  List<dynamic> _devises = [];
  bool _isLoadingDevises = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadDevises();
  }

  Future<void> _loadPreferences() async {
    // previously we read the currency from the user object; this value is now
    // stored exclusively in the preference service
    _currencyCode = AppCurrencyPreference.readCode(locator.databaseService);
    _loadTaux();
  }

  Future<void> _loadDevises() async {
    final currentUser = locator.authRepository.currentUser;
    if (currentUser == null) return;

    setState(() {
      _devises = [];
      _isLoadingDevises = true;
    });

    try {
      final idSite = int.tryParse(currentUser.idSite) ?? 0;
      if (idSite > 0) {
        final response = await locator.apiService.getDevisesBySite(idSite, actives: true);
        if (mounted) {
          setState(() {
            _devises = response.devises;
            _isLoadingDevises = false;
          });
        // rate may have changed if the selected currency is in the new list
        _loadTaux();
        }
      } else {
        final idSociete = int.tryParse(currentUser.idSociete) ?? 0;
        if (idSociete > 0) {
          final devises = await locator.apiService.getDevisesBySociete(idSociete, true);
          if (mounted) {
            setState(() {
              // we no longer maintain a fallback list from the user; just
              // display whatever the API returned (possibly empty).
              _devises = devises;
              _isLoadingDevises = false;
            });
            // update rate if selection matches an entry
            _loadTaux();
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

  // the merge helper is no longer required since we no longer keep an
  // initial list coming from the user object.  It can be removed or
  // repurposed later if we ever need to merge another source, but for now
  // it's not used.
  //
  // List<dynamic> _mergeDevises(List<dynamic> first, List<dynamic> second) {
  //   final seen = <String>{};
  //   final merged = <dynamic>[];
  //
  //   void addList(List<dynamic> list) {
  //     for (final item in list) {
  //       if (item is! Map) continue;
  //       final code = item['code']?.toString().trim().toUpperCase() ?? '';
  //       if (code.isEmpty || seen.contains(code)) continue;
  //       seen.add(code);
  //       merged.add(item);
  //     }
  //   }
  //
  //   addList(first);
  //   addList(second);
  //   return merged;
  // }

  Future<void> _loadTaux() async {
    try {
      // the current exchange rate is carried by the selected currency object
      // returned from the API, so we look for the matching entry in our
      // cached list rather than fetching it separately from the TauxService.
      dynamic found;
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
      if (found is Map) {
        setState(() {
          _tauxActuel = found['tauxActuel']?.toString() ?? _tauxActuel;
          _nomDevise = found['nom']?.toString() ?? _nomDevise;
        });
      } else if (found is Devise) {
        setState(() {
          _tauxActuel = found.tauxActuel;
          _nomDevise = found.nom;
        });
      }
      // we still leave the TauxService in charge of broadcasting changes when
      // the user actually chooses a new currency; callers can rely on it if
      // needed elsewhere.
    } catch (e, st) {
      // log error so crash is easier to diagnose
      debugPrint('[_loadTaux] failed: $e\n$st');
    }
  }

  Future<void> _setCurrencyCode(String value) async {
    final normalized = AppCurrencyPreference.normalizeCode(value);
    
    // Trouver la devise selectionnee pour obtenir son taux et son nom
    String? selectedNomDevise;
    String? selectedTauxActuel;
    String? selectedSymbole;
    
    for (final devise in _devises) {
      if (devise is! Map) continue;
      final code = devise['code']?.toString().trim().toUpperCase();
      if (code == normalized) {
        selectedNomDevise = devise['nom']?.toString().trim();
        selectedTauxActuel = devise['tauxActuel']?.toString();
        selectedSymbole = devise['symbole']?.toString().trim();
        break;
      }
    }
    
    setState(() {
      _currencyCode = normalized;
      if (selectedTauxActuel != null) {
        _tauxActuel = selectedTauxActuel;
      }
      if (selectedNomDevise != null) {
        _nomDevise = selectedNomDevise;
      }
    });
    
    try {
      await AppCurrencyPreference.saveCode(locator.databaseService, normalized);
      // also update the global TauxService so other screens see the change
      final taux = Taux(
        codeDevise: normalized,
        nomDevise: selectedNomDevise ?? '',
        symboleDevise: selectedSymbole ?? '',
        tauxActuel: selectedTauxActuel ?? '0',
      );
      await locator.tauxService.sauvegarderTaux(taux);
    } catch (_) {}
  }

  List<DropdownMenuItem<String>> _buildCurrencyItems() {
    if (_isLoadingDevises) {
      return const [];
    }

    if (_devises.isEmpty) {
      // API returned no devises and we had none from the user either –
      // just show an empty dropdown.  Consumers of this method should handle
      // the absence of items themselves (e.g. display a message or disable
      // the field).
      return const [];
    }

    final seenCodes = <String>{};
    final items = <DropdownMenuItem<String>>[];

    for (final devise in _devises) {
      String code = '';
      String? nom;
      String symbole = '';

      if (devise is Map) {
        code = devise['code']?.toString().trim().toUpperCase() ?? '';
        nom = devise['nom']?.toString().trim();
        symbole = devise['symbole']?.toString().trim() ?? '';
      } else if (devise is Devise) {
        code = devise.code.trim().toUpperCase();
        nom = devise.nom;
        symbole = devise.symbole ?? '';
      }

      if (code.isEmpty || !seenCodes.add(code)) continue;

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
  Widget build(BuildContext context) {
    final user = locator.authRepository.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Utilisateur'),
        backgroundColor: const Color(0xFF212E53),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (String value) {
              switch (value) {
                case 'edit_profile':
                  _showEditProfileDialog(context);
                  break;
                case 'change_password':
                  _openChangePasswordPage(context);
                  break;
                case 'change_photo':
                  _showChangePhotoDialog(context);
                  break;
                case 'about':
                  _showAboutDialog(context);
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'edit_profile',
                child: Row(
                  children: [
                    Icon(
                      Icons.edit,
                      size: 20,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    SizedBox(width: 12),
                    Text('Modifier le profil'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'change_password',
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    SizedBox(width: 12),
                    Text('Changer le mot de passe'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'change_photo',
                child: Row(
                  children: [
                    Icon(
                      Icons.photo_camera,
                      size: 20,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    SizedBox(width: 12),
                    Text('Changer la photo'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'about',
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    SizedBox(width: 12),
                    Text('A propos'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile picture/avatar
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[300],
                child: Text(
                  user != null ? _getUserInitials(user.nomComplet) : '??',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF212E53),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // User information
              if (user != null) ...[
                _buildInfoTile('Nom complet', user.nomComplet),
                const SizedBox(height: 16),
                _buildInfoTile('Email/Login', user.login),
                const SizedBox(height: 16),
                _buildInfoTile('Role', user.role),
                const SizedBox(height: 16),
                _buildInfoTile('Telephone', user.numeroTelephone),
                const SizedBox(height: 16),
                _buildInfoTile('Site', user.nomSite),
                const SizedBox(height: 16),
                _buildInfoTile('Societe', user.nomSociete),
              ] else ...[
                const Text('Informations utilisateur indisponibles'),
              ],

              const SizedBox(height: 24),

              _buildCurrencyPreferenceCard(),

              const SizedBox(height: 24),

              // Change password button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _openChangePasswordPage(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF212E53),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Changer le mot de passe'),
                ),
              ),

              const SizedBox(height: 16),

              // Logout button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    await locator.authRepository.logout();
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/login',
                        (route) => false,
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Deconnexion'),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // Extract initials from user's full name
  String _getUserInitials(String fullName) {
    if (fullName.isEmpty) return '??';

    final names = fullName.trim().split(' ');
    if (names.length >= 2) {
      // Take first letter of first name and first letter of last name
      return '${names[0][0].toUpperCase()}${names[names.length - 1][0].toUpperCase()}';
    } else if (names.isNotEmpty) {
      // Take first two letters of the single name
      final name = names[0];
      if (name.length >= 2) {
        return '${name[0].toUpperCase()}${name[1].toUpperCase()}';
      } else {
        return name.toUpperCase();
      }
    }
    return '??';
  }

  Widget _buildInfoTile(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyPreferenceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preferences',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            // only keep the current value if it's present in the returned
            // item list; otherwise let the field start with null which avoids
            // the assertion crash.
            initialValue: () {
              final items = _buildCurrencyItems();
              return items.any((i) => i.value == _currencyCode)
                  ? _currencyCode
                  : null;
            }(),
            decoration: const InputDecoration(
              labelText: 'Devise',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.payments_outlined),
            ),
            items: _buildCurrencyItems(),
            onChanged: _isLoadingDevises
                ? null
                : (value) {
                    if (value == null) return;
                    _setCurrencyCode(value);
                  },
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Taux de change actuel',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      Text(
                        // keep USD on left side; rate always refers to 1 USD
                        // in CDF. changing the dropdown doesn't alter the base.
                        '1 USD = $_tauxActuel CDF ($_nomDevise)',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF212E53),
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
            'Cette devise sera utilisee pour la facturation, les calculs et la comptabilite.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              final currentUser = locator.authRepository.currentUser;
              if (currentUser != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DeviseListScreen(
                      idSite: int.tryParse(currentUser.idSite) ?? 0,
                      siteName: currentUser.nomSite,
                    ),
                  ),
                );
              }
            },
            child: const Text("Configurer la devise ou le taux de change")
          )
        ],
      ),
    );
  }

  void _openChangePasswordPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
    );
  }

  // Page dediee pour modifier le profil
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

  // Dialog pour changer la photo
  Future<void> _showChangePhotoDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Changer la photo de profil'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choisissez une option :'),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Prendre une photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Fonctionnalite en cours de developpement',
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choisir depuis la galerie'),
                onTap: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Fonctionnalite en cours de developpement',
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Annuler'),
            ),
          ],
        );
      },
    );
  }

  // Dialog a propos
  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('A propos'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mombongo',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF212E53),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Version 1.0.0'),
              const SizedBox(height: 16),
              const Text(
                'Application de gestion de ventes et de stocks',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                '© 2026 Mombongo',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }
}
