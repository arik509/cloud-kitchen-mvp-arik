import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/rpc_response.dart';
import '../domain/payment_models.dart';

abstract interface class PaymentRepository {
  Future<OrderPayment> submitBkashTransaction(
    String orderId,
    String transactionId,
  );
  Future<OrderPayment> reviewBkash(String orderId, {required bool verify});
  Future<OrderPayment> markRefundCompleted(String orderId);
  Future<double> confirmCodCollection(String orderId);
}

class SupabasePaymentRepository implements PaymentRepository {
  SupabasePaymentRepository(this._client);
  final SupabaseClient _client;

  Future<Map<String, dynamic>> _rpc(
    String name,
    Map<String, dynamic> params,
  ) async {
    try {
      return singleRpcRow(await _client.rpc(name, params: params));
    } on PostgrestException catch (error) {
      throw PaymentException.fromBackend(error.message);
    }
  }

  @override
  Future<OrderPayment> submitBkashTransaction(
    String orderId,
    String transactionId,
  ) async {
    final row = await _rpc('submit_bkash_transaction', {
      'p_order_id': orderId,
      'p_transaction_id': normalizeBkashTransactionId(transactionId),
    });
    return OrderPayment.fromMap({...row, 'payment_method': 'bkash'});
  }

  @override
  Future<OrderPayment> reviewBkash(
    String orderId, {
    required bool verify,
  }) async {
    final row = await _rpc('review_bkash_payment', {
      'p_order_id': orderId,
      'p_action': verify ? 'verify' : 'reject',
    });
    return OrderPayment.fromMap({...row, 'payment_method': 'bkash'});
  }

  @override
  Future<OrderPayment> markRefundCompleted(String orderId) async {
    final row = await _rpc('mark_bkash_refund_completed', {
      'p_order_id': orderId,
    });
    return OrderPayment.fromMap({...row, 'payment_method': 'bkash'});
  }

  @override
  Future<double> confirmCodCollection(String orderId) async {
    final row = await _rpc('confirm_cod_collection', {'p_order_id': orderId});
    return (row['authoritative_amount'] as num).toDouble();
  }
}

class PaymentException implements Exception {
  const PaymentException(this.message);
  factory PaymentException.fromBackend(String message) {
    final value = message.toLowerCase();
    if (value.contains('already_used')) {
      return const PaymentException('That Transaction ID was already used.');
    }
    if (value.contains('invalid_bkash')) {
      return const PaymentException('Enter a valid bKash Transaction ID.');
    }
    if (value.contains('payment_not_ready')) {
      return const PaymentException(
        'Verify the payment before accepting this order.',
      );
    }
    if (value.contains('cod_collection_required')) {
      return const PaymentException('Confirm cash collection before delivery.');
    }
    if (value.contains('access_denied')) {
      return const PaymentException(
        'You are not allowed to update this payment.',
      );
    }
    if (value.contains('invalid_payment_transition')) {
      return const PaymentException(
        'This payment action is no longer available. Refresh and retry.',
      );
    }
    return const PaymentException(
      'Could not update payment. Check your connection and retry.',
    );
  }
  final String message;
  @override
  String toString() => message;
}
