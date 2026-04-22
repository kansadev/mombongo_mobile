import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/services/app_currency_preference.dart';

class CreateChargeScreen extends StatefulWidget {
  final List<dynamic> typesCharge;

  const CreateChargeScreen({super.key, required this.typesCharge});

  @override
  State<CreateChargeScreen> createState() => _CreateChargeScreenState();
}

class _CreateChargeScreenState extends State<CreateChargeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _libelleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _fournisseurController = TextEditingController();

  String? _selectedTypeCharge;
  String _selectedModePaiement = 'Espèces';
  String _selectedStatut = 'PAID';
  late String _selectedDevise;
  String _selectedFrequence = 'UNIQUE';
  bool _isLoading = false;

  final List<String> _modesPaiement = [
    'Espèces',
    'Mobile Money',
    'Carte',
    'Virement',
  ];
  final List<String> _statuts = ['PAID', 'PENDING'];
  final List<Map<String, String>> _devises = [
    {'code': 'CDF', 'nom': 'Franc Congolais (CDF)'},
    {'code': 'USD', 'nom': 'Dollar Américain (USD)'},
  ];
  final List<Map<String, String>> _frequences = [
    {'code': 'UNIQUE', 'nom': 'Unique'},
    {'code': 'MENSUEL', 'nom': 'Mensuel'},
    {'code': 'TRIMESTRIEL', 'nom': 'Trimestriel'},
    {'code': 'ANNUEL', 'nom': 'Annuel'},
  ];

  List<Map<String, String>> get _typeOptions {
    if (widget.typesCharge.isEmpty) {
      return [
        {'code': 'SALAIRE', 'nom': 'Salaires'},
        {'code': 'ENERGIE', 'nom': 'Énergie'},
        {'code': 'LOYER', 'nom': 'Loyer'},
        {'code': 'TRANSPORT', 'nom': 'Transport'},
        {'code': 'FOURNITURE', 'nom': 'Fournitures'},
        {'code': 'MAINTENANCE', 'nom': 'Maintenance'},
        {'code': 'MARKETING', 'nom': 'Marketing'},
        {'code': 'ASSURANCE', 'nom': 'Assurances'},
        {'code': 'AUTRE', 'nom': 'Autre'},
      ];
    }
    return widget.typesCharge.map((type) {
      final typeMap = type is Map ? type : {};
      return {
        'code': typeMap['code']?.toString() ?? type.toString(),
        'nom': typeMap['nom']?.toString() ?? typeMap['code']?.toString() ?? '',
      };
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _selectedDevise = AppCurrencyPreference.readCode(locator.databaseService);
    if (_typeOptions.isNotEmpty) {
      _selectedTypeCharge = _typeOptions.first['code'];
    }
  }

  @override
  void dispose() {
    _montantController.dispose();
    _libelleController.dispose();
    _descriptionController.dispose();
    _fournisseurController.dispose();
    super.dispose();
  }

  String _getApiMode(String mode) {
    switch (mode) {
      case 'Espèces':
        return 'ESPECE';
      case 'Mobile Money':
        return 'MOBILE_MONEY';
      case 'Carte':
        return 'CARTE';
      case 'Virement':
        return 'VIREMENT';
      default:
        return 'ESPECE';
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'SALAIRE':
      case 'PRIME':
      case 'INDEMNITE':
        return Icons.people;
      case 'SOCIAL':
        return Icons.health_and_safety;
      case 'FORMATION':
        return Icons.school;
      case 'LOYER':
        return Icons.home;
      case 'ENERGIE':
        return Icons.bolt;
      case 'TRANSPORT':
        return Icons.local_shipping;
      case 'FOURNITURE':
        return Icons.inventory;
      case 'MAINTENANCE':
        return Icons.build;
      case 'MARKETING':
        return Icons.campaign;
      case 'ASSURANCE':
        return Icons.security;
      case 'HONORAIRE':
        return Icons.work;
      case 'IMPUT':
        return Icons.receipt_long;
      case 'BANQUE':
        return Icons.account_balance;
      case 'TELECOM':
        return Icons.phone;
      case 'AMORTISSEMENT':
        return Icons.trending_down;
      case 'PROVISION':
        return Icons.savings;
      case 'INTERET':
        return Icons.percent;
      case 'CHANGE':
        return Icons.currency_exchange;
      case 'CREANCE':
        return Icons.money_off;
      case 'PENALITE':
        return Icons.gavel;
      default:
        return Icons.receipt;
    }
  }

  Future<void> _submitCharge() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTypeCharge == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un type de charge'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = locator.authRepository.currentUser;
      final idUtilisateur =
          int.tryParse(currentUser?.idUtilisateur ?? '0') ?? 0;
      final idSite = int.tryParse(currentUser?.idSite ?? '0') ?? 0;
      final idSociete = int.tryParse(currentUser?.idSociete ?? '0') ?? 0;

      final chargeData = {
        'idSite': idSite,
        'idSociete': idSociete,
        'typeCharge': _selectedTypeCharge,
        'libelle': _libelleController.text,
        'montant': double.tryParse(_montantController.text) ?? 0,
        'devise': _selectedDevise,
        'dateCharge': DateTime.now().toUtc().toIso8601String(),
        'frequence': _selectedFrequence,
        'estRecurrent': _selectedFrequence != 'UNIQUE',
        'modePaiement': _getApiMode(_selectedModePaiement),
        'statut': _selectedStatut,
        'description': _descriptionController.text,
        'fournisseur': _fournisseurController.text,
        'idUtilisateurCreation': idUtilisateur,
        'referencePaiement': 'CHG-${DateTime.now().millisecondsSinceEpoch}',
        'categorieComptable': _selectedTypeCharge,
      };

      await locator.apiService.createCharge(chargeData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Charge créée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Erreur lors de la création';
        if (e.toString().contains('ApiException')) {
          final match = RegExp(
            r"ApiException\('([^']+)",
          ).firstMatch(e.toString());
          if (match != null) {
            errorMessage = match.group(1) ?? errorMessage;
          }
        } else {
          final messageMatch = RegExp(
            r'"message":"([^"]+)"',
          ).firstMatch(e.toString());
          if (messageMatch != null) {
            errorMessage = messageMatch.group(1) ?? errorMessage;
          } else if (e.toString().length < 100) {
            errorMessage = e.toString();
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Nouvelle Charge',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
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
                            color: const Color(
                              0xFF2C3E50,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _getTypeIcon(_selectedTypeCharge ?? ''),
                            color: const Color(0xFF2C3E50),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Type de charge',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedTypeCharge,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      items: _typeOptions.map<DropdownMenuItem<String>>((type) {
                        return DropdownMenuItem<String>(
                          value: type['code'],
                          child: Text(
                            type['nom'] ?? '',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedTypeCharge = value);
                        }
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
                    Text(
                      'Détails',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _libelleController,
                      decoration: InputDecoration(
                        labelText: 'Libellé',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un libellé';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Description (optionnel)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedDevise,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Devise',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            items: _devises.map((devise) {
                              return DropdownMenuItem<String>(
                                value: devise['code'],
                                child: Text(
                                  devise['nom'] ?? '',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedDevise = value);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedFrequence,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Fréquence',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            items: _frequences.map((freq) {
                              return DropdownMenuItem<String>(
                                value: freq['code'],
                                child: Text(
                                  freq['nom'] ?? '',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedFrequence = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _montantController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Montant',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un montant';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Veuillez entrer un nombre valide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _fournisseurController,
                      decoration: InputDecoration(
                        labelText: 'Fournisseur (optionnel)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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
                    Text(
                      'Paiement',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedModePaiement,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Mode de paiement',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: _modesPaiement.map((mode) {
                        return DropdownMenuItem<String>(
                          value: mode,
                          child: Text(mode, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedModePaiement = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedStatut,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Statut',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: _statuts.map((statut) {
                        return DropdownMenuItem<String>(
                          value: statut,
                          child: Text(
                            statut == 'PAID' ? 'Payé' : 'En attente',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedStatut = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitCharge,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C3E50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Créer la charge',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
