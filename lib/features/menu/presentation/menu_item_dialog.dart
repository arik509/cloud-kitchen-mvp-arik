import 'package:flutter/material.dart';

import '../data/menu_image_repository.dart';
import '../domain/menu_item.dart';
import '../domain/menu_validation.dart';

class MenuItemFormResult {
  const MenuItemFormResult({required this.draft, this.image});

  final MenuItemDraft draft;
  final PickedMenuImage? image;
}

class MenuItemDialog extends StatefulWidget {
  const MenuItemDialog({
    required this.imagePicker,
    this.item,
    this.existingImageUrl,
    super.key,
  });

  final MenuImagePicker imagePicker;
  final MenuItem? item;
  final String? existingImageUrl;

  @override
  State<MenuItemDialog> createState() => _MenuItemDialogState();
}

class _MenuItemDialogState extends State<MenuItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late bool _available;
  bool _pickingImage = false;
  PickedMenuImage? _selectedImage;
  String? _imageError;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.item?.name ?? '');
    _description = TextEditingController(text: widget.item?.description ?? '');
    _price = TextEditingController(text: widget.item?.price.toString() ?? '');
    _available = widget.item?.isAvailable ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() {
      _pickingImage = true;
      _imageError = null;
    });
    try {
      final image = await widget.imagePicker.pick();
      if (image != null && mounted) {
        setState(() => _selectedImage = image);
      }
    } on MenuImageValidationException catch (error) {
      if (mounted) setState(() => _imageError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _imageError = 'The image could not be selected.');
      }
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.item == null ? 'Add menu item' : 'Edit menu item'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ImagePreview(
              selectedImage: _selectedImage,
              existingImageUrl: widget.existingImageUrl,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickingImage ? null : _pickImage,
              icon: const Icon(Icons.image_outlined),
              label: Text(
                _pickingImage
                    ? 'Selecting...'
                    : _selectedImage == null
                    ? 'Choose image'
                    : 'Replace image',
              ),
            ),
            if (_imageError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _imageError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: MenuInputValidator.name,
            ),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
              maxLines: 2,
            ),
            TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Price (৳)'),
              validator: MenuInputValidator.price,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Available'),
              value: _available,
              onChanged: (value) => setState(() => _available = value),
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
      MenuItemFormResult(
        draft: MenuItemDraft(
          name: _name.text.trim(),
          description: _description.text.trim(),
          price: double.parse(_price.text.trim()),
          isAvailable: _available,
        ),
        image: _selectedImage,
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({this.selectedImage, this.existingImageUrl});

  final PickedMenuImage? selectedImage;
  final String? existingImageUrl;

  @override
  Widget build(BuildContext context) {
    final selected = selectedImage;
    if (selected != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          selected.bytes,
          key: const Key('selected-menu-image-preview'),
          width: 180,
          height: 120,
          fit: BoxFit.cover,
        ),
      );
    }
    if (existingImageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          existingImageUrl!,
          width: 180,
          height: 120,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const _ImageFallback(),
        ),
      );
    }
    return const _ImageFallback();
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) => Container(
    width: 180,
    height: 120,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Icon(Icons.no_food_outlined, size: 42),
  );
}
