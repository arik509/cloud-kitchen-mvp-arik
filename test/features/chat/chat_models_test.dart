import 'package:cloud_kitchen_mvp/features/chat/data/chat_repository.dart';
import 'package:cloud_kitchen_mvp/features/chat/domain/chat_models.dart';
import 'package:cloud_kitchen_mvp/features/notifications/data/notification_dispatcher.dart';
import 'package:cloud_kitchen_mvp/features/orders/domain/order_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('validates and trims reasonable chat messages', () {
    expect(validateChatMessage('   '), 'Enter a message.');
    expect(validateChatMessage('x' * 1001), contains('1000'));
    expect(validateChatMessage(' hello '), isNull);
  });

  test('maps safe message fields', () {
    final message = ChatMessage.fromMap({
      'message_id': 'message-1',
      'chat_id': 'chat-1',
      'sender_id': 'user-1',
      'message_text': 'Hello',
      'created_at': '2026-08-13T12:00:00Z',
    });
    expect(message.text, 'Hello');
    expect(message.senderId, 'user-1');
  });

  test('limits chat to the current active order lifecycle', () {
    expect(isOrderChatAvailable(OrderStatus.pending), isTrue);
    expect(isOrderChatAvailable(OrderStatus.accepted), isTrue);
    expect(isOrderChatAvailable(OrderStatus.preparing), isTrue);
    expect(isOrderChatAvailable(OrderStatus.ready), isTrue);
    expect(isOrderChatAvailable(OrderStatus.rejected), isFalse);
    expect(isOrderChatAvailable(OrderStatus.awaitingRider), isFalse);
    expect(isOrderChatAvailable(OrderStatus.delivered), isFalse);
  });

  test('push dispatch failure preserves the stored chat message', () async {
    final message = ChatMessage(
      id: 'message-1',
      chatId: 'chat-1',
      senderId: 'sender-1',
      text: 'Stored first',
      createdAt: DateTime.utc(2026, 8, 14),
    );
    final result = await dispatchStoredChatMessage(
      message,
      FailingNotificationDispatcher(),
    );
    expect(result, same(message));
  });
}

class FailingNotificationDispatcher implements NotificationDispatcher {
  @override
  Future<void> dispatchChatMessage(String messageId) =>
      Future.error(StateError('FCM unavailable'));
}
