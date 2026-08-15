import 'package:flutter/material.dart';

import '../../../core/presentation/app_ui.dart';
import '../../finance/data/settlement_repository.dart';

import '../../menu/data/menu_repository.dart';
import '../../orders/data/kitchen_order_repository.dart';
import '../../orders/domain/order_models.dart';
import '../../orders/presentation/order_ui.dart';
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

    // Compute revenue directly from delivered orders — no SQL RPC required.
    // Only count orders where payment is actually confirmed (verified/collected).
    final deliveredOrders = orders.where((o) => o.status == OrderStatus.delivered);
    double grossSales = 0;
    for (final o in deliveredOrders) {
      final isPaid = o.payment.status == PaymentStatus.verified ||
          o.payment.status == PaymentStatus.collected;
      if (isPaid) grossSales += o.finalPrice;
    }
    final platformFee = grossSales * 0.05;
    final riderShare = grossSales * 0.10;
    final ownerNet = grossSales * 0.85;
    final clientRevenue = _ClientOwnerRevenue(
      grossSales: grossSales,
      platformFee: platformFee,
      riderShare: riderShare,
      ownerNet: ownerNet,
      settledCount: deliveredOrders.where((o) =>
          o.payment.status == PaymentStatus.verified ||
          o.payment.status == PaymentStatus.collected).length,
    );

    return _OwnerOverview(
      kitchen: kitchen,
      activeItems: items.where((item) => item.isAvailable).length,
      totalMenuItems: items.length,
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
      deliveredOrders: orders
          .where((order) => order.status == OrderStatus.delivered)
          .length,
      rejectedOrders: orders
          .where((order) => order.status == OrderStatus.rejected)
          .length,
      paymentAttention: orders
          .where(
            (order) =>
                order.payment.status == PaymentStatus.awaitingVerification,
          )
          .length,
      clientRevenue: clientRevenue,
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
            // Kitchen header card
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
                  total: overview.totalMenuItems,
                  icon: Icons.restaurant_menu,
                ),
                _MetricCard(
                  label: 'Pending orders',
                  value: overview.pendingOrders,
                  icon: Icons.receipt_long_outlined,
                  highlight: overview.pendingOrders > 0,
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
                  highlight: overview.paymentAttention > 0,
                ),
                _MetricCard(
                  label: 'Delivered',
                  value: overview.deliveredOrders,
                  icon: Icons.check_circle_outline,
                ),
                _MetricCard(
                  label: 'Rejected',
                  value: overview.rejectedOrders,
                  icon: Icons.cancel_outlined,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _OwnerRevenueCard(clientRevenue: overview.clientRevenue),
          ],
        ),
      );
    },
  );
}

class _OwnerRevenueCard extends StatelessWidget {
  const _OwnerRevenueCard({required this.clientRevenue});

  final _ClientOwnerRevenue clientRevenue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      key: const Key('owner-revenue-summary'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppSectionHeader(
              title: 'Revenue Summary',
              subtitle: 'All paid & delivered orders — 85 / 10 / 5 split',
            ),
            const SizedBox(height: 16),

            // Income breakdown rows
            _RevenueRow(
              label: 'Gross Sales',
              value: clientRevenue.grossSales,
              strong: true,
            ),
            _RevenueRow(
              label: 'Rider Share (10%)',
              value: -clientRevenue.riderShare,
            ),
            _RevenueRow(
              label: 'FoodCircle Platform Fee (5%)',
              value: -clientRevenue.platformFee,
            ),
            const Divider(),
            _RevenueRow(
              key: const Key('owner-net-earnings'),
              label: 'Your Net Earnings (85%)',
              value: clientRevenue.ownerNet,
              strong: true,
            ),
            const SizedBox(height: 16),

            // Split ratio bar visualization
            const _RatioBar(),
            const SizedBox(height: 6),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _RatioDot(color: scheme.primary, label: 'You 85%'),
                _RatioDot(color: scheme.secondary, label: 'Rider 10%'),
                _RatioDot(color: scheme.tertiary, label: 'Platform 5%'),
              ],
            ),

            // Settlement count
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.summarize_outlined,
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${clientRevenue.settledCount} paid & delivered order${clientRevenue.settledCount == 1 ? '' : 's'}',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Platform fee owed notice
            if (clientRevenue.platformFee > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: scheme.onErrorContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Platform fee due: ৳${clientRevenue.platformFee.toStringAsFixed(2)} (5% of gross) — payable to FoodCircle.',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),
            Text(
              'Calculated from all confirmed (bKash verified / COD collected) delivered orders.',
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _RatioBar extends StatelessWidget {
  const _RatioBar();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 12,
        child: Row(
          children: [
            Expanded(
              flex: 85,
              child: Container(color: scheme.primary),
            ),
            Expanded(
              flex: 10,
              child: Container(color: scheme.secondary),
            ),
            Expanded(
              flex: 5,
              child: Container(color: scheme.tertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatioDot extends StatelessWidget {
  const _RatioDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(radius: 5, backgroundColor: color),
      const SizedBox(width: 4),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ],
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
    this.total,
    this.highlight = false,
  });

  final String label;
  final int value;
  final IconData icon;
  final int? total;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: highlight ? scheme.errorContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  highlight ? scheme.error : scheme.primaryContainer,
              child: Icon(
                icon,
                size: 20,
                color: highlight ? scheme.onError : scheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '$value',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: highlight ? scheme.onErrorContainer : null,
                        ),
                      ),
                      if (total != null && total! > 0) ...[
                        const SizedBox(width: 3),
                        Text(
                          '/ $total',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: highlight ? scheme.onErrorContainer : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerOverview {
  const _OwnerOverview({
    this.kitchen,
    this.activeItems = 0,
    this.totalMenuItems = 0,
    this.pendingOrders = 0,
    this.activeOrders = 0,
    this.deliveredOrders = 0,
    this.rejectedOrders = 0,
    this.paymentAttention = 0,
    this.clientRevenue = const _ClientOwnerRevenue(),
  });

  final Kitchen? kitchen;
  final int activeItems;
  final int totalMenuItems;
  final int pendingOrders;
  final int activeOrders;
  final int deliveredOrders;
  final int rejectedOrders;
  final int paymentAttention;
  final _ClientOwnerRevenue clientRevenue;
}

class _ClientOwnerRevenue {
  const _ClientOwnerRevenue({
    this.grossSales = 0,
    this.platformFee = 0,
    this.riderShare = 0,
    this.ownerNet = 0,
    this.settledCount = 0,
  });
  final double grossSales;
  final double platformFee;
  final double riderShare;
  final double ownerNet;
  final int settledCount;
}
