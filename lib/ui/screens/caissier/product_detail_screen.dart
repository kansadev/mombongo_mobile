import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mombongo/ui/widgets/fastFacturation.dart';
import 'package:provider/provider.dart';
import '../../../services/app_currency_preference.dart';
import '../../../services/cart_service.dart';
import '../../../services/service_locator.dart';
import '../caissier/cart_screen.dart';
import 'package:mombongo/models/article_data.dart';

class ProductDetailScreen extends StatelessWidget {
  final ArticleData productData;

  const ProductDetailScreen({super.key, required this.productData});

  // Vérifier si la vente rapide est activée
  bool _isFastSaleEnabled() {
    try {
      return locator.databaseService.get<bool>('pref_fast_sale_enabled') ??
          true;
    } catch (_) {
      return true; // Par défaut, la vente rapide est activée
    }
  }

  // Vérifier si le produit peut être ajouté au panier
  bool _canAddToCart() {
    // Les services peuvent toujours être ajoutés
    if (!productData.withStock) return true;
    // Les articles avec stock doivent avoir une quantité > 0
    return productData.quantiteStock > 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          productData.libelle,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [_buildCartBadge(context)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMainInfoCard(context),
            const SizedBox(height: 16),
            _buildPriceSection(),
            const SizedBox(height: 16),
            _buildStockSection(),
            const SizedBox(height: 32),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCartBadge(BuildContext context) {
    return Consumer<CartService>(
      builder: (context, cartService, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.shopping_cart),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CartScreen()),
              ),
            ),
            if (cartService.totalQuantity > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '${cartService.totalQuantity}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMainInfoCard(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.inventory_2,
                color: Theme.of(context).colorScheme.primary,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productData.libelle,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Code: ${productData.idArticle}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: productData.withStock
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      productData.withStock
                          ? 'Géré en stock'
                          : 'Service/Hors stock',
                      style: TextStyle(
                        color: productData.withStock
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceSection() {
    return _buildSectionCard(
      title: 'Tarification',
      icon: Icons.payments_outlined,
      child: Column(
        children: [
          _buildDataRow(
            'Prix de Vente TTC',
            locator.tauxService.formatPrice(productData.prixVentTTC),
            isPrimary: true,
          ),
          const Divider(height: 24),
          _buildDataRow(
            'Prix HT',
            locator.tauxService.formatPrice(productData.prixVentHT),
          ),
          _buildDataRow('TVA', '${productData.tva}%'),
          _buildDataRow('Remise max', '${productData.remise}%'),
        ],
      ),
    );
  }

  Widget _buildStockSection() {
    final bool isLowStock =
        productData.quantiteStock <= productData.seuilAlerte;

    return _buildSectionCard(
      title: 'État des stocks',
      icon: Icons.analytics_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Disponible', style: TextStyle(color: Colors.grey.shade600)),
              Text(
                '${productData.quantiteStock} unités',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isLowStock ? Colors.red : Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: productData.quantiteStock <= 0
                ? 0
                : (productData.quantiteStock / (productData.seuilAlerte * 3))
                      .clamp(0, 1),
            backgroundColor: Colors.grey.shade200,
            color: isLowStock ? Colors.red : Colors.green,
            borderRadius: BorderRadius.circular(4),
          ),
          if (isLowStock)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Attention: Seuil d\'alerte atteint (${productData.seuilAlerte})',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFF1E3C72)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E3C72),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value, {bool isPrimary = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: isPrimary ? 16 : 14,
              fontWeight: isPrimary ? FontWeight.bold : FontWeight.w500,
              color: isPrimary ? Colors.green.shade700 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final bool isFastSaleEnabled = _isFastSaleEnabled();
    final bool canAddToCart = _canAddToCart();

    return SafeArea(
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                /* Logique ajustement stock */
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Ajuster Stock',
                style: TextStyle(color: Colors.black87),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: canAddToCart
                  ? () {
                      final cartService = context.read<CartService>();

                      // Ajouter l'article au panier
                      cartService.addItem(productData);

                      // Afficher un message de confirmation
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${productData.libelle} ajouté au panier',
                          ),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Colors.green.shade800,
                        ),
                      );

                      // Rediriger selon le mode de vente
                      if (isFastSaleEnabled) {
                        // Mode vente rapide : ouvrir le bottomsheet
                        final currencyCode = AppCurrencyPreference.readCode(
                          locator.databaseService,
                        );
                        final currencyFormat =
                            AppCurrencyPreference.formatterFor(
                              currencyCode,
                              decimalDigits: 2,
                            );
                        final currencySymbol = AppCurrencyPreference.symbolFor(
                          currencyCode,
                        );

                        FastSaleBottomSheet(
                          currencySymbol: currencySymbol,
                          currencyFormat: currencyFormat,
                          initialFocusedArticle: productData,
                          onClose: () {
                            // Revenir à l'écran précédent
                            Navigator.pop(context);
                          },
                        );
                      } else {
                        // Mode normal : rediriger vers la page du panier
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CartScreen(),
                          ),
                        );
                      }
                    }
                  : null,
              icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
              label: Text(
                canAddToCart
                    ? 'Ajouter au panier'
                    : (productData.quantiteStock == 0 && productData.withStock)
                    ? 'Rupture de stock'
                    : 'Indisponible',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: canAddToCart
                    ? Theme.of(context).colorScheme.secondary
                    : Colors.grey,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
