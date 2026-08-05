import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/services/sync_service.dart';

/// Bandeau statut réseau + file d'attente ventes offline.
class OfflineStatusBanner extends StatelessWidget {
  const OfflineStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: locator.syncService,
      builder: (context, _) {
        final sync = locator.syncService;
        final show = !sync.isOnline || sync.pendingCount > 0 || sync.isSyncing;
        if (!show) return const SizedBox.shrink();

        final Color bg;
        final IconData icon;
        final String label;

        if (sync.isSyncing) {
          bg = Colors.blue.shade700;
          icon = Icons.sync;
          label = 'Synchronisation en cours…';
        } else if (!sync.isOnline) {
          bg = Colors.orange.shade800;
          icon = Icons.cloud_off;
          label = sync.pendingCount > 0
              ? 'Hors ligne — ${sync.pendingCount} vente(s) en attente'
              : 'Mode hors ligne';
        } else {
          bg = Colors.amber.shade800;
          icon = Icons.cloud_upload_outlined;
          label = '${sync.pendingCount} vente(s) en attente de sync';
        }

        return Material(
          color: bg,
          child: SafeArea(
            bottom: false,
            child: InkWell(
              onTap: sync.isOnline && !sync.isSyncing
                  ? () => _syncManually(context, sync)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    if (sync.isSyncing)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (sync.isOnline &&
                        sync.pendingCount > 0 &&
                        !sync.isSyncing)
                      Text(
                        'Synchroniser',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _syncManually(BuildContext context, SyncService sync) async {
    final result = await sync.syncNow();
    if (!context.mounted) return;
    final message = result.synced > 0
        ? '${result.synced} vente(s) synchronisée(s)'
        : result.remaining > 0
            ? 'Échec partiel — ${result.remaining} restante(s)'
            : 'Rien à synchroniser';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: result.failed > 0 ? Colors.orange : Colors.green,
      ),
    );
  }
}
