import 'package:cloud_kitchen_mvp/app/legacy_app_shell.dart';
import 'package:cloud_kitchen_mvp/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('login is polished, validates fields, and toggles password', (
    tester,
  ) async {
    _mobileView(tester);
    await tester.pumpWidget(_app(const LoginScreen()));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.textContaining('Demo Wallet'), findsNothing);
    await tester.enterText(find.byKey(const Key('login-email')), 'invalid');
    await tester.enterText(find.byKey(const Key('login-password')), '123');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Use at least 6 characters.'), findsOneWidget);

    final passwordField = find.descendant(
      of: find.byKey(const Key('login-password')),
      matching: find.byType(EditableText),
    );
    final before = tester.widget<EditableText>(passwordField);
    expect(before.obscureText, isTrue);
    await tester.tap(find.byKey(const Key('toggle-login-password')));
    await tester.pump();
    final after = tester.widget<EditableText>(passwordField);
    expect(after.obscureText, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signup uses role choices and Bangladesh phone validation', (
    tester,
  ) async {
    _mobileView(tester);
    await tester.pumpWidget(_app(const SignupScreen()));
    expect(find.byKey(const Key('role-customer')), findsOneWidget);
    expect(find.byKey(const Key('role-owner')), findsOneWidget);
    expect(find.byKey(const Key('role-rider')), findsOneWidget);

    await tester.tap(find.byKey(const Key('role-owner')));
    await tester.pump();
    final ownerChoice = tester.widget<ChoiceChip>(
      find.descendant(
        of: find.byKey(const Key('role-owner')),
        matching: find.byType(ChoiceChip),
      ),
    );
    expect(ownerChoice.selected, isTrue);

    await _enterVisible(tester, 'signup-name', 'Test Owner');
    await _enterVisible(tester, 'signup-phone', '01234');
    await _enterVisible(tester, 'signup-address', 'Dhaka');
    await _enterVisible(tester, 'signup-email', 'owner@example.com');
    await _enterVisible(tester, 'signup-password', 'password');
    await tester.ensureVisible(find.byKey(const Key('signup-submit')));
    await tester.tap(find.byKey(const Key('signup-submit')));
    await tester.pump();
    expect(
      find.text('Enter a valid Bangladeshi mobile number.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _enterVisible(
  WidgetTester tester,
  String key,
  String value,
) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.enterText(finder, value);
}

Widget _app(Widget home) => MaterialApp(theme: AppTheme.light, home: home);

void _mobileView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 800);
  addTearDown(tester.view.reset);
}
