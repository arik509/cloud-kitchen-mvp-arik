import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/rpc_response.dart';
import '../domain/order_models.dart';

abstract interface class KitchenOrderRepository {
  Future<List<KitchenOrder>> fetchOwnerOrders();

  Future<KitchenOrderStatusResult> updateStatus(
    String orderId,
    OrderStatus newStatus,
  );
}

abstract interface class KitchenOrderRemoteDataSource {
  Future<List<Map<String, dynamic>>> fetchOwnerOrders();

  Future<Object?> updateStatus(Map<String, dynamic> parameters);
}

class SupabaseKitchenOrderRepository implements KitchenOrderRepository {
  SupabaseKitchenOrderRepository(SupabaseClient client)
    : this.withDataSource(SupabaseKitchenOrderRemoteDataSource(client));

  SupabaseKitchenOrderRepository.withDataSource(this._dataSource);

  final KitchenOrderRemoteDataSource _dataSource;

  @override
  Future<List<KitchenOrder>> fetchOwnerOrders() async {
    try {
      final rows = await _dataSource.fetchOwnerOrders();
      return rows.map(KitchenOrder.fromMap).toList(growable: false);
    } on KitchenOrderRepositoryException {
      rethrow;
    } on PostgrestException catch (error) {
      throw KitchenOrderRepositoryException.fromBackend(
        error.message,
        backendCode: error.code,
      );
    } catch (_) {
      throw const KitchenOrderRepositoryException(
        KitchenOrderFailureCode.invalidResponse,
        'The kitchen orders response could not be read.',
      );
    }
  }

  @override
  Future<KitchenOrderStatusResult> updateStatus(
    String orderId,
    OrderStatus newStatus,
  ) async {
    try {
      final row = singleRpcRow(
        await _dataSource.updateStatus({
          'p_order_id': orderId,
          'p_new_status': orderStatusValue(newStatus),
        }),
      );
      return KitchenOrderStatusResult.fromRpc(row);
    } on KitchenOrderRepositoryException {
      rethrow;
    } on PostgrestException catch (error) {
      throw KitchenOrderRepositoryException.fromBackend(
        error.message,
        backendCode: error.code,
      );
    } on FormatException {
      throw const KitchenOrderRepositoryException(
        KitchenOrderFailureCode.invalidResponse,
        'The status update response could not be read.',
      );
    }
  }
}

class SupabaseKitchenOrderRemoteDataSource
    implements KitchenOrderRemoteDataSource {
  SupabaseKitchenOrderRemoteDataSource(this._client);

  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const KitchenOrderRepositoryException(
        KitchenOrderFailureCode.unauthenticated,
        'Sign in again to manage kitchen orders.',
      );
    }
    return id;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchOwnerOrders() async {
    final rows = await _client
        .from('orders')
        .select(
          'id,kitchen_id,status,final_price,delivery_address,'
          'delivery_latitude,delivery_longitude,created_at,'
          'kitchens!inner(owner_id),'
          'order_items(quantity,unit_price,menu_items(name)),'
          'order_payments(payment_method,payment_status,transaction_id,submitted_at)',
        )
        .eq('kitchens.owner_id', _userId)
        .order('created_at', ascending: false);
    return rows.map(Map<String, dynamic>.from).toList(growable: false);
  }

  @override
  Future<Object?> updateStatus(Map<String, dynamic> parameters) {
    _userId;
    return _client.rpc('update_kitchen_order_status', params: parameters);
  }
}

enum KitchenOrderFailureCode {
  unauthenticated,
  ownerRoleRequired,
  orderNotFound,
  forbidden,
  invalidTransition,
  alreadyRefunded,
  invalidResponse,
  unavailable,
}

class KitchenOrderRepositoryException implements Exception {
  const KitchenOrderRepositoryException(
    this.code,
    this.message, {
    this.backendCode,
  });

  factory KitchenOrderRepositoryException.fromBackend(
    String message, {
    String? backendCode,
  }) {
    final normalized = message.toLowerCase();
    if (normalized.contains('authentication_required') ||
        normalized.contains('jwt expired') ||
        normalized.contains('not authenticated')) {
      return KitchenOrderRepositoryException(
        KitchenOrderFailureCode.unauthenticated,
        'Your session expired. Sign in again.',
        backendCode: backendCode,
      );
    }
    if (normalized.contains('kitchen_owner_role_required')) {
      return KitchenOrderRepositoryException(
        KitchenOrderFailureCode.ownerRoleRequired,
        'Only kitchen-owner accounts can manage these orders.',
        backendCode: backendCode,
      );
    }
    if (normalized.contains('order_not_found')) {
      return KitchenOrderRepositoryException(
        KitchenOrderFailureCode.orderNotFound,
        'This order no longer exists.',
        backendCode: backendCode,
      );
    }
    if (normalized.contains('order_access_denied')) {
      return KitchenOrderRepositoryException(
        KitchenOrderFailureCode.forbidden,
        'You can manage only orders for your own kitchen.',
        backendCode: backendCode,
      );
    }
    if (normalized.contains('invalid_order_status_transition')) {
      return KitchenOrderRepositoryException(
        KitchenOrderFailureCode.invalidTransition,
        'That order status change is no longer allowed. Refresh and retry.',
        backendCode: backendCode,
      );
    }
    if (normalized.contains('payment_not_ready')) {
      return KitchenOrderRepositoryException(
        KitchenOrderFailureCode.invalidTransition,
        'Verify the bKash payment before accepting this order.',
        backendCode: backendCode,
      );
    }
    if (normalized.contains('order_already_refunded')) {
      return KitchenOrderRepositoryException(
        KitchenOrderFailureCode.alreadyRefunded,
        'This rejected order was already refunded.',
        backendCode: backendCode,
      );
    }
    return KitchenOrderRepositoryException(
      KitchenOrderFailureCode.unavailable,
      'Could not update the order. Check your connection and retry.',
      backendCode: backendCode,
    );
  }

  final KitchenOrderFailureCode code;
  final String message;
  final String? backendCode;

  @override
  String toString() => message;
}
