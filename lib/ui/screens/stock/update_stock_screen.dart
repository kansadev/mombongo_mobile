import 'package:flutter/material.dart';
import 'package:mombongo/models/article_update_request.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:flutter/foundation.dart';

class UpdateStockScreen extends StatefulWidget {
  final Map<String, dynamic> stock;

  const UpdateStockScreen({super.key, required this.stock});

  @override
  State<UpdateStockScreen> createState() => _UpdateStockScreenState();
}

class _UpdateStockScreenState extends State<UpdateStockScreen> {
  late TextEditingController _quantiteController;
  late TextEditingController _prixAchatController;
  late TextEditingController _prixVenteController;
  late TextEditingController _numeroLotController;
  late TextEditingController _commentairePeremptionController;

  DateTime? _selectedDateExpiration;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    final stock = widget.stock;

    // Pré-remplir les champs avec les valeurs actuelles
    _quantiteController = TextEditingController(
      text: _parseDouble(stock['quantiteStock']).toInt().toString(),
    );
    _prixAchatController = TextEditingController(
      text: _parseDouble(stock['prixAchat']).toString(),
    );
    // Note: le champ dans l'API est 'prixVentHT'
    _prixVenteController = TextEditingController(
      text: _parseDouble(stock['prixVentHT']).toString(),
    );
    _numeroLotController = TextEditingController(
      text: stock['numeroLot']?.toString() ?? '',
    );
    _commentairePeremptionController = TextEditingController(
      text: stock['commentairePeremption']?.toString() ?? '',
    );

    if (stock['dateExpiration'] != null) {
      _selectedDateExpiration = DateTime.tryParse(stock['dateExpiration'].toString());
    }
  }

  @override
  void dispose() {
    _quantiteController.dispose();
    _prixAchatController.dispose();
    _prixVenteController.dispose();
    _numeroLotController.dispose();
    _commentairePeremptionController.dispose();
    super.dispose();
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Future<void> _updateStock() async {
    // Validation des champs
    if (_quantiteController.text.isEmpty ||
        _prixAchatController.text.isEmpty ||
        _prixVenteController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir tous les champs'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final newQuantite = double.tryParse(_quantiteController.text) ?? 0.0;
    final newPrixAchat = double.tryParse(_prixAchatController.text) ?? 0.0;
    final newPrixVente = double.tryParse(_prixVenteController.text) ?? 0.0;

    // Validation des valeurs
    if (newQuantite < 0 || newPrixAchat < 0 || newPrixVente < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Les valeurs ne peuvent pas être négatives'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isUpdating = true);

    try {
      final stock = widget.stock;
      final idStock = _parseInt(stock['idStock']);

      // Create a typed request object
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
        dateExpiration: _selectedDateExpiration,
        seuilAlerte: _parseInt(stock['seuilAlerte']),
      );

      if (kDebugMode) {
        print('=== UPDATE STOCK (UPDATE_STOCK_SCREEN) ===');
        print('Request: ${request.toJson()}');
      }

      // Appeler l'API pour mise à jour du stock
      await locator.apiService.updateStock(
        idStock,
        request.toJson(),
      );

      if (!mounted) return;

      Navigator.pop(context, true); // Retourner true pour indicate succès

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${stock['libelle']} mis à jour avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('=== UPDATE STOCK ERROR ===');
        print('Erreur lors de la mise à jour: $e');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString().replaceAll('Exception:', '').trim()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stock = widget.stock;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Theme.of(context).colorScheme.onSecondary,
        elevation: 0,
        title: const Text(
          'Mettre à jour le stock',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec le nom de l'article
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stock['libelle'] ?? 'Article',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ID Stock: ${stock['idStock']} | ID Article: ${stock['idArticle']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Informations actuelles
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Informations actuelles',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('Numéro de lot', stock['numeroLot']?.toString() ?? 'Non défini'),
                  _buildInfoRow(
                    'Date d\'expiration',
                    stock['dateExpiration'] != null
                        ? (() {
                            final date = DateTime.tryParse(stock['dateExpiration'].toString());
                            return date != null
                                ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
                                : 'Non définie';
                          })()
                        : 'Non définie',
                  ),
                  _buildInfoRow('Commentaire', stock['commentairePeremption']?.toString() ?? 'Aucun'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Formulaire
            const Text(
              'Nouvelles valeurs',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),

            const SizedBox(height: 16),

            // Quantité
            _buildTextField(
              controller: _quantiteController,
              label: 'Quantité',
              prefixIcon: Icons.inventory_2_outlined,
              backgroundColor: Colors.grey.shade50,
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 16),

            // Prix d'achat et Prix de vente
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _prixAchatController,
                    label: 'Prix d\'achat',
                    prefixIcon: Icons.attach_money,
                    backgroundColor: Colors.green.shade50,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _prixVenteController,
                    label: 'Prix de vente HT',
                    prefixIcon: Icons.sell_outlined,
                    backgroundColor: Colors.orange.shade50,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Numéro de lot
            _buildTextField(
              controller: _numeroLotController,
              label: 'Numéro de lot',
              prefixIcon: Icons.tag,
              backgroundColor: Colors.grey.shade50,
            ),

            const SizedBox(height: 16),

            // Date d'expiration
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Date d\'expiration',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDateExpiration ?? DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (date != null) {
                      setState(() {
                        _selectedDateExpiration = date;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                        const SizedBox(width: 12),
                        Text(
                          _selectedDateExpiration != null
                              ? '${_selectedDateExpiration!.day.toString().padLeft(2, '0')}/${_selectedDateExpiration!.month.toString().padLeft(2, '0')}/${_selectedDateExpiration!.year}'
                              : 'Sélectionner une date',
                          style: TextStyle(
                            fontSize: 16,
                            color: _selectedDateExpiration != null ? Colors.black87 : Colors.grey,
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
            _buildTextField(
              controller: _commentairePeremptionController,
              label: 'Commentaire péremption',
              prefixIcon: Icons.note_outlined,
              backgroundColor: Colors.grey.shade50,
              maxLines: 3,
            ),

            const SizedBox(height: 32),

            // Bouton de validation
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isUpdating ? null : _updateStock,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: _isUpdating
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'MISE À JOUR...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline),
                          SizedBox(width: 12),
                          Text(
                            'VALIDER',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label :',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData prefixIcon,
    required Color backgroundColor,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: backgroundColor,
        prefixIcon: Icon(prefixIcon, size: 20),
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
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
