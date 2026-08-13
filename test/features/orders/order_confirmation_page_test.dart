import 'dart:async';

import 'package:cloud_kitchen_mvp/features/kitchen/domain/kitchen.dart';
import 'package:cloud_kitchen_mvp/features/menu/domain/menu_item.dart';
import 'package:cloud_kitchen_mvp/features/orders/data/order_repository.dart';
import 'package:cloud_kitchen_mvp/features/orders/domain/order_models.dart';
import 'package:cloud_kitchen_mvp/features/orders/presentation/order_confirmation_page.dart';
import 'package:cloud_kitchen_mvp/features/wallet/data/wallet_repository.dart';
import 'package:cloud_kitchen_mvp/features/wallet/domain/wallet_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('submits exactly one minimal request and blocks duplicates', (
    tester,
  ) async {
    final orderRepository = FakeOrderRepository();
    await tester.pumpWidget(_app(orderRepository: orderRepository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '  Delivery Road  ');
    await tester.tap(find.byKey(const Key('place-order-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('place-order-button')));
    await tester.pump();

    expect(orderRepository.calls, 1);
    expect(orderRepository.request!.toRpcParameters(), {
      'p_menu_item_id': 'item-1',
      'p_delivery_address': 'Delivery Road',
    });

    orderRepository.completer.complete(
      const PlaceOrderResult(
        orderId: 'order-1',
        authoritativeTotal: 120,
        walletBalance: 880,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('order-success')), findsOneWidget);
  });

  testWidgets('adds demo balance and updates the displayed wallet', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        orderRepository: FakeOrderRepository(),
        walletRepository: FakeWalletRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Wallet: ৳1000.00'), findsOneWidget);
    await tester.tap(find.text('Add Demo Balance'));
    await tester.pumpAndSettle();
    expect(find.text('Wallet: ৳1500.00'), findsOneWidget);
  });

  testWidgets('shows typed insufficient-balance error', (tester) async {
    final repository = FakeOrderRepository(
      error: const OrderRepositoryException(
        OrderFailureCode.insufficientBalance,
        'Your wallet balance is too low for this order.',
      ),
    );
    await tester.pumpWidget(_app(orderRepository: repository));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Delivery Road');
    await tester.tap(find.byKey(const Key('place-order-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('order-error')), findsOneWidget);
    expect(find.textContaining('too low'), findsOneWidget);
  });

  for (final failure in const [
    (
      OrderFailureCode.unavailableItem,
      'This menu item is no longer available.',
    ),
    (
      OrderFailureCode.unauthenticated,
      'Sign in again before placing an order.',
    ),
    (
      OrderFailureCode.unavailable,
      'The order service is unavailable. Try again.',
    ),
  ]) {
    testWidgets('shows ${failure.$1.name} order error', (tester) async {
      await tester.pumpWidget(
        _app(
          orderRepository: FakeOrderRepository(
            error: OrderRepositoryException(failure.$1, failure.$2),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Delivery Road');
      await tester.tap(find.byKey(const Key('place-order-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('order-error')), findsOneWidget);
      expect(find.text(failure.$2), findsOneWidget);
    });
  }
}

Widget _app({
  required FakeOrderRepository orderRepository,
  WalletRepository? walletRepository,
}) => MaterialApp(
  home: OrderConfirmationPage(
    kitchen: const Kitchen(
      id: 'kitchen-1',
      ownerId: 'owner-1',
      name: 'Kitchen',
      address: 'Address',
    ),
    item: const MenuItem(
      id: 'item-1',
      kitchenId: 'kitchen-1',
      name: 'Meal',
      price: 120,
      isAvailable: true,
    ),
    walletRepository: walletRepository ?? FakeWalletRepository(),
    orderRepository: orderRepository,
  ),
);

class FakeWalletRepository implements WalletRepository {
  @override
  Future<WalletBalance> fetchCurrentBalance() async =>
      const WalletBalance(1000);

  @override
  Future<AddDemoBalanceResult> addDemoBalance() async => AddDemoBalanceResult(
    transactionId: 'transaction-1',
    creditedAmount: 500,
    balanceAfter: 1500,
    kind: WalletTransactionKind.demoCredit,
    createdAt: DateTime.utc(2026),
  );
}

class FakeOrderRepository implements OrderRepository {
  FakeOrderRepository({this.error});

  final OrderRepositoryException? error;
  final completer = Completer<PlaceOrderResult>();
  PlaceOrderRequest? request;
  int calls = 0;

  @override
  Future<List<CustomerOrder>> fetchCurrentCustomerOrders() async => const [];

  @override
  Future<PlaceOrderResult> placeOrder(PlaceOrderRequest request) {
    calls++;
    this.request = request;
    if (error != null) return Future.error(error!);
    return completer.future;
  }
}
