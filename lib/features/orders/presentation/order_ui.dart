import 'package:flutter/material.dart';

import '../domain/order_models.dart';

String orderStatusLabel(OrderStatus status) => switch (status) {
  OrderStatus.pending => 'Pending',
  OrderStatus.accepted => 'Accepted',
  OrderStatus.rejected => 'Rejected',
  OrderStatus.preparing => 'Preparing',
  OrderStatus.ready => 'Ready',
  OrderStatus.awaitingRider => 'Awaiting rider',
  OrderStatus.riderAssigned => 'Rider assigned',
  OrderStatus.pickedUp => 'Picked up',
  OrderStatus.delivered => 'Delivered',
};

Color orderStatusColor(BuildContext context, OrderStatus status) {
  final colors = Theme.of(context).colorScheme;
  return switch (status) {
    OrderStatus.pending => colors.tertiaryContainer,
    OrderStatus.accepted || OrderStatus.preparing => colors.primaryContainer,
    OrderStatus.ready => Colors.green.shade100,
    OrderStatus.rejected => colors.errorContainer,
    _ => colors.secondaryContainer,
  };
}

String orderCurrency(double amount) => '৳${amount.toStringAsFixed(2)}';

String orderTime(DateTime time) {
  final local = time.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
