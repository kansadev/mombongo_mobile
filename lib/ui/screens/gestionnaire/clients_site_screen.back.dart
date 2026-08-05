import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/service_locator.dart';
import '../../../models/site.dart';

class ClientsSiteScreen extends StatefulWidget {
  const ClientsSiteScreen({super.key});

  @override
  State<ClientsSiteScreen> createState() => _ClientsSiteScreenState();
}

class _ClientsSiteScreenState extends State<ClientsSiteScreen> {
  List<Site> _sites = [];
  Site? _selectedSite;
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _clientsDuJour = [];
  bool _isLoadingSites = true;
  bool _isLoadingClients = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  Future<void> _loadSites() async {
    try {
      final currentUser = locator.authRepository.currentUser;
      if (currentUser == null) return;

      final idSociete = int.tryParse(currentUser.idSociete) ?? 0;
      final sites = await locator.apiService.getSitesBySociete(idSociete);

      if (mounted) {
        setState(() {
          _sites = sites;
          _isLoadingSites = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement des sites: $e');
      if (mounted) {
        setState(() {
          _isLoadingSites = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement des sites: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadClients() async {
    if (_selectedSite == null) return;

    setState(() {
      _isLoadingClients = true;
      _clients.clear();
      _clientsDuJour.clear();
    });

    try {
      final idSite = int.tryParse(_selectedSite!.idSite) ?? 0;
      final clients = await locator.apiService.getClientsBySite(idSite);

      if (!mounted) return;

      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);

      final List<Map<String, dynamic>> clientsDuJour = [];
      final List<Map<String, dynamic>> autresClients = [];

      for (var client in clients) {
        final dateCreationStr = client['dateCreation']?.toString();
        if (dateCreationStr != null) {
          try {
            final dateCreation = DateTime.parse(dateCreationStr);
            if (dateCreation.isAfter(todayStart) || dateCreation.isAtSameMomentAs(todayStart)) {
              clientsDuJour.add(Map<String, dynamic>.from(client));
            } else {
              autresClients.add(Map<String, dynamic>.from(client));
            }
          } catch (e) {
            debugPrint('Erreur parsing date: $e');
            autresClients.add(Map<String, dynamic>.from(client));
          }
        } else {
          autresClients.add(Map<String, dynamic>.from(client));
        }
      }

      setState(() {
        _clientsDuJour = clientsDuJour;
        _clients = autresClients;
        _isLoadingClients = false;
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement des clients: $e');
      if (mounted) {
        setState(() {
          _isLoadingClients = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement des clients: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredClients {
    if (_searchQuery.isEmpty) {
      return [..._clientsDuJour, ..._clients];
    }
    final query = _searchQuery.toLowerCase();
    return [..._clientsDuJour, ..._clients].where((client) {
      final nomComplet = client['nomComplet']?.toString().toLowerCase() ?? '';
      final email = client['email']?.toString().toLowerCase() ?? '';
      final telephone = client['telephone']?.toString().toLowerCase() ?? '';
      return nomComplet.contains(query) || email.contains(query) || telephone.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients par Site'),
        centerTitle: true,
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadSites();
          if (_selectedSite != null) {
            await _loadClients();
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sélection du site
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sélectionner un site',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _isLoadingSites
                          ? const Center(child: CircularProgressIndicator())
                          : DropdownButtonFormField<Site>(
                              value: _selectedSite,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              items: _sites.map((site) {
                                return DropdownMenuItem<Site>(
                                  value: site,
                                  child: Text(site.nomSite),
                                );
                              }).toList(),
                              onChanged: (Site? site) {
                                setState(() {
                                  _selectedSite = site;
                                  _clients.clear();
                                  _clientsDuJour.clear();
                                  _searchQuery = '';
                                });
                                if (site != null) {
                                  _loadClients();
                                }
                              },
                            ),
                    ],
                  ),
                ),
              ),

              if (_selectedSite != null) ...[
                const SizedBox(height: 16),

                // Barre de recherche
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Rechercher un client...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Statistiques
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        title: 'Total clients',
                        value: (_clientsDuJour.length + _clients.length).toString(),
                        icon: Icons.people,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        title: 'Clients du jour',
                        value: _clientsDuJour.length.toString(),
                        icon: Icons.today,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Liste des clients
                if (_isLoadingClients)
                  const Center(child: CircularProgressIndicator())
                else if (_filteredClients.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(Icons.person_off, size: 60, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun client trouvé',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ..._filteredClients.asMap().entries.map((entry) {
                    final index = entry.key;
                    final client = entry.value;
                    final isClientDuJour = index < _clientsDuJour.length;

                    return _buildClientCard(client, isClientDuJour);
                  }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
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

  Widget _buildClientCard(Map<String, dynamic> client, bool isClientDuJour) {
    final nomComplet = client['nomComplet']?.toString() ?? 'N/A';
    final email = client['email']?.toString() ?? '';
    final telephone = client['telephone']?.toString() ?? '';
    final dateCreationStr = client['dateCreation']?.toString();
    DateTime? dateCreation;
    if (dateCreationStr != null) {
      try {
        dateCreation = DateTime.parse(dateCreationStr);
      } catch (e) {
        debugPrint('Erreur parsing date: $e');
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isClientDuJour ? 4 : 2,
      color: isClientDuJour ? Colors.green[50] : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isClientDuJour ? Colors.green : const Color(0xFF3498DB),
          child: Text(
            nomComplet.isNotEmpty ? nomComplet[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                nomComplet,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isClientDuJour ? Colors.green[900] : null,
                ),
              ),
            ),
            if (isClientDuJour)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Aujourd\'hui',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (email.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.email, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      email,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (telephone.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    telephone,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
            if (dateCreation != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Inscrit le ${DateFormat('dd/MM/yyyy').format(dateCreation)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ],
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.info_outline),
          onPressed: () {
            _showClientDetails(client);
          },
        ),
      ),
    );
  }

  void _showClientDetails(Map<String, dynamic> client) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(client['nomComplet']?.toString() ?? 'Détails du client'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Nom complet', client['nomComplet']?.toString() ?? 'N/A'),
              _buildDetailRow('Genre', client['genre']?.toString() ?? 'N/A'),
              _buildDetailRow('Email', client['email']?.toString() ?? 'N/A'),
              _buildDetailRow('Téléphone', client['telephone']?.toString() ?? 'N/A'),
              _buildDetailRow('Adresse', client['adresseClient']?.toString() ?? 'N/A'),
              _buildDetailRow('Pièce d\'identité', client['pieceIdentite']?.toString() ?? 'N/A'),
              _buildDetailRow('Site', client['nomSite']?.toString() ?? 'N/A'),
              if (client['dateCreation'] != null)
                _buildDetailRow(
                  'Date de création',
                  DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(client['dateCreation'])),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
