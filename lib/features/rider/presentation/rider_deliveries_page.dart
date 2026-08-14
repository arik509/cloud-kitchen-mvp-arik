import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/navigation/external_navigation.dart';
import '../../notifications/data/notification_dispatcher.dart';
import '../../orders/domain/order_models.dart';
import '../../orders/presentation/order_ui.dart';
import '../../payments/data/payment_repository.dart';
import '../../payments/domain/payment_models.dart';
import '../data/rider_delivery_repository.dart';
import '../domain/rider_delivery.dart';

enum RiderDeliverySection { available, active, history }

class RiderDeliveriesPage extends StatefulWidget {
  const RiderDeliveriesPage({
    required this.repository,
    this.paymentRepository,
    this.notificationDispatcher,
    this.navigation = const UrlExternalNavigation(),
    super.key,
  });
  final RiderDeliveryRepository repository;
  final PaymentRepository? paymentRepository;
  final OrderNotificationDispatcher? notificationDispatcher;
  final ExternalNavigation navigation;

  @override
  State<RiderDeliveriesPage> createState() => _RiderDeliveriesPageState();
}

class _RiderDeliveriesPageState extends State<RiderDeliveriesPage> {
  RiderDeliverySection _section = RiderDeliverySection.available;
  late Future<List<RiderDelivery>> _deliveries;
  Timer? _timer;
  final Set<String> _updating = {};

  @override
  void initState() {
    super.initState();
    _deliveries = _load();
    _timer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refresh(silent: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<List<RiderDelivery>> _load() =>
      _section == RiderDeliverySection.available
      ? widget.repository.fetchAvailable()
      : widget.repository.fetchMine();

  Future<void> _refresh({bool silent = false}) async {
    final future = _load();
    if (!silent && mounted) {
      setState(() {
        _deliveries = future;
      });
    }
    try {
      final result = await future;
      if (silent && mounted) {
        setState(() => _deliveries = Future.value(result));
      }
    } catch (_) {
      if (!silent && mounted) {
        setState(() {
          _deliveries = future;
        });
      }
    }
  }

  void _select(RiderDeliverySection section) {
    if (_section == section) return;
    setState(() {
      _section = section;
      _deliveries = _load();
    });
  }

  Future<void> _claim(RiderDelivery delivery) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept this delivery?'),
        content: Text(
          'Pick up from ${delivery.kitchenName} and deliver to '
          '${delivery.deliveryAddress}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Accept delivery'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _mutate(delivery.id, () => widget.repository.claim(delivery.id));
  }

  Future<void> _advance(RiderDelivery delivery) async {
    final target = nextRiderStatus(delivery.status);
    if (target == null) return;
    final action = target == OrderStatus.pickedUp
        ? 'Mark as picked up'
        : 'Mark as delivered';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$action?'),
        content: Text(
          target == OrderStatus.pickedUp
              ? 'Confirm that you collected this order from the kitchen.'
              : 'Confirm that this order reached the delivery address.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _mutate(
      delivery.id,
      () => widget.repository.updateStatus(delivery.id, target),
    );
  }

  Future<void> _collectCash(RiderDelivery delivery) async {
    final repository = widget.paymentRepository;
    if (repository == null || _updating.contains(delivery.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cash Collected?'),
        content: Text(
          'Confirm you collected the authoritative amount ${orderCurrency(delivery.finalPrice)} from the customer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cash Collected'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _updating.add(delivery.id));
    try {
      await repository.confirmCodCollection(delivery.id);
      await dispatchOrderEventsBestEffort(
        widget.notificationDispatcher,
        delivery.id,
      );
      await _refresh(silent: true);
    } on PaymentException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _updating.remove(delivery.id));
    }
  }

  Future<void> _navigate(bool kitchen, RiderDelivery delivery) async {
    final opened =
        kitchen &&
            delivery.kitchenLatitude != null &&
            delivery.kitchenLongitude != null
        ? await widget.navigation.toCoordinates(
            delivery.kitchenLatitude!,
            delivery.kitchenLongitude!,
          )
        : await widget.navigation.toAddress(
            kitchen ? delivery.kitchenAddress : delivery.deliveryAddress,
          );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open a maps application.')),
      );
    }
  }

