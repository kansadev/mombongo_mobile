import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mombongo/services/app_currency_preference.dart';
import 'package:mombongo/services/service_locator.dart';

class StockMouvementsScreen extends StatefulWidget {
  const StockMouvementsScreen({super.key});

  @override
  State<StockMouvementsScreen> createState() => _StockMouvementsScreenState();
}

class _StockMouvementsScreenState extends State<StockMouvementsScreen> {
  List<dynamic> _mouvements = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMouvements();
  }

  Future<void> _loadMouvements() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentUser = locator.authRepository.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecte');
      }

      final idSite = int.tryParse(currentUser.idSite) ?? 0;
      if (idSite == 0) {
        throw Exception('ID du site invalide');
      }

      final mouvements = await locator.apiService.getMouvementsStockBySite(
        idSite,
      );

      if (!mounted) return;

      setState(() {
        _mouvements = mouvements;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement des mouvements: $e');
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Erreur lors du chargement des mouvements: $e';
        _isLoading = false;
      });
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

  String _formatCurrency(double amount) {
    final code = AppCurrencyPreference.readCode(locator.databaseService);
    final formatter = AppCurrencyPreference.formatterFor(code);
    final symbol = AppCurrencyPreference.symbolFor(code);
    return '${formatter.format(amount)} $symbol';
  }

  Color _getTypeMouvementColor(String? typeMouvement) {
    if (typeMouvement == null) return Colors.grey;
    final type = typeMouvement.toLowerCase();
    if (type.contains('entree') ||
        type.contains('in') ||
        type.contains('ajout')) {
      return Colors.green;
    } else if (type.contains('sortie') ||
        type.contains('out') ||
        type.contains('vente')) {
      return Colors.red;
    } else if (type.contains('transfert')) {
      return Colors.orange;
    }
    return Colors.blue;
  }

  IconData _getTypeMouvementIcon(String? typeMouvement) {
    if (typeMouvement == null) return Icons.swap_horiz;
    final type = typeMouvement.toLowerCase();
    if (type.contains('entree') ||
        type.contains('in') ||
        type.contains('ajout')) {
      return Icons.add_circle;
    } else if (type.contains('sortie') ||
        type.contains('out') ||
        type.contains('vente')) {
      return Icons.remove_circle;
    } else if (type.contains('transfert')) {
      return Icons.swap_horiz;
    }
    return Icons.swap_horiz;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Mouvements de Stock',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadMouvements,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
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
                      onPressed: _loadMouvements,
                      child: const Text('Reessayer'),
                    ),
                  ],
                ),
              )
            : _mouvements.isEmpty
            ? const Center(child: Text('Aucun mouvement de stock'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _mouvements.length,
                itemBuilder: (context, index) {
                  final mouvement = _mouvements[index];
                  return _buildMouvementCard(mouvement);
                },
              ),
      ),
    );
  }

  Widget _buildMouvementCard(Map<String, dynamic> mouvement) {
    final typeMouvement = mouvement['typeMouvement']?.toString();
    final quantite = _parseDouble(mouvement['quantite']);
    final ancienneQuantite = _parseDouble(mouvement['ancienneQuantite']);
    final nouvelleQuantite = _parseDouble(mouvement['nouvelleQuantite']);
    final commentaire = mouvement['commentaire']?.toString();
    final dateMouvement = mouvement['dateMouvement'];
    final libelle = mouvement['nomArticle']?.toString() ?? '-';

    DateTime? parsedDate;
    if (dateMouvement != null) {
      try {
        parsedDate = DateTime.parse(dateMouvement.toString());
      } catch (e) {
        debugPrint('Error parsing date: $e');
      }
    }

    final color = _getTypeMouvementColor(typeMouvement);
    final icon = _getTypeMouvementIcon(typeMouvement);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (libelle != '-')
                        Text(
                          libelle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      Text(
                        typeMouvement ?? 'Mouvement',
                        style: TextStyle(fontSize: 13, color: color),
                      ),
                      if (parsedDate != null)
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(parsedDate),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    quantite > 0
                        ? '+${quantite.toInt()}'
                        : '${quantite.toInt()}',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoChip(
                    icon: Icons.inventory,
                    label: 'Stock',
                    value:
                        '${ancienneQuantite.toInt()} -> ${nouvelleQuantite.toInt()}',
                  ),
                ),
              ],
            ),
            if (commentaire != null && commentaire.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                commentaire,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
      ],
    );
  }
}
