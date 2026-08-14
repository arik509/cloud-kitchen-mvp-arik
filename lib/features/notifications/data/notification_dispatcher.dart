import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class NotificationDispatcher {
  Future<void> dispatchChatMessage(String messageId);
}

abstract interface class OrderNotificationDispatcher {
  Future<void> dispatchOrderEvents(String orderId);
}

Future<void> dispatchOrderEventsBestEffort(
  OrderNotificationDispatcher? dispatcher,
  String orderId,
) async {
  try {
    await dispatcher?.dispatchOrderEvents(orderId);
  } catch (_) {
    // Notifications are downstream side effects, never the primary workflow.
  }
}

class SupabaseNotificationDispatcher
    implements NotificationDispatcher, OrderNotificationDispatcher {
  SupabaseNotificationDispatcher(this._client);
  final SupabaseClient _client;
  @override
  Future<void> dispatchChatMessage(String messageId) async {
    await _client.functions.invoke(
      'send-chat-notification',
      body: {'message_id': messageId},
    );
  }

  @override
  Future<void> dispatchOrderEvents(String orderId) async {
    await _client.functions.invoke(
      'send-chat-notification',
      body: {'order_id': orderId},
    );
  }
}
