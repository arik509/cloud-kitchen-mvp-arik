import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/rpc_response.dart';
import '../../orders/domain/order_models.dart';
import '../domain/rider_delivery.dart';

abstract interface class RiderDeliveryRepository {
  Future<List<RiderDelivery>> fetchAvailable();
  Future<List<RiderDelivery>> fetchMine();
  Future<RiderDeliveryUpdate> claim(String orderId);
  Future<RiderDeliveryUpdate> updateStatus(String orderId, OrderStatus status);
}

abstract interface class RiderDeliveryRemoteDataSource {
  Future<Object?> available();
  Future<Object?> mine();
  Future<Object?> claim(Map<String, dynamic> parameters);
  Future<Object?> updateStatus(Map<String, dynamic> parameters);
}

class SupabaseRiderDeliveryRepository implements RiderDeliveryRepository {
  SupabaseRiderDeliveryRepository(SupabaseClient client)
    : this.withDataSource(SupabaseRiderDeliveryRemoteDataSource(client));
  SupabaseRiderDeliveryRepository.withDataSource(this._source);

  final RiderDeliveryRemoteDataSource _source;

  @override
  Future<List<RiderDelivery>> fetchAvailable() => _list(_source.available);

  @override
  Future<List<RiderDelivery>> fetchMine() => _list(_source.mine);

  Future<List<RiderDelivery>> _list(Future<Object?> Function() load) async {
    try {
      final response = await load();
      if (response is! List) throw const FormatException();
      return response
          .map(
            (row) =>
                RiderDelivery.fromMap(Map<String, dynamic>.from(row as Map)),
          )
          .toList(growable: false);
    } on RiderDeliveryException {
      rethrow;
    } on PostgrestException catch (error) {
      throw RiderDeliveryException.fromBackend(error.message);
    } catch (_) {
      throw const RiderDeliveryException(
        RiderDeliveryFailure.invalidResponse,
        'The delivery response could not be read.',
      );
    }
  }

  @override
  Future<RiderDeliveryUpdate> claim(String orderId) =>
      _update(() => _source.claim({'p_order_id': orderId}));

  @override
  Future<RiderDeliveryUpdate> updateStatus(
    String orderId,
    OrderStatus status,
  ) => _update(
    () => _source.updateStatus({
      'p_order_id': orderId,
      'p_new_status': orderStatusValue(status),
    }),
  );

  Future<RiderDeliveryUpdate> _update(Future<Object?> Function() call) async {
    try {
      return RiderDeliveryUpdate.fromMap(singleRpcRow(await call()));
    } on RiderDeliveryException {
      rethrow;
    } on PostgrestException catch (error) {
      throw RiderDeliveryException.fromBackend(error.message);
    } catch (_) {
      throw const RiderDeliveryException(
        RiderDeliveryFailure.invalidResponse,
        'The delivery update response could not be read.',
      );
    }
  }
}

class SupabaseRiderDeliveryRemoteDataSource
    implements RiderDeliveryRemoteDataSource {
  SupabaseRiderDeliveryRemoteDataSource(this._client);
  final SupabaseClient _client;

  void _requireSession() {
    if (_client.auth.currentUser == null) {
      throw const RiderDeliveryException(
        RiderDeliveryFailure.unauthenticated,
        'Sign in again to manage deliveries.',
      );
    }
  }

  @override
  Future<Object?> available() {
    _requireSession();
    return _client.rpc('list_available_deliveries');
  }

  @override
  Future<Object?> mine() {
    _requireSession();
    return _client.rpc('list_my_rider_deliveries');
  }

  @override
  Future<Object?> claim(Map<String, dynamic> parameters) {
    _requireSession();
    return _client.rpc('claim_delivery', params: parameters);
  }

  @override
  Future<Object?> updateStatus(Map<String, dynamic> parameters) {
    _requireSession();
    return _client.rpc('update_rider_delivery_status', params: parameters);
  }
}

enum RiderDeliveryFailure {
  unauthenticated,
  riderRoleRequired,
  orderNotFound,
  alreadyClaimed,
  forbidden,
  invalidTransition,
  invalidResponse,
  unavailable,
}

class RiderDeliveryException implements Exception {
  const RiderDeliveryException(this.code, this.message);

  factory RiderDeliveryException.fromBackend(String message) {
    final value = message.toLowerCase();
    if (value.contains('authentication_required') ||
        value.contains('jwt expired')) {
      return const RiderDeliveryException(
        RiderDeliveryFailure.unauthenticated,
        'Your session expired. Sign in again.',
      );
    }
    if (value.contains('rider_role_required')) {
      return const RiderDeliveryException(
        RiderDeliveryFailure.riderRoleRequired,
        'Only rider accounts can manage deliveries.',
      );
    }
    if (value.contains('order_not_found')) {
      return const RiderDeliveryException(
        RiderDeliveryFailure.orderNotFound,
        'This order no longer exists.',
      );
    }
    if (value.contains('delivery_already_claimed')) {
      return const RiderDeliveryException(
        RiderDeliveryFailure.alreadyClaimed,
        'Another rider already accepted this delivery.',
      );
    }
    if (value.contains('delivery_access_denied')) {
      return const RiderDeliveryException(
        RiderDeliveryFailure.forbidden,
        'Only the assigned rider can update this delivery.',
      );
    }
    if (value.contains('invalid_delivery_status_transition')) {
      return const RiderDeliveryException(
        RiderDeliveryFailure.invalidTransition,
        'That delivery update is no longer allowed. Refresh and retry.',
      );
    }
    return const RiderDeliveryException(
      RiderDeliveryFailure.unavailable,
      'Delivery service is unavailable. Check your connection and retry.',
    );
  }

  final RiderDeliveryFailure code;
  final String message;
  @override
  String toString() => message;
}
