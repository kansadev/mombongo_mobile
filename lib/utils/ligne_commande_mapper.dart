import 'package:mombongo/services/cart_service.dart';

Map<String, dynamic> cartItemToLigneCommande(CartItem item) {
  final ligne = <String, dynamic>{
    'idStock': item.article.idStock,
    'quantite': item.quantity,
    'prixUnitaire': item.unitPrice,
    'tva': item.article.tva,
    'remise': item.discountPercentage,
  };

  if (!item.article.withStock &&
      item.description != null &&
      item.description!.trim().isNotEmpty) {
    ligne['description'] = item.description!.trim();
  }

  return ligne;
}

List<Map<String, dynamic>> cartItemsToLignesCommandes(List<CartItem> items) {
  return items.map(cartItemToLigneCommande).toList();
}
