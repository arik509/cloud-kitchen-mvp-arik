import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/location/location_service.dart';
import '../../menu/application/menu_item_workflow.dart';
import '../../menu/data/menu_image_repository.dart';
import '../../menu/data/menu_repository.dart';
import '../../menu/domain/menu_item.dart';
import '../../menu/presentation/menu_image_view.dart';
import '../../menu/presentation/menu_item_dialog.dart';
import '../application/kitchen_workflow.dart';
import '../data/kitchen_image_repository.dart';
import '../data/kitchen_repository.dart';
import '../domain/kitchen.dart';
import 'kitchen_form_dialog.dart';

class KitchenPage extends StatefulWidget {
  const KitchenPage({
    required this.ownerId,
    required this.kitchenRepository,
    required this.menuRepository,
    required this.imageRepository,
    required this.imagePicker,
    required this.kitchenImageRepository,
    required this.locationService,
    super.key,
  });

  factory KitchenPage.supabase(SupabaseClient client, {Key? key}) =>
      KitchenPage(
        key: key,
        ownerId: client.auth.currentUser!.id,
        kitchenRepository: SupabaseKitchenRepository(client),
        menuRepository: SupabaseMenuRepository(client),
        imageRepository: SupabaseMenuImageRepository(client),
        imagePicker: PlatformMenuImagePicker(),
        kitchenImageRepository: SupabaseKitchenImageRepository(client),
        locationService: const GeolocatorLocationService(),
      );

  final String ownerId;
  final KitchenRepository kitchenRepository;
  final MenuRepository menuRepository;
  final MenuImageRepository imageRepository;
  final MenuImagePicker imagePicker;
  final KitchenImageRepository kitchenImageRepository;
  final LocationService locationService;

  @override
  State<KitchenPage> createState() => _KitchenPageState();
}

class _KitchenPageState extends State<KitchenPage> {
  bool _loading = true;
  bool _mutating = false;
  String? _error;
  Kitchen? _kitchen;
  List<MenuItem> _items = const [];

  MenuItemWorkflow get _workflow => MenuItemWorkflow(
    menuRepository: widget.menuRepository,
    imageRepository: widget.imageRepository,
  );

