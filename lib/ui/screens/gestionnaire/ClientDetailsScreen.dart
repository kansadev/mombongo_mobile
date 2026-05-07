import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'client_paiements_screen.dart';

class ClientDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> client;

  const ClientDetailsScreen({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    final String nom = client['nomComplet'] ?? 'N/A';
    final bool isNew =
        client['dateCreation'] != null &&
        DateTime.parse(client['dateCreation']).day == DateTime.now().day;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: const Text("Détails du Client"),
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header avec l'avatar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              color: const Color(0xFF2C3E50),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Text(
                      nom[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 40,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    nom,
                    style: const TextStyle(
                      fontSize: 22,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isNew)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "Nouveau Client",
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),

            // Liste des informations
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(context),
                  const SizedBox(height: 16),
                  _buildActionButtons(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          _buildDetailTile(Icons.person_outline, "Genre", client['genre']),
          _buildDetailTile(
            Icons.phone_android,
            "Téléphone",
            client['telephone'],
          ),
          _buildDetailTile(Icons.email_outlined, "Email", client['email']),
          _buildDetailTile(
            Icons.location_on_outlined,
            "Adresse",
            client['adresseClient'],
          ),
          _buildDetailTile(
            Icons.badge_outlined,
            "Pièce d'identité",
            client['pieceIdentite'],
          ),
          _buildDetailTile(
            Icons.store_outlined,
            "Site d'inscription",
            client['nomSite'],
          ),
          _buildDetailTile(
            Icons.calendar_today,
            "Inscrit le",
            client['dateCreation'] != null
                ? DateFormat(
                    'dd MMMM yyyy à HH:mm',
                  ).format(DateTime.parse(client['dateCreation']))
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTile(IconData icon, String label, dynamic value) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF3498DB)),
      title: Text(
        label,
        style: TextStyle(color: Colors.grey[600], fontSize: 13),
      ),
      subtitle: Text(
        (value == null || value.toString().isEmpty)
            ? "Non renseigné"
            : value.toString(),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions Rapides',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ClientPaiementsScreen(client: client),
                    ),
                  );
                },
                icon: Icon(Icons.payment),
                label: Text('Voir les Paiements'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF2C3E50),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
