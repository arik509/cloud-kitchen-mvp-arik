import 'package:cloud_kitchen_mvp/core/validation/bangladesh_phone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts and normalizes standard Bangladesh mobile numbers', () {
    expect(normalizeBangladeshPhone('+880 1700-000000'), '01700000000');
    expect(normalizeBangladeshPhone('8801700000000'), '01700000000');
    expect(validateBangladeshPhone('01300000000'), isNull);
    expect(validateBangladeshPhone('01999999999'), isNull);
  });

  test('rejects invalid prefixes, lengths, letters, and other countries', () {
    for (final value in [
      '01200000000',
      '0170000000',
      '017000000000',
      '01700abc000',
      '+919876543210',
      '',
    ]) {
      expect(validateBangladeshPhone(value), isNotNull, reason: value);
    }
  });
}
