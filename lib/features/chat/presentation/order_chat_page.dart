import 'dart:async';

import 'package:flutter/material.dart';

import '../data/chat_repository.dart';
import '../domain/chat_models.dart';

class OrderChatPage extends StatefulWidget {
  const OrderChatPage({
    required this.repository,
    required this.orderId,
    required this.title,
    super.key,
  });
  final ChatRepository repository;
  final String orderId;
  final String title;

  @override
  State<OrderChatPage> createState() => _OrderChatPageState();
}

class _OrderChatPageState extends State<OrderChatPage> {
  final _controller = TextEditingController();
  OrderChat? _chat;
  Future<List<ChatMessage>>? _messages;
  Timer? _timer;
  bool _sending = false;
  String? _openError;
  String? _validation;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    setState(() => _openError = null);
    try {
      final chat = await widget.repository.open(widget.orderId);
      if (!mounted) return;
      _chat = chat;
      await _refresh();
      _timer ??= Timer.periodic(
        const Duration(seconds: 20),
        (_) => _refresh(silent: true),
      );
    } on ChatException catch (error) {
      if (mounted) setState(() => _openError = error.message);
    }
  }

  Future<void> _refresh({bool silent = false}) async {
    final chat = _chat;
    if (chat == null) return;
    final future = widget.repository.fetchMessages(chat.id);
    if (!silent && mounted) {
      setState(() {
        _messages = future;
      });
    }
    try {
      final messages = await future;
      if (silent && mounted) {
        setState(() {
          _messages = Future.value(messages);
        });
      }
    } catch (_) {
      if (!silent && mounted) {
        setState(() {
          _messages = future;
        });
      }
    }
  }

  Future<void> _send() async {
    if (_sending || _chat == null) return;
    final validation = validateChatMessage(_controller.text);
    if (validation != null) {
      setState(() => _validation = validation);
      return;
    }
    setState(() {
      _sending = true;
      _validation = null;
    });
    try {
      await widget.repository.send(_chat!.id, _controller.text);
      _controller.clear();
      await _refresh(silent: true);
    } on ChatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title),
          Text(
            'Order #${widget.orderId.substring(0, widget.orderId.length < 8 ? widget.orderId.length : 8)}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    ),
    body: _openError != null
        ? _OpenError(message: _openError!, retry: _open)
        : _chat == null || _messages == null
        ? const Center(
            key: Key('chat-loading'),
            child: CircularProgressIndicator(),
          )
        : Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: FutureBuilder<List<ChatMessage>>(
                    future: _messages,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return _MessagesError(retry: _refresh);
                      }
                      final messages = snapshot.data!;
                      if (messages.isEmpty) {
                        return ListView(
                          key: const Key('chat-empty'),
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 120),
                            Icon(Icons.chat_bubble_outline, size: 56),
                            Text(
                              'No messages yet',
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              'Start the order conversation.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        );
                      }
                      return ListView.builder(
                        key: const Key('chat-messages'),
                        padding: const EdgeInsets.all(12),
                        itemCount: messages.length,
                        itemBuilder: (_, index) {
                          final message = messages[index];
                          final mine =
                              message.senderId ==
                              widget.repository.currentUserId;
                          return Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(10),
                              constraints: const BoxConstraints(maxWidth: 320),
                              decoration: BoxDecoration(
                                color: mine
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer
                                    : Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(message.text),
                                  const SizedBox(height: 3),
                                  Text(
                                    _time(message.createdAt),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('chat-input'),
                          controller: _controller,
                          maxLength: 1000,
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Message',
                            errorText: _validation,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        key: const Key('chat-send'),
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
  );
}

class _OpenError extends StatelessWidget {
  const _OpenError({required this.message, required this.retry});
  final String message;
  final Future<void> Function() retry;
  @override
  Widget build(BuildContext context) => Center(
    key: const Key('chat-error'),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        TextButton.icon(
          onPressed: retry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    ),
  );
}

class _MessagesError extends StatelessWidget {
  const _MessagesError({required this.retry});
  final Future<void> Function({bool silent}) retry;
  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('chat-messages-error'),
    children: [
      const SizedBox(height: 100),
      const Text('Could not load messages.', textAlign: TextAlign.center),
      Center(
        child: TextButton(onPressed: retry, child: const Text('Retry')),
      ),
    ],
  );
}

String _time(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
