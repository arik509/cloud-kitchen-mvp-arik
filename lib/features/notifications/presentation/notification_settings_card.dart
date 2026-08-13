import 'package:flutter/material.dart';
import '../application/push_notification_service.dart';
import '../domain/notification_models.dart';

class NotificationSettingsCard extends StatefulWidget {
  const NotificationSettingsCard({required this.service, super.key});
  final PushNotificationService service;
  @override
  State<NotificationSettingsCard> createState() =>
      _NotificationSettingsCardState();
}

class _NotificationSettingsCardState extends State<NotificationSettingsCard> {
  bool _busy = false;
  Future<void> _request() async {
    setState(() => _busy = true);
    await widget.service.requestPermission();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: widget.service.permissionStatus,
    builder: (context, status, _) {
      final (icon, title, message) = switch (status) {
        PushPermissionStatus.authorized => (
          Icons.notifications_active_outlined,
          'Notifications enabled',
          'Order chat notifications are enabled for this device.',
        ),
        PushPermissionStatus.denied => (
          Icons.notifications_off_outlined,
          'Notifications are off',
          'The app still works. Enable notifications to receive new chat messages.',
        ),
        PushPermissionStatus.unavailable => (
          Icons.notifications_paused_outlined,
          'Notifications not configured',
          'Push messaging is not configured in this build. All app features remain available.',
        ),
        PushPermissionStatus.error => (
          Icons.cloud_off_outlined,
          'Notifications unavailable',
          'Notification setup could not be checked. Retry when you are online.',
        ),
        PushPermissionStatus.notDetermined => (
          Icons.notifications_none,
          'Chat notifications',
          'Enable notifications to know when an order participant replies.',
        ),
      };
      return Card(
        key: const Key('notification-settings-card'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(message),
              if (status == PushPermissionStatus.notDetermined ||
                  status == PushPermissionStatus.error) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  key: const Key('enable-notifications'),
                  onPressed: _busy ? null : _request,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: Text(_busy ? 'Checking...' : 'Enable notifications'),
                ),
              ],
              if (status == PushPermissionStatus.denied) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      key: const Key('retry-notification-permission'),
                      onPressed: _busy ? null : _request,
                      child: const Text('Retry'),
                    ),
                    TextButton(
                      key: const Key('open-notification-settings'),
                      onPressed: widget.service.openSettings,
                      child: const Text('Open settings'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
