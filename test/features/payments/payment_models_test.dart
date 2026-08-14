import 'package:cloud_kitchen_mvp/features/payments/domain/payment_models.dart';
import 'package:cloud_kitchen_mvp/features/payments/data/payment_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes and validates bKash Transaction IDs', () {
    expect(normalizeBkashTransactionId(' ab 12-cd '), 'AB12-CD');
    expect(validateBkashTransactionId('ab12cd'), isNull);
    expect(validateBkashTransactionId('123'), isNotNull);
    expect(validateBkashTransactionId('unsafe id!'), isNotNull);
  });

  test('validates practical Bangladeshi mobile formats', () {
    expect(validateBangladeshiMobile('01700-000000'), isNull);
    expect(validateBangladeshiMobile('+8801700000000'), isNull);
    expect(validateBangladeshiMobile('01200000000'), isNotNull);
  });

  test('only verified bKash and pending COD can enter preparation', () {
    expect(
      isPaymentReadyForPreparation(
        const OrderPayment(
          method: PaymentMethod.bkash,
          status: PaymentStatus.awaitingVerification,
        ),
      ),
      isFalse,
    );
    expect(
      isPaymentReadyForPreparation(
        const OrderPayment(
          method: PaymentMethod.bkash,
          status: PaymentStatus.verified,
        ),
      ),
      isTrue,
    );
    expect(
      isPaymentReadyForPreparation(
        const OrderPayment(
          method: PaymentMethod.cashOnDelivery,
          status: PaymentStatus.codPending,
        ),
      ),
      isTrue,
    );
  });

  test('payment labels distinguish order payment states', () {
    expect(
      paymentStatusLabel(PaymentMethod.bkash, PaymentStatus.refundPending),
      'Refund pending',
    );
    expect(
      paymentStatusLabel(
        PaymentMethod.cashOnDelivery,
        PaymentStatus.codPending,
      ),
      contains('pending collection'),
    );
  });

  test('COD backend failures retain specific safe messages', () {
    expect(
      PaymentException.fromBackend('cash_already_collected').message,
      contains('already collected'),
    );
    expect(
      PaymentException.fromBackend('cod_payment_required').message,
      contains('only for Cash on Delivery'),
    );
    expect(
      PaymentException.fromBackend('pickup_required').message,
      contains('picked up'),
    );
    expect(
      PaymentException.fromBackend('delivery_access_denied').message,
      contains('not allowed'),
    );
  });
}
