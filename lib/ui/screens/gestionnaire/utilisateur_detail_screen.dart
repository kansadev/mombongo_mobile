import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/service_locator.dart';

class UtilisateurDetailScreen extends StatefulWidget {
  final Map<String, dynamic> utilisateur;

  const UtilisateurDetailScreen({
    super.key,
    required this.utilisateur,
  });

  @override
  State<UtilisateurDetailScreen> createState() => _UtilisateurDetailScreenState();
}

class _UtilisateurDetailScreenState extends State<UtilisateurDetailScreen> {
  Map<String, dynamic>? _utilisateurDetails;
  bool _isLoading = false;
  String? _nomSite;
  String? _nomRole;

  @override
  void initState() {
    super.initState();
    _loadUtilisateurDetails();
  }

  Future<void> _loadUtilisateurDetails() async {
    final idUtilisateur = int.tryParse(widget.utilisateur['idUtilisateur']?.toString() ?? '0') ?? 0;
    if (idUtilisateur == 0) {
      setState(() {
        _utilisateurDetails = widget.utilisateur;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final details = await locator.apiService.getUtilisateur(idUtilisateur);
      
      // Charger le nom du site
      final idSite = int.tryParse(details['idSite']?.toString() ?? '0') ?? 0;
      if (idSite > 0) {
        try {
          final siteData = await locator.apiService.getSite(idSite);
          _nomSite = siteData['nomSite']?.toString();
        } catch (e) {
          debugPrint('Erreur lors du chargement du site: $e');
        }
      }
      
      // Charger le nom du rôle
      final idRole = int.tryParse(details['idRole']?.toString() ?? '0') ?? 0;
      if (idRole > 0) {
        try {
          final roleData = await locator.apiService.getRole(idRole);
          _nomRole = roleData['nom']?.toString();
        } catch (e) {
          debugPrint('Erreur lors du chargement du rôle: $e');
        }
      }
      
      if (mounted) {
        setState(() {
          _utilisateurDetails = details;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement des détails: $e');
      if (mounted) {
        setState(() {
          _utilisateurDetails = widget.utilisateur;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final utilisateur = _utilisateurDetails ?? widget.utilisateur;
    final nom = utilisateur['nomUtilisateur']?.toString() ?? '';
    final prenom = utilisateur['prenomUtilisateur']?.toString() ?? '';
    final postNom = utilisateur['postNomUtilisateur']?.toString() ?? '';
    final nomComplet = '$prenom $nom $postNom'.trim();
    final statut = utilisateur['statut'] == true;
    final isConnected = utilisateur['isConnected'] == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(nomComplet.isNotEmpty ? nomComplet : 'Détails utilisateur'),
        centerTitle: true,
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
           

                  // Informations personnelles
                  _buildSection(
                    title: 'Informations personnelles',
                    icon: Icons.person,
                    children: [
                      _buildInfoRow('Nom', utilisateur['nomUtilisateur']?.toString() ?? 'N/A'),
                      _buildInfoRow('Prénom', utilisateur['prenomUtilisateur']?.toString() ?? 'N/A'),
                      _buildInfoRow('Post-nom', utilisateur['postNomUtilisateur']?.toString() ?? 'N/A'),
                      _buildInfoRow('Sexe', utilisateur['sexe']?.toString() ?? 'N/A'),
                      _buildInfoRow(
                        'Date de naissance',
                        utilisateur['dateNaissance'] != null
                            ? DateFormat('dd/MM/yyyy').format(DateTime.parse(utilisateur['dateNaissance']))
                            : 'N/A',
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Informations de contact
                  _buildSection(
                    title: 'Contact',
                    icon: Icons.contact_mail,
                    children: [
                      _buildInfoRow('Email', utilisateur['email']?.toString() ?? 'N/A'),
                      _buildInfoRow('Téléphone', utilisateur['numeroTelephone']?.toString() ?? 'N/A'),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Informations de connexion
                  _buildSection(
                    title: 'Informations de connexion',
                    icon: Icons.lock,
                    children: [
                      _buildInfoRow('Login', utilisateur['login']?.toString() ?? 'N/A'),
                      _buildInfoRow('Mot de passe', '••••••••', isPassword: true),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Adresse
                  _buildSection(
                    title: 'Adresse',
                    icon: Icons.location_on,
                    children: [
                      _buildInfoRow('Province', utilisateur['province']?.toString() ?? 'N/A'),
                      _buildInfoRow('Ville', utilisateur['ville']?.toString() ?? 'N/A'),
                      _buildInfoRow('Commune', utilisateur['commune']?.toString() ?? 'N/A'),
                      _buildInfoRow('Quartier', utilisateur['quartier']?.toString() ?? 'N/A'),
                      _buildInfoRow('Avenue', utilisateur['avenue']?.toString() ?? 'N/A'),
                      _buildInfoRow('Numéro', utilisateur['numero']?.toString() ?? 'N/A'),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Informations système
                  _buildSection(
                    title: 'Informations système',
                    icon: Icons.info,
                    children: [
                      _buildInfoRow('Site', _nomSite ?? utilisateur['nomSite']?.toString() ?? 'N/A'),
                      _buildInfoRow('Rôle', _nomRole ?? utilisateur['role']?.toString() ?? 'N/A'),
                      _buildInfoRow(
                        'Date de création',
                        utilisateur['dateCreation'] != null
                            ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(utilisateur['dateCreation']))
                            : 'N/A',
                      ),
                      _buildInfoRow(
                        'Dernière modification',
                        utilisateur['dateLastModification'] != null
                            ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(utilisateur['dateLastModification']))
                            : 'N/A',
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF2C3E50)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                color: isPassword ? Colors.grey : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
