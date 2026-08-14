import 'package:cloud_kitchen_mvp/features/kitchen/domain/kitchen.dart';
import 'package:cloud_kitchen_mvp/features/orders/presentation/order_confirmation_page.dart';
import 'package:cloud_kitchen_mvp/features/payments/domain/payment_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('owner payment settings map into refreshed customer availability', () {
    final before = Kitchen.fromMap(
      _row(acceptsBkash: false, bkashNumber: null, acceptsCod: true),
    );
    final after = Kitchen.fromMap(
      _row(acceptsBkash: true, bkashNumber: '01700000000', acceptsCod: true),
    );

    expect(availableCheckoutPaymentMethods(before), [
      PaymentMethod.cashOnDelivery,
    ]);
    expect(availableCheckoutPaymentMethods(after), [
      PaymentMethod.bkash,
      PaymentMethod.cashOnDelivery,
    ]);
  });

  test('invalid or missing bKash number is never presented as payable', () {
    final missing = Kitchen.fromMap(
      _row(acceptsBkash: true, bkashNumber: null, acceptsCod: false),
    );
    final invalid = Kitchen.fromMap(
      _row(acceptsBkash: true, bkashNumber: '123', acceptsCod: false),
    );
    expect(availableCheckoutPaymentMethods(missing), isEmpty);
    expect(availableCheckoutPaymentMethods(invalid), isEmpty);
  });

  test('owner payment settings round-trip through canonical schema fields', () {
    const draft = KitchenDraft(
      name: 'Kitchen',
      address: 'Address',
      acceptsBkash: true,
      bkashNumber: '+8801700000000',
      acceptsCod: false,
    );
    final insert = draft.toInsertMap('owner-1');

    expect(insert['accepts_bkash'], isTrue);
    expect(insert['bkash_number'], '+8801700000000');
    expect(insert['accepts_cod'], isFalse);

    final loaded = Kitchen.fromMap({...insert, 'id': 'kitchen-1'});
    expect(loaded.acceptsBkash, isTrue);
    expect(loaded.bkashNumber, '+8801700000000');
    expect(loaded.acceptsCod, isFalse);
    expect(availableCheckoutPaymentMethods(loaded), [PaymentMethod.bkash]);
  });
}

Map<String, dynamic> _row({
  required bool acceptsBkash,
  required String? bkashNumber,
  required bool acceptsCod,
}) => {
  'id': 'kitchen-1',
  'owner_id': 'owner-1',
  'name': 'Kitchen',
  'address': 'Address',
  'accepts_bkash': acceptsBkash,
  'bkash_number': bkashNumber,
  'accepts_cod': acceptsCod,
};
