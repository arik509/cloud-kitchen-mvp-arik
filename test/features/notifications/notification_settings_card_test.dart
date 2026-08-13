import 'package:cloud_kitchen_mvp/features/notifications/application/push_notification_service.dart';
import 'package:cloud_kitchen_mvp/features/notifications/domain/notification_models.dart';
import 'package:cloud_kitchen_mvp/features/notifications/presentation/notification_settings_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('disabled notification setup is clear and non-blocking', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationSettingsCard(
            service: DisabledPushNotificationService(),
          ),
        ),
      ),
    );
    expect(find.text('Notifications not configured'), findsOneWidget);
    expect(
      find.textContaining('All app features remain available'),
      findsOneWidget,
    );
  });

  testWidgets('denied permission exposes retry and settings actions', (
    tester,
  ) async {
    final service = FakePushNotificationService(PushPermissionStatus.denied);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NotificationSettingsCard(service: service)),
      ),
    );
    expect(
      find.byKey(const Key('retry-notification-permission')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('open-notification-settings')), findsOneWidget);
    await tester.tap(find.byKey(const Key('retry-notification-permission')));
    await tester.pump();
    expect(service.requestCalls, 1);
  });
}

class FakePushNotificationService implements PushNotificationService {
  FakePushNotificationService(PushPermissionStatus status)
    : permission = ValueNotifier(status);
  final ValueNotifier<PushPermissionStatus> permission;
  final ValueNotifier<NotificationDestination?> destination = ValueNotifier(
    null,
  );
  int requestCalls = 0;
  @override
  bool get isConfigured => true;
  @override
  ValueListenable<PushPermissionStatus> get permissionStatus => permission;
  @override
  ValueListenable<NotificationDestination?> get pendingDestination =>
      destination;
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> openSettings() async => true;
  @override
  Future<PushPermissionStatus> requestPermission() async {
    requestCalls++;
    return permission.value;
  }

  @override
  Future<void> syncForCurrentSession() async {}
  @override
  Future<void> unregisterCurrentDevice() async {}
  @override
  void consumeDestination(NotificationDestination destination) {
    this.destination.value = null;
  }

  @override
  void dispose() {}
}
