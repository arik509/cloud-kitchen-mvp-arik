import 'package:flutter/material.dart';

import '../../../core/presentation/app_ui.dart';
import '../../finance/data/settlement_repository.dart';
import '../../finance/domain/settlement_models.dart';
import '../../orders/presentation/order_ui.dart';

class RiderEarningsPage extends StatefulWidget {
  const RiderEarningsPage({
    required this.repository,
    this.refreshNotifier,
    super.key,
  });

  final SettlementRepository repository;

  /// Increment this notifier after any delivery action to auto-refresh earnings.
  final ValueNotifier<int>? refreshNotifier;

  @override
  State<RiderEarningsPage> createState() => _RiderEarningsPageState();
}

class _RiderEarningsPageState extends State<RiderEarningsPage> {
  late Future<RiderEarningsSummary> _earnings;

  @override
  void initState() {
    super.initState();
    _earnings = widget.repository.fetchRiderEarnings();
    widget.refreshNotifier?.addListener(_onExternalRefresh);
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_onExternalRefresh);
    super.dispose();
  }

  void _onExternalRefresh() {
    if (!mounted) return;
    _refresh();
  }

  Future<void> _refresh() async {
    final future = widget.repository.fetchRiderEarnings();
    setState(() {
      _earnings = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<RiderEarningsSummary>(
    future: _earnings,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(
          key: Key('rider-earnings-loading'),
          child: CircularProgressIndicator(),
        );
      }
      if (snapshot.hasError) {
        return AppStateView(
          key: const Key('rider-earnings-error'),
          icon: Icons.account_balance_wallet_outlined,
          title: 'Earnings unavailable',
          message: 'Check your connection and try again.',
          actionLabel: 'Retry',
          onAction: _refresh,
        );
      }
      final earnings = snapshot.data!;
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          key: const Key('rider-earnings'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _BalanceCard(earnings: earnings),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    key: const Key('rider-total-deliveries'),
                    label: 'Total Deliveries',
                    value: '${earnings.completedDeliveries}',
                    icon: Icons.task_alt_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryCard(
                    key: const Key('rider-total-earnings'),
                    label: 'Total Earnings',
                    value: orderCurrency(earnings.totalEarnings),
                    icon: Icons.trending_up_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const AppSectionHeader(
              title: 'Earnings History',
              subtitle: '10% of each eligible delivered order',
            ),
            const SizedBox(height: 10),
            if (earnings.entries.isEmpty)
              const Card(
                key: Key('rider-earnings-empty'),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Completed delivery earnings will appear here.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...earnings.entries.map(_EarningHistoryCard.new),
            const SizedBox(height: 14),
            Text(
              'Payout settlement is handled separately.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    },
  );
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.earnings});

  final RiderEarningsSummary earnings;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('rider-available-balance'),
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Balance',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          orderCurrency(earnings.availableBalance),
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Internal FoodCircle earnings balance',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onPrimary.withValues(alpha: .84),
          ),
        ),
      ],
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    ),
  );
}

class _EarningHistoryCard extends StatelessWidget {
  const _EarningHistoryCard(this.entry);

  final RiderEarningEntry entry;

  @override
  Widget build(BuildContext context) => Card(
    key: Key('rider-earning-${entry.orderId}'),
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        child: const Icon(Icons.delivery_dining),
      ),
      title: Text('Order #${_shortReference(entry.orderId)}'),
      subtitle: Text(
        '${orderTime(entry.createdAt)} · Gross ${orderCurrency(entry.grossAmount)}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '+${orderCurrency(entry.riderEarning)}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text('Earned'),
        ],
      ),
    ),
  );
}

String _shortReference(String orderId) =>
    (orderId.length <= 8 ? orderId : orderId.substring(orderId.length - 8))
        .toUpperCase();
