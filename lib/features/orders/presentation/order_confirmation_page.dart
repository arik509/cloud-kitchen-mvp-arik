import 'package:flutter/material.dart';

import '../../kitchen/domain/kitchen.dart';
import '../../menu/domain/menu_item.dart';
import '../../wallet/data/wallet_repository.dart';
import '../data/order_repository.dart';
import '../domain/order_models.dart';

class OrderConfirmationPage extends StatefulWidget {
  const OrderConfirmationPage({
    required this.kitchen,
    required this.item,
    required this.walletRepository,
    required this.orderRepository,
    super.key,
  });

  final Kitchen kitchen;
  final MenuItem item;
  final WalletRepository walletRepository;
  final OrderRepository orderRepository;

  @override
  State<OrderConfirmationPage> createState() => _OrderConfirmationPageState();
}

class _OrderConfirmationPageState extends State<OrderConfirmationPage> {
  final _formKey = GlobalKey<FormState>();
  final _address = TextEditingController();
  late Future<double> _balance;
  bool _addingBalance = false;
  bool _submitting = false;
  PlaceOrderResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _balance = _fetchBalance();
  }

  Future<double> _fetchBalance() async =>
      (await widget.walletRepository.fetchCurrentBalance()).amount;

  void _refreshBalance() {
    setState(() {
      _error = null;
      _balance = _fetchBalance();
    });
  }

  Future<void> _addDemoBalance() async {
    if (_addingBalance || _submitting || _result != null) return;
    setState(() {
      _addingBalance = true;
      _error = null;
    });
    try {
      final result = await widget.walletRepository.addDemoBalance();
      if (!mounted) return;
      setState(() => _balance = Future.value(result.balanceAfter));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added ${_currency(result.creditedAmount)} demo balance.',
          ),
        ),
      );
    } on WalletRepositoryException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not add demo balance. Retry.');
    } finally {
      if (mounted) setState(() => _addingBalance = false);
    }
  }

  Future<void> _placeOrder() async {
    if (_submitting || _addingBalance || _result != null) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await widget.orderRepository.placeOrder(
        PlaceOrderRequest(
          menuItemId: widget.item.id,
          deliveryAddress: _address.text,
        ),
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _balance = Future.value(result.walletBalance);
      });
    } on OrderRepositoryException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = 'Network failure. Check your connection and retry.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm order')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.kitchen.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(widget.item.name),
            const SizedBox(height: 4),
            Text(
              _currency(widget.item.price),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FutureBuilder<double>(
                  future: _balance,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const LinearProgressIndicator(
                        key: Key('wallet-loading'),
                      );
                    }
                    if (snapshot.hasError) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Could not load wallet balance.'),
                          TextButton(
                            onPressed: _refreshBalance,
                            child: const Text('Retry'),
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Wallet: ${_currency(snapshot.data!)}',
                            key: const Key('wallet-balance'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed: _addingBalance || _submitting
                              ? null
                              : _addDemoBalance,
                          child: Text(
                            _addingBalance ? 'Adding...' : 'Add Demo Balance',
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (result == null)
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _address,
                  enabled: !_submitting,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Delivery address',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Delivery address is required';
                    if (text.length > 500) return 'Use 500 characters or fewer';
                    return null;
                  },
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
                onPressed: _submitting || _addingBalance ? null : _placeOrder,
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_outline),
                label: Text(_submitting ? 'Placing order...' : 'Place order'),
              )
            else
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 54),
                      const SizedBox(height: 8),
                      const Text('Order placed', key: Key('order-success')),
                      Text('Total: ${_currency(result.authoritativeTotal)}'),
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
              'One menu item per order. Price and fees are confirmed securely by the server.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

String _currency(double amount) => '৳${amount.toStringAsFixed(2)}';
