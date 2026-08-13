import 'package:cloud_kitchen_mvp/features/orders/domain/order_models.dart';
import 'package:cloud_kitchen_mvp/features/rider/data/rider_delivery_repository.dart';
import 'package:cloud_kitchen_mvp/features/rider/domain/rider_delivery.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps available and assigned delivery data from secure RPCs', () async {
    final source = FakeRiderDeliverySource(
      availableResponse: [_deliveryMap(status: 'awaiting_rider')],
      mineResponse: [_deliveryMap(status: 'rider_assigned')],
    );
    final repository = SupabaseRiderDeliveryRepository.withDataSource(source);

    final available = await repository.fetchAvailable();
    final mine = await repository.fetchMine();

    expect(available.single.status, OrderStatus.awaitingRider);
    expect(available.single.kitchenName, 'Secure Kitchen');
    expect(available.single.deliveryAddress, 'Delivery Road');
    expect(mine.single.status, OrderStatus.riderAssigned);
  });

  test(
    'claim sends only the order ID and parses server rider identity',
    () async {
      final source = FakeRiderDeliverySource(
        claimResponse: [
          {
            'order_id': 'order-1',
            'status': 'rider_assigned',
            'rider_id': 'server-rider',
          },
        ],
      );
      final result = await SupabaseRiderDeliveryRepository.withDataSource(
        source,
      ).claim('order-1');

      expect(source.claimParameters, {'p_order_id': 'order-1'});
      expect(source.claimParameters, isNot(contains('rider_id')));
      expect(result.riderId, 'server-rider');
      expect(result.status, OrderStatus.riderAssigned);
    },
  );

  test('delivery transition sends only order ID and target state', () async {
    final source = FakeRiderDeliverySource(
      updateResponse: [
        {
          'order_id': 'order-1',
          'status': 'picked_up',
          'rider_id': 'server-rider',
        },
      ],
    );
    await SupabaseRiderDeliveryRepository.withDataSource(
      source,
    ).updateStatus('order-1', OrderStatus.pickedUp);

    expect(source.updateParameters, {
      'p_order_id': 'order-1',
      'p_new_status': 'picked_up',
    });
    expect(source.updateParameters, isNot(contains('rider_id')));
  });

  test('defines strict rider transitions and authoritative earnings', () {
    expect(nextRiderStatus(OrderStatus.riderAssigned), OrderStatus.pickedUp);
    expect(nextRiderStatus(OrderStatus.pickedUp), OrderStatus.delivered);
    expect(nextRiderStatus(OrderStatus.awaitingRider), isNull);
    expect(nextRiderStatus(OrderStatus.rejected), isNull);

    final earnings = RiderEarnings.fromDeliveries([
      _delivery(status: OrderStatus.delivered, riderFee: 40),
      _delivery(status: OrderStatus.delivered, riderFee: 30),
      _delivery(status: OrderStatus.pickedUp, riderFee: 99),
    ]);
    expect(earnings.total, 70);
    expect(earnings.deliveryCount, 2);
  });

  test('maps contested claims and forbidden transitions to safe failures', () {
    expect(
      RiderDeliveryException.fromBackend('delivery_already_claimed').code,
      RiderDeliveryFailure.alreadyClaimed,
    );
    expect(
      RiderDeliveryException.fromBackend('delivery_access_denied').code,
      RiderDeliveryFailure.forbidden,
    );
    expect(
      RiderDeliveryException.fromBackend(
        'invalid_delivery_status_transition',
      ).code,
      RiderDeliveryFailure.invalidTransition,
    );
    expect(
      RiderDeliveryException.fromBackend('private database details').message,
      isNot(contains('database')),
    );
  });
}

Map<String, dynamic> _deliveryMap({required String status}) => {
  'order_id': 'order-1',
  'kitchen_id': 'kitchen-1',
  'kitchen_name': 'Secure Kitchen',
  'kitchen_address': 'Kitchen Road',
  'kitchen_latitude': 23.8,
  'kitchen_longitude': 90.4,
  'delivery_address': 'Delivery Road',
  'status': status,
  'final_price': 250,
  'rider_fee': 40,
  'item_name': 'Rice Bowl',
  'quantity': 1,
  'created_at': '2026-08-13T12:00:00Z',
};

RiderDelivery _delivery({
  required OrderStatus status,
  required double riderFee,
}) => RiderDelivery(
  id: 'order-${status.name}',
  kitchenId: 'kitchen-1',
  kitchenName: 'Secure Kitchen',
  kitchenAddress: 'Kitchen Road',
  deliveryAddress: 'Delivery Road',
  status: status,
  finalPrice: 250,
  riderFee: riderFee,
  itemName: 'Rice Bowl',
  quantity: 1,
  createdAt: DateTime.utc(2026, 8, 13),
);

class FakeRiderDeliverySource implements RiderDeliveryRemoteDataSource {
  FakeRiderDeliverySource({
    this.availableResponse = const [],
    this.mineResponse = const [],
    this.claimResponse,
    this.updateResponse,
  });

  final Object? availableResponse;
  final Object? mineResponse;
  final Object? claimResponse;
  final Object? updateResponse;
  Map<String, dynamic>? claimParameters;
  Map<String, dynamic>? updateParameters;

  @override
  Future<Object?> available() async => availableResponse;

  @override
  Future<Object?> mine() async => mineResponse;

  @override
  Future<Object?> claim(Map<String, dynamic> parameters) async {
    claimParameters = Map<String, dynamic>.from(parameters);
    return claimResponse;
  }

  @override
  Future<Object?> updateStatus(Map<String, dynamic> parameters) async {
    updateParameters = Map<String, dynamic>.from(parameters);
    return updateResponse;
  }
}
