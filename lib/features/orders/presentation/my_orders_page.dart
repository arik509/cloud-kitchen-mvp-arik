import 'dart:async';

import 'package:flutter/material.dart';

import '../../chat/data/chat_repository.dart';
import '../../chat/presentation/order_chat_page.dart';
import '../data/order_repository.dart';
import '../domain/order_models.dart';
import 'order_ui.dart';

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({
    required this.repository,
    this.chatRepository,
    super.key,
  });

  final OrderRepository repository;
  final ChatRepository? chatRepository;

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  late Future<List<CustomerOrder>> _orders;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _orders = widget.repository.fetchCurrentCustomerOrders();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refresh(silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    final future = widget.repository.fetchCurrentCustomerOrders();
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _orders = future;
      });
    }
    try {
      final orders = await future;
      if (mounted && silent) {
        setState(() {
          _orders = Future.value(orders);
        });
      }
    } catch (_) {
      if (!silent && mounted) {
        setState(() {
          _orders = future;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _refresh,
    child: FutureBuilder<List<CustomerOrder>>(
      future: _orders,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            key: Key('orders-loading'),
            child: CircularProgressIndicator(),
          );
        }
        if (snapshot.hasError) {
          final message = snapshot.error is OrderRepositoryException
              ? (snapshot.error! as OrderRepositoryException).message
              : 'Could not load your orders. Check your connection.';
          return ListView(
            key: const Key('orders-error'),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 100),
              const Icon(Icons.cloud_off_outlined, size: 64),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              Center(
                child: TextButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ),
            ],
          );
        }
        final orders = snapshot.data!;
        if (orders.isEmpty) {
          return ListView(
            key: const Key('orders-empty'),
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 100),
              Icon(Icons.receipt_long_outlined, size: 64),
              SizedBox(height: 12),
              Text('No orders yet', textAlign: TextAlign.center),
              Text(
                'Your placed orders will appear here.',
                textAlign: TextAlign.center,
              ),
            ],
          );
        }
        return ListView.separated(
          key: const Key('orders-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final order = orders[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.kitchenName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Chip(
                          backgroundColor: orderStatusColor(
                            context,
                            order.status,
                          ),
                          label: Text(orderStatusLabel(order.status)),
                        ),
                      ],
                    ),
                    Text(order.itemName),
                    Text(
                      'Item ${orderCurrency(order.itemPrice)} · '
                      'Total ${orderCurrency(order.finalPrice)}',
                    ),
                    const SizedBox(height: 6),
                    Text(order.deliveryAddress),
                    const SizedBox(height: 6),
                    Text(orderTime(order.createdAt)),
                    if (isOrderChatAvailable(order.status) &&
                        widget.chatRepository != null) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        key: Key('customer-chat-${order.id}'),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OrderChatPage(
                              repository: widget.chatRepository!,
                              orderId: order.id,
                              title: order.kitchenName,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Contact Kitchen'),
                      ),
                    ],
                    if (order.status == OrderStatus.rejected) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Rejected · The full order total was returned to your wallet.',
                        key: Key('order-refund-message'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
