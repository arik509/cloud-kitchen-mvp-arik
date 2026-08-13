import 'dart:async';

import 'package:cloud_kitchen_mvp/features/orders/data/kitchen_order_repository.dart';
import 'package:cloud_kitchen_mvp/features/orders/domain/order_models.dart';
import 'package:cloud_kitchen_mvp/features/orders/presentation/kitchen_orders_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows owner-order loading and empty states', (tester) async {
    final pending = Completer<List<KitchenOrder>>();
    await tester.pumpWidget(_app(FakeKitchenOrderRepository([pending.future])));
    expect(find.byKey(const Key('kitchen-orders-loading')), findsOneWidget);
    pending.complete(const []);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kitchen-orders-empty')), findsOneWidget);
    expect(find.text('No kitchen orders yet'), findsOneWidget);
  });

  testWidgets('shows error and retries', (tester) async {
    final repository = FakeKitchenOrderRepository([
      Future.delayed(
        Duration.zero,
        () => throw const KitchenOrderRepositoryException(
          KitchenOrderFailureCode.unavailable,
          'Network failure.',
        ),
      ),
      Future.value(const []),
    ]);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kitchen-orders-error')), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repository.fetchCalls, 2);
    expect(find.byKey(const Key('kitchen-orders-empty')), findsOneWidget);
  });

  testWidgets('lists authoritative order details and legal actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        FakeKitchenOrderRepository([
          Future.value([_pendingOrder]),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Order #order-1'), findsOneWidget);
    expect(find.text('1 × Chicken Bowl'), findsOneWidget);
    expect(find.text('Unit price: ৳250.00'), findsOneWidget);
    expect(find.text('Authoritative total: ৳260.00'), findsOneWidget);
    expect(find.text('Customer delivery road'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Accepted'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    expect(find.text('Preparing'), findsNothing);
  });

  testWidgets('accepts a pending order and prevents duplicate submission', (
    tester,
  ) async {
    final update = Completer<KitchenOrderStatusResult>();
    final repository = FakeKitchenOrderRepository([
      Future.value([_pendingOrder]),
      Future.value([_pendingOrder]),
    ], updateResponse: update.future);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Accepted'));
    await tester.pump();
    expect(repository.updateCalls, 1);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Accepted'), findsNothing);

    update.complete(
      const KitchenOrderStatusResult(
        orderId: 'order-1',
        status: OrderStatus.accepted,
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.lastTarget, OrderStatus.accepted);
  });

  testWidgets('confirms rejection and reports the atomic refund', (
    tester,
  ) async {
    final repository = FakeKitchenOrderRepository(
      [
        Future.value([_pendingOrder]),
        Future.value(const []),
      ],
      updateResponse: Future.value(
        const KitchenOrderStatusResult(
          orderId: 'order-1',
          status: OrderStatus.rejected,
          refundedAmount: 260,
          walletBalance: 1260,
        ),
      ),
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();
    expect(find.text('Reject and refund order?'), findsOneWidget);
    expect(find.textContaining('৳260.00'), findsWidgets);
    await tester.tap(find.text('Reject & refund'));
    await tester.pumpAndSettle();

    expect(repository.lastTarget, OrderStatus.rejected);
    expect(find.textContaining('৳260.00 refunded'), findsOneWidget);
  });

  testWidgets('hands a ready order to riders but exposes no rider actions', (
    tester,
  ) async {
    final ready = KitchenOrder(
      id: 'ready-1',
      kitchenId: 'kitchen-1',
      itemName: 'Chicken Bowl',
      quantity: 1,
      unitPrice: 250,
      status: OrderStatus.ready,
      finalPrice: 260,
      deliveryAddress: 'Customer delivery road',
      createdAt: DateTime.utc(2026, 8, 13, 12),
    );
    final repository = FakeKitchenOrderRepository(
      [
        Future.value([ready]),
        Future.value(const []),
      ],
      updateResponse: Future.value(
        const KitchenOrderStatusResult(
          orderId: 'ready-1',
          status: OrderStatus.awaitingRider,
        ),
      ),
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ready'));
    await tester.pumpAndSettle();

    expect(find.text('Awaiting rider'), findsOneWidget);
    expect(find.text('Mark as picked up'), findsNothing);
    expect(find.text('Mark as delivered'), findsNothing);
    await tester.tap(find.text('Awaiting rider'));
    await tester.pumpAndSettle();

    expect(repository.lastTarget, OrderStatus.awaitingRider);
  });

  testWidgets('owner sees assigned delivery status without rider actions', (
    tester,
  ) async {
    final order = KitchenOrder(
      id: 'assigned-1',
      kitchenId: 'kitchen-1',
      itemName: 'Chicken Bowl',
      quantity: 1,
      unitPrice: 250,
      status: OrderStatus.riderAssigned,
      finalPrice: 260,
      deliveryAddress: 'Customer delivery road',
      createdAt: DateTime.utc(2026, 8, 13, 12),
    );
    await tester.pumpWidget(
      _app(
        FakeKitchenOrderRepository([
          Future.value([order]),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delivery'));
    await tester.pumpAndSettle();

    expect(find.text('Rider assigned'), findsOneWidget);
    expect(find.text('Mark as picked up'), findsNothing);
    expect(find.text('Mark as delivered'), findsNothing);
  });
}

final _pendingOrder = KitchenOrder(
  id: 'order-1',
  kitchenId: 'kitchen-1',
  itemName: 'Chicken Bowl',
  quantity: 1,
  unitPrice: 250,
  status: OrderStatus.pending,
  finalPrice: 260,
  deliveryAddress: 'Customer delivery road',
  createdAt: DateTime.utc(2026, 8, 13, 12),
);

Widget _app(KitchenOrderRepository repository) => MaterialApp(
  home: Scaffold(body: KitchenOrdersPage(repository: repository)),
);

class FakeKitchenOrderRepository implements KitchenOrderRepository {
  FakeKitchenOrderRepository(this.responses, {this.updateResponse});

  final List<Future<List<KitchenOrder>>> responses;
  final Future<KitchenOrderStatusResult>? updateResponse;
  int fetchCalls = 0;
  int updateCalls = 0;
  OrderStatus? lastTarget;

  @override
  Future<List<KitchenOrder>> fetchOwnerOrders() {
    final index = fetchCalls++;
    return responses[index < responses.length ? index : responses.length - 1];
  }

  @override
  Future<KitchenOrderStatusResult> updateStatus(
    String orderId,
    OrderStatus newStatus,
  ) {
    updateCalls++;
    lastTarget = newStatus;
    return updateResponse!;
  }
}
