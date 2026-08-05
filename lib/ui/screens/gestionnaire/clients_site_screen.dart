import 'package:flutter/material.dart';
import '../../../services/service_locator.dart';
import '../../../models/site.dart';
import 'ClientDetailsScreen.dart';

class ClientsSiteScreen extends StatefulWidget {
  const ClientsSiteScreen({super.key});

  @override
  State<ClientsSiteScreen> createState() => _ClientsSiteScreenState();
}

class _ClientsSiteScreenState extends State<ClientsSiteScreen> {
  List<Site> _sites = [];
  Site? _selectedSite;
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _clientsDuJour = [];
  bool _isLoadingSites = true;
  bool _isLoadingClients = false;
  String _searchQuery = '';

  // Couleurs du thème
  final Color primaryColor = const Color(0xFF2C3E50);
  final Color accentColor = const Color(0xFF3498DB);

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  Future<void> _loadSites() async {
    try {
      final currentUser = locator.authRepository.currentUser;
      if (currentUser == null) return;

      final idSociete = int.tryParse(currentUser.idSociete) ?? 0;
      final sites = await locator.apiService.getSitesBySociete(idSociete);

      if (mounted) {
        setState(() {
          _sites = sites;
          _isLoadingSites = false;

          // --- SÉLECTION PAR DÉFAUT : site opérationnel ---
          if (_sites.isNotEmpty && _selectedSite == null) {
            final opId = currentUser.idSite;
            Site? match;
            for (final s in _sites) {
              if (s.idSite == opId) {
                match = s;
                break;
              }
            }
            _selectedSite = match ?? _sites.first;
          }
        });

        if (_selectedSite != null) {
          _loadClients();
        }
      }
    } catch (e) {
      _showError("Erreur lors du chargement des sites");
    }
  }

  Future<void> _loadClients() async {
    if (_selectedSite == null) return;

    setState(() {
      _isLoadingClients = true;
      _clients.clear();
      _clientsDuJour.clear();
    });

    try {
      final idSite = int.tryParse(_selectedSite!.idSite) ?? 0;

      // L'appel au service qui gère maintenant les messages 404 et l'environnement
      final clients = await locator.apiService.getClientsBySite(idSite);

      if (!mounted) return;

      final todayStart = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      final List<Map<String, dynamic>> duJour = [];
      final List<Map<String, dynamic>> autres = [];

      for (var client in clients) {
        final dateStr = client['dateCreation']?.toString();
        if (dateStr != null) {
          final date = DateTime.parse(dateStr);
          if (date.isAfter(todayStart) || date.isAtSameMomentAs(todayStart)) {
            duJour.add(Map<String, dynamic>.from(client));
          } else {
            autres.add(Map<String, dynamic>.from(client));
          }
        } else {
          autres.add(Map<String, dynamic>.from(client));
        }
      }

      setState(() {
        _clientsDuJour = duJour;
        _clients = autres;
        _isLoadingClients = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoadingClients = false);

      // AMÉLIORATION : On passe l'erreur 'e' directement.
      // Si c'est un 404, 'e' vaudra "Client non trouvé" (ou le message détaillé en debug)
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  List<Map<String, dynamic>> get _filteredClients {
    final all = [..._clientsDuJour, ..._clients];
    if (_searchQuery.isEmpty) return all;
    final q = _searchQuery.toLowerCase();
    return all.where((c) {
      final nom = c['nomComplet']?.toString().toLowerCase() ?? '';
      final tel = c['telephone']?.toString() ?? '';
      return nom.contains(q) || tel.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      // --- APPBAR CLASSIQUE ---
      appBar: AppBar(
        title: const Text(
          'Annuaire Clients',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadSites,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Sélection du Site
              _buildSectionTitle("Site actuel"),
              const SizedBox(height: 8),
              _buildSiteSelectorCard(),

              const SizedBox(height: 20),

              // Section Recherche & Stats
              _buildSearchBar(),
              const SizedBox(height: 16),
              _buildStatsRow(),

              const SizedBox(height: 24),

              // Section Liste des Clients
              _buildSectionTitle("Liste des clients"),
              const SizedBox(height: 12),
              _isLoadingClients
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _buildClientList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.grey[600],
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildSiteSelectorCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: _isLoadingSites
            ? const LinearProgressIndicator()
            : DropdownButtonFormField<Site>(
                isExpanded: true, // Correction overflow
                value: _selectedSite,
                decoration: const InputDecoration(border: InputBorder.none),
                icon: Icon(Icons.storefront, color: accentColor),
                items: _sites.map((s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Text(s.nomSite, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (s) {
                  setState(() => _selectedSite = s);
                  _loadClients();
                },
              ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: "Rechercher un nom ou un numéro...",
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard(
          "Total",
          (_clients.length + _clientsDuJour.length).toString(),
          Icons.group,
          Colors.blue,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          "Aujourd'hui",
          _clientsDuJour.length.toString(),
          Icons.today,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientList() {
    final clients = _filteredClients;
    if (clients.isEmpty) {
      return const Center(child: Text("Aucun client trouvé"));
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: clients.length,
      itemBuilder: (context, index) {
        final client = clients[index];
        final isNew = index < _clientsDuJour.length && _searchQuery.isEmpty;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isNew ? Colors.green.shade200 : Colors.grey.shade200,
            ),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isNew ? Colors.green : accentColor,
              child: Text(
                client['nomComplet']?[0].toUpperCase() ?? '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(
              client['nomComplet'] ?? 'Inconnu',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(client['telephone'] ?? 'Pas de téléphone'),
            trailing: isNew
                ? const Chip(
                    label: Text(
                      "Nouveau",
                      style: TextStyle(fontSize: 10, color: Colors.white),
                    ),
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.zero,
                  )
                : const Icon(Icons.chevron_right),
            onTap: () => _showClientDetails(client),
          ),
        );
      },
    );
  }

  void _showClientDetails(Map<String, dynamic> client) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClientDetailsScreen(client: client),
      ),
    );
  }
}
