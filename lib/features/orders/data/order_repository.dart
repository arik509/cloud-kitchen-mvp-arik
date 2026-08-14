import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/rpc_response.dart';
import '../domain/order_models.dart';

abstract interface class OrderRepository {
  Future<PlaceOrderResult> placeOrder(PlaceOrderRequest request);

  Future<List<CustomerOrder>> fetchCurrentCustomerOrders();
}

abstract interface class OrderRemoteDataSource {
  Future<Object?> placeOrder(Map<String, dynamic> parameters);

  Future<List<Map<String, dynamic>>> fetchCurrentCustomerOrders();
}

class SupabaseOrderRepository implements OrderRepository {
  SupabaseOrderRepository(SupabaseClient client)
    : this.withDataSource(SupabaseOrderRemoteDataSource(client));

  SupabaseOrderRepository.withDataSource(this._dataSource);

  final OrderRemoteDataSource _dataSource;

  @override
  Future<PlaceOrderResult> placeOrder(PlaceOrderRequest request) async {
    try {
      final row = singleRpcRow(
        await _dataSource.placeOrder(request.toRpcParameters()),
      );
      return PlaceOrderResult.fromRpc(row);
    } on OrderRepositoryException {
      rethrow;
    } on PostgrestException catch (error) {
      throw OrderRepositoryException.fromBackend(
        message: error.message,
        backendCode: error.code,
      );
    } on FormatException {
      throw const OrderRepositoryException(
        OrderFailureCode.invalidResponse,
        'The order response could not be read.',
      );
    }
  }

  @override
  Future<List<CustomerOrder>> fetchCurrentCustomerOrders() async {
    try {
      final rows = await _dataSource.fetchCurrentCustomerOrders();
      return rows.map(CustomerOrder.fromMap).toList(growable: false);
    } on OrderRepositoryException {
      rethrow;
    } on PostgrestException catch (error) {
      throw OrderRepositoryException.fromBackend(
        message: error.message,
        backendCode: error.code,
      );
    } catch (_) {
      throw const OrderRepositoryException(
        OrderFailureCode.invalidResponse,
        'The orders response could not be read.',
      );
    }
  }
}

class SupabaseOrderRemoteDataSource implements OrderRemoteDataSource {
  SupabaseOrderRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<Object?> placeOrder(Map<String, dynamic> parameters) {
    if (_client.auth.currentUser == null) {
      throw const OrderRepositoryException(
        OrderFailureCode.unauthenticated,
        'Sign in again before placing an order.',
      );
    }
    return _client.rpc('place_order_v4', params: parameters);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCurrentCustomerOrders() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const OrderRepositoryException(
        OrderFailureCode.unauthenticated,
        'Sign in to view your orders.',
      );
    }
    final rows = await _client
        .from('orders')
        .select(
          'id,kitchen_id,status,final_price,delivery_address,'
          'delivery_latitude,delivery_longitude,created_at,'
          'kitchens(name),'
          'order_items(quantity,unit_price,menu_items(name)),'
          'order_payments(payment_method,payment_status,transaction_id,submitted_at),'
          'ratings(stars)',
        )
        .eq('customer_id', userId)
        .order('created_at', ascending: false);
    return rows.map(Map<String, dynamic>.from).toList(growable: false);
  }
}

enum OrderFailureCode {
  unauthenticated,
  customerRoleRequired,
  invalidAddress,
  invalidLocation,
  invalidQuantity,
  invalidPayment,
  duplicateTransaction,
  unavailableItem,
  insufficientBalance,
  invalidResponse,
  unavailable,
}

class OrderRepositoryException implements Exception {
  const OrderRepositoryException(this.code, this.message, {this.backendCode});

  factory OrderRepositoryException.fromBackend({
    required String message,
    String? backendCode,
  }) {
    final normalized = message.toLowerCase();
    if (normalized.contains('authentication_required') ||
        normalized.contains('profile_not_found') ||
        normalized.contains('jwt expired') ||
        normalized.contains('not authenticated')) {
      return OrderRepositoryException(
        OrderFailureCode.unauthenticated,
        'Sign in again before placing an order.',
        backendCode: backendCode,
      );
    }
    if (normalized.contains('customer_role_required')) {
      return OrderRepositoryException(
        OrderFailureCode.customerRoleRequired,
        'Only customer accounts can place orders.',
        backendCode: backendCode,
      );
    }
    if (normalized.contains('invalid_delivery_address')) {
      return OrderRepositoryException(
        OrderFailureCode.invalidAddress,
        'Enter a valid delivery address.',
        backendCode: backendCode,
      );
    }
    if (normalized.contains('invalid_delivery_location')) {
      return OrderRepositoryException(
        OrderFailureCode.invalidLocation,
        'Choose a valid delivery location.',
        backendCode: backendCode,
      );
    }
    if (normalized.contains('invalid_order_quantity')) {
      return OrderRepositoryException(
        OrderFailureCode.invalidQuantity,
        'Choose a quantity between 1 and $maxOrderQuantity.',
        backendCode: backendCode,
      );
    }
    if (normalized.contains('menu_item_unavailable')) {
      return OrderRepositoryException(
        OrderFailureCode.unavailableItem,
        'This menu item is no longer available.',
        backendCode: backendCode,
      );
    }
    if (normalized.contains('invalid_payment_method') ||
        normalized.contains('payment_method_unavailable') ||
        normalized.contains('invalid_bkash_transaction_id')) {
      return OrderRepositoryException(
        OrderFailureCode.invalidPayment,
        'Choose an available payment method and enter a valid Transaction ID.',
        backendCode: backendCode,
      );
    }
    if (normalized.contains('bkash_transaction_id_already_used')) {
      return OrderRepositoryException(
        OrderFailureCode.duplicateTransaction,
        'That Transaction ID was already used.',
        backendCode: backendCode,
      );
    }
    if (normalized.contains('insufficient_wallet_balance')) {
      return OrderRepositoryException(
        OrderFailureCode.insufficientBalance,
        'Your wallet balance is too low for this order.',
        backendCode: backendCode,
      );
    }
    return OrderRepositoryException(
      OrderFailureCode.unavailable,
      'The order service is unavailable. Try again.',
      backendCode: backendCode,
    );
  }

  final OrderFailureCode code;
  final String message;
  final String? backendCode;

  @override
  String toString() => message;
}
