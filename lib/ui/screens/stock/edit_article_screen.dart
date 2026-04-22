import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/services/app_currency_preference.dart';
import 'package:mombongo/models/article_update_request.dart';

class EditArticleScreen extends StatefulWidget {
  /// Objet article complet passé depuis la liste des produits
  final Map<String, dynamic>? article;

  /// [article] peut être utilisé directement pour éviter un appel API supplémentaire.
  /// Les autres informations (stock, ids) seront extraites de cet objet.
  const EditArticleScreen({
    super.key,
    this.article,
  });

  @override
  State<EditArticleScreen> createState() => _EditArticleScreenState();
}

class _EditArticleScreenState extends State<EditArticleScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isFetching = false; // retrieving details from API
  String? _errorMessage;
  String? _successMessage;

  // Variables pour les champs du formulaire
  late int idArticle;
  late String libelle;
  late double tva;
  late int idSociete;
  late bool perissable;
  late bool withStock;
  late int idDevise;

  // valeurs liées au stock (non modifiables par l'utilisateur)
  late int idStock;
  late int idSite;
  late double remise;
  late double quantiteInitial;
  late double prixAchat;
  late double prixVenteHT;
  late double seuilAlerte;

  @override
  void initState() {
    super.initState();

    // Extraire les valeurs de l'objet article s'il est fourni
    if (widget.article != null) {
      final data = widget.article!;
      idArticle = _parseInt(data['idArticle']);
      libelle = data['libelle']?.toString() ?? '';
      tva = _parseDouble(data['tva']);
      idStock = _parseInt(data['idStock']);
      idSite = _parseInt(data['idSite']);
      remise = _parseDouble(data['remise']);
      quantiteInitial = _parseDouble(data['quantiteStock']);
      prixAchat = _parseDouble(data['prixAchat']);
      prixVenteHT = _parseDouble(data['prixVentHT']);
      seuilAlerte = _parseDouble(data['seuilAlerte']);
      perissable = data['perissable'] == true || data['perissable'] == 'true';
      withStock = data['withStock'] == true || data['withStock'] == 'true';
    } else {
      // Valeurs par défaut si aucun article fourni
      idArticle = 0;
      libelle = '';
      tva = 0.0;
      idStock = 0;
      idSite = 0;
      remise = 0.0;
      quantiteInitial = 0.0;
      prixAchat = 0.0;
      prixVenteHT = 0.0;
      seuilAlerte = 0.0;
      perissable = false;
      withStock = true;
    }

    if (idArticle <= 0) {
      // erreur de construction, on avertit l'utilisateur localement
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ID d\'article invalide'),
            backgroundColor: Colors.red,
          ),
        );
      });
    }

    // les autres valeurs (ids et stock) sont déjà extraites de l'article
    // pas besoin de charger depuis l'API

    // Récupérer idSociete depuis l'utilisateur connecté
    final currentUser = locator.authRepository.currentUser;
    if (currentUser != null) {
      idSociete = int.tryParse(currentUser.idSociete) ?? 0;
    } else {
      idSociete = 0;
    }

    // Récupérer idDevise depuis les préférences ou l'API
    _loadIdDevise();
  }


  Future<void> _loadIdDevise() async {
    // Pour l'instant, on utilise une valeur par défaut
    // Cette méthode peut être améliorée pour récupérer depuis l'API
    setState(() {
      idDevise = 1;
    });
  }

  /// Charge les informations détaillées de la ligne de stock/article
  /// en interrogeant l'API à partir de `idArticle` (et `idSite` de
  /// l'utilisateur).  Les champs `idStock`, `idSite`, `remise`, etc.
  /// sont remplis ici et serviront pour la requête de mise à jour.
  Future<void> _loadArticleDetails() async {
    setState(() {
      _isFetching = true;
      _isLoading = false; // ensure submit flag cleared
    });
    try {
      final currentUser = locator.authRepository.currentUser;
      if (currentUser == null) throw Exception('Utilisateur non connecté');

      final siteId = int.tryParse(currentUser.idSite) ?? 0;
      if (siteId == 0) throw Exception('ID du site invalide');

      // récupérer l'enregistrement correspondant
      final result = await locator.apiService.getStockArticles(
        idSite: siteId,
        idArticle: idArticle,
        pageSize: 1,
      );

      if (result.isNotEmpty) {
        final data = result.first as Map<String, dynamic>;
        idStock = _parseInt(data['idStock']);
        idSite = _parseInt(data['idSite']);
        remise = _parseDouble(data['remise']);
        quantiteInitial = _parseDouble(data['quantiteInitial']);
        prixAchat = _parseDouble(data['prixAchat']);
        prixVenteHT = _parseDouble(data['prixVenteHT']);
        seuilAlerte = _parseDouble(data['seuilAlerte']);

        // si l'API retourne aussi un libellé ou tva différents
        libelle = data['libelle'] ?? libelle;
        tva = _parseDouble(data['tva']);
      } else {
        debugPrint('Aucun détail trouvé pour idArticle=$idArticle');
      }
    } catch (e) {
      debugPrint('Erreur chargement détails article: $e');
      // laisser les valeurs par défaut issues du widget.article
    } finally {
      if (mounted) {
        setState(() {
        _isFetching = false;
      });
      }
    }
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  String _getCurrencySymbol() {
    final code = AppCurrencyPreference.readCode(locator.databaseService);
    return AppCurrencyPreference.symbolFor(code);
  }

  String _formatCurrency(double amount) {
    final code = AppCurrencyPreference.readCode(locator.databaseService);
    final formatter = AppCurrencyPreference.formatterFor(code);
    final symbol = AppCurrencyPreference.symbolFor(code);
    return '${formatter.format(amount)} $symbol';
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  // Helper pour décorer uniformément les champs
  InputDecoration _buildInputDecoration(String label, IconData icon, {String? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.secondary),
      suffixText: suffix,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    );
  }

  // Widget helper pour les titres de section
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8, top: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Modifier l\'Article'),
        centerTitle: true,
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
      ),
      body: _isFetching
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                // Message de succès
                if (_successMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: TextStyle(color: Colors.green.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Message d'erreur
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),

                // SECTION 1 : Informations de base
                _buildSectionTitle('Informations de base'),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // Libellé (Nom de l'article)
                        TextFormField(
                          initialValue: libelle,
                          decoration: _buildInputDecoration('Nom de l\'article *', Icons.shopping_bag),
                          validator: (value) => (value == null || value.isEmpty)
                              ? 'Veuillez saisir le nom de l\'article'
                              : null,
                          onSaved: (value) => libelle = value ?? '',
                        ),
                        // ID Article - caché pour l'utilisateur
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // SECTION 2 : TVA et Devise
                _buildSectionTitle('TVA et Devise'),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: tva.toString(),
                                decoration: _buildInputDecoration('TVA', Icons.percent, suffix: '%'),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d+[\.,]?\d*')),
                                ],
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'TVA requise';
                                  }
                                  final parsed = double.tryParse(value.replaceAll(',', '.'));
                                  if (parsed == null || parsed < 0) {
                                    return 'Valeur invalide';
                                  }
                                  return null;
                                },
                                onSaved: (value) {
                                  tva = double.tryParse(value?.replaceAll(',', '.') ?? '0') ?? 0;
                                },
                              ),
                            ),
                            // ID Devise - caché pour l'utilisateur
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // SECTION 3 : Stock & Prix
                _buildSectionTitle('Stock & Prix'),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // Quantité initiale
                        TextFormField(
                          initialValue: quantiteInitial.toStringAsFixed(0),
                          decoration: _buildInputDecoration('Quantité initiale', Icons.inventory),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Quantité requise';
                            final parsed = double.tryParse(value);
                            if (parsed == null || parsed < 0) return 'Valeur invalide';
                            return null;
                          },
                          onSaved: (value) {
                            quantiteInitial = double.tryParse(value ?? '') ?? 0;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Prix d'achat
                        TextFormField(
                          initialValue: prixAchat.toString(),
                          decoration: _buildInputDecoration(
                              'Prix d\'achat', Icons.shopping_bag,
                              suffix: _getCurrencySymbol()),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Prix requis';
                            final parsed = double.tryParse(value.replaceAll(',', '.'));
                            if (parsed == null || parsed < 0) return 'Valeur invalide';
                            return null;
                          },
                          onSaved: (value) {
                            prixAchat = double.tryParse(value?.replaceAll(',', '.') ?? '') ?? 0;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Prix de vente HT
                        TextFormField(
                          initialValue: prixVenteHT.toString(),
                          decoration: _buildInputDecoration(
                              'Prix de vente HT', Icons.receipt,
                              suffix: _getCurrencySymbol()),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Prix requis';
                            final parsed = double.tryParse(value.replaceAll(',', '.'));
                            if (parsed == null || parsed < 0) return 'Valeur invalide';
                            return null;
                          },
                          onSaved: (value) {
                            prixVenteHT = double.tryParse(value?.replaceAll(',', '.') ?? '') ?? 0;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Seuil d'alerte
                        TextFormField(
                          initialValue: seuilAlerte.toStringAsFixed(0),
                          decoration: _buildInputDecoration('Seuil d\'alerte', Icons.warning),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Seuil requis';
                            final parsed = double.tryParse(value);
                            if (parsed == null || parsed < 0) return 'Valeur invalide';
                            return null;
                          },
                          onSaved: (value) {
                            seuilAlerte = double.tryParse(value ?? '') ?? 0;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Remise
                        TextFormField(
                          initialValue: remise.toString(),
                          decoration: _buildInputDecoration('Remise (%)', Icons.discount, suffix: '%'),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value == null || value.isEmpty) return null;
                            final parsed = double.tryParse(value.replaceAll(',', '.'));
                            if (parsed == null || parsed < 0) return 'Valeur invalide';
                            return null;
                          },
                          onSaved: (value) {
                            remise = double.tryParse(value?.replaceAll(',', '.') ?? '') ?? 0;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // SECTION 4 : Boutons d'action
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Gérer cet article en stock', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Activez pour suivre les quantités'),
                        value: withStock,
                        activeColor: Theme.of(context).colorScheme.tertiary,
                        onChanged: (bool value) {
                          setState(() => withStock = value);
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Article périssable', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Gérer les dates d\'expiration'),
                        value: perissable,
                        activeColor: Theme.of(context).colorScheme.tertiary,
                        onChanged: (bool value) {
                          setState(() => perissable = value);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // SECTION 4 : Boutons d'action
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: Color(0xFF2C3E50), width: 2),
                        ),
                        child: const Text(
                          'ANNULER',
                          style: TextStyle(fontSize: 14, color: Color(0xFF2C3E50), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updateArticle,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.tertiary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'ENREGISTRER',
                                style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Bouton de suppression
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : () => _confirmDeleteArticle(),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Supprimer l\'article'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateArticle() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _formKey.currentState!.save();

    debugPrint('=== DEBUG SUBMIT ===');
    debugPrint('libelle after save: "$libelle"');
    debugPrint('idStock: $idStock, idSite: $idSite, idArticle: $idArticle');

    // Vérifier que le libellé n'est pas vide
    if (libelle.isEmpty) {
      setState(() {
        _errorMessage = 'Le libellé de l\'article est requis';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le libellé de l\'article est requis'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final currentUser = locator.authRepository.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Construire l'objet de mise à jour complet
      final request = ArticleUpdateRequest(
        idStock: idStock,
        idSite: idSite,
        idArticle: idArticle,
        libelle: libelle,
        tva: tva,
        perissable: perissable,
        remise: remise,
        withStock: withStock,
        quantiteInitial: quantiteInitial,
        prixAchat: prixAchat,
        prixVenteHT: prixVenteHT,
        seuilAlerte: seuilAlerte.toInt(),
      );

      debugPrint('Requête envoyée à l\'API: ${request.toJson()}');

      // Appel API pour mettre à jour l'article/stock
      await locator.apiService.updateArticleByStockSiteArticle(request, idDevise: idDevise);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _successMessage = 'Article modifié avec succès';
      });

      // Afficher un message de succès et retourner à la liste
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Article modifié avec succès'),
          backgroundColor: Colors.green,
        ),
      );

      // Retourner à l'écran précédent avec indication de succès
      Navigator.of(context).pop(true);
      
    } catch (e) {
      debugPrint('Erreur lors de la modification de l\'article: $e');
      
      // Extraire un message d'erreur plus lisible
      String errorMessage = 'Une erreur est survenue';
      
      if (e.toString().contains('Libelle')) {
        errorMessage = 'Le champ "Libellé" est requis';
      } else if (e.toString().contains('400')) {
        errorMessage = 'Erreur de validation: vérifiez les champs obligatoires';
      } else if (e.toString().contains('500')) {
        errorMessage = 'Erreur serveur. Veuillez réessayer plus tard';
      } else if (e.toString().contains('network') || e.toString().contains('SocketException')) {
        errorMessage = 'Erreur de connexion. Vérifiez votre connexion internet';
      } else {
        // Nettoyer le message d'erreur
        errorMessage = e.toString().replaceAll('ApiException:', '').trim();
      }
      
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = errorMessage;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmDeleteArticle() async {
    // Afficher une boîte de dialogue de confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: Text('Êtes-vous sûr de vouloir supprimer l\'article "$libelle" ? Cette action est irréversible.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ANNULER'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('SUPPRIMER'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteArticle();
    }
  }

  Future<void> _deleteArticle() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Appel API pour supprimer l'article
      await locator.apiService.deleteArticle(idArticle);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Article supprimé avec succès'),
          backgroundColor: Colors.green,
        ),
      );

      // Retourner à l'écran précédent avec indication de suppression
      Navigator.of(context).pop('deleted');
      
    } catch (e) {
      debugPrint('Erreur lors de la suppression de l\'article: $e');
      
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
