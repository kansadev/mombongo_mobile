import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mombongo/models/client.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/ui/screens/caissier/create_client_screen.dart';
import 'package:mombongo/ui/theme/pos_colors.dart';
import 'package:mombongo/utils/google_fonts_compat.dart';

/// Résultat du choix de client : [client] null = « Client comptoir ».
class ClientPick {
  const ClientPick(this.client);
  final Client? client;
}

/// Feuille de choix du client : recherche (nom, téléphone ou e-mail),
/// création d'un nouveau client, ou retour au client comptoir.
/// Retourne null si l'utilisateur ferme la feuille sans choisir.
Future<ClientPick?> showClientPickerSheet(
  BuildContext context, {
  Client? current,
}) {
  return showModalBottomSheet<ClientPick>(
    context: context,
    isScrollControlled: true,
    backgroundColor: PosColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ClientPickerSheet(current: current),
  );
}

/// Convertit un résultat de recherche API en [Client] (mêmes règles de
/// normalisation que l'ancien écran de vente). Retourne null si invalide.
Client? clientFromSearchResult(Map<String, dynamic> raw) {
  try {
    final data = Map<String, dynamic>.from(raw);

    if (data.containsKey('idClient') && !data.containsKey('id')) {
      final idValue = data['idClient'];
      if (idValue is num) {
        data['id'] = idValue.toInt();
      } else if (idValue is String && int.tryParse(idValue) != null) {
        data['id'] = int.parse(idValue);
      } else {
        return null;
      }
    }

    if (data['dateCreation'] == null) {
      data['dateCreation'] = DateTime.now().toIso8601String();
    } else if (data['dateCreation'] is! String) {
      data['dateCreation'] = data['dateCreation'].toString();
    }

    final statut = data['statut'];
    if (statut == null) {
      data['statut'] = true;
    } else if (statut is String) {
      data['statut'] = statut.toLowerCase() == 'true' || statut == '1';
    } else if (statut is int) {
      data['statut'] = statut == 1;
    } else if (statut is! bool) {
      data['statut'] = true;
    }

    return Client.fromJson(data);
  } catch (e) {
    debugPrint('Client invalide dans la recherche : $e');
    return null;
  }
}

class _ClientPickerSheet extends StatefulWidget {
  const _ClientPickerSheet({this.current});

  final Client? current;

  @override
  State<_ClientPickerSheet> createState() => _ClientPickerSheetState();
}

class _ClientPickerSheetState extends State<_ClientPickerSheet> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<Client> _results = [];
  bool _loading = false;
  String? _error;
  int _requestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value));
  }

  Future<void> _search(String raw) async {
    final query = raw.trim();
    final requestId = ++_requestId;
    if (query.length < 2) {
      setState(() {
        _results = [];
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final isEmail = query.contains('@');
      final isPhone = RegExp(r'^[0-9+\s-]+$').hasMatch(query);
      final results = await locator.apiService.searchClients(
        email: isEmail ? query : null,
        nom: (isEmail || isPhone) ? null : query,
        telephone: isPhone ? query : null,
        pageSize: 10,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _results = results
            .whereType<Map>()
            .map((r) => clientFromSearchResult(Map<String, dynamic>.from(r)))
            .whereType<Client>()
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _results = [];
        _loading = false;
        _error = 'Recherche impossible (vérifiez la connexion).';
      });
    }
  }

  Future<void> _createClient() async {
    final created = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CreateClientScreen()));
    if (!mounted) return;
    if (created is Client) {
      Navigator.of(context).pop(ClientPick(created));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: PosColors.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Client de la vente',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: PosColors.ink,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  onChanged: _onChanged,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _search,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Nom, téléphone ou e-mail',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: PosColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: PosColors.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: PosColors.line),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.of(context).pop(const ClientPick(null)),
                        icon: const Icon(Icons.storefront_outlined),
                        label: const Text('Client comptoir'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: PosColors.ink,
                          minimumSize: const Size.fromHeight(46),
                          side: const BorderSide(color: PosColors.line),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _createClient,
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: const Text('Nouveau'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PosColors.ink,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(color: PosColors.terracotta),
                    ),
                  )
                else if (_results.isEmpty &&
                    _controller.text.trim().length >= 2)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Aucun client trouvé',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(color: PosColors.muted),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _results.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: PosColors.lineSoft),
                      itemBuilder: (context, index) {
                        final client = _results[index];
                        final selected = widget.current?.id == client.id;
                        final details = [
                          client.telephone ?? '',
                          client.email ?? '',
                        ].where((v) => v.isNotEmpty).join(' · ');
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: PosColors.greenSoft,
                            foregroundColor: PosColors.green,
                            child: Text(
                              client.nom.isNotEmpty
                                  ? client.nom[0].toUpperCase()
                                  : '?',
                            ),
                          ),
                          title: Text(
                            '${client.prenom} ${client.nom}'.trim(),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: details.isEmpty ? null : Text(details),
                          trailing: selected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: PosColors.green,
                                )
                              : null,
                          onTap: () =>
                              Navigator.of(context).pop(ClientPick(client)),
                        );
                      },
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
