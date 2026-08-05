import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mombongo/services/app_currency_preference.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/models/article_update_request.dart';
import 'package:mombongo/ui/screens/stock/update_stock_screen.dart';

class UpdateArticleScreen extends StatefulWidget {
  const UpdateArticleScreen({super.key});

  @override
  State<UpdateArticleScreen> createState() => _UpdateArticleScreenState();
}

class _UpdateArticleScreenState extends State<UpdateArticleScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _stocks = [];
  String _searchQuery = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStocks();
  }

  Future<void> _loadStocks() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentUser = locator.authRepository.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      final userRole = currentUser.role.toUpperCase();
      List<Map<String, dynamic>> stocks;

      if (userRole == 'ADMIN' || userRole == 'ADMINISTRATEUR') {
        // Admin : site opérationnel (bascule profil)
        final idSite = int.tryParse(currentUser.idSite) ?? 0;
        if (idSite == 0) throw Exception('ID site invalide — choisissez un site dans le profil');

        final result = await locator.apiService.getStockArticles(
          idSite: idSite,
        );
        stocks = result.cast<Map<String, dynamic>>();
      } else if (userRole == 'GESTIONNAIRE') {
        final idSite = int.tryParse(currentUser.idSite) ?? 0;
        if (idSite == 0) throw Exception('ID site invalide');

        final result = await locator.apiService.getStockArticles(
          idSite: idSite,
        );
        stocks = result.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Rôle non autorisé pour cette action');
      }

      if (!mounted) return;

      setState(() {
        _stocks = stocks;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement des stocks: $e');
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredStocks {
    if (_searchQuery.isEmpty) return _stocks;

    final query = _searchQuery.toLowerCase();
    return _stocks.where((stock) {
      final libelle = (stock['libelle'] ?? '').toString().toLowerCase();
      final codeBarre = (stock['codeBarreQR'] ?? '').toString().toLowerCase();
      return libelle.contains(query) || codeBarre.contains(query);
    }).toList();
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

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  String _formatCurrency(double amount) {
    final code = AppCurrencyPreference.readCode(locator.databaseService);
    final formatter = AppCurrencyPreference.formatterFor(code);
    final symbol = AppCurrencyPreference.symbolFor(code);
    return '${formatter.format(amount)} $symbol';
  }

  void _showUpdateStockBottomSheet(Map<String, dynamic> stock) {
    final quantiteController = TextEditingController();
    final prixAchatController = TextEditingController();
    final prixVenteController = TextEditingController();
    final numeroLotController = TextEditingController(text: stock['numeroLot']?.toString() ?? '');
    final commentairePeremptionController = TextEditingController(text: stock['commentairePeremption']?.toString() ?? '');

    DateTime? selectedDateExpiration;
    if (stock['dateExpiration'] != null) {
      selectedDateExpiration = DateTime.tryParse(stock['dateExpiration'].toString());
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (BuildContext context) {
        bool isUpdating = false;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête avec titre et bouton fermer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'CONFIRMER L\'ARTICLE',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Nom de l'article
                    Text(
                      stock['libelle'] ?? 'Article',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Informations actuelles
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Informations actuelles',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Numéro de lot : ${stock['numeroLot'] ?? 'Non défini'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            'Date d\'expiration : ${stock['dateExpiration'] != null ? (() {
                              final date = DateTime.tryParse(stock['dateExpiration'].toString());
                              return date != null ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}' : 'Non définie';
                            })() : 'Non définie'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            'Commentaire : ${stock['commentairePeremption'] ?? 'Aucun'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Champs de formulaire
                    // Quantité
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Quantité actuelle',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _parseDouble(
                                  stock['quantiteStock'],
                                ).toInt().toString(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Nouvelle quantité
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Nouvelle quantité',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: quantiteController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.blue,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Prix d'achat
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Prix d\'achat actuel',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _formatCurrency(
                                  _parseDouble(stock['prixAchat']),
                                ),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 16),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Nouveau prix d\'achat',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: prixAchatController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.green.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.green.shade200,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.green.shade200,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Prix de vente
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Prix de vente actuel',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _formatCurrency(
                                  _parseDouble(stock['prixVentHT']),
                                ),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 16),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Nouveau prix de vente',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: prixVenteController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.orange.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.orange.shade200,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.orange.shade200,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Numéro de lot
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Numéro de lot',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: numeroLotController,
                          style: const TextStyle(
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Colors.blue,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Date d'expiration
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Date d\'expiration',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: selectedDateExpiration ?? DateTime.now().add(const Duration(days: 30)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 3650)),
                            );
                            if (date != null) {
                              setModalState(() {
                                selectedDateExpiration = date;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text(
                                  selectedDateExpiration != null
                                      ? '${selectedDateExpiration!.day.toString().padLeft(2, '0')}/${selectedDateExpiration!.month.toString().padLeft(2, '0')}/${selectedDateExpiration!.year}'
                                      : 'Sélectionner une date',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: selectedDateExpiration != null ? Colors.black87 : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Commentaire péremption
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Commentaire péremption',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: commentairePeremptionController,
                          maxLines: 2,
                          style: const TextStyle(
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Colors.blue,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Boutons d'action
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isUpdating
                                ? null
                                : () => Navigator.pop(context),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text(
                              'ANNULER',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isUpdating
                                ? null
                                : () async {
                                    // Marquer comme en cours de mise à jour
                                    setModalState(() {
                                      isUpdating = true;
                                    });
                                    // Validation des champs
                                    if (quantiteController.text.isEmpty ||
                                        prixAchatController.text.isEmpty ||
                                        prixVenteController.text.isEmpty) {
                                      setModalState(() {
                                        isUpdating = false;
                                      });
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Veuillez remplir tous les champs',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }

                                    try {
                                      final idStock = _parseInt(
                                        stock['idStock'],
                                      );
                                      final newQuantite =
                                          double.tryParse(
                                            quantiteController.text,
                                          ) ??
                                          0.0;
                                      final newPrixAchat =
                                          double.tryParse(
                                            prixAchatController.text,
                                          ) ??
                                          0.0;
                                      final newPrixVente =
                                          double.tryParse(
                                            prixVenteController.text,
                                          ) ??
                                          0.0;

                                      // Validation des valeurs
                                      if (newQuantite < 0 ||
                                          newPrixAchat < 0 ||
                                          newPrixVente < 0) {
                                        setModalState(() {
                                          isUpdating = false;
                                        });
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Les valeurs ne peuvent pas être négatives',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        return;
                                      }

                                      // les données seront encapsulées dans un
                                      // ArticleUpdateRequest, construit ci‑dessous.


                                      // create a typed request object that matches
                                      // the backend interface.  IDs are sourced from the
                                      // existing `stock` map, so the user never sees or
                                      // types them – they are filled automatically.
                                      final request = ArticleUpdateRequest(
                                        idStock: _parseInt(stock['idStock']),
                                        idSite: _parseInt(stock['idSite']),
                                        idArticle: _parseInt(stock['idArticle']),
                                        libelle: stock['libelle']?.toString() ?? '',
                                        tva: _parseDouble(stock['tva'] ?? 0),
                                        perissable: stock['perissable'] == true || stock['perissable'] == 'true',
                                        remise: _parseDouble(stock['remise'] ?? 0),
                                        withStock: stock['withStock'] == true || stock['withStock'] == 'true',
                                        quantiteInitial: newQuantite,
                                        prixAchat: newPrixAchat,
                                        prixVenteHT: newPrixVente,
                                        seuilAlerte: _parseInt(stock['seuilAlerte']),
                                      );

                                      if (kDebugMode) {
                                        print('=== UPDATE STOCK (UPDATE_ARTICLE_SCREEN) ===');
                                        print('Request: ${request.toJson()}');
                                      }

                                      // Appeler l'API pour mise à jour du stock
                                      await locator.apiService.updateStock(
                                        idStock,
                                        request.toJson(),
                                      );


                                      if (!mounted) return;

                                      Navigator.pop(context);

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${stock['libelle']} mis à jour avec succès',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );

                                      // Recharger les données
                                      await _loadStocks();
                                    } catch (e) {
                                      if (kDebugMode) {
                                        print('=== UPDATE STOCK ERROR ===');
                                        print(
                                          'Erreur lors de la mise à jour: $e',
                                        );
                                      }

                                      setModalState(() {
                                        isUpdating = false;
                                      });

                                      if (!mounted) return;

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Erreur: ${e.toString().replaceAll('Exception:', '').trim()}',
                                          ),
                                          backgroundColor: Colors.red,
                                          duration: const Duration(seconds: 4),
                                        ),
                                      );
                                    }
                                  },
                            icon: isUpdating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.check, size: 18),
                            label: Text(
                              isUpdating ? 'MISE À JOUR...' : 'VALIDER',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mise à jour des articles'),
        centerTitle: true,
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadStocks,
        child: Column(
          children: [
            // Barre de recherche
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Rechercher un article...',
                  prefixIcon: Icon(
                    Icons.search,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),

            // Liste des stocks
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Chargement des articles...'),
                        ],
                      ),
                    )
                  : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadStocks,
                            child: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    )
                  : _filteredStocks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun article trouvé',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredStocks.length,
                      itemBuilder: (context, index) {
                        final stock = _filteredStocks[index];
                        final quantite = _parseDouble(
                          stock['quantiteStock'],
                        ).toInt();
                        final prixVente = _parseDouble(stock['prixVentHT']);
                        final seuilAlerte = _parseInt(stock['seuilAlerte']);
                        final isAlert = quantite <= seuilAlerte;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UpdateStockScreen(stock: stock),
                                ),
                              );
                              if (result == true) {
                                _loadStocks();
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isAlert
                                      ? Colors.orange.shade200
                                      : Colors.grey.shade200,
                                  width: isAlert ? 2 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // Icône
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: isAlert
                                          ? Colors.orange.shade100
                                          : Colors.blue.shade100,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isAlert
                                          ? Icons.warning_amber
                                          : Icons.inventory_2,
                                      color: isAlert
                                          ? Colors.orange.shade700
                                          : Colors.blue.shade700,
                                      size: 24,
                                    ),
                                  ),

                                  const SizedBox(width: 16),

                                  // Informations
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          stock['libelle'] ?? 'Article',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2C3E50),
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Stock: $quantite | Seuil: $seuilAlerte',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isAlert
                                                ? Colors.orange.shade700
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatCurrency(prixVente),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Flèche
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: Colors.grey.shade400,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
