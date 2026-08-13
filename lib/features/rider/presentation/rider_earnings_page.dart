import 'package:flutter/material.dart';

import '../../orders/presentation/order_ui.dart';
import '../data/rider_delivery_repository.dart';
import '../domain/rider_delivery.dart';

class RiderEarningsPage extends StatefulWidget {
  const RiderEarningsPage({required this.repository, super.key});
  final RiderDeliveryRepository repository;

  @override
  State<RiderEarningsPage> createState() => _RiderEarningsPageState();
}

class _RiderEarningsPageState extends State<RiderEarningsPage> {
  late Future<List<RiderDelivery>> _deliveries;

  @override
  void initState() {
    super.initState();
    _deliveries = widget.repository.fetchMine();
  }

  Future<void> _refresh() async {
    final future = widget.repository.fetchMine();
    setState(() => _deliveries = future);
    await future;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<RiderDelivery>>(
    future: _deliveries,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(
          key: Key('rider-earnings-loading'),
          child: CircularProgressIndicator(),
        );
      }
      if (snapshot.hasError) {
        return Center(
          key: const Key('rider-earnings-error'),
          child: TextButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry earnings'),
          ),
        );
      }
      final earnings = RiderEarnings.fromDeliveries(snapshot.data!);
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          key: const Key('rider-earnings'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 64),
            const SizedBox(height: 12),
            Text(
              orderCurrency(earnings.total),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const Text(
              'Recorded delivery earnings',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: const Icon(Icons.task_alt),
                title: const Text('Completed deliveries'),
                trailing: Text('${earnings.deliveryCount}'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This MVP reports the authoritative rider fee stored on delivered '
              'orders. It does not perform wallet settlement or online payment.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    },
  );
}
