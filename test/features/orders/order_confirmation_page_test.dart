import 'dart:async';

import 'package:cloud_kitchen_mvp/features/kitchen/domain/kitchen.dart';
import 'package:cloud_kitchen_mvp/features/menu/domain/menu_item.dart';
import 'package:cloud_kitchen_mvp/features/orders/data/order_repository.dart';
import 'package:cloud_kitchen_mvp/features/orders/domain/order_models.dart';
import 'package:cloud_kitchen_mvp/features/orders/presentation/order_confirmation_page.dart';
import 'package:cloud_kitchen_mvp/features/payments/domain/payment_models.dart';
import 'package:cloud_kitchen_mvp/features/wallet/data/wallet_repository.dart';
import 'package:cloud_kitchen_mvp/features/wallet/domain/wallet_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('COD checkout submits once without wallet or transaction ID', (
    tester,
  ) async {
    _useTallTestView(tester);
    final repository = FakeOrderRepository();
    await tester.pumpWidget(_app(repository));
    await tester.enterText(
      find.byKey(const Key('delivery-address')),
      '  Delivery Road  ',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('place-order-button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('place-order-button')));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('place-order-button')),
      warnIfMissed: false,
    );
    expect(repository.calls, 1);
    expect(repository.request!.toRpcParameters(), {
      'p_menu_item_id': 'item-1',
      'p_delivery_address': 'Delivery Road',
      'p_payment_method': 'cash_on_delivery',
      'p_transaction_id': null,
    });
    repository.completer.complete(
      const PlaceOrderResult(
        orderId: 'order-1',
        authoritativeTotal: 120,
        paymentMethod: PaymentMethod.cashOnDelivery,
        paymentStatus: PaymentStatus.codPending,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('order-success')), findsOneWidget);
    expect(find.textContaining('pending collection'), findsOneWidget);
    expect(find.textContaining('Wallet'), findsNothing);
  });

  testWidgets('bKash checkout requires and normalizes Transaction ID', (
    tester,
  ) async {
    _useTallTestView(tester);
    final repository = FakeOrderRepository();
    await tester.pumpWidget(
      _app(
        repository,
        kitchen: _kitchen.copyWith(
          acceptsBkash: true,
          bkashNumber: '01700000000',
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('payment-bkash')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('delivery-address')),
      'Delivery Road',
    );
    await tester.enterText(
      find.byKey(const Key('bkash-transaction-id')),
      ' ab 12cd ',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('place-order-button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('place-order-button')));
    await tester.pump();
    expect(repository.request!.paymentMethod, PaymentMethod.bkash);
    expect(repository.request!.toRpcParameters()['p_transaction_id'], 'AB12CD');
    expect(find.textContaining('manually verified'), findsOneWidget);
  });

  testWidgets('shows safe repository error', (tester) async {
    _useTallTestView(tester);
    final repository = FakeOrderRepository(
      error: const OrderRepositoryException(
        OrderFailureCode.duplicateTransaction,
        'That Transaction ID was already used.',
      ),
    );
    await tester.pumpWidget(_app(repository));
    await tester.enterText(
      find.byKey(const Key('delivery-address')),
      'Delivery Road',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('place-order-button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('place-order-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('order-error')), findsOneWidget);
  });
}

void _useTallTestView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 1000);
  addTearDown(tester.view.reset);
}

const _kitchen = Kitchen(
  id: 'kitchen-1',
  ownerId: 'owner-1',
  name: 'Kitchen',
  address: 'Address',
  acceptsCod: true,
);
Widget _app(FakeOrderRepository repository, {Kitchen kitchen = _kitchen}) =>
    MaterialApp(
      home: OrderConfirmationPage(
        kitchen: kitchen,
        item: const MenuItem(
          id: 'item-1',
          kitchenId: 'kitchen-1',
          name: 'Meal',
          price: 120,
          isAvailable: true,
        ),
        walletRepository: FakeWalletRepository(),
        orderRepository: repository,
      ),
    );

class FakeWalletRepository implements WalletRepository {
  @override
  Future<WalletBalance> fetchCurrentBalance() async =>
      const WalletBalance(1000);
  @override
  Future<AddDemoBalanceResult> addDemoBalance() => throw UnimplementedError();
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
