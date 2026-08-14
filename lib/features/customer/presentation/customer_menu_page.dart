import 'package:flutter/material.dart';

import '../../kitchen/domain/kitchen.dart';
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

  @override
  void initState() {
    super.initState();
    _items = widget.catalogRepository.fetchAvailableMenuItems(
      widget.kitchen.id,
    );
  }

  Future<void> _refresh() async {
    final future = widget.catalogRepository.fetchAvailableMenuItems(
      widget.kitchen.id,
    );
    setState(() {
      _items = future;
    });
    await future;
  }

  Future<void> _confirm(MenuItem item) async {
    final placed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OrderConfirmationPage(
          kitchen: widget.kitchen,
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
    appBar: AppBar(title: Text(widget.kitchen.name)),
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
                  if (widget.kitchen.acceptsBkash) 'bKash',
                  if (widget.kitchen.acceptsCod) 'Cash on Delivery',
                ];
                return Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.kitchen.name,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(widget.kitchen.address),
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
                              .map((method) => Chip(label: Text(method)))
                              .toList(),
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
