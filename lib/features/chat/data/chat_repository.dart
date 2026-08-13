import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/rpc_response.dart';
import '../domain/chat_models.dart';

abstract interface class ChatRepository {
  String get currentUserId;
  Future<OrderChat> open(String orderId);
  Future<List<ChatMessage>> fetchMessages(String chatId);
  Future<ChatMessage> send(String chatId, String text);
}

class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository(this._client);
  final SupabaseClient _client;

  @override
  String get currentUserId => _client.auth.currentUser?.id ?? '';

  void _requireUser() {
    if (currentUserId.isEmpty) throw const ChatException('Sign in again.');
  }

  @override
  Future<OrderChat> open(String orderId) async {
    _requireUser();
    try {
      return OrderChat.fromMap(
        singleRpcRow(
          await _client.rpc('open_order_chat', params: {'p_order_id': orderId}),
        ),
      );
    } on PostgrestException catch (error) {
      throw ChatException.fromBackend(error.message);
    }
  }

  @override
  Future<List<ChatMessage>> fetchMessages(String chatId) async {
    _requireUser();
    try {
      final rows = await _client
          .from('messages')
          .select('id,chat_id,sender_id,text,created_at')
          .eq('chat_id', chatId)
          .order('created_at');
      return rows.map((row) => ChatMessage.fromMap(row)).toList();
    } on PostgrestException catch (error) {
      throw ChatException.fromBackend(error.message);
    }
  }

  @override
  Future<ChatMessage> send(String chatId, String text) async {
    _requireUser();
    final validation = validateChatMessage(text);
    if (validation != null) throw ChatException(validation);
    try {
      return ChatMessage.fromMap(
        singleRpcRow(
          await _client.rpc(
            'send_order_chat_message',
            params: {'p_chat_id': chatId, 'p_text': text.trim()},
          ),
        ),
      );
    } on PostgrestException catch (error) {
      throw ChatException.fromBackend(error.message);
    }
  }
}

class ChatException implements Exception {
  const ChatException(this.message);
  factory ChatException.fromBackend(String message) => ChatException(
    message.toLowerCase().contains('chat_access_denied')
        ? 'This chat is unavailable for this order.'
        : message.toLowerCase().contains('invalid_chat_message')
        ? 'Enter a message between 1 and 1000 characters.'
        : 'Chat is unavailable. Check your connection and retry.',
  );
  final String message;
  @override
  String toString() => message;
}
