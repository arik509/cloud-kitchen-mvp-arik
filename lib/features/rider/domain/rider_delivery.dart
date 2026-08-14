import '../../orders/domain/order_models.dart';
import '../../payments/domain/payment_models.dart';

class RiderDelivery {
  const RiderDelivery({
    required this.id,
    required this.kitchenId,
    required this.kitchenName,
    required this.kitchenAddress,
    required this.deliveryAddress,
    required this.status,
    required this.finalPrice,
    required this.riderFee,
    required this.itemName,
    required this.quantity,
    required this.createdAt,
    this.kitchenLatitude,
    this.kitchenLongitude,
    this.payment = const OrderPayment(
      method: PaymentMethod.demoWallet,
      status: PaymentStatus.verified,
    ),
  });

  final String id;
  final String kitchenId;
  final String kitchenName;
  final String kitchenAddress;
  final double? kitchenLatitude;
  final double? kitchenLongitude;
  final String deliveryAddress;
  final OrderStatus status;
  final double finalPrice;
  final double riderFee;
  final String itemName;
  final int quantity;
  final DateTime createdAt;
  final OrderPayment payment;

  factory RiderDelivery.fromMap(Map<String, dynamic> map) => RiderDelivery(
    id: map['order_id'] as String,
    kitchenId: map['kitchen_id'] as String,
    kitchenName: map['kitchen_name'] as String,
    kitchenAddress: map['kitchen_address'] as String,
    kitchenLatitude: (map['kitchen_latitude'] as num?)?.toDouble(),
    kitchenLongitude: (map['kitchen_longitude'] as num?)?.toDouble(),
    deliveryAddress: map['delivery_address'] as String,
    status: parseOrderStatus(map['status']),
    finalPrice: (map['final_price'] as num).toDouble(),
    riderFee: (map['rider_fee'] as num).toDouble(),
    itemName: map['item_name'] as String,
    quantity: map['quantity'] as int,
    createdAt: DateTime.parse(map['created_at'] as String),
    payment: OrderPayment.fromMap(map),
  );
}

class RiderDeliveryUpdate {
  const RiderDeliveryUpdate({
    required this.orderId,
    required this.status,
    required this.riderId,
  });

  final String orderId;
  final OrderStatus status;
  final String riderId;

  factory RiderDeliveryUpdate.fromMap(Map<String, dynamic> map) =>
      RiderDeliveryUpdate(
        orderId: map['order_id'] as String,
        status: parseOrderStatus(map['status']),
        riderId: map['rider_id'] as String,
      );
}

OrderStatus? nextRiderStatus(OrderStatus current) => switch (current) {
  OrderStatus.riderAssigned => OrderStatus.pickedUp,
  OrderStatus.pickedUp => OrderStatus.delivered,
  _ => null,
};

class RiderEarnings {
  const RiderEarnings({required this.total, required this.deliveryCount});
  final double total;
  final int deliveryCount;

  factory RiderEarnings.fromDeliveries(List<RiderDelivery> deliveries) {
    final delivered = deliveries.where(
      (delivery) => delivery.status == OrderStatus.delivered,
    );
    return RiderEarnings(
      total: delivered.fold(0, (sum, delivery) => sum + delivery.riderFee),
      deliveryCount: delivered.length,
    );
  }
}
