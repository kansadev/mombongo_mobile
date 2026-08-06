import 'package:flutter/material.dart';
import 'package:mombongo/models/devise_model.dart';
import 'package:mombongo/services/api_service.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/ui/screens/gestionnaire/devise_form_screen.dart';
import 'package:mombongo/ui/screens/gestionnaire/taux_update_screen.dart';
import 'package:mombongo/ui/widgets/devise_card.dart';
import 'package:mombongo/ui/widgets/loading_widget.dart';
import 'package:mombongo/utils/api_error_message.dart';

class DeviseListScreen extends StatefulWidget {
  final int idSite;
  final String siteName;

  const DeviseListScreen({
    super.key,
    required this.idSite,
    required this.siteName,
  });

  @override
  DeviseListScreenState createState() => DeviseListScreenState();
}

class DeviseListScreenState extends State<DeviseListScreen> {
  final ApiService _apiService = locator.apiService;
  late Future<DeviseSiteResponse> _devisesFuture;
  bool _showActivesOnly = true;

  @override
  void initState() {
    super.initState();
    _loadDevises();
  }

  void _loadDevises() {
    setState(() {
      _devisesFuture = _apiService.getDevisesBySite(
        widget.idSite,
        actives: _showActivesOnly,
      );
    });
  }

  Future<void> _toggleDeviseStatus(Devise devise) async {
    try {
      await _apiService.updateStatut(devise.idDevise!, !devise.estActive);
      _loadDevises();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Statut de ${devise.code} mis à jour'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(apiErrorUserMessage(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteDevise(Devise devise) async {
    // Note: L'API ne semble pas avoir d'endpoint DELETE
    // On utilise plutôt la désactivation
    await _toggleDeviseStatus(devise);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Devises - ${widget.siteName}'),
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showActivesOnly ? Icons.visibility : Icons.visibility_off),
            onPressed: () {
              setState(() {
                _showActivesOnly = !_showActivesOnly;
                _loadDevises();
              });
            },
            tooltip: _showActivesOnly ? 'Masquer les inactives' : 'Afficher toutes',
          ),
        ],
      ),
      body: FutureBuilder<DeviseSiteResponse>(
        future: _devisesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingWidget();
          }
      
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Erreur de chargement',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadDevises,
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }
      
          final data = snapshot.data!;
          
          if (data.devises.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.currency_exchange, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune devise trouvée',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Commencez par ajouter une nouvelle devise',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }
      
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total des devises: ${data.totalDevises}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _showActivesOnly ? 'Actives' : 'Toutes',
                            style: TextStyle(
                              color: Colors.deepPurple.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: data.devises.length,
                  itemBuilder: (context, index) {
                    final devise = data.devises[index];
                    return DeviseCard(
                      devise: devise,
                      onEdit: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DeviseFormScreen(
                              devise: devise,
                              idSite: widget.idSite,
                            ),
                          ),
                        );
                        if (result == true) _loadDevises();
                      },
                      onDelete: () => _showDeleteDialog(devise),
                      onUpdateTaux: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TauxUpdateScreen(devise: devise),
                          ),
                        );
                        if (result == true) _loadDevises();
                      },
                      onToggleStatus: () => _toggleDeviseStatus(devise),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DeviseFormScreen(
                idSite: widget.idSite,
              ),
            ),
          );
          if (result == true) _loadDevises();
        },
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle devise'),
        backgroundColor: Colors.deepPurple,
      ),
    );
  }

  void _showDeleteDialog(Devise devise) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Désactiver la devise'),
          content: Text(
            'Voulez-vous vraiment désactiver ${devise.code} - ${devise.nom} ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteDevise(devise);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Désactiver'),
            ),
          ],
        );
      },
    );
  }
}