import 'package:flutter/material.dart';

import '../../kitchen/domain/kitchen.dart';
import '../../kitchen/data/kitchen_image_repository.dart';
import '../../menu/data/menu_image_repository.dart';
import '../../menu/domain/menu_item.dart';
import '../../menu/presentation/menu_image_view.dart';
import '../../orders/data/order_repository.dart';
import '../../orders/presentation/order_confirmation_page.dart';
import '../../notifications/data/notification_dispatcher.dart';
import '../../wallet/data/wallet_repository.dart';
import '../data/customer_catalog_repository.dart';

class CustomerMenuPage extends StatefulWidget {
  const CustomerMenuPage({
    required this.kitchen,
    required this.catalogRepository,
    required this.imageRepository,
    required this.kitchenImageRepository,
    required this.walletRepository,
    required this.orderRepository,
    this.ratingAverage = 0,
    this.ratingCount = 0,
    this.notificationDispatcher,
    super.key,
  });

  final Kitchen kitchen;
  final CustomerCatalogRepository catalogRepository;
  final MenuImageRepository imageRepository;
  final KitchenImageRepository kitchenImageRepository;
  final WalletRepository walletRepository;
  final OrderRepository orderRepository;
  final double ratingAverage;
  final int ratingCount;
  final OrderNotificationDispatcher? notificationDispatcher;

  @override
  State<CustomerMenuPage> createState() => _CustomerMenuPageState();
}

class _CustomerMenuPageState extends State<CustomerMenuPage> {
  late Future<List<MenuItem>> _items;
  late Kitchen _kitchen;

  @override
  void initState() {
    super.initState();
    _kitchen = widget.kitchen;
    _items = widget.catalogRepository.fetchAvailableMenuItems(
      widget.kitchen.id,
    );
  }

  Future<void> _refresh() async {
    final kitchenFuture = widget.catalogRepository.fetchKitchen(_kitchen.id);
    final future = widget.catalogRepository.fetchAvailableMenuItems(
      _kitchen.id,
    );
    setState(() {
      _items = future;
    });
    final refreshedKitchen = await kitchenFuture;
    await future;
    if (mounted) setState(() => _kitchen = refreshedKitchen);
  }

  Future<void> _confirm(MenuItem item) async {
    final placed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OrderConfirmationPage(
          kitchen: _kitchen,
          item: item,
          walletRepository: widget.walletRepository,
          orderRepository: widget.orderRepository,
          notificationDispatcher: widget.notificationDispatcher,
        ),
      ),
    );
    if (placed == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_kitchen.name)),
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<MenuItem>>(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              key: Key('customer-menu-loading'),
              child: CircularProgressIndicator(),
            );
          }
          if (snapshot.hasError) {
            return ListView(
              key: const Key('customer-menu-error'),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 100),
                const Icon(Icons.cloud_off_outlined, size: 64),
                const Text(
                  'Could not load this menu.',
                  textAlign: TextAlign.center,
                ),
                Center(
                  child: TextButton(
                    onPressed: _refresh,
                    child: const Text('Retry'),
                  ),
                ),
              ],
            );
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return ListView(
              key: const Key('customer-menu-empty'),
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 100),
                Icon(Icons.no_food_outlined, size: 64),
                Text(
                  'No available items right now.',
                  textAlign: TextAlign.center,
                ),
              ],
            );
          }
          return ListView.separated(
            key: const Key('customer-menu-list'),
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: items.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                final methods = <String>[
                  if (_kitchen.hasUsableBkash) 'bKash',
                  if (_kitchen.acceptsCod) 'Cash on Delivery',
                ];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _KitchenCover(
                          imageUrl: _kitchen.imagePath == null
                              ? null
                              : widget.kitchenImageRepository.publicUrl(
                                  _kitchen.imagePath!,
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _kitchen.name,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(child: Text(_kitchen.address)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    color: Colors.amber.shade700,
                                  ),
                                  Text(
                                    widget.ratingCount == 0
                                        ? ' New kitchen'
                                        : ' ${widget.ratingAverage.toStringAsFixed(1)} (${widget.ratingCount})',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                children: methods
                                    .map(
                                      (method) => Chip(
                                        avatar: Icon(
                                          method == 'bKash'
                                              ? Icons.phone_android
                                              : Icons.payments_outlined,
                                          size: 17,
                                        ),
                                        label: Text(method),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final item = items[index - 1];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      MenuImageView(
                        imageRepository: widget.imageRepository,
                        imagePath: item.imagePath,
                        imageUrl: item.imageUrl,
                        size: 80,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (item.description != null)
                              Text(
                                item.description!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            Text('৳${item.price.toStringAsFixed(2)}'),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: () => _confirm(item),
                        child: const Text('Order'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    ),
  );
}

class _KitchenCover extends StatelessWidget {
  const _KitchenCover({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        key: const Key('customer-kitchen-cover'),
        height: 210,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _KitchenCoverFallback(),
      );
    }
    return const _KitchenCoverFallback();
  }
}

class _KitchenCoverFallback extends StatelessWidget {
  const _KitchenCoverFallback();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('customer-kitchen-cover-fallback'),
    height: 210,
    width: double.infinity,
    color: Theme.of(context).colorScheme.primaryContainer,
    alignment: Alignment.center,
    child: const Icon(Icons.storefront_rounded, size: 72),
  );
}
