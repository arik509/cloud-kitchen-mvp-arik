import 'dart:async';

import 'package:cloud_kitchen_mvp/features/orders/domain/order_models.dart';
import 'package:cloud_kitchen_mvp/features/rider/data/rider_delivery_repository.dart';
import 'package:cloud_kitchen_mvp/features/rider/domain/rider_delivery.dart';
import 'package:cloud_kitchen_mvp/features/rider/presentation/rider_deliveries_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows available eligible delivery and claims once', (
    tester,
  ) async {
    final claim = Completer<RiderDeliveryUpdate>();
    final repository = FakeRiderRepository(
      available: [_delivery(OrderStatus.awaitingRider)],
      claimResponse: claim.future,
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.text('Secure Kitchen'), findsOneWidget);
    expect(find.text('Kitchen Road'), findsOneWidget);
    expect(find.text('Delivery Road'), findsOneWidget);
    await tester.tap(find.text('Accept delivery'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Accept delivery').last);
    await tester.pump();
    expect(repository.claimCalls, 1);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    claim.complete(
      const RiderDeliveryUpdate(
        orderId: 'order-1',
        status: OrderStatus.riderAssigned,
        riderId: 'rider-1',
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('assigned rider sees active delivery and marks picked up', (
    tester,
  ) async {
    final repository = FakeRiderRepository(
      mine: [_delivery(OrderStatus.riderAssigned, withCoordinates: true)],
      updateResponse: Future.value(
        const RiderDeliveryUpdate(
          orderId: 'order-1',
          status: OrderStatus.pickedUp,
          riderId: 'rider-1',
        ),
      ),
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();

    expect(find.text('Mark as picked up'), findsOneWidget);
    expect(find.byKey(const Key('map-marker-pickup')), findsOneWidget);
    expect(find.byKey(const Key('map-marker-delivery')), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('rider-deliveries-list')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('advance-order-1')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Mark as picked up').last,
    );
    await tester.pumpAndSettle();

    expect(repository.lastStatus, OrderStatus.pickedUp);
  });

  testWidgets('active old order handles missing map coordinates', (
    tester,
  ) async {
    final repository = FakeRiderRepository(
      mine: [_delivery(OrderStatus.riderAssigned)],
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('delivery-map-unavailable-order-1')),
      findsOneWidget,
    );
  });

  testWidgets('delivered order appears only in history', (tester) async {
    final repository = FakeRiderRepository(
      mine: [_delivery(OrderStatus.delivered)],
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('Delivered'), findsOneWidget);
    expect(find.text('Accept delivery'), findsNothing);
    expect(find.textContaining('Mark as'), findsNothing);
  });

  testWidgets('shows loading, empty, error, and retry states', (tester) async {
    final pending = Completer<List<RiderDelivery>>();
    final repository = FakeRiderRepository(
      availableResponses: [pending.future, Future.value(const [])],
    );
    await tester.pumpWidget(_app(repository));
    expect(find.byKey(const Key('rider-deliveries-loading')), findsOneWidget);
    pending.completeError(
      const RiderDeliveryException(
        RiderDeliveryFailure.unavailable,
        'Network failure.',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rider-deliveries-error')), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rider-deliveries-empty')), findsOneWidget);
  });
}

Widget _app(RiderDeliveryRepository repository) => MaterialApp(
  home: Scaffold(body: RiderDeliveriesPage(repository: repository)),
);

RiderDelivery _delivery(OrderStatus status, {bool withCoordinates = false}) =>
    RiderDelivery(
      id: 'order-1',
      kitchenId: 'kitchen-1',
      kitchenName: 'Secure Kitchen',
      kitchenAddress: 'Kitchen Road',
      kitchenLatitude: withCoordinates ? 23.8 : null,
      kitchenLongitude: withCoordinates ? 90.4 : null,
      deliveryLatitude: withCoordinates ? 23.81 : null,
      deliveryLongitude: withCoordinates ? 90.41 : null,
      deliveryAddress: 'Delivery Road',
      status: status,
      finalPrice: 250,
      riderFee: 40,
      itemName: 'Rice Bowl',
      quantity: 1,
      createdAt: DateTime.utc(2026, 8, 13),
    );

class FakeRiderRepository implements RiderDeliveryRepository {
  FakeRiderRepository({
    this.available = const [],
    this.mine = const [],
    List<Future<List<RiderDelivery>>>? availableResponses,
    this.claimResponse,
    this.updateResponse,
  }) : availableResponses = availableResponses ?? const [];

  final List<RiderDelivery> available;
  final List<RiderDelivery> mine;
  final List<Future<List<RiderDelivery>>> availableResponses;
  final Future<RiderDeliveryUpdate>? claimResponse;
  final Future<RiderDeliveryUpdate>? updateResponse;
  int availableCalls = 0;
  int claimCalls = 0;
  OrderStatus? lastStatus;

  @override
  Future<List<RiderDelivery>> fetchAvailable() {
    if (availableResponses.isNotEmpty) {
      final index = availableCalls++;
      return availableResponses[index < availableResponses.length
          ? index
          : availableResponses.length - 1];
    }
    return Future.value(available);
  }

  @override
  Future<List<RiderDelivery>> fetchMine() async => mine;

  @override
  Future<RiderDeliveryUpdate> claim(String orderId) {
    claimCalls++;
    return claimResponse!;
  }

  @override
  Future<RiderDeliveryUpdate> updateStatus(String orderId, OrderStatus status) {
    lastStatus = status;
    return updateResponse!;
  }
}
