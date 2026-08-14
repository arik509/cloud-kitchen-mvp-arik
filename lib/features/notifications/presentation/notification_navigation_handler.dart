import 'package:flutter/material.dart';

import '../application/push_notification_service.dart';
import '../domain/notification_models.dart';

class NotificationNavigationHandler extends StatefulWidget {
  const NotificationNavigationHandler({
    required this.service,
    required this.chatEnabled,
    required this.onOpenChat,
    this.onOpenOrder,
    required this.child,
    super.key,
  });

  final PushNotificationService service;
  final bool chatEnabled;
  final ValueChanged<NotificationDestination> onOpenChat;
  final ValueChanged<NotificationDestination>? onOpenOrder;
  final Widget child;

  @override
  State<NotificationNavigationHandler> createState() =>
      _NotificationNavigationHandlerState();
}

class _NotificationNavigationHandlerState
    extends State<NotificationNavigationHandler> {
  @override
  void initState() {
    super.initState();
    widget.service.pendingDestination.addListener(_handleDestination);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleDestination());
  }

  @override
  void didUpdateWidget(covariant NotificationNavigationHandler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      oldWidget.service.pendingDestination.removeListener(_handleDestination);
      widget.service.pendingDestination.addListener(_handleDestination);
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleDestination());
    }
  }

  @override
  void dispose() {
    widget.service.pendingDestination.removeListener(_handleDestination);
    super.dispose();
  }

  void _handleDestination() {
    if (!mounted) return;
    final destination = widget.service.pendingDestination.value;
    if (destination == null) return;
    if (destination.type == NotificationEventType.chatMessage &&
        !widget.chatEnabled) {
      return;
    }
    widget.service.consumeDestination(destination);
    if (destination.type == NotificationEventType.chatMessage &&
        widget.chatEnabled) {
      widget.onOpenChat(destination);
    } else {
      widget.onOpenOrder?.call(destination);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
