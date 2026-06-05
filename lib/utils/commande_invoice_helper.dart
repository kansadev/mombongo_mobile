import 'package:flutter/material.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/ui/widgets/commande_invoice_generator.dart';
import 'package:mombongo/utils/api_error_message.dart';

int? resolveIdCommandeFromPaiement(Map<String, dynamic> paiement) {
  final commande = paiement['commande'] as Map<String, dynamic>?;
  final idFromPaiement = int.tryParse(paiement['idCommande']?.toString() ?? '');
  final idFromCmd = int.tryParse(commande?['idCommande']?.toString() ?? '');
  final id = idFromPaiement ?? idFromCmd ?? 0;
  return id > 0 ? id : null;
}

Future<void> imprimerFactureCommande(
  BuildContext context,
  int idCommande, {
  CommandeInvoiceType type = CommandeInvoiceType.vente,
  String? withdrawnArticleName,
  int? withdrawnQuantity,
  double? withdrawnAmount,
}) async {
  try {
    final detail = await locator.apiService.getCommandeDetail(idCommande);
    if (!context.mounted || detail.isEmpty) return;

    await CommandeInvoiceGenerator(
      context: context,
      commandeDetail: detail,
      type: type,
      withdrawnArticleName: withdrawnArticleName,
      withdrawnQuantity: withdrawnQuantity,
      withdrawnAmount: withdrawnAmount,
    ).generateAndShow();
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(apiErrorUserMessage(e))),
    );
  }
}
