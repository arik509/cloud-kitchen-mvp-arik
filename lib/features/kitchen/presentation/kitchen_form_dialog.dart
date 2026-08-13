import 'package:flutter/material.dart';

import '../../../core/location/location_models.dart';
import '../../../core/location/location_service.dart';
import '../../menu/data/menu_image_repository.dart';
import '../domain/kitchen.dart';
import '../domain/kitchen_validation.dart';

class KitchenFormResult {
  const KitchenFormResult({required this.draft, this.image});

  final KitchenDraft draft;
  final PickedMenuImage? image;
}

class KitchenFormDialog extends StatefulWidget {
  const KitchenFormDialog({
    required this.locationService,
    required this.imagePicker,
    this.kitchen,
    this.existingImageUrl,
    super.key,
  });

  final LocationService locationService;
  final MenuImagePicker imagePicker;
  final Kitchen? kitchen;
  final String? existingImageUrl;

  @override
  State<KitchenFormDialog> createState() => _KitchenFormDialogState();
}

class _KitchenFormDialogState extends State<KitchenFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  late bool _active;
  bool _locating = false;
  bool _pickingImage = false;
  PickedMenuImage? _selectedImage;
  LocationException? _locationError;
  String? _imageError;
  String? _locationSuccess;

  @override
  void initState() {
    super.initState();
    final kitchen = widget.kitchen;
    _name = TextEditingController(text: kitchen?.name ?? '');
    _address = TextEditingController(text: kitchen?.address ?? '');
    _latitude = TextEditingController(
      text: kitchen?.latitude?.toString() ?? '',
    );
    _longitude = TextEditingController(
      text: kitchen?.longitude?.toString() ?? '',
    );
    _active = kitchen?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _locationError = null;
      _locationSuccess = null;
    });
    try {
      final location = await widget.locationService.determineLocation();
      if (!mounted) return;
      _latitude.text = location.latitude.toString();
      _longitude.text = location.longitude.toString();
      setState(() => _locationSuccess = 'Location added successfully');
    } on LocationException catch (error) {
      if (mounted) setState(() => _locationError = error);
    } catch (_) {
      if (mounted) {
        setState(
          () => _locationError = const LocationException(
            LocationFailureCode.unavailable,
            'Location is unavailable right now. Please retry.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _openSettings() async {
    final opened = await widget.locationService.openLocationSettings();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Open browser or device settings, allow location, then retry.',
          ),
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    if (_pickingImage) return;
    setState(() {
      _pickingImage = true;
      _imageError = null;
    });
    try {
      final image = await widget.imagePicker.pick();
      if (image != null && mounted) setState(() => _selectedImage = image);
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
  Widget build(BuildContext context) {
    final locationError = _locationError;
    final canOpenSettings =
        locationError != null &&
        (locationError.code == LocationFailureCode.permanentlyDenied ||
            locationError.code == LocationFailureCode.servicesDisabled);
    return AlertDialog(
      title: Text(
        widget.kitchen == null ? 'Set Up Your Kitchen' : 'Edit Kitchen',
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _KitchenImagePreview(
                  selectedImage: _selectedImage,
                  existingImageUrl: widget.existingImageUrl,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _pickingImage ? null : _pickImage,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    _pickingImage
                        ? 'Selecting...'
                        : _selectedImage == null
                        ? 'Choose kitchen image'
                        : 'Replace selected image',
                  ),
                ),
                if (_imageError != null)
                  Text(
                    _imageError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                TextFormField(
                  key: const Key('kitchen-name-field'),
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Kitchen name'),
                  validator: KitchenInputValidator.name,
                ),
                TextFormField(
                  key: const Key('kitchen-address-field'),
                  controller: _address,
                  decoration: const InputDecoration(labelText: 'Address'),
                  maxLines: 2,
                  validator: KitchenInputValidator.address,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('use-current-location'),
                  onPressed: _locating ? null : _useCurrentLocation,
                  icon: _locating
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: Text(
                    _locating ? 'Getting location...' : 'Use Current Location',
                  ),
                ),
                if (_locationSuccess != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _locationSuccess!,
                      key: const Key('location-success'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                if (locationError != null)
                  _LocationErrorView(
                    error: locationError,
                    canOpenSettings: canOpenSettings,
                    onRetry: _useCurrentLocation,
                    onOpenSettings: _openSettings,
                  ),
                ExpansionTile(
                  key: const Key('manual-location-section'),
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Advanced / Manual Location'),
                  children: [
                    TextFormField(
                      key: const Key('kitchen-latitude-field'),
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
                      key: const Key('kitchen-longitude-field'),
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
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Kitchen active'),
                  subtitle: const Text(
                    'Inactive kitchens are hidden from customer discovery.',
                  ),
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                ),
              ],
            ),
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
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      KitchenFormResult(
        draft: KitchenDraft(
          name: _name.text.trim(),
          address: _address.text.trim(),
          latitude: _optionalDouble(_latitude.text),
          longitude: _optionalDouble(_longitude.text),
          isActive: _active,
        ),
        image: _selectedImage,
      ),
    );
  }

  double? _optionalDouble(String value) {
    final text = value.trim();
    return text.isEmpty ? null : double.parse(text);
  }
}

class _LocationErrorView extends StatelessWidget {
  const _LocationErrorView({
    required this.error,
    required this.canOpenSettings,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final LocationException error;
  final bool canOpenSettings;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) => Padding(
    key: Key('location-error-${error.code.name}'),
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          error.message,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton(onPressed: onRetry, child: const Text('Retry')),
            if (canOpenSettings)
              TextButton(
                onPressed: onOpenSettings,
                child: const Text('Open settings'),
              ),
          ],
        ),
      ],
    ),
  );
}

class _KitchenImagePreview extends StatelessWidget {
  const _KitchenImagePreview({this.selectedImage, this.existingImageUrl});

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
          key: const Key('selected-kitchen-image-preview'),
          height: 180,
          fit: BoxFit.cover,
        ),
      );
    }
    final imageUrl = existingImageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageUrl,
          height: 180,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const _KitchenImageFallback(),
        ),
      );
    }
    return const _KitchenImageFallback();
  }
}

class _KitchenImageFallback extends StatelessWidget {
  const _KitchenImageFallback();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('kitchen-image-fallback'),
    height: 180,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Icon(Icons.storefront_outlined, size: 56),
  );
}
