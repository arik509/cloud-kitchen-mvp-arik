import 'package:cloud_kitchen_mvp/features/kitchen/domain/kitchen_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KitchenInputValidator', () {
    test('requires a kitchen name and address', () {
      expect(KitchenInputValidator.name('  '), 'Kitchen name is required');
      expect(KitchenInputValidator.address(''), 'Kitchen address is required');
    });

    test('accepts omitted coordinates', () {
      expect(KitchenInputValidator.latitude(''), isNull);
      expect(KitchenInputValidator.longitude(null), isNull);
    });

    test('accepts coordinate boundaries', () {
      expect(KitchenInputValidator.latitude('-90'), isNull);
      expect(KitchenInputValidator.latitude('90'), isNull);
      expect(KitchenInputValidator.longitude('-180'), isNull);
      expect(KitchenInputValidator.longitude('180'), isNull);
    });

    test('rejects out-of-range or non-numeric coordinates', () {
      expect(KitchenInputValidator.latitude('90.1'), isNotNull);
      expect(KitchenInputValidator.longitude('-180.1'), isNotNull);
      expect(KitchenInputValidator.latitude('north'), isNotNull);
    });
  });
}
