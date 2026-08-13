class OrderChat {
  const OrderChat({required this.id, required this.orderId});
  final String id;
  final String orderId;

  factory OrderChat.fromMap(Map<String, dynamic> map) => OrderChat(
    id: map['chat_id'] as String,
    orderId: map['order_id'] as String,
  );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });
  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final DateTime createdAt;

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
    id: (map['id'] ?? map['message_id']) as String,
    chatId: map['chat_id'] as String,
    senderId: map['sender_id'] as String,
    text: (map['text'] ?? map['message_text']) as String,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}

String? validateChatMessage(String value) {
  final text = value.trim();
  if (text.isEmpty) return 'Enter a message.';
  if (text.length > 1000) return 'Messages can be at most 1000 characters.';
  return null;
}
