enum OrderStatus {
  pending,
  accepted,
  rejected,
  preparing,
  ready,
  awaitingRider,
  riderAssigned,
  pickedUp,
  delivered,
}

OrderStatus parseOrderStatus(Object? value) => switch (value) {
  'pending' => OrderStatus.pending,
  'accepted' => OrderStatus.accepted,
  'rejected' => OrderStatus.rejected,
  'preparing' => OrderStatus.preparing,
  'ready' => OrderStatus.ready,
  'awaiting_rider' => OrderStatus.awaitingRider,
  'rider_assigned' => OrderStatus.riderAssigned,
  'picked_up' => OrderStatus.pickedUp,
  'delivered' => OrderStatus.delivered,
  _ => throw FormatException('Unsupported order status: $value'),
};

String orderStatusValue(OrderStatus status) => switch (status) {
  OrderStatus.pending => 'pending',
  OrderStatus.accepted => 'accepted',
  OrderStatus.rejected => 'rejected',
  OrderStatus.preparing => 'preparing',
  OrderStatus.ready => 'ready',
  OrderStatus.awaitingRider => 'awaiting_rider',
  OrderStatus.riderAssigned => 'rider_assigned',
  OrderStatus.pickedUp => 'picked_up',
  OrderStatus.delivered => 'delivered',
};

class PlaceOrderRequest {
  const PlaceOrderRequest({
    required this.menuItemId,
    required this.deliveryAddress,
  });

  final String menuItemId;
  final String deliveryAddress;

  Map<String, dynamic> toRpcParameters() => {
    'p_menu_item_id': menuItemId,
    'p_delivery_address': deliveryAddress.trim(),
  };
}

class PlaceOrderResult {
  const PlaceOrderResult({
    required this.orderId,
    required this.authoritativeTotal,
    required this.walletBalance,
  });

  final String orderId;
  final double authoritativeTotal;
  final double walletBalance;

  factory PlaceOrderResult.fromRpc(Map<String, dynamic> map) =>
      PlaceOrderResult(
        orderId: map['order_id'] as String,
        authoritativeTotal: (map['authoritative_total'] as num).toDouble(),
        walletBalance: (map['wallet_balance'] as num).toDouble(),
      );
}

class CustomerOrder {
  const CustomerOrder({
    required this.id,
    required this.kitchenId,
    required this.kitchenName,
    required this.itemName,
    required this.itemPrice,
    required this.status,
    required this.finalPrice,
    required this.deliveryAddress,
    required this.createdAt,
  });

  final String id;
  final String kitchenId;
  final String kitchenName;
  final String itemName;
  final double itemPrice;
  final OrderStatus status;
  final double finalPrice;
  final String deliveryAddress;
  final DateTime createdAt;

  factory CustomerOrder.fromMap(Map<String, dynamic> map) {
    final kitchen = _firstMap(map['kitchens']);
    final orderItem = _firstMap(map['order_items']);
    final menuItem = _firstMap(orderItem?['menu_items']);
    return CustomerOrder(
      id: map['id'] as String,
      kitchenId: map['kitchen_id'] as String,
      kitchenName: kitchen?['name'] as String? ?? 'Kitchen',
      itemName: menuItem?['name'] as String? ?? 'Menu item',
      itemPrice:
          (orderItem?['unit_price'] as num?)?.toDouble() ??
          (map['final_price'] as num).toDouble(),
      status: parseOrderStatus(map['status']),
      finalPrice: (map['final_price'] as num).toDouble(),
      deliveryAddress: map['delivery_address'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class KitchenOrder {
  const KitchenOrder({
    required this.id,
    required this.kitchenId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.status,
    required this.finalPrice,
    required this.deliveryAddress,
    required this.createdAt,
  });

  final String id;
  final String kitchenId;
  final String itemName;
  final int quantity;
  final double unitPrice;
  final OrderStatus status;
  final double finalPrice;
  final String deliveryAddress;
  final DateTime createdAt;

  double get itemTotal => quantity * unitPrice;

  factory KitchenOrder.fromMap(Map<String, dynamic> map) {
    final orderItem = _firstMap(map['order_items']);
    final menuItem = _firstMap(orderItem?['menu_items']);
    return KitchenOrder(
      id: map['id'] as String,
      kitchenId: map['kitchen_id'] as String,
      itemName: menuItem?['name'] as String? ?? 'Menu item',
      quantity: orderItem?['quantity'] as int? ?? 1,
      unitPrice:
          (orderItem?['unit_price'] as num?)?.toDouble() ??
          (map['final_price'] as num).toDouble(),
      status: parseOrderStatus(map['status']),
      finalPrice: (map['final_price'] as num).toDouble(),
      deliveryAddress: map['delivery_address'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  KitchenOrder copyWith({OrderStatus? status}) => KitchenOrder(
    id: id,
    kitchenId: kitchenId,
    itemName: itemName,
    quantity: quantity,
    unitPrice: unitPrice,
    status: status ?? this.status,
    finalPrice: finalPrice,
    deliveryAddress: deliveryAddress,
    createdAt: createdAt,
  );
}

class KitchenOrderStatusResult {
  const KitchenOrderStatusResult({
    required this.orderId,
    required this.status,
    this.refundedAmount,
    this.walletBalance,
  });

  final String orderId;
  final OrderStatus status;
  final double? refundedAmount;
  final double? walletBalance;

  factory KitchenOrderStatusResult.fromRpc(Map<String, dynamic> map) =>
      KitchenOrderStatusResult(
        orderId: map['order_id'] as String,
        status: parseOrderStatus(map['status']),
        refundedAmount: (map['refunded_amount'] as num?)?.toDouble(),
        walletBalance: (map['wallet_balance'] as num?)?.toDouble(),
      );
}

const kitchenOrderTransitions = <OrderStatus, Set<OrderStatus>>{
  OrderStatus.pending: {OrderStatus.accepted, OrderStatus.rejected},
  OrderStatus.accepted: {OrderStatus.preparing},
  OrderStatus.preparing: {OrderStatus.ready},
};

Set<OrderStatus> allowedKitchenOrderTransitions(OrderStatus current) =>
    kitchenOrderTransitions[current] ?? const {};

Map<String, dynamic>? _firstMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is List && value.isNotEmpty && value.first is Map) {
    return Map<String, dynamic>.from(value.first as Map);
  }
  return null;
}
