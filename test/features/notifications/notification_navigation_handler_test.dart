import 'package:cloud_kitchen_mvp/features/notifications/application/push_notification_service.dart';
import 'package:cloud_kitchen_mvp/features/notifications/domain/notification_models.dart';
import 'package:cloud_kitchen_mvp/features/notifications/presentation/notification_navigation_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final chatDestination = NotificationDestination.fromData({
    'type': 'chat_message',
    'order_id': '123e4567-e89b-42d3-a456-426614174000',
    'kitchen_name': 'Kitchen',
  });

  testWidgets('authorized role consumes and opens exact order chat intent', (
    tester,
  ) async {
    final service = FakeDestinationService(chatDestination);
    NotificationDestination? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationNavigationHandler(
          service: service,
          chatEnabled: true,
          onOpenChat: (destination) => opened = destination,
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pump();
    expect(opened?.orderId, chatDestination.orderId);
    expect(service.consumeCalls, 1);
  });

  testWidgets('rider context cannot consume customer-owner chat intent', (
    tester,
  ) async {
    final service = FakeDestinationService(chatDestination);
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationNavigationHandler(
          service: service,
          chatEnabled: false,
          onOpenChat: (_) => fail('Rider must not open order chat.'),
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pump();
    expect(service.consumeCalls, 0);
  });
}

class FakeDestinationService implements PushNotificationService {
  FakeDestinationService(NotificationDestination destination)
    : pending = ValueNotifier(destination);
  final ValueNotifier<NotificationDestination?> pending;
  final ValueNotifier<PushPermissionStatus> permission = ValueNotifier(
    PushPermissionStatus.authorized,
  );
  int consumeCalls = 0;
  @override
  bool get isConfigured => true;
  @override
  ValueListenable<NotificationDestination?> get pendingDestination => pending;
  @override
  ValueListenable<PushPermissionStatus> get permissionStatus => permission;
  @override
  void consumeDestination(NotificationDestination destination) {
    consumeCalls++;
    pending.value = null;
  }

  @override
  void dispose() {}
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> openSettings() async => true;
  @override
  Future<PushPermissionStatus> requestPermission() async => permission.value;
  @override
  Future<void> syncForCurrentSession() async {}
  @override
  Future<void> unregisterCurrentDevice() async {}
}
