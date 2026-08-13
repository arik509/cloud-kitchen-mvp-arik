import 'package:cloud_kitchen_mvp/features/orders/data/order_repository.dart';
import 'package:cloud_kitchen_mvp/features/orders/domain/order_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('place-order request contains only item ID and delivery address', () {
    const request = PlaceOrderRequest(
      menuItemId: 'item-1',
      deliveryAddress: '  12 Test Road  ',
    );

    expect(request.toRpcParameters(), {
      'p_menu_item_id': 'item-1',
      'p_delivery_address': '12 Test Road',
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
          deliveryAddress: 'Customer address',
        ),
      );

      expect(source.lastParameters, {
        'p_menu_item_id': 'item-1',
        'p_delivery_address': 'Customer address',
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
      expect(orders.single.status, OrderStatus.pending);
      expect(orders.single.finalPrice, 240);
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
