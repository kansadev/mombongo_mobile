import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Demande une description pour un service (ex. pressing) à la confirmation de vente.
Future<String?> showServiceDescriptionDialog(
  BuildContext context, {
  required String articleName,
  String? initialValue,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => _ServiceDescriptionDialog(
      articleName: articleName,
      initialValue: initialValue,
    ),
  );
}

class _ServiceDescriptionDialog extends StatefulWidget {
  const _ServiceDescriptionDialog({
    required this.articleName,
    this.initialValue,
  });

  final String articleName;
  final String? initialValue;

  @override
  State<_ServiceDescriptionDialog> createState() =>
      _ServiceDescriptionDialogState();
}

class _ServiceDescriptionDialogState extends State<_ServiceDescriptionDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validate() {
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Description du service',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.articleName,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 3,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Description (facultatif)',
              hintText: 'Ex: Veste costume, repassage urgent...',
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
          child: const Text('Passer'),
        ),
        ElevatedButton(
          onPressed: _validate,
          child: const Text('Valider'),
        ),
      ],
    );
  }
}
