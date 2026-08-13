import 'package:flutter/material.dart';

import '../data/order_repository.dart';
import '../domain/order_models.dart';

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({required this.repository, super.key});

  final OrderRepository repository;

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  late Future<List<CustomerOrder>> _orders;

  @override
  void initState() {
    super.initState();
    _orders = widget.repository.fetchCurrentCustomerOrders();
  }

  Future<void> _refresh() async {
    final future = widget.repository.fetchCurrentCustomerOrders();
    setState(() {
      _orders = future;
    });
    await future;
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
                        Chip(label: Text(orderStatusLabel(order.status))),
                      ],
                    ),
                    Text(order.itemName),
                    Text(
                      'Item ${_currency(order.itemPrice)} · Total ${_currency(order.finalPrice)}',
                    ),
                    const SizedBox(height: 6),
                    Text(order.deliveryAddress),
                    const SizedBox(height: 6),
                    Text(_formatTime(order.createdAt)),
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

String orderStatusLabel(OrderStatus status) => switch (status) {
  OrderStatus.pending => 'Pending',
  OrderStatus.accepted => 'Accepted',
  OrderStatus.rejected => 'Rejected',
  OrderStatus.preparing => 'Preparing',
  OrderStatus.ready => 'Ready',
  OrderStatus.awaitingRider => 'Awaiting rider',
  OrderStatus.riderAssigned => 'Rider assigned',
  OrderStatus.pickedUp => 'Picked up',
  OrderStatus.delivered => 'Delivered',
};

String _currency(double amount) => '৳${amount.toStringAsFixed(2)}';

String _formatTime(DateTime time) {
  final local = time.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
