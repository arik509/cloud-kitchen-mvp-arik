import 'dart:async';

import 'package:cloud_kitchen_mvp/features/chat/data/chat_repository.dart';
import 'package:cloud_kitchen_mvp/features/chat/domain/chat_models.dart';
import 'package:cloud_kitchen_mvp/features/chat/presentation/order_chat_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows loading then empty conversation', (tester) async {
    final open = Completer<OrderChat>();
    final repository = FakeChatRepository(openResponse: open.future);
    await tester.pumpWidget(_app(repository));
    expect(find.byKey(const Key('chat-loading')), findsOneWidget);
    open.complete(const OrderChat(id: 'chat-1', orderId: 'order-1'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-empty')), findsOneWidget);
  });

  testWidgets('distinguishes senders and renders text literally', (
    tester,
  ) async {
    final repository = FakeChatRepository(
      messages: [
        ChatMessage(
          id: '1',
          chatId: 'chat-1',
          senderId: 'me',
          text: '<b>not html</b>',
          createdAt: DateTime.utc(2026, 8, 13, 12),
        ),
        ChatMessage(
          id: '2',
          chatId: 'chat-1',
          senderId: 'them',
          text: 'Hello',
          createdAt: DateTime.utc(2026, 8, 13, 12, 1),
        ),
      ],
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    expect(find.text('<b>not html</b>'), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('validates input and blocks duplicate sends', (tester) async {
    final send = Completer<ChatMessage>();
    final repository = FakeChatRepository(sendResponse: send.future);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pump();
    expect(find.text('Enter a message.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('chat-input')), '  Hi  ');
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pump();
    expect(repository.sendCalls, 1);
    expect(repository.lastText, '  Hi  ');
    expect(find.byKey(const Key('chat-send')), findsOneWidget);
    send.complete(
      ChatMessage(
        id: '3',
        chatId: 'chat-1',
        senderId: 'me',
        text: 'Hi',
        createdAt: DateTime.now(),
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('shows access error and retry', (tester) async {
    final repository = FakeChatRepository(
      openResponse: Future.delayed(
        Duration.zero,
        () => throw const ChatException('Unavailable.'),
      ),
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-error')), findsOneWidget);
  });
}

Widget _app(ChatRepository repository) => MaterialApp(
  home: OrderChatPage(
    repository: repository,
    orderId: 'order-1',
    title: 'Kitchen',
  ),
);

class FakeChatRepository implements ChatRepository {
  FakeChatRepository({
    Future<OrderChat>? openResponse,
    this.messages = const [],
    this.sendResponse,
  }) : openResponse =
           openResponse ??
           Future.value(const OrderChat(id: 'chat-1', orderId: 'order-1'));
  final Future<OrderChat> openResponse;
  final List<ChatMessage> messages;
  final Future<ChatMessage>? sendResponse;
  int sendCalls = 0;
  String? lastText;
  @override
  String get currentUserId => 'me';
  @override
  Future<OrderChat> open(String orderId) => openResponse;
  @override
  Future<List<ChatMessage>> fetchMessages(String chatId) async => messages;
  @override
  Future<ChatMessage> send(String chatId, String text) {
    sendCalls++;
    lastText = text;
    return sendResponse!;
  }
}
