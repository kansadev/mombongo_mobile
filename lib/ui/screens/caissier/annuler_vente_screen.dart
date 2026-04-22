import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/services/app_currency_preference.dart';

class AnnulerVenteScreen extends StatefulWidget {
  final Map<String, dynamic> vente;

  const AnnulerVenteScreen({super.key, required this.vente});

  @override
  State<AnnulerVenteScreen> createState() => _AnnulerVenteScreenState();
}

class _AnnulerVenteScreenState extends State<AnnulerVenteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _motifController = TextEditingController();
  final _commentaireController = TextEditingController();
  bool _rembourserStock = true;
  bool _annulerPaiement = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _motifController.dispose();
    _commentaireController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    return locator.tauxService.formatPrice(amount);
  }

  double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  Future<void> _confirmerAnnulation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = locator.authRepository.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }
      final idUtilisateur = int.tryParse(currentUser.idUtilisateur) ?? 0;
      final idCommande = widget.vente['idCommande'] as int;

      await locator.apiService.annulerVente(
        idCommande: idCommande,
        motif: _motifController.text.trim(),
        idUtilisateurAnnulation: idUtilisateur,
        RembourserStock: _rembourserStock,
        annulerPaiement: _annulerPaiement,
        commentaire: _commentaireController.text.trim().isNotEmpty
            ? _commentaireController.text.trim()
            : null,
        montantRembourse: _annulerPaiement
            ? _parseDouble(widget.vente['total'] ?? 0)
            : null,
        referenceRemboursement: _annulerPaiement
            ? 'ANNUL-${DateTime.now().millisecondsSinceEpoch}'
            : null,
        modeRemboursement: _annulerPaiement ? 'Espèces' : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vente #$idCommande annulée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'annulation: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vente = widget.vente;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Annuler la vente',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.red[200]!),
                ),
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.red[700],
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Détails de la vente',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildDetailRow(
                        'Produit',
                        vente['libelle']?.toString() ?? 'N/A',
                      ),
                      _buildDetailRow('Commande', '#${vente['idCommande']}'),
                      _buildDetailRow('Quantité', '${vente['quantite'] ?? 0}'),
                      _buildDetailRow(
                        'Total',
                        _formatCurrency(_parseDouble(vente['total'] ?? 0)),
                        isHighlighted: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Motif d\'annulation *',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _motifController,
                decoration: InputDecoration(
                  hintText: 'Ex: Erreur de caisse, client parti sans payer...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.red[400]!, width: 2),
                  ),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Le motif est obligatoire';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Commentaire (optionnel)',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _commentaireController,
                decoration: InputDecoration(
                  hintText: 'Ajouter un commentaire supplémentaire...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.red[400]!, width: 2),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Text(
                'Options',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(
                        'Rembourser le stock',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      subtitle: Text(
                        'Remettre les produits en inventaire',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                      value: _rembourserStock,
                      onChanged: (value) {
                        setState(() => _rembourserStock = value);
                      },
                      activeColor: Colors.green,
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: Text(
                        'Annuler le paiement',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      subtitle: Text(
                        'Reverser l\'argent au client',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                      value: _annulerPaiement,
                      onChanged: (value) {
                        setState(() => _annulerPaiement = value);
                      },
                      activeColor: Colors.green,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _confirmerAnnulation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cancel_outlined),
                            const SizedBox(width: 8),
                            Text(
                              'Confirmer l\'annulation',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isHighlighted = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
              color: isHighlighted ? Colors.red[700] : Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
}
