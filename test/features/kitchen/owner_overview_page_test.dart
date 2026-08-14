import 'package:cloud_kitchen_mvp/features/kitchen/data/kitchen_repository.dart';
import 'package:cloud_kitchen_mvp/features/finance/data/settlement_repository.dart';
import 'package:cloud_kitchen_mvp/features/finance/domain/settlement_models.dart';
import 'package:cloud_kitchen_mvp/features/kitchen/domain/kitchen.dart';
import 'package:cloud_kitchen_mvp/features/kitchen/presentation/owner_overview_page.dart';
import 'package:cloud_kitchen_mvp/features/menu/data/menu_repository.dart';
import 'package:cloud_kitchen_mvp/features/menu/domain/menu_item.dart';
import 'package:cloud_kitchen_mvp/features/orders/data/kitchen_order_repository.dart';
import 'package:cloud_kitchen_mvp/features/orders/domain/order_models.dart';
import 'package:cloud_kitchen_mvp/features/payments/domain/payment_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('owner dashboard renders existing kitchen metrics on mobile', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 1200);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OwnerOverviewPage(
            ownerId: 'owner-1',
            kitchenRepository: FakeKitchenRepository(),
            menuRepository: FakeMenuRepository(),
            orderRepository: FakeKitchenOrderRepository(),
            settlementRepository: FakeSettlementRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('owner-overview')), findsOneWidget);
    expect(find.text('Owner Kitchen'), findsOneWidget);
    expect(find.text('Active menu'), findsOneWidget);
    expect(find.text('Pending orders'), findsOneWidget);
    expect(find.text('Verify payment'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('owner-revenue-summary')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Gross Sales'), findsOneWidget);
    expect(find.text('FoodCircle Fee (5%)'), findsOneWidget);
    expect(find.text('Rider Share (10%)'), findsOneWidget);
    expect(find.text('Net Earnings (85%)'), findsOneWidget);
    expect(find.text('৳850.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class FakeSettlementRepository implements SettlementRepository {
  @override
  Future<OwnerRevenueSummary> fetchOwnerRevenue() async => OwnerRevenueSummary(
    entries: [
      OwnerSettlementEntry(
        orderId: 'order-settled',
        grossAmount: 1000,
        ownerNetAmount: 850,
        riderEarning: 100,
        platformFee: 50,
        createdAt: DateTime.utc(2026, 8, 14),
      ),
    ],
  );

  @override
  Future<RiderEarningsSummary> fetchRiderEarnings() =>
      throw UnimplementedError();
}

class FakeKitchenRepository implements KitchenRepository {
  @override
  Future<Kitchen?> fetchForOwner(String ownerId) async => const Kitchen(
    id: 'kitchen-1',
    ownerId: 'owner-1',
    name: 'Owner Kitchen',
    address: 'Dhaka',
  );
  @override
  Future<Kitchen> create(String ownerId, KitchenDraft draft) =>
      throw UnimplementedError();
  @override
  Future<Kitchen> update(String ownerId, Kitchen kitchen) =>
      throw UnimplementedError();
}

class FakeMenuRepository implements MenuRepository {
  @override
  Future<List<MenuItem>> fetchForKitchen(String kitchenId) async => const [
    MenuItem(
      id: 'item-1',
      kitchenId: 'kitchen-1',
      name: 'Meal',
      price: 120,
      isAvailable: true,
    ),
  ];
  @override
  Future<MenuItem> create(String kitchenId, MenuItemDraft draft) =>
      throw UnimplementedError();
  @override
  Future<void> delete(String id) => throw UnimplementedError();
  @override
  Future<MenuItem> update(MenuItem item) => throw UnimplementedError();
}

class FakeKitchenOrderRepository implements KitchenOrderRepository {
  @override
  Future<List<KitchenOrder>> fetchOwnerOrders() async => [
    KitchenOrder(
      id: 'order-1',
      kitchenId: 'kitchen-1',
      itemName: 'Meal',
      quantity: 1,
      unitPrice: 120,
      status: OrderStatus.pending,
      finalPrice: 120,
      deliveryAddress: 'Road',
      createdAt: DateTime.utc(2026, 8, 14),
      payment: const OrderPayment(
        method: PaymentMethod.bkash,
        status: PaymentStatus.awaitingVerification,
      ),
    ),
  ];
  @override
  Future<KitchenOrderStatusResult> updateStatus(
    String orderId,
    OrderStatus newStatus,
  ) => throw UnimplementedError();
}
