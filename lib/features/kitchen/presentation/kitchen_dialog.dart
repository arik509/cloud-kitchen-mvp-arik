import 'package:flutter/material.dart';

import '../domain/kitchen.dart';
import '../domain/kitchen_validation.dart';

class KitchenDialog extends StatefulWidget {
  const KitchenDialog({super.key});

  @override
  State<KitchenDialog> createState() => _KitchenDialogState();
}

class _KitchenDialogState extends State<KitchenDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create kitchen'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Kitchen name'),
              validator: KitchenInputValidator.name,
            ),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Address'),
              validator: KitchenInputValidator.address,
            ),
            TextFormField(
              controller: _latitude,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Latitude (optional)',
              ),
              validator: KitchenInputValidator.latitude,
            ),
            TextFormField(
              controller: _longitude,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Longitude (optional)',
              ),
              validator: KitchenInputValidator.longitude,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save')),
    ],
  );

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      KitchenDraft(
        name: _name.text.trim(),
        address: _address.text.trim(),
        latitude: _optionalDouble(_latitude.text),
        longitude: _optionalDouble(_longitude.text),
      ),
    );
  }

  double? _optionalDouble(String value) {
    final text = value.trim();
    return text.isEmpty ? null : double.parse(text);
  }
}
