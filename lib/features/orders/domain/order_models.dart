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
    required this.status,
    required this.finalPrice,
    required this.deliveryAddress,
    required this.createdAt,
  });

  final String id;
  final String kitchenId;
  final OrderStatus status;
  final double finalPrice;
  final String deliveryAddress;
  final DateTime createdAt;

  factory CustomerOrder.fromMap(Map<String, dynamic> map) => CustomerOrder(
    id: map['id'] as String,
    kitchenId: map['kitchen_id'] as String,
    status: parseOrderStatus(map['status']),
    finalPrice: (map['final_price'] as num).toDouble(),
    deliveryAddress: map['delivery_address'] as String,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}
