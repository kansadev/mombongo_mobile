import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/service_locator.dart';
import 'utilisateur_detail_screen.dart';
import 'new_user_screen.dart';

class UtilisateursScreen extends StatefulWidget {
  const UtilisateursScreen({super.key});

  @override
  State<UtilisateursScreen> createState() => _UtilisateursScreenState();
}

class _UtilisateursScreenState extends State<UtilisateursScreen> {
  List<Map<String, dynamic>> _utilisateurs = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUtilisateurs();
  }

  Future<void> _loadUtilisateurs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Récupérer l'utilisateur connecté pour obtenir l'ID du site
      final currentUser = locator.authRepository.currentUser;
      if (currentUser == null) {
        throw Exception('Aucun utilisateur connecté');
      }
      
      final siteId = int.tryParse(currentUser.idSite) ?? 0;
      debugPrint('Chargement des utilisateurs pour le site ID: $siteId');
      
      // Utiliser la nouvelle méthode qui inclut les Admin/Super Admin
      final utilisateurs = await locator.apiService.getAllUtilisateursBySite(siteId);

      // filtrage selon le rôle de l'utilisateur connecté
      final userRole = currentUser.role.toUpperCase();
      List<Map<String, dynamic>> visible;
      if (userRole == 'GESTIONNAIRE') {
        // gestionnaire : ne voit que les caissiers de son site
        visible = utilisateurs
            .where((u) => (u['role'] as String?)?.toUpperCase() == 'CAISSIER')
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else if (userRole.contains('ADMIN')) {
        // administrateur : voit gestionnaires + caissiers mais pas super-admin
        visible = utilisateurs
            .where((u) {
              final r = (u['role'] as String?)?.toUpperCase() ?? '';
              return r == 'CAISSIER' || r == 'GESTIONNAIRE';
            })
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else {
        // autres rôles n'ont pas accès, mais on affiche rien plutôt que planter
        visible = [];
      }

      if (mounted) {
        setState(() {
          _utilisateurs = visible;
          _isLoading = false;
        });
        debugPrint('Utilisateurs chargés: ${_utilisateurs.length} (après filtrage)');
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement des utilisateurs: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement des utilisateurs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredUtilisateurs {
    if (_searchQuery.isEmpty) {
      return _utilisateurs;
    }
    final query = _searchQuery.toLowerCase();
    return _utilisateurs.where((user) {
      final nom = user['nomUtilisateur']?.toString().toLowerCase() ?? '';
      final prenom = user['prenomUtilisateur']?.toString().toLowerCase() ?? '';
      final postNom = user['postNomUtilisateur']?.toString().toLowerCase() ?? '';
      final login = user['login']?.toString().toLowerCase() ?? '';
      final email = user['email']?.toString().toLowerCase() ?? '';
      return nom.contains(query) ||
          prenom.contains(query) ||
          postNom.contains(query) ||
          login.contains(query) ||
          email.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Utilisateurs'),
        centerTitle: true,
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              _showAddUtilisateurDialog();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUtilisateurs,
        child: Column(
          children: [
            // Barre de recherche
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Rechercher un utilisateur...',
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

            // Statistiques
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Total utilisateurs',
                      value: _utilisateurs.length.toString(),
                      icon: Icons.people,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Actifs',
                      value: _utilisateurs.where((u) => u['statut'] == true).length.toString(),
                      icon: Icons.check_circle,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Liste des utilisateurs
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredUtilisateurs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_off, size: 60, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'Aucun utilisateur trouvé',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredUtilisateurs.length,
                          itemBuilder: (context, index) {
                            final utilisateur = _filteredUtilisateurs[index];
                            return _buildUtilisateurCard(utilisateur);
                          },
                        ),
            ),
          ],
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
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

  Widget _buildUtilisateurCard(Map<String, dynamic> utilisateur) {

    final nomComplet = utilisateur['nomComplet']?.toString();
    final login = utilisateur['login']?.toString() ?? 'N/A';
    final email = utilisateur['email']?.toString() ?? '';
    final telephone = utilisateur['numeroTelephone']?.toString() ?? '';
    final statut = utilisateur['statut'] == true;
    final isConnected = utilisateur['isConnected'] == true;
    final dateCreationStr = utilisateur['dateCreation']?.toString();
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
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UtilisateurDetailScreen(utilisateur: utilisateur),
            ),
          );
        },
        child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statut ? Colors.green : Colors.grey,
          child: Text(
            nomComplet != null ? nomComplet[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                nomComplet ?? login,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (isConnected)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            Text('Login: $login', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            if (email.isNotEmpty)
              Text('Email: $email', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            if (telephone.isNotEmpty)
              Text('Tél: $telephone', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            if (dateCreation != null)
              Text(
                'Créé le ${DateFormat('dd/MM/yyyy').format(dateCreation)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
        trailing: PopupMenuButton(
          onSelected: (value) {
            // Empêcher la navigation lors du clic sur le menu
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              child: const Row(
                children: [
                  Icon(Icons.edit, size: 18),
                  SizedBox(width: 8),
                  Text('Modifier'),
                ],
              ),
              onTap: () {
                Future.delayed(const Duration(milliseconds: 100), () {
                  _showEditUtilisateurDialog(utilisateur);
                });
              },
            ),
            PopupMenuItem(
              child: Row(
                children: [
                  Icon(statut ? Icons.block : Icons.check_circle, size: 18),
                  const SizedBox(width: 8),
                  Text(statut ? 'Désactiver' : 'Activer'),
                ],
              ),
              onTap: () {
                Future.delayed(const Duration(milliseconds: 100), () {
                  _toggleStatut(utilisateur);
                });
              },
            ),
            
          ],
        ),
      ),
      ),
    );
  }

  void _showAddUtilisateurDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NewUserScreen(),
      ),
    ).then((success) {
      if (success == true) {
        _loadUtilisateurs();
      }
    });
  }

  void _showEditUtilisateurDialog(Map<String, dynamic> utilisateur) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Modification d\'utilisateur - À implémenter')),
    );
  }

  Future<void> _toggleStatut(Map<String, dynamic> utilisateur) async {
    try {
      final id = int.tryParse(utilisateur['idUtilisateur']?.toString() ?? '0') ?? 0;
      final nouveauStatut = !(utilisateur['statut'] == true);

      // Utiliser l'endpoint /api/Utilisateurs/{id}/statut avec PUT
      await locator.apiService.updateUtilisateurStatut(id, nouveauStatut);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Utilisateur ${nouveauStatut ? 'activé' : 'désactivé'} avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        _loadUtilisateurs();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(Map<String, dynamic> utilisateur) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer l\'utilisateur ${utilisateur['nomUtilisateur']} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteUtilisateur(utilisateur);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUtilisateur(Map<String, dynamic> utilisateur) async {
    try {
      final id = int.tryParse(utilisateur['idUtilisateur']?.toString() ?? '0') ?? 0;
      await locator.apiService.deleteUtilisateur(id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Utilisateur supprimé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        _loadUtilisateurs();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
