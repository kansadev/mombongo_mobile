import 'package:flutter/material.dart';
import 'package:mombongo/ui/theme/pos_colors.dart';

/// Sélecteur de quantité − n + (variante pleine verte ou contour).
class PosQtyStepper extends StatelessWidget {
  const PosQtyStepper({
    super.key,
    required this.quantity,
    required this.onMinus,
    required this.onPlus,
    this.filled = false,
    this.size = 32,
  });

  final int quantity;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  /// true : fond vert (carte produit) ; false : contour (lignes du panier).
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : PosColors.ink;

    Widget button(IconData icon, String label, VoidCallback? onTap) {
      return Semantics(
        button: true,
        label: label,
        child: InkResponse(
          onTap: onTap,
          radius: size * 0.7,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              size: size * 0.55,
              color: onTap == null ? fg.withValues(alpha: 0.35) : fg,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: filled ? PosColors.green : PosColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: filled ? null : Border.all(color: PosColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.remove_rounded, 'Diminuer', onMinus),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 18),
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: fg,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          button(Icons.add_rounded, 'Augmenter', onPlus),
        ],
      ),
    );
  }
}
