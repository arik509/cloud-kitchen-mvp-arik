import 'package:cloud_kitchen_mvp/features/finance/domain/settlement_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps exact server-authoritative 85/10/5 settlement examples', () {
    final thousand = OwnerSettlementEntry.fromMap({
      'order_id': 'order-1000',
      'gross_amount': '1000.00',
      'owner_net_amount': '850.00',
      'rider_earning': '100.00',
      'platform_fee': '50.00',
      'created_at': '2026-08-14T10:00:00Z',
    });
    final fiveHundred = OwnerSettlementEntry.fromMap({
      'order_id': 'order-500',
      'gross_amount': 500,
      'owner_net_amount': 425,
      'rider_earning': 50,
      'platform_fee': 25,
      'created_at': '2026-08-14T11:00:00Z',
    });

    expect(
      thousand.ownerNetAmount + thousand.riderEarning + thousand.platformFee,
      thousand.grossAmount,
    );
    expect(thousand.ownerNetAmount, 850);
    expect(thousand.riderEarning, 100);
    expect(thousand.platformFee, 50);
    expect(fiveHundred.ownerNetAmount, 425);
    expect(fiveHundred.riderEarning, 50);
    expect(fiveHundred.platformFee, 25);
  });

  test('quantity-based totals feed exact 85/10/5 settlement breakdown', () {
    const unitPrice = 250.0;
    const quantity = 4;
    final gross = unitPrice * quantity; // 1000.0
    final ownerNet = (gross * 0.85).roundToDouble();
    final riderEarning = (gross * 0.10).roundToDouble();
    final platformFee = gross - ownerNet - riderEarning;

    final entry = OwnerSettlementEntry.fromMap({
      'order_id': 'qty-order-1',
      'gross_amount': gross,
      'owner_net_amount': ownerNet,
      'rider_earning': riderEarning,
      'platform_fee': platformFee,
      'created_at': '2026-08-14T12:00:00Z',
    });

    expect(entry.grossAmount, 1000.0);
    expect(entry.ownerNetAmount, 850.0);
    expect(entry.riderEarning, 100.0);
    expect(entry.platformFee, 50.0);
  });

  test('summaries derive balances only from immutable settlement rows', () {
    final rider = RiderEarningsSummary(
      entries: [
        RiderEarningEntry(
          orderId: 'one',
          grossAmount: 1000,
          riderEarning: 100,
          createdAt: DateTime.utc(2026, 8, 14),
        ),
        RiderEarningEntry(
          orderId: 'two',
          grossAmount: 500,
          riderEarning: 50,
          createdAt: DateTime.utc(2026, 8, 14),
        ),
      ],
    );

    expect(rider.availableBalance, 150);
    expect(rider.totalEarnings, 150);
    expect(rider.completedDeliveries, 2);
  });
}
