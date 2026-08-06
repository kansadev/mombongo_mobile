import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/ui/widgets/commande_invoice_generator.dart';
import 'package:mombongo/utils/api_error_message.dart';
import 'package:mombongo/utils/parse_utils.dart';

class CommandeDetailScreen extends StatefulWidget {
  const CommandeDetailScreen({super.key, required this.idCommande});

  final int idCommande;

  @override
  State<CommandeDetailScreen> createState() => _CommandeDetailScreenState();
}

class _CommandeDetailScreenState extends State<CommandeDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _detail;
  bool _actionLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail({bool showFullScreenLoader = true}) async {
    if (showFullScreenLoader) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      setState(() => _errorMessage = null);
    }

    try {
      final data = await locator.apiService.getCommandeDetail(
        widget.idCommande,
      );
      if (!mounted) return;

      Map<String, dynamic>? normalized;
      if (data.isNotEmpty) {
        normalized = Map<String, dynamic>.from(data);
        final lignes =
            normalized['articles'] ?? normalized['lignesCommandes'];
        if (lignes is List) {
          normalized['articles'] = normalizeCommandeArticles(lignes);
        }
        if (kDebugMode && lignes is List && lignes.isNotEmpty) {
          debugPrint('=== ECHANTILLON LIGNE COMMANDE (detail) ===');
          debugPrint(jsonEncode(lignes.first));
        }
      }

      setState(() {
        _detail = normalized;
        _isLoading = false;
        if (_detail == null) {
          _errorMessage = 'Aucune donnée reçue';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = apiErrorUserMessage(e);
        _isLoading = false;
      });
    }
  }

  double _parseDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  int _parseInt(dynamic v) => parseAsInt(v);

  String _formatCurrency(double amount) {
    return locator.tauxService.formatPrice(amount);
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  bool _commandePermetRetraitArticle(String statut) {
    final s = statut.toUpperCase().replaceAll('É', 'E').trim();
    const bloques = {
      'ANNULEE',
      'ANNULE',
      'REMBOURSEE',
      'REMBOURSE',
      'CLOTUREE',
      'CLOTURE',
    };
    return !bloques.contains(s);
  }

  void _showLoadingOverlay() {
    if (!mounted || _actionLoading) return;
    _actionLoading = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Expanded(child: Text('Traitement en cours...')),
            ],
          ),
        ),
      ),
    );
  }

  void _hideLoadingOverlay() {
    if (!_actionLoading) return;
    _actionLoading = false;
    if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  /// idStock attendu par /api/Vente/retirer-produit et /reduire-quantite.
  /// Priorité : idStock direct sur la ligne (FK LigneCommande), puis stock imbriqué.
  int _resolveIdStockFromLigne(Map<String, dynamic> ligne) {
    final ligneIdStock = _parseInt(ligne['idStock']);
    if (ligneIdStock > 0) return ligneIdStock;

    final stock = ligne['stock'];
    if (stock is Map<String, dynamic>) {
      final stockIdStock = _parseInt(stock['idStock']);
      if (stockIdStock > 0) return stockIdStock;

      final stockId = _parseInt(stock['id']);
      if (stockId > 0) return stockId;

      final article = stock['article'];
      if (article is Map<String, dynamic>) {
        final articleIdStock = _parseInt(article['idStock']);
        if (articleIdStock > 0) return articleIdStock;
      }
    }

    return 0;
  }

  void _logPayloadAvantApi({
    required String operation,
    required Map<String, dynamic> ligne,
    required int idStock,
    required int idUtilisateur,
    int? nouvelleQuantite,
  }) {
    if (!kDebugMode) return;

    final Map<String, dynamic> payload;
    if (operation == 'retirer-produit') {
      payload = {
        'idCommande': widget.idCommande,
        'idStock': idStock,
        'idUtilisateur': idUtilisateur,
      };
    } else {
      payload = {
        'idCommande': widget.idCommande,
        'idStock': idStock,
        'nouvelleQuantite': nouvelleQuantite,
        'idUtilisateur': idUtilisateur,
      };
    }

    debugPrint('=== AVANT API $operation ===');
    debugPrint('Payload envoyé: ${jsonEncode(payload)}');
    debugPrint(
      'Ligne source (non envoyée): idLigneCommande=${ligne['idLigneCommande']}, '
      'idStock=${ligne['idStock']}, quantite=${ligne['quantite']}, '
      'libelle=${ligne['stock']?['article']?['libelle'] ?? ligne['libelle']}',
    );
  }

  void _logVenteModificationResponse(
    String operation,
    Map<String, dynamic> response,
  ) {
    if (!kDebugMode) return;

    debugPrint('=== API VENTE / $operation ===');
    try {
      debugPrint(const JsonEncoder.withIndent('  ').convert(response));
    } catch (_) {
      debugPrint(response.toString());
    }

    final commande = response['commande'];
    debugPrint(
      'Statuts détectés → '
      'statut=${response['statut']}, '
      'statutCommande=${response['statutCommande']}, '
      'commande.statut=${commande is Map ? commande['statut'] : null}, '
      'statutPaiement=${response['statutPaiement']}',
    );
  }

  /// Applique immédiatement les champs renvoyés par l'API (statuts, montants).
  void _mergeDetailFromApiResponse(Map<String, dynamic> response) {
    if (_detail == null) return;

    final merged = Map<String, dynamic>.from(_detail!);
    final commande = response['commande'];

    void applyField(String targetKey, dynamic value) {
      if (value == null) return;
      merged[targetKey] = value;
    }

    applyField('statut', response['statut'] ?? response['statutCommande']);
    applyField('montantTotal', response['montantTotal']);
    applyField('montantPaye', response['montantPaye']);
    applyField('resteAPayer', response['resteAPayer']);

    if (commande is Map<String, dynamic>) {
      applyField('statut', commande['statut'] ?? commande['statutCommande']);
      applyField('montantTotal', commande['montantTotal']);
      applyField('montantPaye', commande['montantPaye']);
      applyField('resteAPayer', commande['resteAPayer']);

      if (commande['articles'] is List) {
        merged['articles'] = normalizeCommandeArticles(
          commande['articles'] as List,
        );
      }
    }

    if (response['articles'] is List) {
      merged['articles'] = normalizeCommandeArticles(
        response['articles'] as List,
      );
    }

    if (response['paiements'] is List) {
      merged['paiements'] = response['paiements'];
    }

    if (kDebugMode) {
      debugPrint(
        'Statut commande après fusion locale: ${merged['statut']} '
        '(reste=${merged['resteAPayer']})',
      );
    }

    setState(() => _detail = merged);
  }

  Future<int?> _idUtilisateurConnecte() async {
    final user = locator.authRepository.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Utilisateur non connecté')),
        );
      }
      return null;
    }
    final id = _parseInt(user.idUtilisateur);
    if (id <= 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID utilisateur invalide')),
      );
    }
    return id > 0 ? id : null;
  }

  Future<void> _afterModificationSuccess({
    required String operation,
    required Map<String, dynamic> response,
    required String successMessage,
    String? libelle,
    int? withdrawnQuantity,
    double? withdrawnAmount,
    bool offerPrint = false,
  }) async {
    _logVenteModificationResponse(operation, response);
    _mergeDetailFromApiResponse(response);
    _hasChanges = true;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(successMessage)),
    );

    await _loadDetail(showFullScreenLoader: false);

    if (!mounted || _detail == null) return;

    if (kDebugMode) {
      debugPrint(
        'Statut commande après rechargement: ${_detail!['statut']} '
        '(reste=${_detail!['resteAPayer']})',
      );
    }

    if (!offerPrint || libelle == null) return;

    final shouldPrint = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Imprimer la facture ?'),
        content: const Text(
          'Souhaitez-vous imprimer la facture de retrait mise à jour ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Imprimer'),
          ),
        ],
      ),
    );

    if (shouldPrint == true && mounted && _detail != null) {
      await CommandeInvoiceGenerator(
        context: context,
        commandeDetail: _detail!,
        type: CommandeInvoiceType.retrait,
        withdrawnArticleName: libelle,
        withdrawnQuantity: withdrawnQuantity,
        withdrawnAmount: withdrawnAmount,
      ).generateAndShow();
    }
  }

  Future<void> _retirerArticle({
    required String libelle,
    required int idStock,
  }) async {
    final idUtilisateur = await _idUtilisateurConnecte();
    if (idUtilisateur == null || idStock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Données invalides pour retirer l\'article'),
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer l\'article'),
        content: Text(
          'Retirer "$libelle" de la commande #${widget.idCommande} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    final articles = _detail?['articles'] as List<dynamic>? ?? [];
    final montantPaye = _parseDouble(_detail?['montantPaye']);
    final isLastArticle = articles.length <= 1;

    if (isLastArticle && montantPaye > 0) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Dernier article'),
          content: Text(
            'Vous retirez le dernier article d\'une commande déjà payée '
            '(${_formatCurrency(montantPaye)}). Un remboursement sera nécessaire.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuer'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    Map<String, dynamic>? withdrawnLine;
    for (final raw in articles) {
      final ligne = raw as Map<String, dynamic>;
      if (_resolveIdStockFromLigne(ligne) == idStock) {
        withdrawnLine = ligne;
        break;
      }
    }

    if (withdrawnLine != null) {
      _logPayloadAvantApi(
        operation: 'retirer-produit',
        ligne: withdrawnLine,
        idStock: idStock,
        idUtilisateur: idUtilisateur,
      );
    }

    try {
      _showLoadingOverlay();
      final response = await locator.apiService.retirerProduitVente(
        idCommande: widget.idCommande,
        idStock: idStock,
        idUtilisateur: idUtilisateur,
      );
      _hideLoadingOverlay();
      if (!mounted) return;

      final withdrawnAmount = withdrawnLine != null
          ? _parseDouble(withdrawnLine['totalLigne'])
          : null;
      final withdrawnQuantity = withdrawnLine != null
          ? _parseInt(withdrawnLine['quantite'])
          : null;

      await _afterModificationSuccess(
        operation: 'retirer-produit',
        response: response,
        successMessage: 'Article retiré avec succès',
        libelle: libelle,
        withdrawnQuantity: withdrawnQuantity,
        withdrawnAmount: withdrawnAmount,
        offerPrint: true,
      );
    } catch (e) {
      _hideLoadingOverlay();
      if (!mounted) return;
      final message = apiErrorUserMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _reduireQuantiteArticle({
    required String libelle,
    required int idStock,
    required int quantiteActuelle,
  }) async {
    final idUtilisateur = await _idUtilisateurConnecte();
    if (idUtilisateur == null || idStock <= 0) {
      if (mounted && idStock <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Données invalides pour réduire la quantité'),
          ),
        );
      }
      return;
    }

    if (quantiteActuelle <= 1) {
      final useRetrait = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Quantité minimale'),
          content: Text(
            'La quantité de "$libelle" est 1. '
            'Réduire va retirer complètement l\'article.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Retirer'),
            ),
          ],
        ),
      );
      if (useRetrait == true) {
        await _retirerArticle(libelle: libelle, idStock: idStock);
      }
      return;
    }

    final controller = TextEditingController(
      text: '${quantiteActuelle - 1}',
    );

    try {
      final nouvelleQuantite = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Réduire la quantité'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                libelle,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Nouvelle quantité',
                  hintText: 'Max: ${quantiteActuelle - 1}',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = int.tryParse(controller.text.trim());
                Navigator.pop(context, value);
              },
              child: const Text('Valider'),
            ),
          ],
        ),
      );

      if (nouvelleQuantite == null || !mounted) return;
      if (nouvelleQuantite <= 0) {
        throw Exception('La quantité doit être supérieure à 0');
      }
      if (nouvelleQuantite >= quantiteActuelle) {
        throw Exception(
          'La nouvelle quantité doit être inférieure à $quantiteActuelle',
        );
      }

      Map<String, dynamic>? targetLine;
      final articles = _detail?['articles'] as List<dynamic>? ?? [];
      for (final raw in articles) {
        final ligne = raw as Map<String, dynamic>;
        if (_resolveIdStockFromLigne(ligne) == idStock) {
          targetLine = ligne;
          break;
        }
      }

      if (targetLine != null) {
        _logPayloadAvantApi(
          operation: 'reduire-quantite',
          ligne: targetLine,
          idStock: idStock,
          idUtilisateur: idUtilisateur,
          nouvelleQuantite: nouvelleQuantite,
        );
      } else if (kDebugMode) {
        debugPrint(
          'ATTENTION: aucune ligne trouvée pour idStock=$idStock '
          'dans ${_detail?['articles']?.length ?? 0} article(s)',
        );
      }

      _showLoadingOverlay();
      final response = await locator.apiService.reduireQuantiteProduitVente(
        idCommande: widget.idCommande,
        idStock: idStock,
        nouvelleQuantite: nouvelleQuantite,
        idUtilisateur: idUtilisateur,
      );
      _hideLoadingOverlay();

      await _afterModificationSuccess(
        operation: 'reduire-quantite',
        response: response,
        successMessage: 'Quantité mise à jour avec succès',
      );
    } catch (e) {
      _hideLoadingOverlay();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorUserMessage(e))),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _reimprimerFacture() async {
    if (_detail == null) return;
    await CommandeInvoiceGenerator(
      context: context,
      commandeDetail: _detail!,
    ).generateAndShow();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && _hasChanges) {
          // Le parent peut écouter le résultat via Navigator.pop explicite.
        }
      },
      child: Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        title: Text(
          'Commande #${widget.idCommande}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _hasChanges),
        ),
        actions: [
          if (_detail != null)
            IconButton(
              tooltip: 'Réimprimer la facture',
              icon: const Icon(Icons.print),
              onPressed: _reimprimerFacture,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadDetail,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            )
          : _detail == null
          ? const Center(child: Text('Détail indisponible'))
          : RefreshIndicator(
              onRefresh: _loadDetail,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: _buildContent(_detail!),
              ),
            ),
    ),
    );
  }

  Widget _buildContent(Map<String, dynamic> d) {
    final statut = d['statut']?.toString() ?? '-';
    final dateCmd = _formatDate(d['dateCommande']?.toString());
    final montantTotal = _parseDouble(d['montantTotal']);
    final montantPaye = _parseDouble(d['montantPaye']);
    final reste = _parseDouble(d['resteAPayer']);

    final client = d['client'] as Map<String, dynamic>?;
    final telClient = client?['telephone']?.toString() ?? '';
    final mailClient = client?['email']?.toString() ?? '';
    final contactClient = telClient.isNotEmpty
        ? telClient
        : (mailClient.isNotEmpty ? mailClient : '—');

    final utilisateur = d['utilisateur'] as Map<String, dynamic>?;
    final articles = d['articles'] as List<dynamic>? ?? [];
    final paiements = d['paiements'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Statut',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Chip(
                      label: Text(statut),
                      backgroundColor: const Color(0xFF2C3E50).withOpacity(0.1),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Date commande: $dateCmd',
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
                const Divider(height: 24),
                _rowMontant('Montant total', montantTotal, Colors.black87),
                _rowMontant('Montant payé', montantPaye, Colors.green[700]!),
                _rowMontant(
                  'Reste à payer',
                  reste,
                  reste > 0 ? Colors.red : Colors.green,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Client',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(
              '${client?['nom'] ?? ''} ${client?['prenom'] ?? ''}'
                      .trim()
                      .isEmpty
                  ? '—'
                  : '${client?['nom'] ?? ''} ${client?['prenom'] ?? ''}'.trim(),
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              contactClient,
              style: GoogleFonts.poppins(fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Caissier',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: Text(
              '${utilisateur?['nomUtilisateur'] ?? ''} ${utilisateur?['postNomUtilisateur'] ?? ''} ${utilisateur?['prenomUtilisateur'] ?? ''}'
                  .trim(),
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              utilisateur?['login']?.toString() ?? '',
              style: GoogleFonts.poppins(fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Articles (${articles.length})',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 8),
        ...articles.map((a) {
          final m = a as Map<String, dynamic>;
          final stock = m['stock'] as Map<String, dynamic>?;
          final article = stock?['article'] as Map<String, dynamic>?;
          final libelle =
              article?['libelle']?.toString() ??
              m['libelle']?.toString() ??
              'Article';
          final description = m['description']?.toString().trim();
          final qte = _parseInt(m['quantite']);
          final pu = _parseDouble(m['prixUnitaire']);
          final totalLigne = _parseDouble(m['totalLigne']);
          final idStock = _resolveIdStockFromLigne(m);
          final peutRetirer =
              _commandePermetRetraitArticle(statut) && idStock > 0;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(
                libelle,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Qté: $qte × ${_formatCurrency(pu)}',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  if (description != null && description.isNotEmpty)
                    Text(
                      description,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.blueGrey,
                      ),
                    ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatCurrency(totalLigne),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                  if (peutRetirer)
                    PopupMenuButton<String>(
                      tooltip: 'Actions article',
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'retirer') {
                          _retirerArticle(
                            libelle: libelle,
                            idStock: idStock,
                          );
                        } else if (value == 'reduire') {
                          _reduireQuantiteArticle(
                            libelle: libelle,
                            idStock: idStock,
                            quantiteActuelle: qte,
                          );
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem<String>(
                          value: 'retirer',
                          child: Text('Retirer le produit'),
                        ),
                        PopupMenuItem<String>(
                          value: 'reduire',
                          child: Text('Réduire la quantité'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        Text(
          'Paiements (${paiements.length})',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 8),
        ...paiements.map((p) {
          final m = p as Map<String, dynamic>;
          final ref =
              m['referencePaiemenet']?.toString() ??
              m['referencePaiement']?.toString() ??
              '-';
          final dateP = _formatDate(m['datePaiement']?.toString());
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(Icons.payment, color: Colors.blueGrey[600]),
              title: Text(
                ref,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${m['modePaiement'] ?? ''} · ${m['statut'] ?? ''}\n$dateP',
                style: GoogleFonts.poppins(fontSize: 11),
              ),
              trailing: Text(
                _formatCurrency(_parseDouble(m['montant'])),
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          );
        }),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _rowMontant(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
          ),
          Text(
            _formatCurrency(value),
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
