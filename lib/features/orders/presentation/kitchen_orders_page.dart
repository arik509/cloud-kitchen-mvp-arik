import 'dart:async';

import 'package:flutter/material.dart';

import '../../chat/data/chat_repository.dart';
import '../../chat/presentation/order_chat_page.dart';
import '../../notifications/data/notification_dispatcher.dart';
import '../../payments/data/payment_repository.dart';
import '../../payments/domain/payment_models.dart';
import '../data/kitchen_order_repository.dart';
import '../domain/order_models.dart';
import 'order_ui.dart';

enum KitchenOrderFilter { newOrders, active, ready, delivery, history }

class KitchenOrdersPage extends StatefulWidget {
  const KitchenOrdersPage({
    required this.repository,
    this.chatRepository,
    this.paymentRepository,
    this.notificationDispatcher,
    super.key,
  });

  final KitchenOrderRepository repository;
  final ChatRepository? chatRepository;
  final PaymentRepository? paymentRepository;
  final OrderNotificationDispatcher? notificationDispatcher;

  @override
  State<KitchenOrdersPage> createState() => _KitchenOrdersPageState();
}

class _KitchenOrdersPageState extends State<KitchenOrdersPage> {
  late Future<List<KitchenOrder>> _orders;
  Timer? _pollTimer;
  KitchenOrderFilter _filter = KitchenOrderFilter.newOrders;
  final Set<String> _updating = {};

