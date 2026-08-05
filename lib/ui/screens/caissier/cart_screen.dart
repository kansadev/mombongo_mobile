import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mombongo/services/app_currency_preference.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/ui/screens/caissier/payment_screen.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../services/cart_service.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cartService = Provider.of<CartService>(context);
    final currencyCode = AppCurrencyPreference.readCode(
      locator.databaseService,
    );
    final NumberFormat currencyFormat = AppCurrencyPreference.formatterFor(
      currencyCode,
    );
    final currencySymbol = AppCurrencyPreference.symbolFor(currencyCode);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Panier (${cartService.totalQuantity})',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Colors.white,
        actions: [
          if (cartService.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              onPressed: () {
                _showClearCartDialog(context, cartService);
              },
            ),
        ],
      ),
      body: cartService.isEmpty
          ? _buildEmptyCartView(context)
          : _buildCartContent(
              context,
              cartService,
              currencyFormat,
              currencySymbol,
            ),
      bottomNavigationBar: cartService.isNotEmpty
          ? _buildBottomSummary(
              context,
              cartService,
              currencyFormat,
              currencySymbol,
            )
          : null,
    );
  }

  Widget _buildEmptyCartView(BuildContext context) {
    return Builder(
      builder: (context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 20),
            Text(
              'Votre panier est vide',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Ajoutez des articles depuis la page de facturation',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.tertiary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
              ),
              child: Text(
                'Retour à la facturation',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartContent(
    BuildContext context,
    CartService cartService,
    NumberFormat currencyFormat,
    String currencySymbol,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cartService.items.length,
      itemBuilder: (context, index) {
        final cartItem = cartService.items[index];
        return _buildCartItem(
          context,
          cartItem,
          cartService,
          currencyFormat,
          currencySymbol,
        );
      },
    );
  }

  Widget _buildCartItem(
    BuildContext context,
    CartItem cartItem,
    CartService cartService,
    NumberFormat currencyFormat,
    String currencySymbol,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    cartItem.article.libelle,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    cartService.removeItem(cartItem.article.idArticle);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${cartItem.article.libelle} supprimé du panier',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  },
                ),
              ],
            ),

            // Display HT and TTC prices
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Prix HT:',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '${locator.tauxService.formatPrice(cartItem.unitPriceHT)}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Prix TTC:',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '${locator.tauxService.formatPrice(cartItem.unitPrice)}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Quantity selector
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: cartItem.quantity > 1
                          ? () => cartService.updateQuantity(
                              cartItem.article.idArticle,
                              cartItem.quantity - 1,
                            )
                          : null,
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          cartItem.quantity.toString(),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        // Vérifier si l'augmentation dépasserait le stock disponible
                        if (cartItem.quantity >=
                            cartItem.article.quantiteStock) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Stock insuffisant pour ${cartItem.article.libelle}. Stock disponible: ${cartItem.article.quantiteStock}',
                              ),
                              backgroundColor: Colors.orange,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                          return;
                        }

                        cartService.updateQuantity(
                          cartItem.article.idArticle,
                          cartItem.quantity + 1,
                        );
                      },
                    ),
                  ],
                ),
                // Total price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      locator.tauxService.formatPrice(cartItem.totalPrice),
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    if (cartItem.totalDiscount > 0)
                      Text(
                        'Économisé: ${locator.tauxService.formatPrice(cartItem.totalDiscount)}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.green[600],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSummary(
    BuildContext context,
    CartService cartService,
    NumberFormat currencyFormat,
    String currencySymbol,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sous-total HT:', style: GoogleFonts.poppins(fontSize: 16)),
              Text(
                '${locator.tauxService.formatPrice(_calculateSubtotalHT(cartService))}',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (cartService.totalDiscount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Remise totale:',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.green[700],
                  ),
                ),
                Text(
                  '-${locator.tauxService.formatPrice(cartService.totalDiscount)}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total TTC:', style: GoogleFonts.poppins(fontSize: 16)),
              Text(
                '${locator.tauxService.formatPrice(_calculateTotalTTC(cartService))}',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total à payer:',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                locator.tauxService.formatPrice(cartService.total),
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _processPayment(
                  context,
                  cartService,
                  currencyFormat,
                  currencySymbol,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Valider la commande',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearCartDialog(BuildContext context, CartService cartService) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Vider le panier',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Êtes-vous sûr de vouloir vider le panier ? Cette action est irréversible.',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Annuler',
                style: GoogleFonts.poppins(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                cartService.clear();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Panier vidé avec succès'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(
                'Vider',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  double _calculateSubtotalHT(CartService cartService) {
    return cartService.items.fold(0.0, (sum, item) => sum + item.totalHT);
  }

  double _calculateTotalTTC(CartService cartService) {
    return cartService.items.fold(0.0, (sum, item) => sum + item.totalTTC);
  }

  void _processPayment(
    BuildContext context,
    CartService cartService,
    NumberFormat currencyFormat,
    String currencySymbol,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Confirmation de paiement',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vous allez valider une commande de ${cartService.totalQuantity} article(s) pour un montant total de ${locator.tauxService.formatPrice(cartService.total)}.',
                style: GoogleFonts.poppins(),
              ),
              const SizedBox(height: 16),
              Text(
                'Après confirmation, le panier sera vidé automatiquement.',
                style: GoogleFonts.poppins(color: Colors.blue[700]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Annuler',
                style: GoogleFonts.poppins(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PaymentScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text(
                'Confirmer le paiement',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