  Future<void> _mutate(
    String orderId,
    Future<RiderDeliveryUpdate> Function() operation,
  ) async {
    if (_updating.contains(orderId)) return;
    setState(() => _updating.add(orderId));
    try {
      final result = await operation();
      await dispatchOrderEventsBestEffort(
        widget.notificationDispatcher,
        orderId,
      );
      if (!mounted) return;
      await _refresh(silent: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delivery is ${orderStatusLabel(result.status)}.'),
        ),
      );
    } on RiderDeliveryException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      await _refresh(silent: true);
    } finally {
      if (mounted) setState(() => _updating.remove(orderId));
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: SegmentedButton<RiderDeliverySection>(
          segments: const [
            ButtonSegment(
              value: RiderDeliverySection.available,
              label: Text('Available'),
              icon: Icon(Icons.delivery_dining),
            ),
            ButtonSegment(
              value: RiderDeliverySection.active,
              label: Text('Active'),
              icon: Icon(Icons.route_outlined),
            ),
            ButtonSegment(
              value: RiderDeliverySection.history,
              label: Text('History'),
              icon: Icon(Icons.history),
            ),
          ],
          selected: {_section},
          onSelectionChanged: (selection) => _select(selection.single),
        ),
      ),
      Expanded(
        child: FutureBuilder<List<RiderDelivery>>(
          future: _deliveries,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                key: Key('rider-deliveries-loading'),
                child: CircularProgressIndicator(),
              );
            }
            if (snapshot.hasError) return _error(snapshot.error);
            final deliveries = snapshot.data!.where(_matchesSection).toList();
            if (deliveries.isEmpty) return _empty();
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                key: const Key('rider-deliveries-list'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: deliveries.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) => _card(deliveries[index]),
              ),
            );
          },
        ),
      ),
    ],
  );

  bool _matchesSection(RiderDelivery delivery) => switch (_section) {
    RiderDeliverySection.available =>
      delivery.status == OrderStatus.awaitingRider,
    RiderDeliverySection.active =>
      delivery.status == OrderStatus.riderAssigned ||
          delivery.status == OrderStatus.pickedUp,
    RiderDeliverySection.history => delivery.status == OrderStatus.delivered,
  };

  Widget _error(Object? error) {
    final message = error is RiderDeliveryException
        ? error.message
        : 'Could not load deliveries. Check your connection.';
    return ListView(
      key: const Key('rider-deliveries-error'),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 100),
        const Icon(Icons.cloud_off_outlined, size: 64),
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

  Widget _empty() => ListView(
    key: const Key('rider-deliveries-empty'),
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      const SizedBox(height: 100),
      const Icon(Icons.delivery_dining_outlined, size: 64),
      Text(switch (_section) {
        RiderDeliverySection.available => 'No available deliveries',
        RiderDeliverySection.active => 'No active delivery',
        RiderDeliverySection.history => 'No completed deliveries',
      }, textAlign: TextAlign.center),
      const Text(
        'Pull down to check for updates.',
        textAlign: TextAlign.center,
      ),
    ],
  );

  Widget _card(RiderDelivery delivery) {
    final busy = _updating.contains(delivery.id);
    final shortId = delivery.id.substring(
      0,
      delivery.id.length < 8 ? delivery.id.length : 8,
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
                Chip(label: Text(orderStatusLabel(delivery.status))),
              ],
            ),
            Text('${delivery.quantity} × ${delivery.itemName}'),
            const SizedBox(height: 8),
            const Text(
              'Pick up',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(delivery.kitchenName),
            Text(delivery.kitchenAddress),
            const SizedBox(height: 8),
            const Text(
              'Deliver to',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(delivery.deliveryAddress),
            const SizedBox(height: 8),
            Text('Order total: ${orderCurrency(delivery.finalPrice)}'),
            Text('Delivery earning: ${orderCurrency(delivery.riderFee)}'),
            Text(
              'Payment: ${paymentStatusLabel(delivery.payment.method, delivery.payment.status)}',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: Key('navigate-kitchen-${delivery.id}'),
                  onPressed: () => _navigate(true, delivery),
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('Navigate to Kitchen'),
                ),
                OutlinedButton.icon(
                  key: Key('navigate-customer-${delivery.id}'),
                  onPressed: () => _navigate(false, delivery),
                  icon: const Icon(Icons.navigation_outlined),
                  label: const Text('Navigate to Customer'),
                ),
              ],
            ),
            if (busy) const LinearProgressIndicator(),
            if (!busy && _section == RiderDeliverySection.available)
              FilledButton.icon(
                key: Key('claim-${delivery.id}'),
                onPressed: () => _claim(delivery),
                icon: const Icon(Icons.check),
                label: const Text('Accept delivery'),
              ),
            if (!busy &&
                _section == RiderDeliverySection.active &&
                delivery.status == OrderStatus.pickedUp &&
                delivery.payment.method == PaymentMethod.cashOnDelivery &&
                delivery.payment.status == PaymentStatus.codPending)
              FilledButton.icon(
                key: Key('cash-collected-${delivery.id}'),
                onPressed: () => _collectCash(delivery),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Cash Collected'),
              ),
            if (!busy &&
                _section == RiderDeliverySection.active &&
                !(delivery.status == OrderStatus.pickedUp &&
                    delivery.payment.method == PaymentMethod.cashOnDelivery &&
                    delivery.payment.status == PaymentStatus.codPending))
              FilledButton.icon(
                key: Key('advance-${delivery.id}'),
                onPressed: () => _advance(delivery),
                icon: const Icon(Icons.arrow_forward),
                label: Text(
                  delivery.status == OrderStatus.riderAssigned
                      ? 'Mark as picked up'
                      : 'Mark as delivered',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
