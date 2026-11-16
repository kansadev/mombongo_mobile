import 'package:flutter/material.dart';
import 'package:mombongo/models/article_data.dart';
import 'package:mombongo/services/cart_service.dart';

/// Règles de modification du panier, communes aux écrans de vente :
/// - un service n'a pas de limite de quantité ;
/// - un article stocké est limité à son stock disponible ;
/// - une quantité à 0 retire la ligne.
class PosCartActions {
  PosCartActions._();

  static bool isOutOfStock(ArticleData article) =>
      article.withStock && article.quantiteStock <= 0;

  static int quantityOf(CartService cart, ArticleData article) =>
      cart.getItem(article.idArticle)?.quantity ?? 0;

  /// Ajoute [delta] (positif ou négatif) à la quantité de [article].
  /// Retourne false si la limite de stock a empêché l'ajout.
  static bool change(
    BuildContext context,
    CartService cart,
    ArticleData article,
    int delta,
  ) {
    final current = quantityOf(cart, article);
    var next = current + delta;
    if (next < 0) next = 0;

    var limited = false;
    if (article.withStock && next > article.quantiteStock) {
      next = article.quantiteStock < 0 ? 0 : article.quantiteStock;
      limited = true;
    }

    if (next == current) {
      if (limited) _showStockLimit(context, article);
      return !limited;
    }

    if (current == 0) {
      cart.addItem(article, quantity: next);
    } else {
      cart.updateQuantity(article.idArticle, next);
    }

    if (limited) _showStockLimit(context, article);
    return !limited;
  }

  static void _showStockLimit(BuildContext context, ArticleData article) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            article.quantiteStock <= 0
                ? '${article.libelle} : rupture de stock'
                : '${article.libelle} : stock max ${article.quantiteStock}',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }
}
