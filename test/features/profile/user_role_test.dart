import 'package:cloud_kitchen_mvp/features/profile/domain/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses every supported profile role', () {
    expect(parseUserRole('customer'), UserRole.customer);
    expect(parseUserRole('kitchen_owner'), UserRole.owner);
    expect(parseUserRole('rider'), UserRole.rider);
  });

  test('rejects missing and unsupported profile roles', () {
    expect(
      () => parseUserRole(null),
      throwsA(isA<UnsupportedUserRoleException>()),
    );
    expect(
      () => parseUserRole('admin'),
      throwsA(isA<UnsupportedUserRoleException>()),
    );
  });
}
