// lib/ui/screens/caissier/create_client_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/models/client.dart';
import 'package:intl/intl.dart';

class CreateClientScreen extends StatefulWidget {
  const CreateClientScreen({super.key});

  @override
  State<CreateClientScreen> createState() => _CreateClientScreenState();
}

class _CreateClientScreenState extends State<CreateClientScreen> {
  // Form controllers
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _prenomController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telephoneController = TextEditingController();
  final TextEditingController _pieceIdentiteController =
      TextEditingController();
  final TextEditingController _dateNaissanceController =
      TextEditingController();
  final TextEditingController _quartierController = TextEditingController();
  final TextEditingController _avenueController = TextEditingController();
  final TextEditingController _numeroController = TextEditingController();

  // Genre selection
  String _selectedGenre = 'M';

  // Date de naissance
  DateTime? _dateNaissance;

  // Client search
  final TextEditingController _searchClientController = TextEditingController();
  List<dynamic> _searchResults = [];
  Client? _selectedClient;

  // Form key
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Loading state
  bool _isLoading = false;

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _telephoneController.dispose();
    _pieceIdentiteController.dispose();
    _dateNaissanceController.dispose();
    _quartierController.dispose();
    _avenueController.dispose();
    _numeroController.dispose();
    _searchClientController.dispose();
    super.dispose();
  }

  Future<void> _searchClients(String query) async {
    debugPrint('=== RECHERCHE CLIENTS ===');
    debugPrint('Query: $query');
    
    if (query.length < 2) {
      debugPrint('Query trop courte (< 2 caractères), abandon de la recherche');
      setState(() {
        _searchResults = [];
      });
      return;
    }

    try {
      final isEmail = query.contains('@');
      final isPhone = RegExp(r'^[0-9+\s-]+$').hasMatch(query);

      debugPrint('Type de recherche:');
      debugPrint('  - Email: $isEmail');
      debugPrint('  - Téléphone: $isPhone');
      debugPrint('  - Nom: ${!isEmail && !isPhone}');
      
      final results = await locator.apiService.searchClients(
        email: isEmail ? query : null,
        nom: (isEmail || isPhone) ? null : query,
        telephone: isPhone ? query : null,
        pageSize: 20,
      );

      if (!mounted) {
        debugPrint('Widget non monté, abandon de la mise à jour des résultats');
        return;
      }

      debugPrint('Nombre de résultats trouvés: ${results.length}');
      if (results.isNotEmpty) {
        debugPrint('Premiers résultats:');
        for (var i = 0; i < (results.length > 3 ? 3 : results.length); i++) {
          final client = results[i];
          debugPrint('  ${i + 1}. ${client['nom']} ${client['prenom']} - ${client['email'] ?? 'Pas d\'email'}');
        }
      }

      setState(() {
        _searchResults = results;
      });
      
      debugPrint('=== FIN RECHERCHE CLIENTS ===');
    } catch (e, stackTrace) {
      debugPrint('=== ERREUR RECHERCHE CLIENTS ===');
      debugPrint('Erreur: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('================================');
      
      if (!mounted) return;

      setState(() {
        _searchResults = [];
      });
    }
  }

  void _selectClientFromSearch(Map<String, dynamic> clientData) {
    debugPrint('=== SELECTION CLIENT DEPUIS RECHERCHE ===');
    debugPrint('Données client reçues: $clientData');
    
    try {
      final clientDataFixed = Map<String, dynamic>.from(clientData);

      if (clientDataFixed.containsKey('idClient') &&
          !clientDataFixed.containsKey('id')) {
        final idClientValue = clientDataFixed['idClient'];
        debugPrint('Conversion idClient vers id: $idClientValue (${idClientValue.runtimeType})');
        
        if (idClientValue is String) {
          final parsedId = int.tryParse(idClientValue);
          if (parsedId != null) {
            clientDataFixed['id'] = parsedId;
            debugPrint('ID converti avec succès: $parsedId');
          } else {
            debugPrint('ERREUR: Impossible de parser idClient: $idClientValue');
            return;
          }
        } else if (idClientValue is num) {
          clientDataFixed['id'] = idClientValue.toInt();
          debugPrint('ID converti depuis num: ${idClientValue.toInt()}');
        } else {
          debugPrint('ERREUR: Type inattendu pour idClient: ${idClientValue.runtimeType}');
          return;
        }
      }

      if (clientDataFixed.containsKey('dateCreation')) {
        final dateCreationValue = clientDataFixed['dateCreation'];
        if (dateCreationValue is! String) {
          clientDataFixed['dateCreation'] = dateCreationValue.toString();
          debugPrint('dateCreation converti en String');
        }
      } else {
        clientDataFixed['dateCreation'] = DateTime.now().toIso8601String();
        debugPrint('dateCreation par défaut ajouté');
      }

      if (clientDataFixed.containsKey('statut')) {
        final statutValue = clientDataFixed['statut'];
        if (statutValue is String) {
          clientDataFixed['statut'] =
              statutValue.toLowerCase() == 'true' || statutValue == '1';
        } else if (statutValue is int) {
          clientDataFixed['statut'] = statutValue == 1;
        } else if (statutValue is! bool) {
          clientDataFixed['statut'] = true;
        }
        debugPrint('Statut converti: ${clientDataFixed['statut']}');
      } else {
        clientDataFixed['statut'] = true;
        debugPrint('Statut par défaut: true');
      }

      debugPrint('Création de l\'objet Client...');
      final client = Client.fromJson(clientDataFixed);
      debugPrint('Client créé: ${client.nom} ${client.prenom} (ID: ${client.id})');
      
      setState(() {
        _selectedClient = client;
        _nomController.text = client.nom;
        _prenomController.text = client.prenom;
        _emailController.text = client.email ?? '';
        _telephoneController.text = client.telephone ?? '';
        _pieceIdentiteController.text = client.pieceIdentite ?? '';
        _selectedGenre = client.genre ?? 'M';
        if (client.dateNaissance != null) {
          _dateNaissance = client.dateNaissance;
          _dateNaissanceController.text = DateFormat(
            'yyyy-MM-dd',
          ).format(client.dateNaissance!);
        }
        _searchResults = [];
        _searchClientController.clear();
      });
      
      debugPrint('Formulaire pré-rempli avec les données du client');
      debugPrint('=== FIN SELECTION CLIENT (SUCCES) ===');
    } catch (e, stackTrace) {
      debugPrint('=== ERREUR SELECTION CLIENT ===');
      debugPrint('Erreur: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('===============================');
    }
  }

  Future<void> _saveClient() async {
    debugPrint('=== DEBUT CREATION CLIENT ===');
    
    if (!_formKey.currentState!.validate()) {
      debugPrint('Validation du formulaire échouée');
      return;
    }

    debugPrint('Formulaire validé avec succès');
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = locator.authRepository.currentUser;
      debugPrint('Utilisateur actuel: ${currentUser?.nomComplet}');
      debugPrint('Site ID: ${currentUser?.idSite}');
      
      final clientData = {
        'nom': _nomController.text,
        'prenom': _prenomController.text,
        'email': _emailController.text.isNotEmpty
            ? _emailController.text
            : null,
        'telephone': _telephoneController.text.isNotEmpty
            ? _telephoneController.text
            : null,
        'pieceIdentite': _pieceIdentiteController.text.isNotEmpty
            ? _pieceIdentiteController.text
            : null,
        'genre': _selectedGenre,
        'dateNaissance': _dateNaissance?.toIso8601String(),
        'statut': true,
        'idSite': int.tryParse(currentUser?.idSite ?? '1') ?? 1,
      };

      debugPrint('Données du client à créer:');
      debugPrint('  - Nom: ${clientData['nom']}');
      debugPrint('  - Prénom: ${clientData['prenom']}');
      debugPrint('  - Email: ${clientData['email']}');
      debugPrint('  - Téléphone: ${clientData['telephone']}');
      debugPrint('  - Pièce d\'identité: ${clientData['pieceIdentite']}');
      debugPrint('  - Genre: ${clientData['genre']}');
      debugPrint('  - Date de naissance: ${clientData['dateNaissance']}');
      debugPrint('  - Statut: ${clientData['statut']}');
      debugPrint('  - ID Site: ${clientData['idSite']}');

      debugPrint('Envoi de la requête API...');
      final response = await locator.apiService.createClient(clientData);
      debugPrint('Réponse API reçue: $response');
      
      // Convertir idClient en id si nécessaire
      if (response.containsKey('idClient') && !response.containsKey('id')) {
        final idClientValue = response['idClient'];
        debugPrint('Conversion idClient vers id: $idClientValue (${idClientValue.runtimeType})');
        
        if (idClientValue is String) {
          response['id'] = int.parse(idClientValue);
        } else if (idClientValue is num) {
          response['id'] = idClientValue.toInt();
        }
        debugPrint('ID converti: ${response['id']}');
      }
      
      // S'assurer que dateCreation est présent
      if (!response.containsKey('dateCreation') || response['dateCreation'] == null) {
        response['dateCreation'] = DateTime.now().toIso8601String();
        debugPrint('dateCreation ajouté par défaut');
      }
      
      // S'assurer que statut est un bool
      if (response.containsKey('statut') && response['statut'] is! bool) {
        final statutValue = response['statut'];
        if (statutValue is String) {
          response['statut'] = statutValue.toLowerCase() == 'true' || statutValue == '1';
        } else if (statutValue is int) {
          response['statut'] = statutValue == 1;
        }
        debugPrint('Statut converti: ${response['statut']}');
      }
      
      debugPrint('Données après conversion: $response');
      
      // Gérer dateNaissance qui peut être null
      if (response.containsKey('dateNaissance') && response['dateNaissance'] == null) {
        debugPrint('dateNaissance est null, sera ignoré');
      }
      
      final client = Client.fromJson(response);
      debugPrint('Client créé avec succès:');
      debugPrint('  - ID: ${client.id}');
      debugPrint('  - Nom complet: ${client.nom} ${client.prenom}');
      debugPrint('  - Email: ${client.email}');
      debugPrint('  - Téléphone: ${client.telephone}');

      if (!mounted) {
        debugPrint('Widget non monté, abandon de la navigation');
        return;
      }

      debugPrint('Retour à l\'écran précédent avec le client créé');
      // Return the created client to the previous screen
      Navigator.of(context).pop(client);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Client créé avec succès'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      
      debugPrint('=== FIN CREATION CLIENT (SUCCES) ===');
    } catch (e, stackTrace) {
      debugPrint('=== ERREUR CREATION CLIENT ===');
      debugPrint('Erreur: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('==============================');
      
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la création du client: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        debugPrint('État de chargement désactivé');
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Color(0xFF1E3C72)),
            hintText: 'Entrez $label',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFF1E3C72), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          ),
          style: GoogleFonts.poppins(fontSize: 16),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color(0xFF1E3C72),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Créer un client',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Client search section
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rechercher un client existant',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchClientController,
                                  decoration: InputDecoration(
                                    hintText: 'Nom ou email',
                                    prefixIcon: Icon(Icons.search),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  onChanged: (value) {
                                    if (value.length >= 2) {
                                      _searchClients(value);
                                    } else {
                                      setState(() {
                                        _searchResults = [];
                                      });
                                    }
                                  },
                                ),
                              ),
                              SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.clear),
                                onPressed: () {
                                  _searchClientController.clear();
                                  setState(() {
                                    _searchResults = [];
                                    _selectedClient = null;
                                  });
                                },
                              ),
                            ],
                          ),
                          if (_searchResults.isNotEmpty) ...[
                            SizedBox(height: 12),
                            Container(
                              constraints: BoxConstraints(maxHeight: 200),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _searchResults.length,
                                itemBuilder: (context, index) {
                                  final client = _searchResults[index];
                                  final clientName =
                                      '${client['nom'] ?? ''} ${client['prenom'] ?? ''}'
                                          .trim();
                                  final clientEmail = client['email'] ?? '';
                                  final clientId =
                                      int.tryParse(
                                        client['idClient']?.toString() ?? '0',
                                      ) ??
                                      0;
                                  final isSelected =
                                      _selectedClient != null &&
                                      _selectedClient!.id == clientId;

                                  return ListTile(
                                    title: Text(clientName),
                                    subtitle: clientEmail.isNotEmpty
                                        ? Text(clientEmail)
                                        : null,
                                    trailing: isSelected
                                        ? Icon(
                                            Icons.check_circle,
                                            color: Colors.green,
                                          )
                                        : null,
                                    onTap: () {
                                      _selectClientFromSearch(client);
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    // Selected client display
                    if (_selectedClient != null) ...[
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.person, color: Colors.green[700]),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_selectedClient!.nom} ${_selectedClient!.prenom}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[900],
                                    ),
                                  ),
                                  if (_selectedClient!.email != null &&
                                      _selectedClient!.email!.isNotEmpty)
                                    Text(
                                      _selectedClient!.email!,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  _selectedClient = null;
                                  _searchClientController.clear();
                                  _searchResults = [];
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),
                      Divider(),
                      SizedBox(height: 24),
                      Text(
                        'OU créer un nouveau client',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: 24),
                    ],

                    _buildTextField(
                      controller: _nomController,
                      label: 'Nom',
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Requis';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _prenomController,
                      label: 'Prénom',
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Requis';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20),

                    _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    SizedBox(height: 20),

                    _buildTextField(
                      controller: _telephoneController,
                      label: 'Téléphone',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    SizedBox(height: 20),

                    _buildTextField(
                      controller: _pieceIdentiteController,
                      label: 'Pièce d\'identité',
                      icon: Icons.badge_outlined,
                    ),
                    SizedBox(height: 20),

                    DropdownButtonFormField<String>(
                      value: _selectedGenre,
                      decoration: InputDecoration(
                        labelText: 'Genre',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      items: [
                        DropdownMenuItem(value: 'M', child: Text('Masculin')),
                        DropdownMenuItem(value: 'F', child: Text('Féminin')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedGenre = value;
                          });
                        }
                      },
                    ),
                    SizedBox(height: 20),

                    TextFormField(
                      controller: _dateNaissanceController,
                      decoration: InputDecoration(
                        labelText: 'Date de naissance',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      readOnly: true,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().subtract(
                            Duration(days: 365 * 25),
                          ),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _dateNaissance = picked;
                            _dateNaissanceController.text = DateFormat(
                              'yyyy-MM-dd',
                            ).format(picked);
                          });
                        }
                      },
                    ),
                    SizedBox(height: 20),

                    _buildTextField(
                      controller: _quartierController,
                      label: 'Quartier',
                      icon: Icons.location_on_outlined,
                    ),
                    SizedBox(height: 20),

                    _buildTextField(
                      controller: _avenueController,
                      label: 'Avenue',
                      icon: Icons.streetview_outlined,
                    ),
                    SizedBox(height: 20),

                    _buildTextField(
                      controller: _numeroController,
                      label: 'Numéro',
                      icon: Icons.numbers_outlined,
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),

          // Bottom action buttons
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.of(context).pop();
                          },
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      'Annuler',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 15),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveClient,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF1E3C72),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Enregistrer',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
