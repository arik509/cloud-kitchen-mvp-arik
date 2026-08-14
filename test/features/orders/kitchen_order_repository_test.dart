import 'package:cloud_kitchen_mvp/features/orders/data/kitchen_order_repository.dart';
import 'package:cloud_kitchen_mvp/features/orders/domain/order_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'maps owner order data without exposing customer profile fields',
    () async {
      final source = FakeKitchenOrderSource(
        rows: [
          {
            'id': 'order-1',
            'kitchen_id': 'kitchen-1',
            'status': 'pending',
            'final_price': 260,
            'delivery_address': 'Safe delivery address',
            'created_at': '2026-08-13T12:00:00Z',
            'order_items': [
              {
                'quantity': 1,
                'unit_price': 250,
                'menu_items': {'name': 'Chicken Bowl'},
              },
            ],
          },
        ],
      );

      final orders = await SupabaseKitchenOrderRepository.withDataSource(
        source,
      ).fetchOwnerOrders();

      expect(orders.single.id, 'order-1');
      expect(orders.single.itemName, 'Chicken Bowl');
      expect(orders.single.quantity, 1);
      expect(orders.single.unitPrice, 250);
      expect(orders.single.finalPrice, 260);
      expect(orders.single.status, OrderStatus.pending);
    },
  );

  test('status RPC sends only order ID and requested status', () async {
    final source = FakeKitchenOrderSource(
      response: [
        {
          'order_id': 'order-1',
          'status': 'rejected',
          'refunded_amount': 260,
          'wallet_balance': 1000,
        },
      ],
    );
    final result = await SupabaseKitchenOrderRepository.withDataSource(
      source,
    ).updateStatus('order-1', OrderStatus.rejected);

    expect(source.parameters, {
      'p_order_id': 'order-1',
      'p_new_status': 'rejected',
    });
    expect(source.parameters!.keys, isNot(contains('kitchen_id')));
    expect(source.parameters!.keys, isNot(contains('customer_id')));
    expect(source.parameters!.keys, isNot(contains('price')));
    expect(result.status, OrderStatus.rejected);
    expect(result.refundedAmount, 260);
    expect(result.walletBalance, 1000);
  });

  test('defines owner transitions through rider handoff only', () {
    expect(allowedKitchenOrderTransitions(OrderStatus.pending), {
      OrderStatus.accepted,
      OrderStatus.rejected,
    });
    expect(allowedKitchenOrderTransitions(OrderStatus.accepted), {
      OrderStatus.preparing,
    });
    expect(allowedKitchenOrderTransitions(OrderStatus.preparing), {
      OrderStatus.ready,
    });
    expect(allowedKitchenOrderTransitions(OrderStatus.ready), {
      OrderStatus.awaitingRider,
    });
    expect(allowedKitchenOrderTransitions(OrderStatus.awaitingRider), isEmpty);
    expect(allowedKitchenOrderTransitions(OrderStatus.riderAssigned), isEmpty);
    expect(allowedKitchenOrderTransitions(OrderStatus.rejected), isEmpty);
  });

  test('maps authorization and invalid-transition failures safely', () {
    expect(
      KitchenOrderRepositoryException.fromBackend(
        'kitchen_owner_role_required',
      ).code,
      KitchenOrderFailureCode.ownerRoleRequired,
    );
    expect(
      KitchenOrderRepositoryException.fromBackend('order_access_denied').code,
      KitchenOrderFailureCode.forbidden,
    );
    expect(
      KitchenOrderRepositoryException.fromBackend(
        'invalid_order_status_transition',
      ).code,
      KitchenOrderFailureCode.invalidTransition,
    );
    expect(
      KitchenOrderRepositoryException.fromBackend(
        'order_already_refunded',
      ).code,
      KitchenOrderFailureCode.alreadyRefunded,
    );
  });
}

class FakeKitchenOrderSource implements KitchenOrderRemoteDataSource {
  FakeKitchenOrderSource({this.rows = const [], this.response});

  final List<Map<String, dynamic>> rows;
  final Object? response;
  Map<String, dynamic>? parameters;

  @override
  Future<List<Map<String, dynamic>>> fetchOwnerOrders() async => rows;

  @override
  Future<Object?> updateStatus(Map<String, dynamic> parameters) async {
    this.parameters = Map<String, dynamic>.from(parameters);
    return response;
  }
}
