import 'package:flutter/material.dart';

import '../../../core/location/location_models.dart';
import '../../../core/location/location_service.dart';
import '../../kitchen/data/kitchen_image_repository.dart';
import '../../menu/data/menu_image_repository.dart';
import '../../menu/presentation/menu_image_view.dart';
import '../../orders/data/order_repository.dart';
import '../../notifications/data/notification_dispatcher.dart';
import '../../ratings/data/rating_repository.dart';
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
    this.ratingRepository,
    this.notificationDispatcher,
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
  final RatingRepository? ratingRepository;
  final OrderNotificationDispatcher? notificationDispatcher;

  @override
  State<CustomerDiscoveryPage> createState() => _CustomerDiscoveryPageState();
}

class _CustomerDiscoveryPageState extends State<CustomerDiscoveryPage>
    with WidgetsBindingObserver {
  late Future<List<NearbyKitchen>> _kitchens;
  bool _refreshingOnResume = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _kitchens = _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAfterResume();
    }
  }

  Future<void> _refreshAfterResume() async {
    if (_refreshingOnResume || !mounted) return;
    _refreshingOnResume = true;
    try {
      await _refresh();
    } catch (_) {
      // The FutureBuilder keeps the actionable location or network error.
    } finally {
      _refreshingOnResume = false;
    }
  }

  Future<List<NearbyKitchen>> _load() async {
    final location = await widget.locationService.determineLocation();
    final kitchensFuture = widget.catalogRepository
        .fetchKitchensWithCoordinates();
    final imagesFuture = widget.catalogRepository.fetchRepresentativeImages();
    final nearby = nearbyKitchens(
      origin: location,
      kitchens: await kitchensFuture,
      representativeImages: await imagesFuture,
      radiusKm: widget.radiusKm,
    );
    final ratings = await widget.ratingRepository?.fetchSummaries() ?? const {};
    return nearby
        .map((entry) {
          final rating = ratings[entry.kitchen.id];
          return rating == null
              ? entry
              : entry.copyWithRating(
                  average: rating.average,
                  count: rating.count,
                );
        })
        .toList(growable: false);
  }

  void _retry() {
    final future = _load();
    setState(() {
      _kitchens = future;
    });
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _kitchens = future;
    });
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
          kitchenImageRepository: widget.kitchenImageRepository,
          walletRepository: widget.walletRepository,
          orderRepository: widget.orderRepository,
          ratingAverage: nearby.averageRating,
          ratingCount: nearby.ratingCount,
          notificationDispatcher: widget.notificationDispatcher,
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: kitchens.length + 2,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == 0) {
              return TextField(
                readOnly: true,
                decoration: const InputDecoration(
                  hintText: 'Search nearby kitchens',
                  prefixIcon: Icon(Icons.search),
                ),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Search is coming in a future release.'),
                  ),
                ),
              );
            }
            if (index == 1) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fresh food, closer to home',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text('Discover local cloud kitchens within 10 km.'),
                        ],
                      ),
                    ),
                    Icon(Icons.ramen_dining_rounded, size: 54),
                  ],
                ),
              );
            }
            final nearby = kitchens[index - 2];
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
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 18,
                                  color: Colors.amber.shade700,
                                ),
                                Text(
                                  nearby.ratingCount == 0
                                      ? ' New'
                                      : ' ${nearby.averageRating.toStringAsFixed(1)} (${nearby.ratingCount})',
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: nearby.kitchen.isActive
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                                Text(
                                  nearby.kitchen.isActive ? ' Open' : ' Closed',
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (nearby.kitchen.hasUsableBkash)
                                  const _MarketplaceBadge(
                                    icon: Icons.phone_android,
                                    label: 'bKash',
                                  ),
                                if (nearby.kitchen.acceptsCod)
                                  const _MarketplaceBadge(
                                    icon: Icons.payments_outlined,
                                    label: 'COD',
                                  ),
                              ],
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
          LocationFailureCode.servicesDisabled =>
            'Turn on location to discover nearby kitchens.',
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

class _MarketplaceBadge extends StatelessWidget {
  const _MarketplaceBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    ),
  );
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
