import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/utils/api_error_message.dart';

class EditChargeScreen extends StatefulWidget {
  final Map<String, dynamic> charge;
  final List<dynamic> typesCharge;

  const EditChargeScreen({
    super.key,
    required this.charge,
    required this.typesCharge,
  });

  @override
  State<EditChargeScreen> createState() => _EditChargeScreenState();
}

class _EditChargeScreenState extends State<EditChargeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _fournisseurController = TextEditingController();

  String _selectedModePaiement = 'Espèces';
  String _selectedStatut = 'PAID';
  bool _isLoading = false;

  final List<String> _modesPaiement = ['Espèces', 'Mobile Money', 'Carte', 'Virement'];
  final List<String> _statuts = ['PAID', 'PENDING'];

  @override
  void initState() {
    super.initState();
    final charge = widget.charge;
    _montantController.text = charge['montant']?.toString() ?? '';
    _descriptionController.text = charge['description']?.toString() ?? charge['libelle']?.toString() ?? '';
    _fournisseurController.text = charge['fournisseur']?.toString() ?? '';
    _selectedModePaiement = _getModeLabel(charge['modePaiement']?.toString() ?? 'ESPECE');
    _selectedStatut = charge['statut']?.toString() ?? 'PAID';
  }

  @override
  void dispose() {
    _montantController.dispose();
    _descriptionController.dispose();
    _fournisseurController.dispose();
    super.dispose();
  }

  String _getApiMode(String mode) {
    switch (mode) {
      case 'Espèces': return 'ESPECE';
      case 'Mobile Money': return 'MOBILE_MONEY';
      case 'Carte': return 'CARTE';
      case 'Virement': return 'VIREMENT';
      default: return 'ESPECE';
    }
  }

  String _getModeLabel(String mode) {
    switch (mode.toUpperCase()) {
      case 'ESPECE': return 'Espèces';
      case 'MOBILE_MONEY': return 'Mobile Money';
      case 'CARTE': return 'Carte';
      case 'VIREMENT': return 'Virement';
      default: return mode;
    }
  }

  Future<void> _submitCharge() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = locator.authRepository.currentUser;
      final idUtilisateur = int.tryParse(currentUser?.idUtilisateur ?? '0') ?? 0;

      final idCharge = widget.charge['idCharge'] as int;
      final chargeData = {
        'libelle': _descriptionController.text,
        'montant': double.tryParse(_montantController.text) ?? 0,
        'dateCharge': widget.charge['dateCharge'] ?? DateTime.now().toUtc().toIso8601String(),
        'statut': _selectedStatut,
        'modePaiement': _getApiMode(_selectedModePaiement),
        'referencePaiement': widget.charge['referencePaiement'] ?? '',
        'description': _descriptionController.text,
        'idUtilisateurModification': idUtilisateur,
      };

      await locator.apiService.updateCharge(idCharge, chargeData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Charge modifiée avec succès'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorUserMessage(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCharge() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous supprimer cette charge "${widget.charge['libelle']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final idCharge = widget.charge['idCharge'] as int;
      final success = await locator.apiService.deleteCharge(idCharge);
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Charge supprimée'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur lors de la suppression'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorUserMessage(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeCharge = widget.charge['typeCharge']?.toString() ?? '';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Modifier charge',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteCharge,
            tooltip: 'Supprimer',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.receipt_long, color: Colors.red, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          typeCharge.replaceAll('_', ' '),
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Montant', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _montantController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        prefixText: 'CDF ',
                        prefixStyle: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                        filled: true, fillColor: Colors.red.withValues(alpha: 0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.red.withValues(alpha: 0.3))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.red.withValues(alpha: 0.3))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 2)),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Veuillez entrer un montant';
                        final amount = double.tryParse(value);
                        if (amount == null || amount <= 0) return 'Montant invalide';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Description', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Description de la charge',
                        hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2C3E50), width: 2)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fournisseur (optionnel)', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _fournisseurController,
                      decoration: InputDecoration(
                        hintText: 'Nom du fournisseur',
                        hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2C3E50), width: 2)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mode de paiement', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedModePaiement,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2C3E50), width: 2)),
                      ),
                      items: _modesPaiement.map((mode) => DropdownMenuItem(value: mode, child: Text(mode))).toList(),
                      onChanged: (value) => setState(() => _selectedModePaiement = value ?? 'Espèces'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Statut', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedStatut,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2C3E50), width: 2)),
                      ),
                      items: _statuts.map((statut) => DropdownMenuItem(
                        value: statut,
                        child: Text(statut == 'PAID' ? 'Payé' : 'En attente'),
                      )).toList(),
                      onChanged: (value) => setState(() => _selectedStatut = value ?? 'PAID'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitCharge,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.save, size: 20),
                          const SizedBox(width: 8),
                          Text('Enregistrer', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
