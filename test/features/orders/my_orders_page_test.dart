import 'dart:async';

import 'package:cloud_kitchen_mvp/features/chat/data/chat_repository.dart';
import 'package:cloud_kitchen_mvp/features/chat/domain/chat_models.dart';
import 'package:cloud_kitchen_mvp/features/chat/presentation/order_chat_page.dart';
import 'package:cloud_kitchen_mvp/features/orders/data/order_repository.dart';
import 'package:cloud_kitchen_mvp/features/orders/domain/order_models.dart';
import 'package:cloud_kitchen_mvp/features/orders/presentation/my_orders_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows loading then empty orders state', (tester) async {
    final pending = Completer<List<CustomerOrder>>();
    await tester.pumpWidget(_app(FakeOrderRepository([pending.future])));
    expect(find.byKey(const Key('orders-loading')), findsOneWidget);
    pending.complete(const []);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('orders-empty')), findsOneWidget);
  });

  testWidgets('shows error and retries My Orders', (tester) async {
    final repository = FakeOrderRepository([
      Future.delayed(
        Duration.zero,
        () => throw const OrderRepositoryException(
          OrderFailureCode.unavailable,
          'Network failure.',
        ),
      ),
      Future.value(const []),
    ]);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('orders-error')), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repository.fetchCalls, 2);
    expect(find.byKey(const Key('orders-empty')), findsOneWidget);
  });

  testWidgets('shows kitchen, item, price, status, address, and time', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        FakeOrderRepository([
          Future.value([
            CustomerOrder(
              id: 'order-1',
              kitchenId: 'kitchen-1',
              kitchenName: 'Nearby Kitchen',
              itemName: 'Rice Bowl',
              itemPrice: 150,
              quantity: 1,
              status: OrderStatus.pending,
              finalPrice: 150,
              deliveryAddress: 'Delivery Road',
              createdAt: DateTime.utc(2026, 8, 13, 5, 30),
            ),
          ]),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nearby Kitchen'), findsOneWidget);
    expect(find.text('Rice Bowl × 1'), findsOneWidget);
    expect(find.textContaining('৳150.00'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Delivery Road'), findsOneWidget);
    expect(find.textContaining('2026-08-13'), findsOneWidget);
  });

  testWidgets('explains the rejected-order refund', (tester) async {
    await tester.pumpWidget(
      _app(
        FakeOrderRepository([
          Future.value([
            CustomerOrder(
              id: 'order-1',
              kitchenId: 'kitchen-1',
              kitchenName: 'Nearby Kitchen',
              itemName: 'Rice Bowl',
              itemPrice: 150,
              quantity: 1,
              status: OrderStatus.rejected,
              finalPrice: 150,
              deliveryAddress: 'Delivery Road',
              createdAt: DateTime.utc(2026, 8, 13),
            ),
          ]),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rejected'), findsOneWidget);
    expect(find.byKey(const Key('order-refund-message')), findsOneWidget);
    expect(find.textContaining('returned to your wallet'), findsOneWidget);
    expect(find.text('Chat with Kitchen'), findsNothing);
  });

  testWidgets('eligible customer order opens its shared chat and can reply', (
    tester,
  ) async {
    final chatRepository = FakeChatRepository(
      messages: [
        ChatMessage(
          id: 'message-1',
          chatId: 'chat-for-order-1',
          senderId: 'owner-1',
          text: 'Your order is being prepared.',
          createdAt: DateTime.utc(2026, 8, 13, 12),
        ),
      ],
    );
    await tester.pumpWidget(
      _app(
        FakeOrderRepository([
          Future.value([_customerOrder(status: OrderStatus.preparing)]),
        ]),
        chatRepository: chatRepository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chat with Kitchen'), findsOneWidget);
    await tester.tap(find.byKey(const Key('customer-chat-order-1')));
    await tester.pumpAndSettle();

    expect(find.byType(OrderChatPage), findsOneWidget);
    expect(chatRepository.openedOrderId, 'order-1');
    expect(find.text('Nearby Kitchen'), findsOneWidget);
    expect(find.text('Order #order-1'), findsOneWidget);
    expect(find.text('Your order is being prepared.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('chat-input')),
      'Thanks, I will be ready.',
    );
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();

    expect(chatRepository.sendCalls, 1);
    expect(chatRepository.sentChatId, 'chat-for-order-1');
    expect(chatRepository.sentText, 'Thanks, I will be ready.');
  });

  testWidgets('completed customer order does not expose chat', (tester) async {
    await tester.pumpWidget(
      _app(
        FakeOrderRepository([
          Future.value([_customerOrder(status: OrderStatus.delivered)]),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chat with Kitchen'), findsNothing);
    expect(find.byKey(const Key('customer-chat-order-1')), findsNothing);
  });

  testWidgets('customer sees delivery progress without rider identity', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        FakeOrderRepository([
          Future.value([_customerOrder(status: OrderStatus.pickedUp)]),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Picked up'), findsOneWidget);
    expect(find.textContaining('rider-'), findsNothing);
    expect(find.text('Chat with Kitchen'), findsNothing);
  });
}

CustomerOrder _customerOrder({required OrderStatus status}) => CustomerOrder(
  id: 'order-1',
  kitchenId: 'kitchen-1',
  kitchenName: 'Nearby Kitchen',
  itemName: 'Rice Bowl',
  itemPrice: 150,
  quantity: 1,
  status: status,
  finalPrice: 150,
  deliveryAddress: 'Delivery Road',
  createdAt: DateTime.utc(2026, 8, 13),
);

Widget _app(OrderRepository repository, {ChatRepository? chatRepository}) =>
    MaterialApp(
      home: Scaffold(
        body: MyOrdersPage(
          repository: repository,
          chatRepository: chatRepository ?? FakeChatRepository(),
        ),
      ),
    );

class FakeOrderRepository implements OrderRepository {
  FakeOrderRepository(this.responses);

  final List<Future<List<CustomerOrder>>> responses;
  int fetchCalls = 0;

  @override
  Future<List<CustomerOrder>> fetchCurrentCustomerOrders() {
    final index = fetchCalls++;
    return responses[index < responses.length ? index : responses.length - 1];
  }

  @override
  Future<PlaceOrderResult> placeOrder(PlaceOrderRequest request) =>
      throw UnimplementedError();
}

class FakeChatRepository implements ChatRepository {
  FakeChatRepository({this.messages = const []});

  final List<ChatMessage> messages;
  String? openedOrderId;
  String? sentChatId;
  String? sentText;
  int sendCalls = 0;

  @override
  String get currentUserId => 'customer-1';

  @override
  Future<OrderChat> open(String orderId) async {
    openedOrderId = orderId;
    return OrderChat(id: 'chat-for-$orderId', orderId: orderId);
  }

  @override
  Future<List<ChatMessage>> fetchMessages(String chatId) async => messages;

  @override
  Future<ChatMessage> send(String chatId, String text) async {
    sendCalls++;
    sentChatId = chatId;
    sentText = text;
    return ChatMessage(
      id: 'customer-reply',
      chatId: chatId,
      senderId: currentUserId,
      text: text.trim(),
      createdAt: DateTime.utc(2026, 8, 13, 12, 1),
    );
  }
}
