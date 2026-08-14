import 'package:flutter/material.dart';

import '../../../core/presentation/app_ui.dart';
import '../../finance/data/settlement_repository.dart';
import '../../finance/domain/settlement_models.dart';
import '../../menu/data/menu_repository.dart';
import '../../orders/data/kitchen_order_repository.dart';
import '../../orders/domain/order_models.dart';
import '../../payments/domain/payment_models.dart';
import '../data/kitchen_repository.dart';
import '../domain/kitchen.dart';

class OwnerOverviewPage extends StatefulWidget {
  const OwnerOverviewPage({
    required this.ownerId,
    required this.kitchenRepository,
    required this.menuRepository,
    required this.orderRepository,
    required this.settlementRepository,
    super.key,
  });

  final String ownerId;
  final KitchenRepository kitchenRepository;
  final MenuRepository menuRepository;
  final KitchenOrderRepository orderRepository;
  final SettlementRepository settlementRepository;

  @override
  State<OwnerOverviewPage> createState() => _OwnerOverviewPageState();
}

class _OwnerOverviewPageState extends State<OwnerOverviewPage> {
  late Future<_OwnerOverview> _overview;

  @override
  void initState() {
    super.initState();
    _overview = _load();
  }

  Future<_OwnerOverview> _load() async {
    final kitchen = await widget.kitchenRepository.fetchForOwner(
      widget.ownerId,
    );
    if (kitchen == null) return const _OwnerOverview();
    final items = await widget.menuRepository.fetchForKitchen(kitchen.id);
    final orders = await widget.orderRepository.fetchOwnerOrders();
    final revenue = await widget.settlementRepository.fetchOwnerRevenue();
    return _OwnerOverview(
      kitchen: kitchen,
      activeItems: items.where((item) => item.isAvailable).length,
      pendingOrders: orders
          .where((order) => order.status == OrderStatus.pending)
          .length,
      activeOrders: orders
          .where(
            (order) =>
                order.status == OrderStatus.accepted ||
                order.status == OrderStatus.preparing ||
                order.status == OrderStatus.ready,
          )
          .length,
      paymentAttention: orders
          .where(
            (order) =>
                order.payment.status == PaymentStatus.awaitingVerification,
          )
          .length,
      revenue: revenue,
    );
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _overview = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_OwnerOverview>(
    future: _overview,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(
          key: Key('owner-overview-loading'),
          child: CircularProgressIndicator(),
        );
      }
      if (snapshot.hasError) {
        return AppStateView(
          key: const Key('owner-overview-error'),
          icon: Icons.cloud_off_outlined,
          title: 'Dashboard unavailable',
          message: 'Check your connection and try again.',
          actionLabel: 'Retry',
          onAction: _refresh,
        );
      }
      final overview = snapshot.data!;
      final kitchen = overview.kitchen;
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          key: const Key('owner-overview'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  const AppBrandMark(compact: true),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kitchen?.name ?? 'Set up your kitchen',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          kitchen == null
                              ? 'Create your kitchen to start selling.'
                              : kitchen.isActive
                              ? 'Open and visible to nearby customers'
                              : 'Currently hidden from customers',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const AppSectionHeader(
              title: 'Today at a glance',
              subtitle: 'Live counts from your current kitchen data',
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.5,
              children: [
                _MetricCard(
                  label: 'Active menu',
                  value: overview.activeItems,
                  icon: Icons.restaurant_menu,
                ),
                _MetricCard(
                  label: 'Pending orders',
                  value: overview.pendingOrders,
                  icon: Icons.receipt_long_outlined,
                ),
                _MetricCard(
                  label: 'In progress',
                  value: overview.activeOrders,
                  icon: Icons.soup_kitchen_outlined,
                ),
                _MetricCard(
                  label: 'Verify payment',
                  value: overview.paymentAttention,
                  icon: Icons.verified_outlined,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _OwnerRevenueCard(revenue: overview.revenue),
          ],
        ),
      );
    },
  );
}

class _OwnerRevenueCard extends StatelessWidget {
  const _OwnerRevenueCard({required this.revenue});

  final OwnerRevenueSummary revenue;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('owner-revenue-summary'),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            title: 'Delivered-order revenue',
            subtitle: 'Internal settlement accounting',
          ),
          const SizedBox(height: 14),
          _RevenueRow(
            label: 'Gross Sales',
            value: revenue.grossSales,
            strong: true,
          ),
          _RevenueRow(
            label: 'FoodCircle Fee (5%)',
            value: -revenue.platformFees,
          ),
          _RevenueRow(label: 'Rider Share (10%)', value: -revenue.riderShare),
          const Divider(),
          _RevenueRow(
            key: const Key('owner-net-earnings'),
            label: 'Net Earnings (85%)',
            value: revenue.ownerNetEarnings,
            strong: true,
          ),
          const SizedBox(height: 8),
          Text(
            'This ledger records settlement obligations; external payouts are handled separately.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

class _RevenueRow extends StatelessWidget {
  const _RevenueRow({
    required this.label,
    required this.value,
    this.strong = false,
    super.key,
  });

  final String label;
  final double value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final amount = value < 0
        ? '-৳${(-value).toStringAsFixed(2)}'
        : '৳${value.toStringAsFixed(2)}';
    final style = strong
        ? Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(amount, style: style),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(child: Icon(icon, size: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _OwnerOverview {
  const _OwnerOverview({
    this.kitchen,
    this.activeItems = 0,
    this.pendingOrders = 0,
    this.activeOrders = 0,
    this.paymentAttention = 0,
    this.revenue = const OwnerRevenueSummary(entries: []),
  });

  final Kitchen? kitchen;
  final int activeItems;
  final int pendingOrders;
  final int activeOrders;
  final int paymentAttention;
  final OwnerRevenueSummary revenue;
}
