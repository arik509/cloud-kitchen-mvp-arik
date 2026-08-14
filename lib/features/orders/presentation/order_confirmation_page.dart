import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/location/location_models.dart';
import '../../../core/location/location_picker_page.dart';
import '../../../core/location/location_service.dart';
import '../../kitchen/domain/kitchen.dart';
import '../../menu/domain/menu_item.dart';
import '../../notifications/data/notification_dispatcher.dart';
import '../../payments/domain/payment_models.dart';
import '../../wallet/data/wallet_repository.dart';
import '../data/order_repository.dart';
import '../domain/order_models.dart';
import 'order_ui.dart';

class OrderConfirmationPage extends StatefulWidget {
  const OrderConfirmationPage({
    required this.kitchen,
    required this.item,
    required this.walletRepository,
    required this.orderRepository,
    this.notificationDispatcher,
    this.locationService = const GeolocatorLocationService(),
    super.key,
  });

  final Kitchen kitchen;
  final MenuItem item;
  final WalletRepository
  walletRepository; // Retained only for legacy test utilities.
  final OrderRepository orderRepository;
  final OrderNotificationDispatcher? notificationDispatcher;
  final LocationService locationService;

  @override
  State<OrderConfirmationPage> createState() => _OrderConfirmationPageState();
}

