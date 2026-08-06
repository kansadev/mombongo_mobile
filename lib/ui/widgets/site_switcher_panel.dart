import 'package:flutter/material.dart';
import 'package:mombongo/models/site.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/utils/api_error_message.dart';

/// Dialogue / carte pour basculer le site opérationnel (admin).
class SiteSwitcherPanel extends StatefulWidget {
  final VoidCallback? onSiteChanged;

  const SiteSwitcherPanel({super.key, this.onSiteChanged});

  /// Affiche un bottom sheet de sélection de site.
  static Future<bool> show(BuildContext context) async {
    var changed = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SiteSwitcherPanel(
            onSiteChanged: () {
              changed = true;
              Navigator.pop(ctx);
            },
          ),
        );
      },
    );
    return changed;
  }

  @override
  State<SiteSwitcherPanel> createState() => _SiteSwitcherPanelState();
}

class _SiteSwitcherPanelState extends State<SiteSwitcherPanel> {
  List<Site> _sites = [];
  Site? _selectedSite;
  bool _isLoading = true;
  bool _isSwitching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  Future<void> _loadSites() async {
    final currentUser = locator.authRepository.currentUser;
    if (currentUser == null) {
      setState(() {
        _isLoading = false;
        _error = 'Utilisateur non connecté';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final idSociete = int.tryParse(currentUser.idSociete) ?? 0;
      if (idSociete <= 0) {
        throw Exception('ID société invalide');
      }

      final sites = await locator.apiService.getSitesBySociete(idSociete);
      Site? selected;
      for (final s in sites) {
        if (s.idSite == currentUser.idSite) {
          selected = s;
          break;
        }
      }
      selected ??= sites.isNotEmpty ? sites.first : null;

      if (!mounted) return;
      setState(() {
        _sites = sites;
        _selectedSite = selected;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatSiteAddress(Site site) {
    final parts = [
      site.province,
      site.ville,
      site.commune,
      site.quartier,
      site.avenue,
      site.numero,
    ].where((p) => p != null && p.trim().isNotEmpty).map((p) => p!.trim());
    return parts.join(', ');
  }

  Future<void> _connect() async {
    if (_selectedSite == null || _isSwitching) return;

    setState(() => _isSwitching = true);
    try {
      final site = _selectedSite!;
      await locator.authRepository.switchOperationalSite(
        idSite: site.idSite,
        nomSite: site.nomSite,
        adresseSite: _formatSiteAddress(site),
        contact: site.contact,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connecté sur le site : ${site.nomSite}'),
          backgroundColor: Colors.green,
        ),
      );
      widget.onSiteChanged?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(apiErrorUserMessage(e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSwitching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = locator.authRepository.currentUser;
    final alreadyOnSelected = _selectedSite != null &&
        _selectedSite!.idSite == currentUser?.idSite;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Changer de site',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Site actuel : ${currentUser?.nomSite.isNotEmpty == true ? currentUser!.nomSite : 'Aucun'}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Column(
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  TextButton(onPressed: _loadSites, child: const Text('Réessayer')),
                ],
              )
            else if (_sites.isEmpty)
              const Text('Aucun site disponible pour cette société.')
            else ...[
              DropdownButtonFormField<Site>(
                value: _selectedSite,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Site',
                  border: OutlineInputBorder(),
                ),
                items: _sites
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.nomSite, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: _isSwitching
                    ? null
                    : (s) => setState(() => _selectedSite = s),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: (_isSwitching ||
                        _selectedSite == null ||
                        alreadyOnSelected)
                    ? null
                    : _connect,
                icon: _isSwitching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.login),
                label: Text(
                  alreadyOnSelected
                      ? 'Déjà connecté sur ce site'
                      : 'Se connecter sur ce site',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C3E50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
