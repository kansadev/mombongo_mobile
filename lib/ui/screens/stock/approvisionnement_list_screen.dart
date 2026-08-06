import 'package:flutter/material.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/utils/api_error_message.dart';

class ApprovisionnementListScreen extends StatefulWidget {
  const ApprovisionnementListScreen({super.key});

  @override
  State<ApprovisionnementListScreen> createState() =>
      _ApprovisionnementListScreenState();
}

class _ApprovisionnementListScreenState
    extends State<ApprovisionnementListScreen> {
  List<Map<String, dynamic>> _approvisionnements = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String _errorMessage = '';
  int _pageNumber = 1;
  int _pageSize = 20;
  int _totalCount = 0;
  bool _hasNextPage = false;
  bool _hasPreviousPage = false;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _quantiteController = TextEditingController();
  final _provenanceController = TextEditingController();
  int? _selectedIdStock;

  // List of stocks for dropdown
  List<Map<String, dynamic>> _stocks = [];

  @override
  void initState() {
    super.initState();
    _loadApprovisionnements();
    _loadStocks();
  }

  @override
  void dispose() {
    _quantiteController.dispose();
    _provenanceController.dispose();
    super.dispose();
  }

  Future<void> _loadStocks() async {
    try {
      final currentUser = locator.authRepository.currentUser;
      if (currentUser == null) return;

      final idSite = int.tryParse(currentUser.idSite) ?? 0;
      if (idSite == 0) return;

      final stocks = await locator.apiService.getStockArticles(
        idSite: idSite,
        page: 1,
        pageSize: 100,
      );

      if (mounted) {
        setState(() {
          _stocks = stocks.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      debugPrint('Error loading stocks: $e');
    }
  }

  Future<void> _loadApprovisionnements({bool resetPage = false}) async {
    if (resetPage) {
      _pageNumber = 1;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final currentUser = locator.authRepository.currentUser;
      if (currentUser == null) throw Exception('Non authentifié');

      final idSite = int.tryParse(currentUser.idSite) ?? 0;
      if (idSite == 0) throw Exception('ID site invalide');

      final result = await locator.apiService.getApprovisionnementsBySite(
        idSite,
        pageNumber: _pageNumber,
        pageSize: _pageSize,
      );

      if (mounted) {
        setState(() {
          _approvisionnements =
              (result['data'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
          _totalCount = result['totalCount'] as int? ?? 0;
          _hasNextPage = result['hasNextPage'] as bool? ?? false;
          _hasPreviousPage = result['hasPreviousPage'] as bool? ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = apiErrorUserMessage(e);
        });
      }
    }
  }

  Future<void> _createApprovisionnement() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedIdStock == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un article')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final currentUser = locator.authRepository.currentUser;
      if (currentUser == null) throw Exception('Non authentifié');

      final idSite = int.tryParse(currentUser.idSite) ?? 0;

      final approvisionnementData = {
        'dateCreation': DateTime.now().toUtc().toIso8601String(),
        'dateLastModification': DateTime.now().toUtc().toIso8601String(),
        'statut': true,
        'idAppro': 0,
        'idStock': _selectedIdStock,
        'idSite': idSite,
        'quantiteAppro': int.tryParse(_quantiteController.text) ?? 0,
        'provenance': _provenanceController.text,
        'dateAppro': DateTime.now().toUtc().toIso8601String(),
      };

      await locator.apiService.createApprovisionnement(approvisionnementData);

      if (mounted) {
        Navigator.of(context).pop();
        _loadApprovisionnements();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Approvisionnement créé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _updateApprovisionnement(Map<String, dynamic> approvisionnement) async {
    final quantiteController = TextEditingController(
      text: approvisionnement['quantiteAppro'].toString(),
    );
    final provenanceController = TextEditingController(
      text: approvisionnement['provenance'] ?? '',
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier l\'approvisionnement'),
        content: Form(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: quantiteController,
                decoration: const InputDecoration(
                  labelText: 'Quantité',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: provenanceController,
                decoration: const InputDecoration(
                  labelText: 'Provenance',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop({
                'quantiteAppro': int.tryParse(quantiteController.text) ?? 0,
                'provenance': provenanceController.text,
              });
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() => _isSaving = true);

      try {
        final idAppro = approvisionnement['idAppro'] as int;

        final updateData = {
          ...approvisionnement,
          'dateLastModification': DateTime.now().toUtc().toIso8601String(),
          'quantiteAppro': result['quantiteAppro'],
          'provenance': result['provenance'],
        };

        await locator.apiService.updateApprovisionnement(idAppro, updateData);

        if (mounted) {
          _loadApprovisionnements();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Approvisionnement mis à jour avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }

  void _showCreateDialog() {
    _selectedIdStock = null;
    _quantiteController.clear();
    _provenanceController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouvel approvisionnement'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: _selectedIdStock,
                  decoration: const InputDecoration(
                    labelText: 'Article',
                    border: OutlineInputBorder(),
                  ),
                  items: _stocks.map((stock) {
                    return DropdownMenuItem<int>(
                      value: _parseInt(stock['idStock']),
                      child: Text(stock['libelle'] ?? 'N/A'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedIdStock = value);
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Veuillez sélectionner un article';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _quantiteController,
                  decoration: const InputDecoration(
                    labelText: 'Quantité',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer une quantité';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Veuillez entrer un nombre valide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _provenanceController,
                  decoration: const InputDecoration(
                    labelText: 'Provenance',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer la provenance';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: _isSaving ? null : _createApprovisionnement,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Créer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Theme.of(context).colorScheme.onSecondary,
        elevation: 0,
        title: const Text(
          'Historique des approvisionnements',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateDialog,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Icon(
          Icons.add,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _approvisionnements.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty && _approvisionnements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage,
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadApprovisionnements(),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (_approvisionnements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun approvisionnement',
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Appuyez sur + pour créer un nouvel approvisionnement',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadApprovisionnements(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _approvisionnements.length,
              itemBuilder: (context, index) {
                return _buildApprovisionnementCard(_approvisionnements[index]);
              },
            ),
          ),
        ),
        _buildPagination(),
      ],
    );
  }

  Widget _buildApprovisionnementCard(Map<String, dynamic> approvisionnement) {
    final idAppro = _parseInt(approvisionnement['idAppro']);
    final quantite = _parseInt(approvisionnement['quantiteAppro']);
    final provenance = approvisionnement['provenance'] ?? 'N/A';
    final dateAppro = approvisionnement['dateAppro'] ?? '';
    final statut = approvisionnement['statut'] ?? true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _updateApprovisionnement(approvisionnement),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.arrow_downward,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Approvisionnement #$idAppro',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Quantité: $quantite',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Provenance: $provenance',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                      ),
                    ),
                    if (dateAppro.isNotEmpty)
                      Text(
                        'Date: ${_formatDate(dateAppro)}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                statut ? Icons.check_circle : Icons.cancel,
                color: statut ? Colors.green : Colors.red,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _hasPreviousPage
                ? () {
                    setState(() => _pageNumber--);
                    _loadApprovisionnements();
                  }
                : null,
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 16),
          Text(
            'Page $_pageNumber - Total: $_totalCount',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: _hasNextPage
                ? () {
                    setState(() => _pageNumber++);
                    _loadApprovisionnements();
                  }
                : null,
            icon: const Icon(Icons.arrow_forward),
          ),
        ],
      ),
    );
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }
}