  @override
  void initState() {
    super.initState();
    _orders = widget.repository.fetchOwnerOrders();
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
    final future = widget.repository.fetchOwnerOrders();
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

  Future<void> _transition(KitchenOrder order, OrderStatus target) async {
    if (_updating.contains(order.id)) return;
    if (target == OrderStatus.rejected) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reject and refund order?'),
          content: Text(
            'The order will be rejected and ${orderCurrency(order.finalPrice)} '
            'will be returned to the customer wallet.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reject & refund'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _updating.add(order.id));
    try {
      final result = await widget.repository.updateStatus(order.id, target);
      await dispatchOrderEventsBestEffort(
        widget.notificationDispatcher,
        order.id,
      );
      if (!mounted) return;
      await _refresh(silent: true);
      if (!mounted) return;
      final refund = result.refundedAmount;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            refund != null && refund > 0
                ? 'Order rejected. ${orderCurrency(refund)} refunded.'
                : 'Order marked ${orderStatusLabel(result.status)}.',
          ),
        ),
      );
    } on KitchenOrderRepositoryException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      await _refresh(silent: true);
    } finally {
      if (mounted) setState(() => _updating.remove(order.id));
    }
  }

  Future<void> _reviewPayment(
    KitchenOrder order, {
    required bool verify,
  }) async {
    final repository = widget.paymentRepository;
    if (repository == null || _updating.contains(order.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          verify ? 'Verify bKash payment?' : 'Reject Transaction ID?',
        ),
        content: Text(
          verify
              ? 'Confirm that ${orderCurrency(order.finalPrice)} was received in the kitchen bKash account.'
              : 'The customer can submit a corrected Transaction ID for this same order.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(verify ? 'Verify Payment' : 'Reject ID'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _updating.add(order.id));
    try {
      await repository.reviewBkash(order.id, verify: verify);
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

  Future<void> _markRefundCompleted(KitchenOrder order) async {
    final repository = widget.paymentRepository;
    if (repository == null || _updating.contains(order.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark refund completed?'),
        content: Text(
          'Confirm that ${orderCurrency(order.finalPrice)} was manually refunded through bKash.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Refund Completed'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _updating.add(order.id));
    try {
      await repository.markRefundCompleted(order.id);
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

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
        child: SegmentedButton<KitchenOrderFilter>(
          segments: const [
            ButtonSegment(
              value: KitchenOrderFilter.newOrders,
              label: Text('New'),
              icon: Icon(Icons.fiber_new_outlined),
            ),
            ButtonSegment(
              value: KitchenOrderFilter.active,
              label: Text('Active'),
              icon: Icon(Icons.soup_kitchen_outlined),
            ),
            ButtonSegment(
              value: KitchenOrderFilter.ready,
              label: Text('Ready'),
              icon: Icon(Icons.task_alt),
            ),
            ButtonSegment(
              value: KitchenOrderFilter.history,
              label: Text('History'),
              icon: Icon(Icons.history),
            ),
            ButtonSegment(
              value: KitchenOrderFilter.delivery,
              label: Text('Delivery'),
              icon: Icon(Icons.delivery_dining),
            ),
          ],
          selected: {_filter},
          onSelectionChanged: (selection) =>
              setState(() => _filter = selection.single),
        ),
      ),
      Expanded(
        child: FutureBuilder<List<KitchenOrder>>(
          future: _orders,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                key: Key('kitchen-orders-loading'),
                child: CircularProgressIndicator(),
              );
            }
            if (snapshot.hasError) return _error(snapshot.error);
            final allOrders = snapshot.data!;
            final orders = allOrders.where(_matchesFilter).toList();
            if (orders.isEmpty) return _empty(allOrders.isEmpty);
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                key: const Key('kitchen-orders-list'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) => _orderCard(orders[index]),
              ),
            );
          },
        ),
      ),
    ],
  );

  bool _matchesFilter(KitchenOrder order) => switch (_filter) {
    KitchenOrderFilter.newOrders => order.status == OrderStatus.pending,
    KitchenOrderFilter.active =>
      order.status == OrderStatus.accepted ||
          order.status == OrderStatus.preparing,
    KitchenOrderFilter.ready => order.status == OrderStatus.ready,
    KitchenOrderFilter.delivery =>
      order.status == OrderStatus.awaitingRider ||
          order.status == OrderStatus.riderAssigned ||
          order.status == OrderStatus.pickedUp,
    KitchenOrderFilter.history =>
      order.status == OrderStatus.rejected ||
          order.status == OrderStatus.delivered,
  };

  Widget _error(Object? error) {
    final message = error is KitchenOrderRepositoryException
        ? error.message
        : 'Could not load kitchen orders. Check your connection.';
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        key: const Key('kitchen-orders-error'),
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
      ),
    );
  }

  Widget _empty(bool hasNoOrders) => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      key: const Key('kitchen-orders-empty'),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 100),
        const Icon(Icons.receipt_long_outlined, size: 64),
        const SizedBox(height: 12),
        Text(
          hasNoOrders ? 'No kitchen orders yet' : 'No orders in this section',
          textAlign: TextAlign.center,
        ),
        const Text(
          'Pull down to check for updates.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  Widget _orderCard(KitchenOrder order) {
    final busy = _updating.contains(order.id);
    final transitions = allowedKitchenOrderTransitions(order.status);
    final shortId = order.id.substring(
      0,
      order.id.length < 8 ? order.id.length : 8,
    );
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
                    'Order #$shortId',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  backgroundColor: orderStatusColor(context, order.status),
                  label: Text(orderStatusLabel(order.status)),
                ),
              ],
            ),
            Text('${order.quantity} × ${order.itemName}'),
            Text('Unit price: ${orderCurrency(order.unitPrice)}'),
            Text('Item total: ${orderCurrency(order.itemTotal)}'),
            Text(
              'Authoritative total: ${orderCurrency(order.finalPrice)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Deliver to',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(order.deliveryAddress),
            const SizedBox(height: 6),
            Text(orderTime(order.createdAt)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PAYMENT',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    paymentStatusLabel(
                      order.payment.method,
                      order.payment.status,
                    ),
                  ),
                  if (order.payment.method == PaymentMethod.bkash &&
                      order.payment.transactionId != null)
                    SelectableText(
                      'Transaction ID: ${order.payment.transactionId}',
                      key: Key('owner-transaction-${order.id}'),
                    ),
                  if (order.payment.submittedAt != null)
                    Text('Submitted: ${orderTime(order.payment.submittedAt!)}'),
                ],
              ),
            ),
            if (!busy &&
                order.payment.method == PaymentMethod.bkash &&
                order.payment.status == PaymentStatus.awaitingVerification &&
                widget.paymentRepository != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    key: Key('verify-payment-${order.id}'),
                    onPressed: () => _reviewPayment(order, verify: true),
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('Verify Payment'),
                  ),
                  OutlinedButton.icon(
                    key: Key('reject-payment-${order.id}'),
                    onPressed: () => _reviewPayment(order, verify: false),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject Transaction ID'),
                  ),
                ],
              ),
            ],
            if (!busy &&
                order.payment.status == PaymentStatus.refundPending &&
                widget.paymentRepository != null)
              FilledButton.tonalIcon(
                key: Key('refund-complete-${order.id}'),
                onPressed: () => _markRefundCompleted(order),
                icon: const Icon(Icons.currency_exchange),
                label: const Text('Mark Refund Completed'),
              ),
            if (isOrderChatAvailable(order.status) &&
                widget.chatRepository != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: Key('owner-chat-${order.id}'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderChatPage(
                      repository: widget.chatRepository!,
                      orderId: order.id,
                      title: 'Chat with Customer',
                    ),
                  ),
                ),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Chat with Customer'),
              ),
            ],
            if (transitions.isNotEmpty) ...[
              const SizedBox(height: 12),
              if (busy) const LinearProgressIndicator(),
              if (!busy)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: transitions
                      .where(
                        (target) =>
                            target != OrderStatus.accepted ||
                            isPaymentReadyForPreparation(order.payment),
                      )
                      .map((target) {
                        final reject = target == OrderStatus.rejected;
                        return reject
                            ? OutlinedButton.icon(
                                key: Key('reject-${order.id}'),
                                onPressed: () => _transition(order, target),
                                icon: const Icon(Icons.close),
                                label: const Text('Reject'),
                              )
                            : FilledButton.icon(
                                key: Key(
                                  '${orderStatusValue(target)}-${order.id}',
                                ),
                                onPressed: () => _transition(order, target),
                                icon: const Icon(Icons.arrow_forward),
                                label: Text(orderStatusLabel(target)),
                              );
                      })
                      .toList(),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
