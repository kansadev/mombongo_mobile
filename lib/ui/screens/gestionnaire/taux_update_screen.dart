import 'package:flutter/material.dart';
import 'package:mombongo/models/devise_model.dart';
import 'package:mombongo/services/api_service.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/utils/api_error_message.dart';


class TauxUpdateScreen extends StatefulWidget {
  final Devise devise;

  const TauxUpdateScreen({super.key, required this.devise});

  @override
  TauxUpdateScreenState createState() => TauxUpdateScreenState();
}

class TauxUpdateScreenState extends State<TauxUpdateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = locator.apiService;
  
  late TextEditingController _tauxController;
  late TextEditingController _raisonController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tauxController = TextEditingController(
      text: widget.devise.tauxActuel.toString(),
    );
    _raisonController = TextEditingController();
  }

  @override
  void dispose() {
    _tauxController.dispose();
    _raisonController.dispose();
    super.dispose();
  }

  Future<void> _updateTaux() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _apiService.updateTaux(
        widget.devise.idDevise,
        double.parse(_tauxController.text),
        _raisonController.text,

      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Taux mis à jour avec succès'),
          backgroundColor: Colors.green,
        ),
      );

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
    return Scaffold(
      appBar: AppBar(
        title: Text('Mise à jour du taux - ${widget.devise.code}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
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
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    widget.devise.symbole ?? widget.devise.code[0],
                                    style: const TextStyle(
                                      fontSize: 24,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.devise.code,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      widget.devise.nom,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'Taux actuel',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    widget.devise.tauxActuel,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _tauxController,
                          decoration: InputDecoration(
                            labelText: 'Nouveau taux',
                            hintText: 'Entrez le nouveau taux',
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
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _raisonController,
                          decoration: InputDecoration(
                            labelText: 'Raison du changement',
                            hintText: 'Ex: Mise à jour marché, dévaluation, etc.',
                            prefixIcon: const Icon(Icons.note),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          maxLines: 2,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'La raison est requise';
                            }
                            return null;
                          },
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
                    onPressed: _isLoading ? null : _updateTaux,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Mettre à jour le taux',
                            style: TextStyle(fontSize: 16),
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