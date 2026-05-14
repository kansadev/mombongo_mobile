import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mombongo/services/service_locator.dart';

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
      setState(() {
        _detail = data.isEmpty ? null : data;
        _isLoading = false;
        if (_detail == null) {
          _errorMessage = 'Aucune donnée reçue';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
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

  int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

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
    final s = statut.toUpperCase();
    return s != 'ANNULÉE' && s != 'ANNULEE' && s != 'ANNULE' && s != 'ANNULÉ';
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

  Future<void> _retirerArticle({
    required String libelle,
    required int idStock,
  }) async {
    final user = locator.authRepository.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Utilisateur non connecté')));
      return;
    }

    final idUtilisateur = _parseInt(user.idUtilisateur);
    if (idUtilisateur <= 0 || idStock <= 0) {
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

    try {
      _showLoadingOverlay();
      await locator.apiService.retirerProduitVente(
        idCommande: widget.idCommande,
        idStock: idStock,
        idUtilisateur: idUtilisateur,
      );
      _hideLoadingOverlay();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Article retiré avec succès')),
      );
      await _loadDetail(showFullScreenLoader: false);
    } catch (e) {
      _hideLoadingOverlay();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        title: Text(
          'Commande #${widget.idCommande}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
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
          final libelle = article?['libelle']?.toString() ?? 'Article';
          final qte = _parseInt(m['quantite']);
          final pu = _parseDouble(m['prixUnitaire']);
          final totalLigne = _parseDouble(m['totalLigne']);
          final idStock = _parseInt(stock?['idStock']) != 0
              ? _parseInt(stock?['idStock'])
              : _parseInt(m['idStock']);
          final peutRetirer =
              _commandePermetRetraitArticle(statut) && idStock > 0;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(
                libelle,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Qté: $qte × ${_formatCurrency(pu)}',
                style: GoogleFonts.poppins(fontSize: 12),
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
                    IconButton(
                      tooltip: 'Retirer l\'article',
                      icon: Icon(
                        Icons.remove_shopping_cart_outlined,
                        color: Colors.red[400],
                      ),
                      onPressed: () =>
                          _retirerArticle(libelle: libelle, idStock: idStock),
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
