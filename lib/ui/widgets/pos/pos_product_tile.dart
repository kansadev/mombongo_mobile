import 'package:flutter/material.dart';
import 'package:mombongo/models/article_data.dart';
import 'package:mombongo/ui/theme/pos_colors.dart';
import 'package:mombongo/ui/widgets/pos/pos_qty_stepper.dart';
import 'package:mombongo/utils/google_fonts_compat.dart';
import 'package:mombongo/utils/pos_money.dart';

/// Carte produit du catalogue de vente : un toucher ajoute 1 au panier,
/// un appui long ouvre le détail.
class PosProductTile extends StatelessWidget {
  const PosProductTile({
    super.key,
    required this.article,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
    this.onLongPress,
  });

  final ArticleData article;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback? onLongPress;

  bool get _isService => !article.withStock;
  bool get _isOut => article.withStock && article.quantiteStock <= 0;
  bool get _isLow {
    final threshold = article.seuilAlerte > 0 ? article.seuilAlerte : 5;
    return article.withStock && article.quantiteStock <= threshold;
  }

  @override
  Widget build(BuildContext context) {
    final inCart = quantity > 0;
    final (tagBg, tagFg, tagLabel) = _tag();

    return Material(
      color: PosColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _isOut ? null : onAdd,
        onLongPress: onLongPress,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: inCart ? PosColors.green : PosColors.line,
              width: inCart ? 2 : 1,
            ),
          ),
          child: Opacity(
            opacity: _isOut ? 0.55 : 1,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: tagBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tagLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: tagFg,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      article.libelle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                        color: PosColors.ink,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          PosMoney.format(article.prixVentTTC),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: PosColors.ink,
                          ),
                        ),
                      ),
                      if (inCart)
                        PosQtyStepper(
                          quantity: quantity,
                          filled: true,
                          size: 30,
                          onMinus: onRemove,
                          onPlus: onAdd,
                        )
                      else
                        _AddButton(onTap: _isOut ? null : onAdd),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  (Color, Color, String) _tag() {
    if (_isService) return (PosColors.plumSoft, PosColors.plum, 'Service');
    if (_isOut) {
      return (PosColors.terracottaSoft, PosColors.terracotta, 'Rupture');
    }
    final label = 'Stock ${article.quantiteStock}';
    if (_isLow) return (PosColors.amberSoft, PosColors.amber, label);
    return (PosColors.greenSoft, PosColors.green, label);
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ajouter au panier',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: PosColors.green),
          ),
          child: const Icon(Icons.add_rounded, color: PosColors.green),
        ),
      ),
    );
  }
}
