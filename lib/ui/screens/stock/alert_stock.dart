import 'package:flutter/material.dart';

class AlertesStockScreen extends StatelessWidget {
  const AlertesStockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertes Stock'),
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
              Center(
                child: Column(
                  children: [
                    const Text(
                      'Alertes Stock',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '0 articles nécessitent votre attention',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Statistiques d'alerte
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.9,
                children: [
                  _buildAlerteStatCard(
                    title: 'Critiques',
                    value: '0',
                    color: Colors.red,
                    icon: Icons.warning_amber,
                  ),
                  _buildAlerteStatCard(
                    title: 'Moyennes',
                    value: '0',
                    color: Colors.orange,
                    icon: Icons.warning,
                  ),
                  _buildAlerteStatCard(
                    title: 'Ruptures',
                    value: '0',
                    color: Colors.deepPurple,
                    icon: Icons.block,
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Ligne de séparation
              Divider(
                color: Colors.grey[300],
                thickness: 1,
              ),
              
              const SizedBox(height: 24),
              
              // Section Articles nécessitant une attention
              const Text(
                'Articles nécessitant une attention',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Zone vide (aucune alerte)
              Container(
                width: double.infinity,
                padding:  EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey[200]!,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 60,
                      color: Colors.green[400],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Aucune alerte pour le moment',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tous vos stocks sont à des niveaux satisfaisants',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Exemple d'alertes (pour démonstration)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Exemples d\'alertes (démonstration)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildAlerteExempleItem(
                      article: 'Basket Nike',
                      stockActuel: 2,
                      seuilMinimum: 10,
                      niveau: 'Critique',
                      color: Colors.red,
                    ),
                    const SizedBox(height: 8),
                    _buildAlerteExempleItem(
                      article: 'T-shirt Blanc',
                      stockActuel: 8,
                      seuilMinimum: 15,
                      niveau: 'Moyen',
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 8),
                    _buildAlerteExempleItem(
                      article: 'Sac à dos',
                      stockActuel: 0,
                      seuilMinimum: 5,
                      niveau: 'Rupture',
                      color: Colors.deepPurple,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Section Actions rapides
              const Text(
                'Actions rapides',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Boutons d'actions rapides
              Row(
                children: [
                  Expanded(
                    child: _buildActionRapideButton(
                      label: 'RÉAPPRO.',
                      icon: Icons.local_shipping,
                      color: Colors.green,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Réapprovisionnement - Fonctionnalité en cours de développement'),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  Expanded(
                    child: _buildActionRapideButton(
                      label: 'MODIFIER SEUILS',
                      icon: Icons.settings,
                      color: Colors.blue,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Modification des seuils - Fonctionnalité en cours de développement'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Bouton retour
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 24,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: const BorderSide(
                      color: Color(0xFF2C3E50),
                      width: 2,
                    ),
                  ),
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
                  label: const Text(
                    'RETOUR',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF2C3E50),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildAlerteStatCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            
            const SizedBox(height: 12),
            
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            
            const SizedBox(height: 4),
            
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionRapideButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(
          vertical: 20,
          horizontal: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: color,
            width: 2,
          ),
        ),
        elevation: 3,
        shadowColor: color.withOpacity(0.2),
      ),
      icon: Icon(icon, size: 28),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
  
  Widget _buildAlerteExempleItem({
    required String article,
    required int stockActuel,
    required int seuilMinimum,
    required String niveau,
    required Color color,
  }) {
    final pourcentage = (stockActuel / seuilMinimum) * 100;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Center(
              child: Icon(
                niveau == 'Rupture' ? Icons.block : Icons.warning,
                color: color,
                size: 20,
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Stock: $stockActuel / $seuilMinimum',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              niveau,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}