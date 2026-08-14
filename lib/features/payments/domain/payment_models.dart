import '../../../core/validation/bangladesh_phone.dart';

export '../../../core/validation/bangladesh_phone.dart';

enum PaymentMethod { bkash, cashOnDelivery, demoWallet }

enum PaymentStatus {
  awaitingVerification,
  verified,
  rejected,
  codPending,
  collected,
  refundPending,
  refunded,
  cancelled,
}

PaymentMethod parsePaymentMethod(Object? value) => switch (value) {
  'bkash' => PaymentMethod.bkash,
  'cash_on_delivery' => PaymentMethod.cashOnDelivery,
  'demo_wallet' || null => PaymentMethod.demoWallet,
  _ => throw FormatException('Unsupported payment method: $value'),
};

String paymentMethodValue(PaymentMethod method) => switch (method) {
  PaymentMethod.bkash => 'bkash',
  PaymentMethod.cashOnDelivery => 'cash_on_delivery',
  PaymentMethod.demoWallet => 'demo_wallet',
};

PaymentStatus parsePaymentStatus(Object? value) => switch (value) {
  'awaiting_verification' => PaymentStatus.awaitingVerification,
  'verified' || null => PaymentStatus.verified,
  'rejected' => PaymentStatus.rejected,
  'cod_pending' => PaymentStatus.codPending,
  'collected' => PaymentStatus.collected,
  'refund_pending' => PaymentStatus.refundPending,
  'refunded' => PaymentStatus.refunded,
  'cancelled' => PaymentStatus.cancelled,
  _ => throw FormatException('Unsupported payment status: $value'),
};

String paymentStatusLabel(PaymentMethod method, PaymentStatus status) =>
    switch ((method, status)) {
      (PaymentMethod.bkash, PaymentStatus.awaitingVerification) =>
        'Awaiting bKash verification',
      (PaymentMethod.bkash, PaymentStatus.verified) => 'bKash verified',
      (PaymentMethod.bkash, PaymentStatus.rejected) =>
        'Transaction ID rejected',
      (PaymentMethod.cashOnDelivery, PaymentStatus.codPending) =>
        'Cash on Delivery — pending collection',
      (PaymentMethod.cashOnDelivery, PaymentStatus.collected) =>
        'Cash on Delivery — collected',
      (_, PaymentStatus.refundPending) => 'Refund processing',
      (_, PaymentStatus.refunded) => 'Refund completed',
      (_, PaymentStatus.cancelled) => 'No payment required',
      (PaymentMethod.demoWallet, _) => 'Legacy test payment',
      (_, PaymentStatus.verified) => 'Verified',
      (_, PaymentStatus.rejected) => 'Rejected',
      (_, PaymentStatus.awaitingVerification) => 'Awaiting verification',
      (_, PaymentStatus.codPending) => 'Pending collection',
      (_, PaymentStatus.collected) => 'Collected',
    };

bool isPaymentReadyForPreparation(OrderPayment payment) =>
    payment.status == PaymentStatus.verified ||
    (payment.method == PaymentMethod.cashOnDelivery &&
        payment.status == PaymentStatus.codPending);

String normalizeBkashTransactionId(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();

String? validateBkashTransactionId(String? value) {
  final normalized = normalizeBkashTransactionId(value ?? '');
  if (normalized.isEmpty) return 'Transaction ID is required';
  if (!RegExp(r'^[A-Z0-9-]{6,40}$').hasMatch(normalized)) {
    return 'Use the 6–40 character Transaction ID from bKash';
  }
  return null;
}

String normalizeBangladeshiMobile(String value) =>
    normalizeBangladeshPhone(value);

String? validateBangladeshiMobile(String? value, {bool required = true}) {
  final normalized = normalizeBangladeshiMobile(value ?? '');
  if (normalized.isEmpty) return required ? 'bKash number is required' : null;
  return validateBangladeshPhone(normalized, required: required);
}

class OrderPayment {
  const OrderPayment({
    required this.method,
    required this.status,
    this.transactionId,
    this.submittedAt,
  });
  final PaymentMethod method;
  final PaymentStatus status;
  final String? transactionId;
  final DateTime? submittedAt;

  factory OrderPayment.fromMap(Map<String, dynamic>? map) => OrderPayment(
    method: parsePaymentMethod(map?['payment_method']),
    status: parsePaymentStatus(map?['payment_status']),
    transactionId: map?['transaction_id'] as String?,
    submittedAt: map?['submitted_at'] == null
        ? null
        : DateTime.parse(map!['submitted_at'] as String),
  );
}

class KitchenRatingSummary {
  const KitchenRatingSummary({
    required this.kitchenId,
    required this.average,
    required this.count,
  });
  final String kitchenId;
  final double average;
  final int count;
}
