import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/service_locator.dart';
import '../../../models/site.dart';

class NewUserScreen extends StatefulWidget {
  const NewUserScreen({super.key});

  @override
  State<NewUserScreen> createState() => _NewUserScreenState();
}

class _NewUserScreenState extends State<NewUserScreen> {
  final formKey = GlobalKey<FormState>();
  
  // Controllers
  final nomController = TextEditingController();
  final prenomController = TextEditingController();
  final postNomController = TextEditingController();
  final emailController = TextEditingController();
  final telephoneController = TextEditingController();
  final loginController = TextEditingController();
  final motDePasseController = TextEditingController();
  final provinceController = TextEditingController();
  final villeController = TextEditingController();
  final communeController = TextEditingController();
  final quartierController = TextEditingController();
  final avenueController = TextEditingController();
  final numeroController = TextEditingController();
  final idRoleController = TextEditingController();

  String? selectedSexe;
  DateTime? dateNaissance;
  int? selectedIdSite;
  int? selectedIdRole;
  bool statut = true;
  bool isLoading = false;
  List<Site> sites = [];
  List<Map<String, dynamic>> roles = [];

  // Couleurs Thème
  final Color primaryColor = const Color(0xFF2C3E50);
  final Color accentColor = const Color(0xFF3498DB);
  final Color bgColor = const Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    // Utiliser Future.microtask pour s'assurer que le widget est prêt
    Future.microtask(() {
      _loadSites();
      _loadRoles();
    });
  }

  @override
  void dispose() {
    // Nettoyage de tous les controllers
    [nomController, prenomController, postNomController, emailController, 
     telephoneController, loginController, motDePasseController, 
     provinceController, villeController, communeController, 
     quartierController, avenueController, numeroController, idRoleController
    ].forEach((c) => c.dispose());
    super.dispose();
  }

  Future<void> _loadSites() async {
    try {
      final currentUser = locator.authRepository.currentUser;
      debugPrint('Current user: $currentUser');
      debugPrint('Current user idSociete: ${currentUser?.idSociete}');
      if (currentUser != null) {
        final idSociete = int.tryParse(currentUser.idSociete) ?? 0;
        debugPrint('Loading sites for idSociete: $idSociete');
        final loadedSites = await locator.apiService.getSitesBySociete(idSociete);
        debugPrint('Loaded sites: ${loadedSites.length}');
        if (mounted) setState(() => sites = loadedSites);
      } else {
        debugPrint('Current user is null - cannot load sites');
      }
    } catch (e) {
      debugPrint('Erreur sites: $e');
    }
  }

  Future<void> _loadRoles() async {
    try {
      debugPrint('Loading roles...');
      final loadedRoles = await locator.apiService.getRoles();
      debugPrint('Loaded roles: ${loadedRoles.length}');

      // Appliquer les mêmes restrictions que pour l'affichage de la liste
      final currentUser = locator.authRepository.currentUser;
      final userRole = currentUser?.role.toUpperCase() ?? '';
      List<Map<String, dynamic>> filteredRoles;

      if (userRole == 'GESTIONNAIRE') {
        // gestionnaire peut uniquement créer des caissiers
        filteredRoles = loadedRoles
            .where((r) => (r['nom'] as String?)?.toUpperCase() == 'CAISSIER')
            .toList();
      } else if (userRole.contains('ADMIN')) {
        // admin peut créer gestionnaires et caissiers mais pas super-admin
        filteredRoles = loadedRoles.where((r) {
          final nom = (r['nom'] as String?)?.toUpperCase() ?? '';
          return nom == 'CAISSIER' || nom == 'GESTIONNAIRE';
        }).toList();
      } else {
        // autres : aucune option
        filteredRoles = [];
      }

      debugPrint('Filtered roles: ${filteredRoles.length}');
      if (mounted) setState(() => roles = filteredRoles);
    } catch (e) {
      debugPrint('Erreur rôles: $e');
    }
  }

  Future<void> _saveUser() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => isLoading = true);
    try {
      if (selectedIdRole == null) throw Exception('Sélectionnez un rôle');
      // vérification supplémentaire au moment de l'enregistrement pour éviter
      // toute élévation de privilège.
      final chosen = roles.firstWhere((r) => (r['idRole'] as int) == selectedIdRole,
          orElse: () => {});
      if (chosen.isEmpty) {
        throw Exception('Rôle invalide pour votre compte');
      }

      final utilisateurData = {
        'nomUtilisateur': nomController.text,
        'prenomUtilisateur': prenomController.text,
        'postNomUtilisateur': postNomController.text.isEmpty ? null : postNomController.text,
        'sexe': selectedSexe,
        'dateNaissance': dateNaissance?.toIso8601String(),
        'email': emailController.text,
        'numeroTelephone': telephoneController.text,
        'login': loginController.text,
        'motDePasse': motDePasseController.text,
        'idSite': selectedIdSite ?? 0,
        'idRole': selectedIdRole,
        'statut': statut,
        'province': provinceController.text,
        'ville': villeController.text,
        'commune': communeController.text,
        'quartier': quartierController.text,
        'avenue': avenueController.text,
        'numero': numeroController.text,
      };

      await locator.apiService.createUtilisateur(utilisateurData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Utilisateur créé'), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Nouvel Utilisateur', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildSectionTitle("Informations personnelles", Icons.person_outline),
              _buildFieldCard([
                _buildTextField(nomController, "Nom", Icons.person, isRequired: true),
                _buildTextField(prenomController, "Prénom", Icons.person_outline, isRequired: true),
                _buildTextField(postNomController, "Post-nom", Icons.person_outline),
                _buildDropdownSexe(),
                _buildDatePicker(),
              ]),

              _buildSectionTitle("Contact & Connexion", Icons.email_outlined),
              _buildFieldCard([
                _buildTextField(emailController, "Email", Icons.email_outlined, isRequired: true, type: TextInputType.emailAddress),
                _buildTextField(telephoneController, "Téléphone", Icons.phone_android, isRequired: true, type: TextInputType.phone),
                _buildTextField(loginController, "Login (Identifiant)", Icons.badge_outlined, isRequired: true),
                _buildTextField(motDePasseController, "Mot de passe", Icons.lock_outline, isRequired: true, isPassword: true),
                _buildSiteDropdown(),
                _buildRoleDropdown(),
                SwitchListTile(
                  title: const Text("Compte actif", style: TextStyle(fontWeight: FontWeight.w500)),
                  value: statut,
                  activeColor: accentColor,
                  onChanged: (v) => setState(() => statut = v),
                ),
              ]),

              _buildSectionTitle("Adresse", Icons.location_on),
              _buildFieldCard([
                _buildTextField(provinceController, "Province", Icons.map_outlined),
                _buildTextField(villeController, "Ville", Icons.location_city),
                _buildTextField(communeController, "Commune", Icons.corporate_fare),
                Row(
                  children: [
                    Expanded(child: _buildTextField(quartierController, "Quartier", null)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField(avenueController, "Avenue", null)),
                  ],
                ),
                _buildTextField(numeroController, "Numéro", Icons.numbers),
              ]),

              const SizedBox(height: 30),
              _buildSubmitButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS DE CONSTRUCTION ---

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 10, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: primaryColor),
          const SizedBox(width: 8),
          Text(title.toUpperCase(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primaryColor.withOpacity(0.8), letterSpacing: 1.1)),
        ],
      ),
    );
  }

  Widget _buildFieldCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: children.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c)).toList()),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData? icon, {bool isRequired = false, bool isPassword = false, TextInputType type = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: isRequired ? "$label *" : label,
        prefixIcon: icon != null ? Icon(icon, size: 20, color: accentColor) : null,
        filled: true,
        fillColor: bgColor.withOpacity(0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      ),
      validator: isRequired ? (v) => v?.isEmpty ?? true ? 'Champ requis' : null : null,
    );
  }

  Widget _buildDropdownSexe() {
    return DropdownButtonFormField<String>(
      value: selectedSexe,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: "Sexe *",
        prefixIcon: Icon(Icons.wc, color: accentColor),
        filled: true,
        fillColor: bgColor.withOpacity(0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      ),
      items: ['Masculin', 'Féminin'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
      onChanged: (v) => setState(() => selectedSexe = v),
      validator: (v) => v == null ? 'Requis' : null,
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(context: context, initialDate: DateTime(2000), firstDate: DateTime(1900), lastDate: DateTime.now());
        if (date != null) setState(() => dateNaissance = date);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: "Date de naissance *",
          prefixIcon: Icon(Icons.calendar_month, color: accentColor),
          filled: true,
          fillColor: bgColor.withOpacity(0.5),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(dateNaissance != null ? DateFormat('dd/MM/yyyy').format(dateNaissance!) : 'Sélectionner...'),
      ),
    );
  }

  Widget _buildSiteDropdown() {
    if (sites.isEmpty) return const Text("Chargement des sites...", style: TextStyle(fontSize: 12));
    return DropdownButtonFormField<int>(
      value: selectedIdSite,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: "Site *",
        prefixIcon: Icon(Icons.storefront, color: accentColor),
        filled: true,
        fillColor: bgColor.withOpacity(0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: sites.map((s) => DropdownMenuItem(value: int.tryParse(s.idSite), child: Text(s.nomSite, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (v) => setState(() => selectedIdSite = v),
      validator: (v) => v == null ? 'Requis' : null,
    );
  }

  Widget _buildRoleDropdown() {
    if (roles.isEmpty) return const Text("Chargement des rôles...", style: TextStyle(fontSize: 12));
    return DropdownButtonFormField<int>(
      value: selectedIdRole,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: "Rôle *",
        prefixIcon: Icon(Icons.admin_panel_settings_outlined, color: accentColor),
        filled: true,
        fillColor: bgColor.withOpacity(0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: roles.map((r) => DropdownMenuItem(value: r['idRole'] as int, child: Text(r['nom'] as String))).toList(),
      onChanged: (v) => setState(() => selectedIdRole = v),
      validator: (v) => v == null ? 'Requis' : null,
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: isLoading ? null : _saveUser,
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: isLoading 
          ? const CircularProgressIndicator(color: Colors.white) 
          : const Text("CRÉER L'UTILISATEUR", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}