import 'package:cloud_kitchen_mvp/app/legacy_app_shell.dart';
import 'package:cloud_kitchen_mvp/features/notifications/application/push_notification_service.dart';
import 'package:cloud_kitchen_mvp/features/profile/data/account_profile_repository.dart';
import 'package:cloud_kitchen_mvp/features/profile/domain/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('profile displays phone and customer refund helper', (
    tester,
  ) async {
    await tester.pumpWidget(_app(FakeAccountProfileRepository()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-content')), findsOneWidget);
    expect(find.text('01700000000'), findsOneWidget);
    expect(find.byKey(const Key('refund-phone-helper')), findsOneWidget);
  });

  testWidgets('profile validates and saves normalized phone updates', (
    tester,
  ) async {
    final repository = FakeAccountProfileRepository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('profile-phone')),
        matching: find.byIcon(Icons.edit_outlined),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('profile-phone-field')),
      '+8801900000000',
    );
    await tester.tap(find.byKey(const Key('save-profile-phone')));
    await tester.pumpAndSettle();
    expect(repository.updatedPhone, '+8801900000000');
    expect(find.text('01900000000'), findsOneWidget);
  });
}

Widget _app(AccountProfileRepository repository) => MaterialApp(
  home: Scaffold(
    body: ProfilePage(
      notificationService: DisabledPushNotificationService(),
      repository: repository,
    ),
  ),
);

class FakeAccountProfileRepository implements AccountProfileRepository {
  String? updatedPhone;
  AccountProfile profile = const AccountProfile(
    id: 'customer-1',
    name: 'Cloud Customer',
    phone: '01700000000',
    address: 'Dhaka',
    role: UserRole.customer,
    email: 'customer@example.com',
  );

  @override
  Future<AccountProfile> fetchCurrent() async => profile;

  @override
  Future<AccountProfile> updatePhone(String phone) async {
    updatedPhone = phone;
    profile = profile.copyWith(phone: '01900000000');
    return profile;
  }
}
