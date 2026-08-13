import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class NotificationDispatcher {
  Future<void> dispatchChatMessage(String messageId);
}

class SupabaseNotificationDispatcher implements NotificationDispatcher {
  SupabaseNotificationDispatcher(this._client);
  final SupabaseClient _client;
  @override
  Future<void> dispatchChatMessage(String messageId) async {
    await _client.functions.invoke(
      'send-chat-notification',
      body: {'message_id': messageId},
    );
  }
}
