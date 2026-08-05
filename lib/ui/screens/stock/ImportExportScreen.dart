import 'package:flutter/material.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/models/article.dart';

class ImportExportScreen extends StatefulWidget {
  const ImportExportScreen({super.key});

  @override
  State<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends State<ImportExportScreen> {
  bool _includeArticles = true;
  bool _includeServices = true;
  String _filterMode = 'all'; // 'all', 'articles', 'services'
  List<Article> _articles = <Article>[];
  bool _isLoading = true;
  String _errorMessage = '';
  
  // Mock services data for now
  final List<Map<String, dynamic>> _services = [
    {
      'name': 'Installation électrique',
      'type': 'Service',
      'rate': 15000.00,
      'duration': '2 heures',
    },
    {
      'name': 'Maintenance informatique',
      'type': 'Service',
      'rate': 8000.00,
      'duration': '1 heure',
    },
    {
      'name': 'Conseil en gestion',
      'type': 'Service',
      'rate': 25000.00,
      'duration': '4 heures',
    },
  ];
  
  int get _selectedCount {
    int count = 0;
    if (_filterMode == 'all' || _filterMode == 'articles') {
      count += _includeArticles ? _articles.length : 0;
    }
    if (_filterMode == 'all' || _filterMode == 'services') {
      count += _includeServices ? _services.length : 0;
    }
    return count;
  }

  @override
  void initState() {
    super.initState();
    _loadArticles();
  }

  Future<void> _loadArticles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Get society ID from authenticated user
      final currentUser = locator.authRepository.currentUser;
      
      if (currentUser == null) {
        throw Exception('Utilisateur non authentifié');
      }
      
      final societyId = int.tryParse(currentUser.idSociete) ?? 1;
      
      if (societyId <= 0) {
        throw Exception('ID société invalide: ${currentUser.idSociete}');
      }
      
      print('Fetching articles for Import/Export screen (society ID: $societyId)');
      
      // Force refresh to bypass potentially corrupted cache
      final articles = await locator.cacheStrategy.getArticlesBySociete(
        societyId,
        withStock: true,
        forceRefresh: true,  // Force API call to bypass cache
      );
      
      setState(() {
        _articles = articles;
        _isLoading = false;
      });
      
      print('Loaded ${articles.length} articles for Import/Export');
      
    } catch (e, stackTrace) {
      print('=== ImportExportScreen Error ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      print('================================');
      
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      
      if (mounted) {
        final currentUser = locator.authRepository.currentUser;
        final societyInfo = currentUser != null 
            ? 'Société #${currentUser.idSociete}' 
            : 'Société inconnue';
            
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur chargement articles ($societyInfo): $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import / Export'),
        centerTitle: true,
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titre principal
              const Center(
                child: Text(
                  'Import / Export articles & services',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Section Sélection des types
              const Text(
                'Sélectionnez les types à inclure',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Checkbox Articles
                    CheckboxListTile(
                      value: _includeArticles,
                      onChanged: (value) {
                        setState(() {
                          _includeArticles = value ?? false;
                        });
                      },
                      activeColor: const Color(0xFF3498DB),
                      title: const Text(
                        'Articles',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Produits physiques en stock',
                        style: TextStyle(fontSize: 14),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    
                    Divider(color: Colors.grey[300]),
                    
                    // Checkbox Services
                    CheckboxListTile(
                      value: _includeServices,
                      onChanged: (value) {
                        setState(() {
                          _includeServices = value ?? false;
                        });
                      },
                      activeColor: const Color(0xFF3498DB),
                      title: const Text(
                        'Services',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Prestations et services',
                        style: TextStyle(fontSize: 14),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Filter buttons
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey[300]!,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildFilterButton('Tout', 'all'),
                    _buildFilterButton('Articles', 'articles'),
                    _buildFilterButton('Services', 'services'),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Note
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'Choisissez les catégories à inclure avant de lancer l\'import ou l\'export.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Ligne de séparation
              Divider(
                color: Colors.grey[300],
                thickness: 1,
              ),
              
              const SizedBox(height: 24),
              
              // Section Aperçu des données
              const Text(
                'Aperçu des données',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Compteur d'éléments
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '{$_selectedCount} élément(s) dans la sélection',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                    Icon(
                      Icons.inventory,
                      color: Colors.blue[600],
                      size: 28,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Loading indicator
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Chargement des articles...'),
                      ],
                    ),
                  ),
                )
              // Error message
              else if (_errorMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 60,
                        color: Colors.red[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Erreur: $_errorMessage',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.red[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadArticles,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              // Liste des produits
              else
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Articles section
                      if (_includeArticles && _articles.isNotEmpty && (_filterMode == 'all' || _filterMode == 'articles')) ...[
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'ARTICLES',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                        ),
                        ..._articles.map((article) => _buildArticleItem(article)).toList(),
                        const Divider(height: 1),
                      ],
                      // Services section
                      if (_includeServices && _services.isNotEmpty && (_filterMode == 'all' || _filterMode == 'services')) ...[
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'SERVICES',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                        ),
                        ..._services.map((service) => _buildServiceItem(service)).toList(),
                      ],
                      // Empty state
                      if (((_includeArticles && _articles.isEmpty) || (_filterMode == 'services')) && 
                          ((_includeServices && _services.isEmpty) || (_filterMode == 'articles')))
                        Container(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 60,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Aucune donnée à afficher',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sélectionnez des catégories à inclure',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 16),
              
              // Total des lignes
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey[300]!,
                    width: 1,
                  ),
                ),
                child: Text(
                  'Données chargées ($_selectedCount lignes)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Boutons d'action
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showImportDialog(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2ECC71),
                        padding: const EdgeInsets.symmetric(
                          vertical: 18,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.upload_file, color: Colors.white),
                      label: const Text(
                        'IMPORTER',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showExportDialog(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3498DB),
                        padding: const EdgeInsets.symmetric(
                          vertical: 18,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.download, color: Colors.white),
                      label: const Text(
                        'EXPORTER',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildFilterButton(String label, String mode) {
    final isSelected = _filterMode == mode;
    
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _filterMode = mode;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected 
            ? const Color(0xFF3498DB) 
            : Colors.white,
        foregroundColor: isSelected 
            ? Colors.white 
            : const Color(0xFF3498DB),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: const Color(0xFF3498DB),
            width: 1.5,
          ),
        ),
        elevation: isSelected ? 2 : 0,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
  
  Widget _buildArticleItem(Article article) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  article.libelle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Article',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Article details
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ID: ${article.idArticle}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'TVA: ${article.tva}%',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Périssable: ${article.perissable ? 'Oui' : 'Non'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Statut: ${article.statut ? 'Actif' : 'Inactif'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: article.statut ? Colors.green[600] : Colors.red[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Checkbox de sélection
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Row(
              children: [
                Checkbox(
                  value: true,
                  onChanged: (value) {
                    // Gérer la sélection individuelle
                  },
                  activeColor: const Color(0xFF3498DB),
                ),
                const SizedBox(width: 8),
                Text(
                  'Inclure dans l\'export',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildServiceItem(Map<String, dynamic> service) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  service['name'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Service',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.purple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Service details
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tarif: ${_formatCurrency(service['rate'])} CDF',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Durée: ${service['duration']}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Checkbox de sélection
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Row(
              children: [
                Checkbox(
                  value: true,
                  onChanged: (value) {
                    // Gérer la sélection individuelle
                  },
                  activeColor: const Color(0xFF3498DB),
                ),
                const SizedBox(width: 8),
                Text(
                  'Inclure dans l\'export',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
  }
  
  void _showImportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importer des données'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sélectionnez le fichier à importer:'),
            SizedBox(height: 8),
            Text('• Format supporté: Excel (.xlsx), CSV'),
            SizedBox(height: 4),
            Text('• Taille maximale: 10 MB'),
            SizedBox(height: 4),
            Text('• Structure: Articles, Services'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ANNULER'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Colors.green,
                  content: Text('Import lancé avec succès'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2ECC71),
            ),
            child: const Text('IMPORTER'),
          ),
        ],
      ),
    );
  }
  
  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exporter des données'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choisissez le format d\'export:'),
            SizedBox(height: 8),
            Text('• Excel (.xlsx)'),
            SizedBox(height: 4),
            Text('• CSV'),
            SizedBox(height: 4),
            Text('• PDF'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ANNULER'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Colors.blue,
                  content: Text('Export lancé avec succès'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3498DB),
            ),
            child: const Text('EXPORTER'),
          ),
        ],
      ),
    );
  }
}