class _OrderConfirmationPageState extends State<OrderConfirmationPage> {
  final _formKey = GlobalKey<FormState>();
  final _address = TextEditingController();
  final _transactionId = TextEditingController();
  late PaymentMethod _method;
  bool _submitting = false;
  PlaceOrderResult? _result;
  String? _error;
  GeoCoordinates? _deliveryLocation;
  String? _locationError;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    final methods = availableCheckoutPaymentMethods(widget.kitchen);
    _method = methods.isNotEmpty ? methods.first : PaymentMethod.cashOnDelivery;
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      final location = await widget.locationService.determineLocation();
      if (!location.isValid) throw const FormatException();
      if (!mounted) return;
      setState(() => _deliveryLocation = location);
    } on LocationException catch (error) {
      if (mounted) setState(() => _locationError = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _locationError =
              'Current location is unavailable. Choose a pin on the map.',
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _chooseDeliveryLocation() async {
    final saved = _deliveryLocation;
    final initial = await resolveInitialMapLocation(
      savedLatitude: saved?.latitude,
      savedLongitude: saved?.longitude,
      currentLocation: widget.locationService.determineLocation,
    );
    if (!mounted) return;
    final selected = await Navigator.push<GeoCoordinates>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          initialLocation: initial,
          currentLocation: widget.locationService.determineLocation,
          title: 'Choose delivery location',
          instruction: 'Tap the map where the rider should deliver.',
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _deliveryLocation = selected;
      _locationError = null;
    });
  }

  Future<void> _placeOrder() async {
    if (_submitting || _result != null) {
      return;
    }
    final methods = availableCheckoutPaymentMethods(widget.kitchen);
    if (methods.isEmpty) {
      setState(
        () => _error =
            'This kitchen has no available payment method. Please contact the kitchen.',
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final location = _deliveryLocation;
    final locationError = validateDeliveryCoordinates(
      location?.latitude,
      location?.longitude,
    );
    if (locationError != null) {
      setState(() => _locationError = locationError);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await widget.orderRepository.placeOrder(
        PlaceOrderRequest(
          menuItemId: widget.item.id,
          deliveryAddress: _address.text,
          paymentMethod: _method,
          transactionId: _method == PaymentMethod.bkash
              ? _transactionId.text
              : null,
          deliveryLatitude: location!.latitude,
          deliveryLongitude: location.longitude,
        ),
      );
      if (!mounted) return;
      setState(() => _result = result);
      final dispatcher = widget.notificationDispatcher;
      if (dispatcher != null) {
        unawaited(dispatchOrderEventsBestEffort(dispatcher, result.orderId));
      }
    } on OrderRepositoryException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Network failure. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _address.dispose();
    _transactionId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Secure checkout')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _CheckoutSection(
              title: 'Selected item',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  widget.item.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(widget.kitchen.name),
                trailing: Text(
                  orderCurrency(widget.item.price),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (result == null)
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CheckoutSection(
                      title: 'Delivery address',
                      child: TextFormField(
                        key: const Key('delivery-address'),
                        controller: _address,
                        enabled: !_submitting,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Where should the rider deliver?',
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) {
                            return 'Delivery address is required';
                          }
                          if (text.length > 500) {
                            return 'Use 500 characters or fewer';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    _CheckoutSection(
                      title: 'Delivery location',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ListTile(
                            key: const Key('delivery-location-state'),
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              _deliveryLocation == null
                                  ? Icons.location_off_outlined
                                  : Icons.check_circle,
                              color: _deliveryLocation == null
                                  ? Theme.of(context).colorScheme.outline
                                  : Theme.of(context).colorScheme.primary,
                            ),
                            title: Text(
                              _deliveryLocation == null
                                  ? 'Not selected'
                                  : 'Location selected',
                            ),
                            subtitle: const Text(
                              'The pin is separate from delivery instructions.',
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonalIcon(
                                key: const Key('use-delivery-location'),
                                onPressed: _locating
                                    ? null
                                    : _useCurrentLocation,
                                icon: _locating
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.my_location),
                                label: Text(
                                  _locating
                                      ? 'Locating...'
                                      : 'Use Current Location',
                                ),
                              ),
                              OutlinedButton.icon(
                                key: const Key('choose-delivery-location'),
                                onPressed: _chooseDeliveryLocation,
                                icon: const Icon(Icons.map_outlined),
                                label: Text(
                                  _deliveryLocation == null
                                      ? 'Choose on Map'
                                      : 'Edit on Map',
                                ),
                              ),
                            ],
                          ),
                          if (_locationError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _locationError!,
                                key: const Key('delivery-location-error'),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _CheckoutSection(
                      title: 'Payment method',
                      child: Column(
                        children: [
                          if (widget.kitchen.hasUsableBkash)
                            _PaymentChoice(
                              key: const Key('payment-bkash'),
                              selected: _method == PaymentMethod.bkash,
                              icon: Icons.phone_android,
                              title: 'bKash',
                              subtitle: 'Manual Transaction ID verification',
                              accent: const Color(0xffd81b60),
                              onTap: () =>
                                  setState(() => _method = PaymentMethod.bkash),
                            ),
                          if (widget.kitchen.acceptsCod) ...[
                            if (widget.kitchen.hasUsableBkash)
                              const SizedBox(height: 10),
                            _PaymentChoice(
                              key: const Key('payment-cod'),
                              selected: _method == PaymentMethod.cashOnDelivery,
                              icon: Icons.payments_outlined,
                              title: 'Cash on Delivery',
                              subtitle: 'Pay the assigned rider when delivered',
                              onTap: () => setState(
                                () => _method = PaymentMethod.cashOnDelivery,
                              ),
                            ),
                          ],
                          if (widget.kitchen.acceptsBkash &&
                              !widget.kitchen.hasUsableBkash)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'bKash is temporarily unavailable because the kitchen receiving number is missing or invalid.',
                                key: Key('bkash-configuration-error'),
                              ),
                            ),
                          if (!widget.kitchen.hasUsablePaymentMethod)
                            Text(
                              'Ordering is unavailable until the kitchen enables a valid payment method.',
                              key: const Key('no-payment-methods'),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          if (_method == PaymentMethod.bkash) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xffffeef5),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Send ${orderCurrency(widget.item.price)} to ${widget.kitchen.bkashNumber}, then enter the Transaction ID below.',
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Payment will be manually verified by the Kitchen Owner.',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              key: const Key('bkash-transaction-id'),
                              controller: _transactionId,
                              enabled: !_submitting,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'bKash Transaction ID',
                              ),
                              validator: validateBkashTransactionId,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const Key('order-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            if (result == null)
              FilledButton.icon(
                key: const Key('place-order-button'),
                onPressed: _submitting || !widget.kitchen.hasUsablePaymentMethod
                    ? null
                    : _placeOrder,
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_outline),
                label: Text(
                  _submitting ? 'Placing order...' : 'Place secure order',
                ),
              )
            else
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 54),
                      const Text('Order placed', key: Key('order-success')),
                      Text(
                        'Total: ${orderCurrency(result.authoritativeTotal)}',
                      ),
                      Text(
                        paymentStatusLabel(
                          result.paymentMethod,
                          result.paymentStatus,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'One item per order. Price, payment, and identities are verified by the server.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

List<PaymentMethod> availableCheckoutPaymentMethods(Kitchen kitchen) => [
  if (kitchen.hasUsableBkash) PaymentMethod.bkash,
  if (kitchen.acceptsCod) PaymentMethod.cashOnDelivery,
];

class _CheckoutSection extends StatelessWidget {
  const _CheckoutSection({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );
}

class _PaymentChoice extends StatelessWidget {
  const _PaymentChoice({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent,
    super.key,
  });
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? accent;
  @override
  Widget build(BuildContext context) {
    final color = accent ?? Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? color
                : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          color: selected ? color.withValues(alpha: .07) : Colors.white,
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(subtitle),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? color : null,
            ),
          ],
        ),
      ),
    );
  }
}
