import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/location/location_map_view.dart';
import '../../../core/presentation/app_ui.dart';
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
    this.onDeliveryCompleted,
    super.key,
  });
  final RiderDeliveryRepository repository;
  final PaymentRepository? paymentRepository;
  final OrderNotificationDispatcher? notificationDispatcher;

  /// Called whenever a delivery action (advance status, cash collected) succeeds.
  final VoidCallback? onDeliveryCompleted;

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
        setState(() {
          _deliveries = Future.value(result);
        });
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
      widget.onDeliveryCompleted?.call();
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
      widget.onDeliveryCompleted?.call();
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
                AppStatusBadge(
                  label: orderStatusLabel(delivery.status),
                  icon: Icons.route_outlined,
                ),
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
            if (_section == RiderDeliverySection.active) ...[
              const SizedBox(height: 14),
              _DeliveryProgress(delivery: delivery),
              const SizedBox(height: 14),
              _activeDeliveryMap(delivery),
            ],
            const SizedBox(height: 12),
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

  Widget _activeDeliveryMap(RiderDelivery delivery) {
    final kitchen = delivery.kitchenCoordinates;
    final customer = delivery.deliveryCoordinates;
    final markers = <LocationMapMarker>[
      if (kitchen != null)
        LocationMapMarker(
          id: 'pickup',
          label: 'Pickup',
          coordinates: kitchen,
          color: Theme.of(context).colorScheme.primary,
          icon: Icons.storefront,
        ),
      if (customer != null)
        LocationMapMarker(
          id: 'delivery',
          label: 'Delivery',
          coordinates: customer,
          color: Theme.of(context).colorScheme.tertiary,
          icon: Icons.location_on,
        ),
    ];
    if (markers.isEmpty) {
      return Container(
        key: Key('delivery-map-unavailable-${delivery.id}'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(Icons.map_outlined),
            SizedBox(width: 10),
            Expanded(
              child: Text('Delivery location not available for this order.'),
            ),
          ],
        ),
      );
    }
    final focus = delivery.status == OrderStatus.pickedUp
        ? customer ?? kitchen
        : kitchen ?? customer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.route_outlined),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                delivery.status == OrderStatus.pickedUp
                    ? 'Delivery location focus'
                    : 'Kitchen pickup focus',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            key: Key('active-delivery-map-${delivery.id}'),
            height: 260,
            child: LocationMapView(
              markers: markers,
              initialCenter: focus,
              fitMarkers: false,
              initialZoom: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _DeliveryProgress extends StatelessWidget {
  const _DeliveryProgress({required this.delivery});

  final RiderDelivery delivery;

  @override
  Widget build(BuildContext context) {
    final cod = delivery.payment.method == PaymentMethod.cashOnDelivery;
    final steps = [
      ('Claimed', true),
      ('Picked up', delivery.status == OrderStatus.pickedUp),
      if (cod) ('Cash', delivery.payment.status == PaymentStatus.collected),
      ('Delivered', delivery.status == OrderStatus.delivered),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DELIVERY PROGRESS',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var index = 0; index < steps.length; index++) ...[
              Expanded(
                child: Column(
                  children: [
                    Icon(
                      steps[index].$2
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: steps[index].$2
                          ? Theme.of(context).colorScheme.secondary
                          : Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      steps[index].$1,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              if (index < steps.length - 1)
                Expanded(
                  child: Divider(
                    color: steps[index].$2
                        ? Theme.of(context).colorScheme.secondary
                        : null,
                  ),
                ),
            ],
          ],
        ),
      ],
    );
  }
}
