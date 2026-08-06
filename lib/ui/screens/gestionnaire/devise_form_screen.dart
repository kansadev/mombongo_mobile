import 'package:flutter/material.dart';
import 'package:mombongo/models/devise_model.dart';
import 'package:mombongo/services/api_service.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/utils/api_error_message.dart';

class DeviseFormScreen extends StatefulWidget {
  final Devise? devise;
  final int idSite;

  const DeviseFormScreen({
    super.key,
    this.devise,
    required this.idSite,
  });

  @override
  DeviseFormScreenState createState() => DeviseFormScreenState();
}

class DeviseFormScreenState extends State<DeviseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = locator.apiService;
  
  late TextEditingController _codeController;
  late TextEditingController _nomController;
  late TextEditingController _symboleController;
  late TextEditingController _descriptionController;
  late TextEditingController _tauxController;
  late bool _estActive;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.devise?.code ?? '');
    _nomController = TextEditingController(text: widget.devise?.nom ?? '');
    _symboleController = TextEditingController(text: widget.devise?.symbole ?? '');
    _descriptionController = TextEditingController(text: widget.devise?.description ?? '');
    _tauxController = TextEditingController(
      text: widget.devise?.tauxActuel.toString() ?? '',
    );
    _estActive = widget.devise?.estActive ?? true;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nomController.dispose();
    _symboleController.dispose();
    _descriptionController.dispose();
    _tauxController.dispose();
    super.dispose();
  }

  Future<void> _saveDevise() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final devise = Devise(
        idDevise: widget.devise?.idDevise ?? 0,
        code: _codeController.text.toUpperCase(),
        nom: _nomController.text,
        symbole: _symboleController.text,
        description: _descriptionController.text,
        idSite: widget.idSite,
        tauxActuel: double.parse(_tauxController.text).toString(),
        dateCreation: widget.devise?.dateCreation ?? DateTime.now(),
        dateModification: DateTime.now(),
        estActive: _estActive,
      );

      if (widget.devise == null) {
        await _apiService.createDevise(devise);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Devise créée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        await _apiService.updateDevise(widget.devise!.idDevise, devise);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Devise modifiée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(apiErrorUserMessage(e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.devise != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Modifier la devise' : 'Nouvelle devise'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple.shade50, Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _codeController,
                          decoration: InputDecoration(
                            labelText: 'Code devise',
                            hintText: 'Ex: USD, EUR, XAF',
                            prefixIcon: const Icon(Icons.code),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          textCapitalization: TextCapitalization.characters,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Le code est requis';
                            }
                            if (value.length < 2 || value.length > 5) {
                              return 'Le code doit contenir 2 à 5 caractères';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nomController,
                          decoration: InputDecoration(
                            labelText: 'Nom de la devise',
                            hintText: 'Ex: Dollar Américain',
                            prefixIcon: const Icon(Icons.abc),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Le nom est requis';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _symboleController,
                                decoration: InputDecoration(
                                  labelText: 'Symbole',
                                  hintText: 'Ex: \$, €',
                                  prefixIcon: const Icon(Icons.attach_money),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Le symbole est requis';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _tauxController,
                                decoration: InputDecoration(
                                  labelText: 'Taux actuel',
                                  prefixIcon: const Icon(Icons.trending_up),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Le taux est requis';
                                  }
                                  if (double.tryParse(value) == null) {
                                    return 'Valeur numérique requise';
                                  }
                                  if (double.parse(value) <= 0) {
                                    return 'Le taux doit être positif';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            labelText: 'Description',
                            hintText: 'Description de la devise...',
                            prefixIcon: const Icon(Icons.description),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 20),
                        SwitchListTile(
                          title: const Text('Devise active'),
                          subtitle: const Text('Décocher pour désactiver'),
                          value: _estActive,
                          onChanged: (value) {
                            setState(() {
                              _estActive = value;
                            });
                          },
                          secondary: Icon(
                            _estActive ? Icons.check_circle : Icons.block,
                            color: _estActive ? Colors.green : Colors.red,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveDevise,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            isEditing ? 'Mettre à jour' : 'Créer la devise',
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}