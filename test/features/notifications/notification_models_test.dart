import 'package:cloud_kitchen_mvp/features/notifications/domain/notification_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts only a validated order-chat destination', () {
    final destination = NotificationDestination.fromData({
      'type': 'chat_message',
      'order_id': '123e4567-e89b-42d3-a456-426614174000',
      'kitchen_name': 'Nearby Kitchen',
    });
    expect(destination.type, NotificationEventType.chatMessage);
    expect(destination.orderId, '123e4567-e89b-42d3-a456-426614174000');
    expect(destination.kitchenName, 'Nearby Kitchen');
  });

  test('rejects arbitrary routes and malformed order identifiers', () {
    expect(
      () => NotificationDestination.fromData({
        'type': 'admin_page',
        'order_id': '123e4567-e89b-42d3-a456-426614174000',
      }),
      throwsFormatException,
    );
    expect(
      () => NotificationDestination.fromData({
        'type': 'chat_message',
        'order_id': '../another-user',
      }),
      throwsFormatException,
    );
  });

  test('future notification event names have typed mappings', () {
    expect(
      parseNotificationEventType('order_ready'),
      NotificationEventType.orderReady,
    );
    expect(
      parseNotificationEventType('rider_assigned'),
      NotificationEventType.riderAssigned,
    );
    expect(
      parseNotificationEventType('delivered'),
      NotificationEventType.delivered,
    );
    expect(
      parseNotificationEventType('bkash_verified'),
      NotificationEventType.bkashVerified,
    );
    expect(
      parseNotificationEventType('refund_pending'),
      NotificationEventType.refundPending,
    );
  });
}
