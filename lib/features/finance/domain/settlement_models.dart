double _money(Object? value, String field) {
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw FormatException('Invalid settlement field: $field');
}

class RiderEarningEntry {
  const RiderEarningEntry({
    required this.orderId,
    required this.grossAmount,
    required this.riderEarning,
    required this.createdAt,
  });

  final String orderId;
  final double grossAmount;
  final double riderEarning;
  final DateTime createdAt;

  factory RiderEarningEntry.fromMap(Map<String, dynamic> map) =>
      RiderEarningEntry(
        orderId: map['order_id'] as String,
        grossAmount: _money(map['gross_amount'], 'gross_amount'),
        riderEarning: _money(map['rider_earning'], 'rider_earning'),
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class RiderEarningsSummary {
  const RiderEarningsSummary({required this.entries});

  final List<RiderEarningEntry> entries;

  double get availableBalance =>
      entries.fold(0, (total, entry) => total + entry.riderEarning);
  double get totalEarnings => availableBalance;
  int get completedDeliveries => entries.length;
}

class OwnerSettlementEntry {
  const OwnerSettlementEntry({
    required this.orderId,
    required this.grossAmount,
    required this.ownerNetAmount,
    required this.riderEarning,
    required this.platformFee,
    required this.createdAt,
  });

  final String orderId;
  final double grossAmount;
  final double ownerNetAmount;
  final double riderEarning;
  final double platformFee;
  final DateTime createdAt;

  factory OwnerSettlementEntry.fromMap(Map<String, dynamic> map) =>
      OwnerSettlementEntry(
        orderId: map['order_id'] as String,
        grossAmount: _money(map['gross_amount'], 'gross_amount'),
        ownerNetAmount: _money(map['owner_net_amount'], 'owner_net_amount'),
        riderEarning: _money(map['rider_earning'], 'rider_earning'),
        platformFee: _money(map['platform_fee'], 'platform_fee'),
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class OwnerRevenueSummary {
  const OwnerRevenueSummary({required this.entries});

  final List<OwnerSettlementEntry> entries;

  double get grossSales =>
      entries.fold(0, (total, entry) => total + entry.grossAmount);
  double get ownerNetEarnings =>
      entries.fold(0, (total, entry) => total + entry.ownerNetAmount);
  double get riderShare =>
      entries.fold(0, (total, entry) => total + entry.riderEarning);
  double get platformFees =>
      entries.fold(0, (total, entry) => total + entry.platformFee);
}
