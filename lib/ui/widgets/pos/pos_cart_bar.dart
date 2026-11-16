import 'package:flutter/material.dart';
import 'package:mombongo/ui/theme/pos_colors.dart';
import 'package:mombongo/utils/google_fonts_compat.dart';

/// Barre fixe en bas du catalogue : résumé du panier + bouton « Encaisser ».
class PosCartBar extends StatelessWidget {
  const PosCartBar({
    super.key,
    required this.lineCount,
    required this.quantity,
    required this.totalLabel,
    required this.onCheckout,
  });

  final int lineCount;
  final int quantity;
  final String totalLabel;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PosColors.ink,
      elevation: 8,
      shadowColor: PosColors.ink.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onCheckout,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$quantity',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$lineCount ${lineCount > 1 ? 'lignes' : 'ligne'} · '
                        '$quantity ${quantity > 1 ? 'articles' : 'article'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: PosColors.onInkMuted,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        totalLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: PosColors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Encaisser',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
