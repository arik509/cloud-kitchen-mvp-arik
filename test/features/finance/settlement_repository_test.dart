import 'package:cloud_kitchen_mvp/features/finance/data/settlement_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps role-scoped rider and owner RPC rows', () async {
    final repository = SupabaseSettlementRepository.withDataSource(
      FakeSettlementSource(),
    );

    final rider = await repository.fetchRiderEarnings();
    final owner = await repository.fetchOwnerRevenue();

    expect(rider.availableBalance, 100);
    expect(rider.entries.single.orderId, 'order-1');
    expect(owner.grossSales, 1000);
    expect(owner.ownerNetEarnings, 850);
    expect(owner.riderShare, 100);
    expect(owner.platformFees, 50);
  });

  test('rejects malformed financial responses safely', () async {
    final repository = SupabaseSettlementRepository.withDataSource(
      BadSettlementSource(),
    );

    expect(repository.fetchRiderEarnings, throwsA(isA<SettlementException>()));
    expect(repository.fetchOwnerRevenue, throwsA(isA<SettlementException>()));
  });
}

class FakeSettlementSource implements SettlementRemoteDataSource {
  @override
  Future<Object?> riderEarnings() async => [
    {
      'order_id': 'order-1',
      'gross_amount': '1000.00',
      'rider_earning': '100.00',
      'created_at': '2026-08-14T10:00:00Z',
    },
  ];

  @override
  Future<Object?> ownerRevenue() async => [
    {
      'order_id': 'order-1',
      'gross_amount': '1000.00',
      'owner_net_amount': '850.00',
      'rider_earning': '100.00',
      'platform_fee': '50.00',
      'created_at': '2026-08-14T10:00:00Z',
    },
  ];
}

class BadSettlementSource implements SettlementRemoteDataSource {
  @override
  Future<Object?> riderEarnings() async => {'not': 'a list'};

  @override
  Future<Object?> ownerRevenue() async => [
    {'missing': 'money fields'},
  ];
}
