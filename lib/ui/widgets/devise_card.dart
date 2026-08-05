import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mombongo/utils/number_format_extensions.dart';
import 'package:mombongo/models/devise_model.dart';


class DeviseCard extends StatelessWidget {
  final Devise devise;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onUpdateTaux;
  final VoidCallback onToggleStatus;

  const DeviseCard({
    super.key,
    required this.devise,
    required this.onEdit,
    required this.onDelete,
    required this.onUpdateTaux,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat('#,##0.00', 'fr_FR');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: devise.estActive
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.grey.shade100, Colors.grey.shade200],
                ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: devise.estActive
                                ? Colors.deepPurple.shade50
                                : Colors.grey.shade300,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              devise.symbole ?? devise.code[0],
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: devise.estActive
                                    ? Colors.deepPurple
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                devise.code,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: devise.estActive
                                      ? Colors.deepPurple
                                      : Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                devise.nom,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: devise.estActive
                                      ? Colors.grey.shade700
                                      : Colors.grey.shade500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: devise.estActive
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: devise.estActive
                            ? Colors.green.shade200
                            : Colors.red.shade200,
                      ),
                    ),
                    child: Text(
                      devise.estActive ? 'Actif' : 'Inactif',
                      style: TextStyle(
                        color: devise.estActive
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (devise.description?.isNotEmpty == true) ...[
                Text(
                  devise.description ?? '',
                  style: TextStyle(
                    color: devise.estActive
                        ? Colors.grey.shade600
                        : Colors.grey.shade500,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: devise.estActive
                      ? Colors.blue.shade50
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Taux actuel',
                          style: TextStyle(
                            fontSize: 12,
                            color: devise.estActive
                                ? Colors.blue.shade700
                                : Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${formatCurrency.formatSafe(devise.tauxActuel)} ${devise.code}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: devise.estActive
                                ? Colors.blue.shade900
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    if (devise.estActive)
                      ElevatedButton.icon(
                        onPressed: onUpdateTaux,
                        icon: const Icon(Icons.update, size: 16),
                        label: const Text('Mettre à jour'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    tooltip: 'Modifier',
                  ),
                  IconButton(
                    onPressed: onToggleStatus,
                    icon: Icon(
                      devise.estActive ? Icons.block : Icons.check_circle,
                      color: devise.estActive ? Colors.orange : Colors.green,
                    ),
                    tooltip: devise.estActive ? 'Désactiver' : 'Activer',
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 12,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Modifié: ${DateFormat('dd/MM/yyyy HH:mm').format(devise.dateModification?? DateTime.now())}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
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
}