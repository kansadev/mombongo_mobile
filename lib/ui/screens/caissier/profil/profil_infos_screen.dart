import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mombongo/services/service_locator.dart';
import 'package:mombongo/ui/screens/edit_profile_screen.dart';
import 'package:mombongo/ui/theme/pos_colors.dart';
import 'package:mombongo/ui/widgets/pos/settings_tiles.dart';
import 'package:mombongo/utils/google_fonts_compat.dart';

/// « Mes informations » : informations personnelles et professionnelles du
/// caissier, en lecture seule, avec accès à la modification du profil.
class ProfilInfosScreen extends StatefulWidget {
  const ProfilInfosScreen({super.key});

  @override
  State<ProfilInfosScreen> createState() => _ProfilInfosScreenState();
}

class _ProfilInfosScreenState extends State<ProfilInfosScreen> {
  bool _changed = false;

  Future<void> _edit() async {
    final updated = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const EditProfileScreen()));
    if (updated == true && mounted) {
      setState(() => _changed = true);
    }
  }

  static int _age(DateTime birth) {
    final now = DateTime.now();
    var age = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    final user = locator.authRepository.currentUser;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: PosColors.background,
        appBar: AppBar(
          backgroundColor: PosColors.surface,
          foregroundColor: PosColors.ink,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 0,
          title: Text(
            'Mes informations',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: PosColors.ink,
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: user == null ? null : _edit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Modifier'),
              style: TextButton.styleFrom(foregroundColor: PosColors.green),
            ),
            const SizedBox(width: 4),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: PosColors.line),
          ),
        ),
        body: user == null
            ? const Center(child: Text('Aucune donnée utilisateur disponible'))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  SettingsSection(
                    title: 'Informations personnelles',
                    children: [
                      InfoRow(
                        icon: Icons.person_outline,
                        label: 'Nom complet',
                        value: user.nomComplet,
                      ),
                      InfoRow(
                        icon: Icons.alternate_email,
                        label: 'Email / login',
                        value: user.login,
                      ),
                      InfoRow(
                        icon: Icons.phone_outlined,
                        label: 'Téléphone',
                        value: user.numeroTelephone,
                      ),
                      InfoRow(
                        icon: Icons.cake_outlined,
                        label: 'Date de naissance',
                        value:
                            '${DateFormat('dd/MM/yyyy').format(user.dateNonce)} (${_age(user.dateNonce)} ans)',
                      ),
                      InfoRow(
                        icon: Icons.wc_outlined,
                        label: 'Sexe',
                        value: user.sexe == 'M' ? 'Masculin' : 'Féminin',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SettingsSection(
                    title: 'Informations professionnelles',
                    children: [
                      InfoRow(
                        icon: Icons.badge_outlined,
                        label: 'Rôle',
                        value: user.role,
                      ),
                      InfoRow(
                        icon: Icons.storefront_outlined,
                        label: 'Site',
                        value: user.nomSite,
                      ),
                      InfoRow(
                        icon: Icons.business_outlined,
                        label: 'Société',
                        value: user.nomSociete,
                      ),
                      if (user.adresseSite.isNotEmpty)
                        InfoRow(
                          icon: Icons.place_outlined,
                          label: 'Adresse',
                          value: user.adresseSite,
                        ),
                      if (user.contact.isNotEmpty)
                        InfoRow(
                          icon: Icons.call_outlined,
                          label: 'Contact du site',
                          value: user.contact,
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
