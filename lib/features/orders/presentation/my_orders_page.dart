import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/presentation/app_ui.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/presentation/order_chat_page.dart';
import '../../notifications/data/notification_dispatcher.dart';
import '../../payments/data/payment_repository.dart';
import '../../payments/domain/payment_models.dart';
import '../../ratings/data/rating_repository.dart';
import '../../ratings/presentation/rating_dialog.dart';
import '../data/order_repository.dart';
import '../domain/order_models.dart';
import 'order_ui.dart';

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({
    required this.repository,
    required this.chatRepository,
    this.paymentRepository,
    this.ratingRepository,
    this.notificationDispatcher,
    this.profilePhoneLoader,
    super.key,
  });

  final OrderRepository repository;
  final ChatRepository chatRepository;
  final PaymentRepository? paymentRepository;
  final RatingRepository? ratingRepository;
  final OrderNotificationDispatcher? notificationDispatcher;
  final Future<String?> Function()? profilePhoneLoader;

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  late Future<List<CustomerOrder>> _orders;
  Timer? _pollTimer;
  final Set<String> _updating = {};
  late final Future<String?> _profilePhone;

  @override
  void initState() {
    super.initState();
    _orders = widget.repository.fetchCurrentCustomerOrders();
    _profilePhone = widget.profilePhoneLoader?.call() ?? Future.value(null);
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

  Future<void> _resubmit(CustomerOrder order) async {
    final repository = widget.paymentRepository;
    if (repository == null || _updating.contains(order.id)) return;
    final controller = TextEditingController();
    final transactionId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Correct Transaction ID'),
        content: TextField(
          key: const Key('resubmit-transaction-id'),
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'bKash Transaction ID'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final error = validateBkashTransactionId(controller.text);
              if (error == null) Navigator.pop(context, controller.text);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (transactionId == null || !mounted) return;
    setState(() => _updating.add(order.id));
    try {
      await repository.submitBkashTransaction(order.id, transactionId);
      await dispatchOrderEventsBestEffort(
        widget.notificationDispatcher,
        order.id,
      );
      await _refresh(silent: true);
    } on PaymentException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _updating.remove(order.id));
    }
  }

  Future<void> _rate(CustomerOrder order) async {
    final repository = widget.ratingRepository;
    if (repository == null) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => RatingDialog(repository: repository, orderId: order.id),
    );
    if (saved == true) await _refresh(silent: true);
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
                        AppStatusBadge(
                          label: orderStatusLabel(order.status),
                          icon: _orderStatusIcon(order.status),
                          color: _orderStatusForeground(context, order.status),
                        ),
                      ],
                    ),
                    Text('${order.itemName} × ${order.quantity}'),
                    Text(
                      'Item ${orderCurrency(order.itemPrice)} · '
                      'Total ${orderCurrency(order.finalPrice)}',
                    ),
                    const SizedBox(height: 6),
                    Text(order.deliveryAddress),
                    const SizedBox(height: 6),
                    Text(orderTime(order.createdAt)),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PAYMENT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            paymentStatusLabel(
                              order.payment.method,
                              order.payment.status,
                            ),
                            key: Key('payment-status-${order.id}'),
                          ),
                          if (order.payment.status ==
                              PaymentStatus.refundPending)
                            _refundPolicy(),
                        ],
                      ),
                    ),
                    if (order.payment.method == PaymentMethod.bkash &&
                        order.payment.status == PaymentStatus.rejected &&
                        widget.paymentRepository != null) ...[
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        key: Key('resubmit-bkash-${order.id}'),
                        onPressed: _updating.contains(order.id)
                            ? null
                            : () => _resubmit(order),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Submit corrected Transaction ID'),
                      ),
                    ],
                    if (isOrderChatAvailable(order.status)) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          key: Key('customer-chat-${order.id}'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrderChatPage(
                                repository: widget.chatRepository,
                                orderId: order.id,
                                title: order.kitchenName,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Chat with Kitchen'),
                        ),
                      ),
                    ],
                    if (order.status == OrderStatus.delivered &&
                        order.ratingStars == null &&
                        widget.ratingRepository != null) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        key: Key('rate-order-${order.id}'),
                        onPressed: () => _rate(order),
                        icon: const Icon(Icons.star_outline_rounded),
                        label: const Text('Rate Order'),
                      ),
                    ],
                    if (order.ratingStars != null)
                      Text(
                        'Your rating: ${List.filled(order.ratingStars!, '★').join()}',
                        key: Key('order-rating-${order.id}'),
                      ),
                    if (order.status == OrderStatus.rejected &&
                        order.payment.method == PaymentMethod.demoWallet) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'This historical order payment was reversed.',
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

  Widget _refundPolicy() => FutureBuilder<String?>(
    future: _profilePhone,
    builder: (context, snapshot) {
      final validPhone = isValidBangladeshPhone(snapshot.data);
      return Container(
        key: const Key('bkash-refund-policy'),
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Refund will be processed manually within 3 working days.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              validPhone
                  ? 'It will be sent to the mobile number registered on your FoodCircle profile.'
                  : 'Add a valid Bangladesh mobile number in Profile before refund processing.',
              key: Key(
                validPhone ? 'refund-phone-ready' : 'refund-phone-warning',
              ),
            ),
          ],
        ),
      );
    },
  );

  IconData _orderStatusIcon(OrderStatus status) => switch (status) {
    OrderStatus.pending => Icons.schedule,
    OrderStatus.accepted ||
    OrderStatus.preparing => Icons.soup_kitchen_outlined,
    OrderStatus.ready => Icons.task_alt,
    OrderStatus.rejected => Icons.cancel_outlined,
    OrderStatus.awaitingRider ||
    OrderStatus.riderAssigned => Icons.delivery_dining,
    OrderStatus.pickedUp => Icons.route_outlined,
    OrderStatus.delivered => Icons.check_circle_outline,
  };

  Color _orderStatusForeground(BuildContext context, OrderStatus status) =>
      switch (status) {
        OrderStatus.rejected => Theme.of(context).colorScheme.error,
        OrderStatus.ready || OrderStatus.delivered => Colors.green.shade700,
        _ => Theme.of(context).colorScheme.primary,
      };
}
