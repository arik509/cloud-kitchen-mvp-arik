import 'package:cloud_kitchen_mvp/features/orders/data/order_repository.dart';
import 'package:cloud_kitchen_mvp/features/orders/domain/order_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('place-order request contains only checkout inputs', () {
    const request = PlaceOrderRequest(
      menuItemId: 'item-1',
      quantity: 3,
      deliveryAddress: '  12 Test Road  ',
      deliveryLatitude: 23.8,
      deliveryLongitude: 90.4,
    );

    expect(request.toRpcParameters(), {
      'p_menu_item_id': 'item-1',
      'p_quantity': 3,
      'p_delivery_address': '12 Test Road',
      'p_payment_method': 'cash_on_delivery',
      'p_transaction_id': null,
      'p_delivery_latitude': 23.8,
      'p_delivery_longitude': 90.4,
    });
    expect(
      request.toRpcParameters().keys,
      isNot(
        containsAll([
          'price',
          'customer_id',
          'kitchen_id',
          'status',
          'platform_fee',
          'rider_fee',
          'wallet_balance',
        ]),
      ),
    );
  });

  test(
    'repository sends the minimal RPC request and parses its result',
    () async {
      final source = FakeOrderRemoteDataSource(
        placeResponse: [
          {
            'order_id': 'order-1',
            'authoritative_total': 240,
            'wallet_balance': 760,
          },
        ],
      );
      final repository = SupabaseOrderRepository.withDataSource(source);

      final result = await repository.placeOrder(
        const PlaceOrderRequest(
          menuItemId: 'item-1',
          quantity: 2,
          deliveryAddress: 'Customer address',
          deliveryLatitude: 23.8,
          deliveryLongitude: 90.4,
        ),
      );

      expect(source.lastParameters, {
        'p_menu_item_id': 'item-1',
        'p_quantity': 2,
        'p_delivery_address': 'Customer address',
        'p_payment_method': 'cash_on_delivery',
        'p_transaction_id': null,
        'p_delivery_latitude': 23.8,
        'p_delivery_longitude': 90.4,
      });
      expect(result.orderId, 'order-1');
      expect(result.authoritativeTotal, 240);
      expect(result.walletBalance, 760);
    },
  );

  test(
    'repository maps authenticated customer orders using a fake source',
    () async {
      final source = FakeOrderRemoteDataSource(
        placeResponse: const [],
        orders: [
          {
            'id': 'order-1',
            'kitchen_id': 'kitchen-1',
            'kitchens': {'name': 'Test Kitchen'},
            'order_items': [
              {
                'unit_price': 240,
                'quantity': 3,
                'menu_items': {'name': 'Test Meal'},
              },
            ],
            'status': 'pending',
            'final_price': 240,
            'delivery_address': 'Customer address',
            'created_at': '2026-07-28T12:00:00Z',
          },
        ],
      );
      final orders = await SupabaseOrderRepository.withDataSource(
        source,
      ).fetchCurrentCustomerOrders();

      expect(orders.single.id, 'order-1');
      expect(orders.single.kitchenName, 'Test Kitchen');
      expect(orders.single.itemName, 'Test Meal');
      expect(orders.single.itemPrice, 240);
      expect(orders.single.quantity, 3);
      expect(orders.single.status, OrderStatus.pending);
      expect(orders.single.finalPrice, 240);
      expect(orders.single.deliveryCoordinates, isNull);
    },
  );

  test('maps wallet and order RPC failures to typed safe errors', () {
    expect(
      OrderRepositoryException.fromBackend(
        message: 'insufficient_wallet_balance',
      ).code,
      OrderFailureCode.insufficientBalance,
    );
    expect(
      OrderRepositoryException.fromBackend(
        message: 'menu_item_unavailable',
      ).code,
      OrderFailureCode.unavailableItem,
    );
    expect(
      OrderRepositoryException.fromBackend(message: 'JWT expired').code,
      OrderFailureCode.unauthenticated,
    );
    expect(
      OrderRepositoryException.fromBackend(
        message: 'private SQL details',
      ).message,
      isNot(contains('SQL')),
    );
  });

  test('validates delivery-coordinate pairs and ranges', () {
    expect(validateDeliveryCoordinates(23.8, 90.4), isNull);
    expect(validateDeliveryCoordinates(null, 90.4), isNotNull);
    expect(validateDeliveryCoordinates(91, 90.4), isNotNull);
    expect(validateDeliveryCoordinates(23.8, -181), isNotNull);
  });

  test('validates order quantity boundaries', () {
    expect(validateOrderQuantity(1), isNull);
    expect(validateOrderQuantity(maxOrderQuantity), isNull);
    expect(validateOrderQuantity(0), isNotNull);
    expect(validateOrderQuantity(-1), isNotNull);
    expect(validateOrderQuantity(maxOrderQuantity + 1), isNotNull);
    expect(
      () => const PlaceOrderRequest(
        menuItemId: 'item',
        deliveryAddress: 'Address',
        quantity: 0,
      ).toRpcParameters(),
      throwsArgumentError,
    );
  });
}

class FakeOrderRemoteDataSource implements OrderRemoteDataSource {
  FakeOrderRemoteDataSource({
    required this.placeResponse,
    this.orders = const [],
  });

  final Object? placeResponse;
  final List<Map<String, dynamic>> orders;
  Map<String, dynamic>? lastParameters;

  @override
  Future<List<Map<String, dynamic>>> fetchCurrentCustomerOrders() async =>
      orders;

  @override
  Future<Object?> placeOrder(Map<String, dynamic> parameters) async {
    lastParameters = Map<String, dynamic>.from(parameters);
    return placeResponse;
  }
}
