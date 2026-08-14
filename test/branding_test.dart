import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('visible platform configuration uses FoodCircle branding', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final webManifest =
        jsonDecode(File('web/manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    final webIndex = File('web/index.html').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final appDart = File('lib/app/cloud_kitchen_app.dart').readAsStringSync();
    final bootstrapDart = File('lib/bootstrap.dart').readAsStringSync();

    expect(manifest, contains('android:label="FoodCircle"'));
    expect(manifest, contains('com.google.firebase.messaging'));
    expect(webManifest['name'], 'FoodCircle');
    expect(webManifest['short_name'], 'FoodCircle');
    expect(webIndex, contains('<title>FoodCircle</title>'));
    expect(pubspec, contains('FoodCircle'));
    expect(appDart, contains("title: 'FoodCircle'"));
    expect(bootstrapDart, contains("title: 'FoodCircle'"));
    expect(File('assets/branding/foodcircle_icon.png').existsSync(), isTrue);
  });

  test('Firebase Android package identity remains unchanged', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(
      gradle,
      contains('applicationId = "com.cloudkitchen.cloud_kitchen_mvp"'),
    );
  });

  test('user navigation does not expose normal Demo Wallet UI', () {
    final legacyShell = File(
      'lib/app/legacy_app_shell.dart',
    ).readAsStringSync();
    // Customer navigation: Discover, My Orders, Profile
    // Owner navigation: Dashboard, Kitchen & Menu, Orders, Profile
    // Rider navigation: Deliveries, Earnings, Profile
    expect(legacyShell, contains("'Discover'"));
    expect(legacyShell, contains("'My Orders'"));
    expect(legacyShell, contains("'Kitchen & Menu'"));
    expect(legacyShell, contains("'Deliveries'"));
    expect(legacyShell, contains("'Earnings'"));
    expect(legacyShell, isNot(contains("'Demo Wallet'")));
  });
}