  KitchenWorkflow get _kitchenWorkflow => KitchenWorkflow(
    kitchenRepository: widget.kitchenRepository,
    imageRepository: widget.kitchenImageRepository,
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final kitchen = await widget.kitchenRepository.fetchForOwner(
        widget.ownerId,
      );
      final items = kitchen == null
          ? const <MenuItem>[]
          : await widget.menuRepository.fetchForKitchen(kitchen.id);
      if (!mounted) return;
      setState(() {
        _kitchen = kitchen;
        _items = items;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createKitchen() async {
    final result = await showDialog<KitchenFormResult>(
      context: context,
      builder: (_) => KitchenFormDialog(
        locationService: widget.locationService,
        imagePicker: widget.imagePicker,
      ),
    );
    if (result == null) return;
    await _mutate(() async {
      try {
        await _kitchenWorkflow.create(
          ownerId: widget.ownerId,
          draft: result.draft,
          image: result.image,
        );
      } on KitchenCreatedWithoutImageException {
        _message(
          'Kitchen saved, but the image upload failed. Retry by editing it.',
        );
      } finally {
        await _load();
      }
    });
  }

  Future<void> _editKitchen() async {
    final kitchen = _kitchen;
    if (kitchen == null) return;
    final result = await showDialog<KitchenFormResult>(
      context: context,
      builder: (_) => KitchenFormDialog(
        kitchen: kitchen,
        existingImageUrl: _kitchenImageUrl(kitchen),
        locationService: widget.locationService,
        imagePicker: widget.imagePicker,
      ),
    );
    if (result == null) return;
    await _mutate(() async {
      await _kitchenWorkflow.update(
        ownerId: widget.ownerId,
        original: kitchen,
        draft: result.draft,
        replacementImage: result.image,
      );
      await _load();
    });
  }

  Future<void> _editItem([MenuItem? item]) async {
    final result = await showDialog<MenuItemFormResult>(
      context: context,
      builder: (_) => MenuItemDialog(
        item: item,
        imagePicker: widget.imagePicker,
        existingImageUrl: item == null ? null : _imageUrl(item),
      ),
    );
    if (result == null || _kitchen == null) return;

    await _mutate(() async {
      try {
        if (item == null) {
          await _workflow.create(
            ownerId: widget.ownerId,
            kitchenId: _kitchen!.id,
            draft: result.draft,
            image: result.image,
          );
        } else {
          await _workflow.update(
            ownerId: widget.ownerId,
            original: item,
            draft: result.draft,
            replacementImage: result.image,
          );
        }
      } on MenuItemCreatedWithoutImageException {
        _message(
          'Item saved, but the image upload failed. Retry by editing it.',
        );
      } finally {
        await _load();
      }
    });
  }

  Future<void> _toggleAvailability(MenuItem item, bool value) async {
    await _mutate(() async {
      await widget.menuRepository.update(item.copyWith(isAvailable: value));
      await _load();
    });
  }

  Future<void> _deleteItem(MenuItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete menu item?'),
        content: Text(
          'Delete ${item.name}? Ordered items will be archived instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _mutate(() async {
      final outcome = await deleteMenuItemSafely(widget.menuRepository, item);
      if (outcome == MenuDeleteOutcome.deleted && item.imagePath != null) {
        try {
          await widget.imageRepository.delete(item.imagePath!);
        } catch (_) {
          _message('Item deleted, but its old image could not be cleaned up.');
        }
      }
      if (outcome == MenuDeleteOutcome.archived) {
        _message('This ordered item was archived instead of deleted.');
      }
      await _load();
    });
  }

  Future<void> _mutate(Future<void> Function() action) async {
    if (_mutating) return;
    setState(() => _mutating = true);
    try {
      await action();
    } catch (error) {
      _message(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  String? _imageUrl(MenuItem item) {
    final path = item.imagePath;
    return path == null || path.isEmpty
        ? item.imageUrl
        : widget.imageRepository.publicUrl(path);
  }

  String? _kitchenImageUrl(Kitchen kitchen) {
    final path = kitchen.imagePath;
    return path == null || path.isEmpty
        ? null
        : widget.kitchenImageRepository.publicUrl(path);
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _errorMessage(Object error) => switch (error) {
    KitchenRepositoryException(:final message) => message,
    MenuRepositoryException(:final message) => message,
    MenuImageRepositoryException(:final message) => message,
    KitchenImageRepositoryException(:final message) => message,
    _ => 'Something went wrong. Check your connection and try again.',
  };

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        key: Key('kitchen-loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (_error != null) {
      return Center(
        key: const Key('kitchen-error'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 64),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_kitchen == null) {
      return Center(
        key: const Key('kitchen-setup-empty'),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storefront, size: 72),
              const SizedBox(height: 14),
              const Text(
                'Set Up Your Kitchen',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add your kitchen details and current location, then build your menu.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _mutating ? null : _createKitchen,
                icon: const Icon(Icons.storefront_outlined),
                label: const Text('Set Up Your Kitchen'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _kitchenSummary(_kitchen!),
              if (_kitchen!.latitude == null || _kitchen!.longitude == null)
                Card(
                  key: const Key('kitchen-location-missing'),
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: ListTile(
                    leading: const Icon(Icons.location_off_outlined),
                    title: const Text('Add your kitchen location'),
                    subtitle: const Text(
                      'Customers cannot find this kitchen in nearby results yet.',
                    ),
                    trailing: TextButton(
                      onPressed: _mutating ? null : _editKitchen,
                      child: const Text('Add location'),
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    'Menu items',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _mutating ? null : () => _editItem(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add item'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_items.isEmpty)
                const Padding(
                  key: Key('menu-empty'),
                  padding: EdgeInsets.all(28),
                  child: Center(child: Text('No menu items yet.')),
                ),
              for (final item in _items) _menuCard(item),
            ],
          ),
        ),
        if (_mutating) const LinearProgressIndicator(),
      ],
    );
  }

  Widget _kitchenSummary(Kitchen kitchen) => Card(
    key: const Key('kitchen-summary'),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _KitchenHeaderImage(imageUrl: _kitchenImageUrl(kitchen)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kitchen.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(kitchen.address),
                    const SizedBox(height: 8),
                    Chip(
                      avatar: Icon(
                        kitchen.isActive
                            ? Icons.check_circle
                            : Icons.pause_circle,
                        size: 18,
                      ),
                      label: Text(kitchen.isActive ? 'Active' : 'Inactive'),
                    ),
                    Text(
                      kitchen.latitude != null && kitchen.longitude != null
                          ? 'Location added'
                          : 'Location not added',
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      key: const Key('owner-payment-methods'),
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (kitchen.hasUsableBkash)
                          const Chip(
                            avatar: Icon(Icons.phone_android, size: 18),
                            label: Text('bKash enabled'),
                          ),
                        if (kitchen.acceptsCod)
                          const Chip(
                            avatar: Icon(Icons.payments_outlined, size: 18),
                            label: Text('COD enabled'),
                          ),
                        if (kitchen.acceptsBkash && !kitchen.hasUsableBkash)
                          const Chip(
                            avatar: Icon(Icons.warning_amber_rounded, size: 18),
                            label: Text('Fix bKash number'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                key: const Key('edit-kitchen-button'),
                onPressed: _mutating ? null : _editKitchen,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _menuCard(MenuItem item) => Card(
    child: ListTile(
      leading: MenuImageView(
        imageRepository: widget.imageRepository,
        imagePath: item.imagePath,
        imageUrl: item.imageUrl,
      ),
      title: Text(item.name),
      subtitle: Text(
        '${item.description ?? 'No description'}\n'
        '৳${item.price.toStringAsFixed(2)} • '
        '${item.isAvailable ? 'Available' : 'Unavailable'}',
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: item.isAvailable,
            onChanged: _mutating
                ? null
                : (value) => _toggleAvailability(item, value),
          ),
          PopupMenuButton<String>(
            enabled: !_mutating,
            onSelected: (value) =>
                value == 'edit' ? _editItem(item) : _deleteItem(item),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    ),
  );
}

class _KitchenHeaderImage extends StatelessWidget {
  const _KitchenHeaderImage({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        height: 190,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _KitchenHeaderFallback(),
      );
    }
    return const _KitchenHeaderFallback();
  }
}

class _KitchenHeaderFallback extends StatelessWidget {
  const _KitchenHeaderFallback();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('kitchen-image-fallback'),
    height: 190,
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const Icon(Icons.storefront_outlined, size: 64),
  );
}
