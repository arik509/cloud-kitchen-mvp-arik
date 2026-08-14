import 'dart:async';

import 'package:cloud_kitchen_mvp/core/location/location_models.dart';
import 'package:cloud_kitchen_mvp/core/location/location_service.dart';
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
    await _selectCurrentLocation(tester);
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
      'p_quantity': 1,
      'p_delivery_address': 'Delivery Road',
      'p_payment_method': 'cash_on_delivery',
      'p_transaction_id': null,
      'p_delivery_latitude': 23.81,
      'p_delivery_longitude': 90.41,
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
    await _selectCurrentLocation(tester);
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
    await _selectCurrentLocation(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('place-order-button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('place-order-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('order-error')), findsOneWidget);
  });

  testWidgets('shows both owner-enabled payment methods', (tester) async {
    _useTallTestView(tester);
    await tester.pumpWidget(
      _app(
        FakeOrderRepository(),
        kitchen: _kitchen.copyWith(
          acceptsBkash: true,
          bkashNumber: '01700000000',
          acceptsCod: true,
        ),
      ),
    );
    expect(find.byKey(const Key('payment-bkash')), findsOneWidget);
    expect(find.byKey(const Key('payment-cod')), findsOneWidget);
  });

  testWidgets('reloads persisted payment settings when checkout opens', (
    tester,
  ) async {
    _useTallTestView(tester);
    await tester.pumpWidget(
      _app(
        FakeOrderRepository(),
        kitchen: _kitchen,
        kitchenLoader: (_) async => _kitchen.copyWith(
          acceptsBkash: true,
          bkashNumber: '01700000000',
          acceptsCod: true,
        ),
      ),
    );
    expect(
      find.byKey(const Key('checkout-configuration-loading')),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('payment-bkash')), findsOneWidget);
    expect(find.byKey(const Key('payment-cod')), findsOneWidget);
  });

  testWidgets('quantity selector updates authoritative request total preview', (
    tester,
  ) async {
    _useTallTestView(tester);
    final repository = FakeOrderRepository();
    await tester.pumpWidget(_app(repository));
    await tester.tap(find.byKey(const Key('quantity-increase')));
    await tester.tap(find.byKey(const Key('quantity-increase')));
    await tester.pump();
    expect(find.textContaining('360.00'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('delivery-address')),
      'Delivery Road',
    );
    await _selectCurrentLocation(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('place-order-button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('place-order-button')));
    await tester.pump();
    expect(repository.request?.quantity, 3);
    expect(repository.request?.toRpcParameters()['p_quantity'], 3);
  });

  testWidgets('supports bKash-only and COD-only kitchens', (tester) async {
    _useTallTestView(tester);
    await tester.pumpWidget(
      _app(
        FakeOrderRepository(),
        kitchen: _kitchen.copyWith(
          acceptsBkash: true,
          bkashNumber: '01700000000',
          acceptsCod: false,
        ),
      ),
    );
    expect(find.byKey(const Key('payment-bkash')), findsOneWidget);
    expect(find.byKey(const Key('payment-cod')), findsNothing);

    await tester.pumpWidget(_app(FakeOrderRepository()));
    await tester.pump();
    expect(find.byKey(const Key('payment-bkash')), findsNothing);
    expect(find.byKey(const Key('payment-cod')), findsOneWidget);
  });

  testWidgets('blocks no-method and invalid bKash configurations', (
    tester,
  ) async {
    _useTallTestView(tester);
    await tester.pumpWidget(
      _app(
        FakeOrderRepository(),
        kitchen: _kitchen.copyWith(
          acceptsBkash: true,
          bkashNumber: null,
          acceptsCod: false,
        ),
      ),
    );
    expect(find.byKey(const Key('payment-bkash')), findsNothing);
    expect(find.byKey(const Key('bkash-configuration-error')), findsOneWidget);
    expect(find.byKey(const Key('no-payment-methods')), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('place-order-button')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('requires a confirmed delivery pin', (tester) async {
    _useTallTestView(tester);
    final repository = FakeOrderRepository();
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
    await tester.pump();
    expect(find.byKey(const Key('delivery-location-error')), findsOneWidget);
    expect(repository.calls, 0);
  });
}

Future<void> _selectCurrentLocation(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('use-delivery-location')),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.byKey(const Key('use-delivery-location')));
  await tester.pumpAndSettle();
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
Widget _app(
  FakeOrderRepository repository, {
  Kitchen kitchen = _kitchen,
  Future<Kitchen> Function(String)? kitchenLoader,
}) => MaterialApp(
  home: OrderConfirmationPage(
    key: UniqueKey(),
    kitchen: kitchen,
    kitchenLoader: kitchenLoader,
    item: const MenuItem(
      id: 'item-1',
      kitchenId: 'kitchen-1',
      name: 'Meal',
      price: 120,
      isAvailable: true,
    ),
    walletRepository: FakeWalletRepository(),
    orderRepository: repository,
    locationService: const FakeLocationService(),
  ),
);

class FakeLocationService implements LocationService {
  const FakeLocationService();

  @override
  Future<GeoCoordinates> determineLocation() async =>
      const GeoCoordinates(latitude: 23.81, longitude: 90.41);

  @override
  Future<bool> openLocationSettings() async => true;
}

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
