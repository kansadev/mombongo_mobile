import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mombongo/services/app_currency_preference.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/ui/screens/stock/product_list_screen.dart';
import 'dart:math';

class NouvelArticleScreen extends StatefulWidget {
  const NouvelArticleScreen({super.key});

  @override
  State<NouvelArticleScreen> createState() => _NouvelArticleScreenState();
}

class _NouvelArticleScreenState extends State<NouvelArticleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeBarreController = TextEditingController();
  bool _isLoading = false;

  // Variables pour les champs du formulaire
  String nomArticle = '';
  String codeBarreQR = '';
  double tva = 0.0;
  double remise = 0.0;
  bool avecStock = false;
  bool perissable = false;
  double prixAchat = 0.0;
  double prixVente = 0.0;
   
  // Nouveaux champs pour le stock
  double quantiteInitial = 0.0;
  double seuilAlerte = 0.0;
  String numeroLot = '';
  double quantiteLot = 0.0;
  DateTime? dateExpiration;
  String commentairePeremption = '';

  // Variable calculee pour la marge
  double get margeBeneficiaire => prixVente - prixAchat;

  // Fonction de generation de code-barres
  String _generateBarcode() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = random.nextInt(999999).toString().padLeft(6, '0');
    return '$timestamp$randomPart';
  }

  @override
  void dispose() {
    _codeBarreController.dispose();
    super.dispose();
  }

  // Helper pour decorer uniformement les champs
  InputDecoration _buildInputDecoration(String label, IconData icon, {String? suffix, Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.secondary),
      suffixText: suffix,
      suffixIcon: suffixIcon,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100, // Fond gris clair pour faire ressortir les cards
      appBar: AppBar(
        title: const Text('Nouvel Article'),
        centerTitle: true,
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Message d'information sur les services
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.purple.shade700, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Les articles sans gestion de stock sont consideres comme des services',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.purple.shade700,
                            fontWeight: FontWeight.w500,
                          ),
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
                        TextFormField(
                          decoration: _buildInputDecoration('Nom de l\'article *', Icons.shopping_bag),
                          validator: (value) => (value == null || value.isEmpty) 
                              ? 'Veuillez saisir le nom de l\'article' 
                              : null,
                          onSaved: (value) => nomArticle = value ?? '',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _codeBarreController,
                          decoration: _buildInputDecoration(
                            'Code-barres (optionnel)',
                            Icons.qr_code,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.autorenew, size: 20),
                              tooltip: 'Generer un code-barres',
                              onPressed: () {
                                setState(() {
                                  codeBarreQR = _generateBarcode();
                                  _codeBarreController.text = codeBarreQR;
                                });
                              },
                            ),
                          ),
                          onSaved: (value) => codeBarreQR = value ?? '',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // SECTION 2 : Tarification (masquee par defaut, visible uniquement pour les services)
                if (!avecStock) ...[
                  _buildSectionTitle('Tarification'),
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
                                child: _buildNumberField(
                                  label: 'TVA',
                                  icon: Icons.percent,
                                  suffix: '%',
                                  onChanged: (val) => tva = val,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildNumberField(
                                  label: 'Remise',
                                  icon: Icons.discount,
                                  suffix: '%',
                                  onChanged: (val) => remise = val,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildNumberField(
                                  label: 'Prix de vente',
                                  icon: Icons.sell,
                                  suffix: AppCurrencyPreference.symbolFor(
                                    AppCurrencyPreference.readCode(locator.databaseService),
                                  ),
                                  onChanged: (val) {
                                    setState(() => prixVente = val);
                                  },
                                  validator: (val) {
                                    if (val == null || val <= 0) return 'Prix requis';
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (prixVente > 0) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Prix de vente TTC (approx):'),
                                  Text(
                                    '${(prixVente * (1 + tva / 100)).toStringAsFixed(2)} ${AppCurrencyPreference.symbolFor(AppCurrencyPreference.readCode(locator.databaseService))}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // SECTION 3 : Gestion de Stock
                _buildSectionTitle('Gestion du Stock'),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Gerer cet article en stock', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Activez pour suivre les quantites'),
                        value: avecStock,
                        activeThumbColor : Theme.of(context).colorScheme.tertiary,
                        onChanged: (bool value) {
                          setState(() => avecStock = value);
                        },
                      ),
                      if (avecStock) ...[
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              // TVA et Remise dans la section Stock
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildNumberField(
                                      label: 'TVA',
                                      icon: Icons.percent,
                                      suffix: '%',
                                      onChanged: (val) => tva = val,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildNumberField(
                                      label: 'Remise',
                                      icon: Icons.discount,
                                      suffix: '%',
                                      onChanged: (val) => remise = val,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Prix d'achat et Prix de vente
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildNumberField(
                                      label: 'Prix d\'achat',
                                      icon: Icons.shopping_cart,
                                      suffix: AppCurrencyPreference.symbolFor(
                                        AppCurrencyPreference.readCode(locator.databaseService),
                                      ),
                                      onChanged: (val) {
                                        setState(() => prixAchat = val);
                                      },
                                      validator: (val) {
                                        if (val == null || val <= 0) return 'Prix requis';
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildNumberField(
                                      label: 'Prix de vente',
                                      icon: Icons.sell,
                                      suffix: AppCurrencyPreference.symbolFor(
                                        AppCurrencyPreference.readCode(locator.databaseService),
                                      ),
                                      onChanged: (val) {
                                        setState(() => prixVente = val);
                                      },
                                      validator: (val) {
                                        if (val == null || val <= 0) return 'Prix requis';
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              if (prixAchat > 0 && prixVente > 0) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: margeBeneficiaire >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: margeBeneficiaire >= 0 ? Colors.green.shade200 : Colors.red.shade200,
                                    )
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Marge beneficiaire :'),
                                      Text(
                                        '${margeBeneficiaire.toStringAsFixed(2)} ${AppCurrencyPreference.symbolFor(AppCurrencyPreference.readCode(locator.databaseService))}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: margeBeneficiaire >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              // Quantite initiale et Seuil d'alerte
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildNumberField(
                                      label: 'Qte Initiale',
                                      icon: Icons.inventory,
                                      isInteger: true,
                                      onChanged: (val) => quantiteInitial = val,
                                      validator: (val) {
                                        if (val == null || val <= 0) return 'Quantite requise';
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildNumberField(
                                      label: 'Seuil Alerte',
                                      icon: Icons.warning_amber,
                                      isInteger: true,
                                      onChanged: (val) => seuilAlerte = val,
                                    ),
                                  ),
                                ],
                              ),
                              
                              // Sous-section Peremption (uniquement si le stock est gere)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                                ),
                                child: Column(
                                  children: [
                                    const Divider(height: 1),
                                    SwitchListTile(
                                      title: const Text('Article perissable', style: TextStyle(fontWeight: FontWeight.w600)),
                                      subtitle: const Text('Gerer les lots et dates d\'expiration'),
                                      value: perissable,
                                      activeThumbColor : Theme.of(context).colorScheme.tertiary,
                                      onChanged: (bool value) {
                                        setState(() => perissable = value);
                                      },
                                    ),
                                    if (perissable)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                        child: Column(
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextFormField(
                                                    decoration: _buildInputDecoration('N° Lot *', Icons.tag),
                                                    onSaved: (value) => numeroLot = value ?? '',
                                                    validator: (value) => (value == null || value.isEmpty) 
                                                        ? 'Requis' 
                                                        : null,
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: _buildNumberField(
                                                    label: 'Qte du lot *',
                                                    icon: Icons.numbers,
                                                    isInteger: true,
                                                    onChanged: (val) => quantiteLot = val,
                                                    validator: (val) => (val == null || val <= 0) ? 'Invalide' : null,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            InkWell(
                                              onTap: () async {
                                                final picked = await showDatePicker(
                                                  context: context,
                                                  initialDate: dateExpiration ?? DateTime.now().add(const Duration(days: 30)),
                                                  firstDate: DateTime.now(),
                                                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                                                );
                                                if (picked != null) {
                                                  setState(() => dateExpiration = picked);
                                                }
                                              },
                                              child: InputDecorator(
                                                decoration: _buildInputDecoration('Date d\'expiration *', Icons.calendar_today),
                                                child: Text(
                                                  dateExpiration != null
                                                      ? '${dateExpiration!.day.toString().padLeft(2, '0')}/${dateExpiration!.month.toString().padLeft(2, '0')}/${dateExpiration!.year}'
                                                      : 'Selectionner une date',
                                                  style: TextStyle(
                                                    color: dateExpiration != null ? Colors.black87 : Colors.grey.shade600,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // SECTION 4 : Boutons d'action
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
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
                      flex: 2, // Le bouton enregistrer prend plus de place car c'est l'action principale
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () async {
                          if (_formKey.currentState!.validate()) {
                            if (perissable && dateExpiration == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Veuillez selectionner une date d\'expiration'), backgroundColor: Colors.red),
                              );
                              return;
                            }
                            _formKey.currentState!.save();
                            await _saveArticle();
                          }
                        },
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
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
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

  // Refonte du champ numerique (plus propre, evite les bugs de curseur)
  Widget _buildNumberField({
    required String label,
    required IconData icon,
    required Function(double) onChanged,
    String? suffix,
    bool isInteger = false,
    String? Function(double?)? validator,
  }) {
    return TextFormField(
      keyboardType: TextInputType.numberWithOptions(decimal: !isInteger),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(isInteger ? r'^\d+' : r'^\d+[\.,]?\d*')),
      ],
      decoration: _buildInputDecoration(label, icon, suffix: suffix),
      onChanged: (text) {
        final newValue = double.tryParse(text.replaceAll(',', '.')) ?? 0.0;
        onChanged(newValue);
      },
      validator: (text) {
        if (validator != null) {
          final val = double.tryParse(text?.replaceAll(',', '.') ?? '');
          return validator(val);
        }
        return null;
      },
    );
  }

  // --- LOGIQUE DE SAUVEGARDE (Inchangee pour la plupart) ---
  Future<void> _saveArticle() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = locator.authRepository.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecte');
      }

      final idSociete = int.tryParse(currentUser.idSociete) ?? 0;
      final idSite = int.tryParse(currentUser.idSite) ?? 0;
      
      if (idSociete == 0) {
        throw Exception('ID de societe invalide');
      }

      if (avecStock && perissable && dateExpiration != null) {
        final maintenant = DateTime.now();
        final aujourdHui = DateTime(maintenant.year, maintenant.month, maintenant.day);
        final dateExp = DateTime(dateExpiration!.year, dateExpiration!.month, dateExpiration!.day);
        
        if (dateExp.isBefore(aujourdHui) || dateExp.isAtSameMomentAs(aujourdHui)) {
          throw Exception('La date d\'expiration doit etre posterieure a la date actuelle');
        }
      }

      Map<String, dynamic> response;

      if (avecStock) {
        final articleWithStockData = {
          'libelle': nomArticle.trim(),
          'codeBarreQR': codeBarreQR.isEmpty ? null : codeBarreQR.trim(),
          'tva': tva.toInt(),
          'remise': remise.toInt(),
          'idSociete': idSociete,
          'perissable': perissable,
          'withStock': true,
          'idSite': idSite,
          'quantiteInitial': quantiteInitial.toInt(),
          'prixAchat': prixAchat.toInt(),
          'prixVenteHT': prixVente.toInt(),
          'seuilAlerte': seuilAlerte.toInt(),
          'numeroLot': numeroLot.isEmpty ? null : numeroLot.trim(),
          'quantiteLot': quantiteLot.toInt(),
          'dateExpiration': perissable && dateExpiration != null 
              ? dateExpiration!.toIso8601String() 
              : null,
          'commentairePeremption': perissable && commentairePeremption.isNotEmpty 
              ? commentairePeremption.trim() 
              : null,
        };
        response = await locator.apiService.createArticleWithStock(articleWithStockData);
      } else {
        final articleData = {
          'idArticle': 0,
          'libelle': nomArticle,
          'codeBarreQR': codeBarreQR.isEmpty ? null : codeBarreQR,
          'quantiteInitial': 0, // Quantite a 0 pour les services
          'prixAchat': 0, // Prix d'achat a 0 pour les services
          'prixVenteHT': prixVente.toInt(),
          'idSociete': idSociete,
          'idSite': idSite,
          'perissable': perissable,
          'withStock': false,
          'statut': true,
        };
        response = await locator.apiService.createArticleWithStock(articleData);
      }

      if (!mounted) return;

      // show confirmation dialog instead of snack bar
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('Succes'),
            content: Text(
              avecStock
                  ? 'Article et stock enregistres avec succes !'
                  : 'Article enregistre avec succes !',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // close dialog
                  Navigator.of(context).pop(true); // return to previous screen
                },
                child: const Text('Fermer'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const ProductListScreen(),
                    ),
                  );
                },
                child: const Text('Voir tous les articles'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      debugPrint('Erreur lors de l\'enregistrement de l\'article: $e');
      if (!mounted) return;

      String messageErreur = 'Une erreur est survenue. Veuillez reessayer.';
      final errorMsg = e.toString().toLowerCase();
      
      if (errorMsg.contains('numero de lot')) {
        messageErreur = 'Le numero de lot est obligatoire pour les articles perissables.';
      } else if (errorMsg.contains('quantite du lot') || errorMsg.contains('quantite du lot')) {
        messageErreur = 'La quantite du lot doit etre superieure a 0 pour les articles perissables.';
      } else if (errorMsg.contains('date d\'expiration')) {
        messageErreur = 'La date d\'expiration doit etre ulterieure a la date actuelle.';
      } else if (errorMsg.contains('libelle')) {
        messageErreur = 'Le nom de l\'article est obligatoire.';
      } else if (errorMsg.contains('quantite')) {
        messageErreur = 'La quantite initiale doit etre superieure a zero.';
      } else if (errorMsg.contains('prix')) {
        messageErreur = 'Veuillez verifier les prix saisis.';
      } else if (errorMsg.contains('apiException')) {
        final apiMessage = e.toString();
        if (apiMessage.contains(':')) {
          messageErreur = apiMessage.split(':').last.trim();
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          content: Text(messageErreur, style: const TextStyle(color: Colors.white)),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
