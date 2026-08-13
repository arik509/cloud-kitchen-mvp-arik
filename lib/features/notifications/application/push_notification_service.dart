import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/push_token_repository.dart';
import '../domain/notification_models.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<bool> initializeFirebaseForNotifications() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    return true;
  } catch (_) {
    return false;
  }
}

abstract interface class PushNotificationService {
  ValueListenable<PushPermissionStatus> get permissionStatus;
  ValueListenable<NotificationDestination?> get pendingDestination;
  bool get isConfigured;
  Future<void> initialize();
  Future<PushPermissionStatus> requestPermission();
  Future<void> syncForCurrentSession();
  Future<void> unregisterCurrentDevice();
  Future<bool> openSettings();
  void consumeDestination(NotificationDestination destination);
  void dispose();
}

class DisabledPushNotificationService implements PushNotificationService {
  DisabledPushNotificationService()
    : _permission = ValueNotifier(PushPermissionStatus.unavailable),
      _destination = ValueNotifier(null);
  final ValueNotifier<PushPermissionStatus> _permission;
  final ValueNotifier<NotificationDestination?> _destination;
  @override
  bool get isConfigured => false;
  @override
  ValueListenable<PushPermissionStatus> get permissionStatus => _permission;
  @override
  ValueListenable<NotificationDestination?> get pendingDestination =>
      _destination;
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> openSettings() async => false;
  @override
  Future<PushPermissionStatus> requestPermission() async =>
      PushPermissionStatus.unavailable;
  @override
  Future<void> syncForCurrentSession() async {}
  @override
  Future<void> unregisterCurrentDevice() async {}
  @override
  void consumeDestination(NotificationDestination destination) {}
  @override
  void dispose() {
    _permission.dispose();
    _destination.dispose();
  }
}

class FirebasePushNotificationService implements PushNotificationService {
  FirebasePushNotificationService({
    required PushTokenRepository tokenRepository,
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _tokens = tokenRepository,
       _messaging = messaging ?? FirebaseMessaging.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'cloud_kitchen_messages',
    'Order messages',
    description: 'Customer and kitchen order chat messages',
    importance: Importance.high,
  );
  final PushTokenRepository _tokens;
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final ValueNotifier<PushPermissionStatus> _permission = ValueNotifier(
    PushPermissionStatus.notDetermined,
  );
  final ValueNotifier<NotificationDestination?> _destination = ValueNotifier(
    null,
  );
  final Set<String> _shownEvents = <String>{};
  final List<StreamSubscription<Object?>> _subscriptions = [];
  String? _currentToken;

  @override
  bool get isConfigured => true;
  @override
  ValueListenable<PushPermissionStatus> get permissionStatus => _permission;
  @override
  ValueListenable<NotificationDestination?> get pendingDestination =>
      _destination;

  @override
  Future<void> initialize() async {
    try {
      await _localNotifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
        ),
        onDidReceiveNotificationResponse: (response) =>
            _handlePayload(response.payload),
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);
      _subscriptions.add(
        FirebaseMessaging.onMessage.listen(_showForegroundMessage),
      );
      _subscriptions.add(
        FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteMessage),
      );
      _subscriptions.add(
        _messaging.onTokenRefresh.listen((token) async {
          _currentToken = token;
          await _registerToken(token);
        }),
      );
      _permission.value = _mapPermission(
        (await _messaging.getNotificationSettings()).authorizationStatus,
      );
      final initial = await _messaging.getInitialMessage();
      if (initial != null) _handleRemoteMessage(initial);
      if (_permission.value == PushPermissionStatus.authorized) {
        await syncForCurrentSession();
      }
    } catch (_) {
      _permission.value = PushPermissionStatus.error;
    }
  }

  @override
  Future<PushPermissionStatus> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      _permission.value = _mapPermission(settings.authorizationStatus);
      if (_permission.value == PushPermissionStatus.authorized) {
        await syncForCurrentSession();
      }
    } catch (_) {
      _permission.value = PushPermissionStatus.error;
    }
    return _permission.value;
  }

  @override
  Future<void> syncForCurrentSession() async {
    if (_permission.value != PushPermissionStatus.authorized) return;
    final token = await _messaging.getToken();
    if (token == null || token.trim().isEmpty) return;
    _currentToken = token;
    await _registerToken(token);
  }

  Future<void> _registerToken(String token) async {
    try {
      await _tokens.register(token: token, platform: 'android');
    } catch (_) {
      // Best effort: the next login or token refresh retries registration.
    }
  }

  @override
  Future<void> unregisterCurrentDevice() async {
    try {
      final token = _currentToken ?? await _messaging.getToken();
      if (token != null && token.isNotEmpty) await _tokens.unregister(token);
    } catch (_) {
      // Logout must remain available during a temporary push-service failure.
    } finally {
      _currentToken = null;
      _destination.value = null;
      _shownEvents.clear();
      try {
        await _messaging.deleteToken();
      } catch (_) {
        // The Supabase association is already removed when available.
      }
    }
  }

  @override
  Future<bool> openSettings() async {
    try {
      return await _localNotifications.openAppNotificationSettings() ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _showForegroundMessage(RemoteMessage message) async {
    final eventId = message.data['event_id'];
    if (eventId != null && !_shownEvents.add(eventId)) return;
    final notification = message.notification;
    if (notification == null) return;
    final payload = jsonEncode(message.data);
    await _localNotifications.show(
      id: (eventId ?? message.messageId ?? payload).hashCode & 0x7fffffff,
      title: notification.title ?? 'Cloud Kitchen',
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'cloud_kitchen_messages',
          'Order messages',
          channelDescription: 'Customer and kitchen order chat messages',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: payload,
    );
  }

  void _handleRemoteMessage(RemoteMessage message) =>
      _setDestination(Map<String, dynamic>.from(message.data));
  void _handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      _setDestination(Map<String, dynamic>.from(jsonDecode(payload) as Map));
    } catch (_) {
      // Ignore malformed local-notification payloads.
    }
  }

  void _setDestination(Map<String, dynamic> data) {
    try {
      _destination.value = NotificationDestination.fromData(data);
    } on FormatException {
      // Unknown event types never become arbitrary app routes.
    }
  }

  @override
  void consumeDestination(NotificationDestination destination) {
    if (identical(_destination.value, destination)) _destination.value = null;
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _permission.dispose();
    _destination.dispose();
  }
}

PushPermissionStatus _mapPermission(AuthorizationStatus status) =>
    switch (status) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional => PushPermissionStatus.authorized,
      AuthorizationStatus.denied => PushPermissionStatus.denied,
      AuthorizationStatus.notDetermined => PushPermissionStatus.notDetermined,
    };
