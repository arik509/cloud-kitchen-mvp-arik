enum PushPermissionStatus {
  unavailable,
  notDetermined,
  denied,
  authorized,
  error,
}

enum NotificationEventType {
  chatMessage,
  orderAccepted,
  orderPreparing,
  orderReady,
  awaitingRider,
  riderAssigned,
  pickedUp,
  delivered,
}

NotificationEventType? parseNotificationEventType(Object? value) =>
    switch (value) {
      'chat_message' => NotificationEventType.chatMessage,
      'order_accepted' => NotificationEventType.orderAccepted,
      'order_preparing' => NotificationEventType.orderPreparing,
      'order_ready' => NotificationEventType.orderReady,
      'awaiting_rider' => NotificationEventType.awaitingRider,
      'rider_assigned' => NotificationEventType.riderAssigned,
      'picked_up' => NotificationEventType.pickedUp,
      'delivered' => NotificationEventType.delivered,
      _ => null,
    };

class NotificationDestination {
  const NotificationDestination({
    required this.type,
    required this.orderId,
    this.kitchenName,
  });
  final NotificationEventType type;
  final String orderId;
  final String? kitchenName;

  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  factory NotificationDestination.fromData(Map<String, dynamic> data) {
    final type = parseNotificationEventType(data['type']);
    final orderId = data['order_id'] as String?;
    if (type != NotificationEventType.chatMessage ||
        orderId == null ||
        !_uuid.hasMatch(orderId)) {
      throw const FormatException('Unsupported notification destination.');
    }
    final rawKitchenName = data['kitchen_name'] as String?;
    return NotificationDestination(
      type: type!,
      orderId: orderId,
      kitchenName: rawKitchenName?.trim().isEmpty ?? true
          ? null
          : rawKitchenName!.trim(),
    );
  }
}
