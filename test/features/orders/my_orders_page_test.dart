import 'dart:async';

import 'package:cloud_kitchen_mvp/features/orders/data/order_repository.dart';
import 'package:cloud_kitchen_mvp/features/orders/domain/order_models.dart';
import 'package:cloud_kitchen_mvp/features/orders/presentation/my_orders_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows loading then empty orders state', (tester) async {
    final pending = Completer<List<CustomerOrder>>();
    await tester.pumpWidget(_app(FakeOrderRepository([pending.future])));
    expect(find.byKey(const Key('orders-loading')), findsOneWidget);
    pending.complete(const []);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('orders-empty')), findsOneWidget);
  });

  testWidgets('shows error and retries My Orders', (tester) async {
    final repository = FakeOrderRepository([
      Future.delayed(
        Duration.zero,
        () => throw const OrderRepositoryException(
          OrderFailureCode.unavailable,
          'Network failure.',
        ),
      ),
      Future.value(const []),
    ]);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('orders-error')), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repository.fetchCalls, 2);
    expect(find.byKey(const Key('orders-empty')), findsOneWidget);
  });

  testWidgets('shows kitchen, item, price, status, address, and time', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        FakeOrderRepository([
          Future.value([
            CustomerOrder(
              id: 'order-1',
              kitchenId: 'kitchen-1',
              kitchenName: 'Nearby Kitchen',
              itemName: 'Rice Bowl',
              itemPrice: 150,
              status: OrderStatus.pending,
              finalPrice: 150,
              deliveryAddress: 'Delivery Road',
              createdAt: DateTime.utc(2026, 8, 13, 5, 30),
            ),
          ]),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nearby Kitchen'), findsOneWidget);
    expect(find.text('Rice Bowl'), findsOneWidget);
    expect(find.textContaining('৳150.00'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Delivery Road'), findsOneWidget);
    expect(find.textContaining('2026-08-13'), findsOneWidget);
  });
}

Widget _app(OrderRepository repository) => MaterialApp(
  home: Scaffold(body: MyOrdersPage(repository: repository)),
);

class FakeOrderRepository implements OrderRepository {
  FakeOrderRepository(this.responses);

  final List<Future<List<CustomerOrder>>> responses;
  int fetchCalls = 0;

  @override
  Future<List<CustomerOrder>> fetchCurrentCustomerOrders() {
    final index = fetchCalls++;
    return responses[index < responses.length ? index : responses.length - 1];
  }

  @override
  Future<PlaceOrderResult> placeOrder(PlaceOrderRequest request) =>
      throw UnimplementedError();
}
