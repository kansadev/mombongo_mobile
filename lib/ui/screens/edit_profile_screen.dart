import 'package:flutter/material.dart';
import 'package:mombongo/services/service_locator.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomController;
  late final TextEditingController _loginController;
  late final TextEditingController _telephoneController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = locator.authRepository.currentUser;
    _nomController = TextEditingController(text: user?.nomComplet ?? '');
    _loginController = TextEditingController(text: user?.login ?? '');
    _telephoneController = TextEditingController(
      text: user?.numeroTelephone ?? '',
    );
  }

  @override
  void dispose() {
    _nomController.dispose();
    _loginController.dispose();
    _telephoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSaving = true;
    });

    final result = await locator.authRepository.updateCurrentUserProfile(
      nomComplet: _nomController.text.trim(),
      login: _loginController.text.trim(),
      numeroTelephone: _telephoneController.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil mis a jour avec succes.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.errorMessage ?? 'Echec de la mise a jour du profil.',
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = locator.authRepository.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le profil')),
      body: user == null
          ? const Center(child: Text('Utilisateur non disponible.'))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _nomController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nom complet',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Le nom complet est obligatoire.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _loginController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email / Login',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email / Login est obligatoire.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _telephoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _saveProfile(),
                    decoration: const InputDecoration(
                      labelText: 'Telephone',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Le telephone est obligatoire.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Enregistrer'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
