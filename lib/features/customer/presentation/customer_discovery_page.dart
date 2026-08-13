import 'package:flutter/material.dart';

import '../../../core/location/location_models.dart';
import '../../../core/location/location_service.dart';
import '../../kitchen/data/kitchen_image_repository.dart';
import '../../menu/data/menu_image_repository.dart';
import '../../menu/presentation/menu_image_view.dart';
import '../../orders/data/order_repository.dart';
import '../../wallet/data/wallet_repository.dart';
import '../data/customer_catalog_repository.dart';
import '../domain/nearby_kitchen.dart';
import '../domain/nearby_kitchen_service.dart';
import 'customer_menu_page.dart';

class CustomerDiscoveryPage extends StatefulWidget {
  const CustomerDiscoveryPage({
    required this.locationService,
    required this.catalogRepository,
    required this.imageRepository,
    required this.kitchenImageRepository,
    required this.walletRepository,
    required this.orderRepository,
    this.radiusKm = defaultNearbyKitchenRadiusKm,
    this.onOrderPlaced,
    super.key,
  });

  final LocationService locationService;
  final CustomerCatalogRepository catalogRepository;
  final MenuImageRepository imageRepository;
  final KitchenImageRepository kitchenImageRepository;
  final WalletRepository walletRepository;
  final OrderRepository orderRepository;
  final double radiusKm;
  final VoidCallback? onOrderPlaced;

  @override
  State<CustomerDiscoveryPage> createState() => _CustomerDiscoveryPageState();
}

class _CustomerDiscoveryPageState extends State<CustomerDiscoveryPage> {
  late Future<List<NearbyKitchen>> _kitchens;

  @override
  void initState() {
    super.initState();
    _kitchens = _load();
  }

  Future<List<NearbyKitchen>> _load() async {
    final location = await widget.locationService.determineLocation();
    final kitchensFuture = widget.catalogRepository
        .fetchKitchensWithCoordinates();
    final imagesFuture = widget.catalogRepository.fetchRepresentativeImages();
    return nearbyKitchens(
      origin: location,
      kitchens: await kitchensFuture,
      representativeImages: await imagesFuture,
      radiusKm: widget.radiusKm,
    );
  }

  void _retry() => setState(() => _kitchens = _load());

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _kitchens = future);
    await future;
  }

  Future<void> _openSettings() async {
    final opened = await widget.locationService.openLocationSettings();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Open your browser or device settings, allow location, then retry.',
          ),
        ),
      );
    }
    if (mounted) _retry();
  }

  Future<void> _openKitchen(NearbyKitchen nearby) async {
    final placed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerMenuPage(
          kitchen: nearby.kitchen,
          catalogRepository: widget.catalogRepository,
          imageRepository: widget.imageRepository,
          walletRepository: widget.walletRepository,
          orderRepository: widget.orderRepository,
        ),
      ),
    );
    if (placed == true) widget.onOrderPlaced?.call();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<NearbyKitchen>>(
    future: _kitchens,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(
          key: Key('discovery-loading'),
          child: CircularProgressIndicator(),
        );
      }
      if (snapshot.hasError) return _errorState(snapshot.error!);
      final kitchens = snapshot.data!;
      if (kitchens.isEmpty) {
        return _DiscoveryMessage(
          key: const Key('discovery-empty'),
          icon: Icons.location_searching,
          title: 'No kitchens within ${widget.radiusKm.toStringAsFixed(0)} km',
          message: 'Pull to refresh or try again from another location.',
          actionLabel: 'Retry',
          onAction: _retry,
        );
      }
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.separated(
          key: const Key('nearby-kitchen-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: kitchens.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final nearby = kitchens[index];
            return Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _openKitchen(nearby),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      MenuImageView(
                        imageRepository:
                            nearby.representativeImageBucket ==
                                KitchenImageBucket.kitchen
                            ? KitchenImageViewAdapter(
                                widget.kitchenImageRepository,
                              )
                            : widget.imageRepository,
                        imagePath: nearby.representativeImagePath,
                        imageUrl: nearby.representativeImageUrl,
                        size: 88,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nearby.kitchen.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              nearby.kitchen.address,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${nearby.distanceKm.toStringAsFixed(1)} km away',
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );

  Widget _errorState(Object error) {
    if (error is LocationException) {
      final settings =
          error.code == LocationFailureCode.permanentlyDenied ||
          error.code == LocationFailureCode.servicesDisabled;
      return _DiscoveryMessage(
        key: Key('location-${error.code.name}'),
        icon: settings ? Icons.location_disabled : Icons.location_off_outlined,
        title: switch (error.code) {
          LocationFailureCode.denied => 'Location permission denied',
          LocationFailureCode.permanentlyDenied =>
            'Location permission blocked',
          LocationFailureCode.servicesDisabled => 'Location is turned off',
          LocationFailureCode.unavailable => 'Location unavailable',
          LocationFailureCode.timeout => 'Location request timed out',
        },
        message: error.message,
        actionLabel: settings ? 'Open settings' : 'Retry',
        onAction: settings ? _openSettings : _retry,
      );
    }
    return _DiscoveryMessage(
      key: const Key('discovery-error'),
      icon: Icons.cloud_off_outlined,
      title: 'Could not load nearby kitchens',
      message: 'Check your network connection and retry.',
      actionLabel: 'Retry',
      onAction: _retry,
    );
  }
}

class KitchenImageViewAdapter implements MenuImageRepository {
  const KitchenImageViewAdapter(this.repository);

  final KitchenImageRepository repository;

  @override
  Future<void> delete(String path) => repository.delete(path);

  @override
  String publicUrl(String path) => repository.publicUrl(path);

  @override
  Future<String> upload({
    required String ownerId,
    required String kitchenId,
    required String menuItemId,
    required PickedMenuImage image,
  }) => repository.upload(ownerId: ownerId, kitchenId: kitchenId, image: image);
}

class _DiscoveryMessage extends StatelessWidget {
  const _DiscoveryMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 68),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.refresh),
            label: Text(actionLabel),
          ),
        ],
      ),
    ),
  );
}
