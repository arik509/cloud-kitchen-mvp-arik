import 'package:cloud_kitchen_mvp/features/finance/data/settlement_repository.dart';
import 'package:cloud_kitchen_mvp/features/finance/domain/settlement_models.dart';
import 'package:cloud_kitchen_mvp/features/rider/presentation/rider_earnings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders authoritative balance and earnings history', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiderEarningsPage(repository: FakeSettlementRepository()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rider-available-balance')), findsOneWidget);
    expect(find.text('৳100.00'), findsWidgets);
    expect(find.text('Total Deliveries'), findsOneWidget);
    expect(find.text('Total Earnings'), findsOneWidget);
    expect(find.text('Order #ORDER-1'), findsOneWidget);
    expect(find.textContaining('+৳100.00'), findsOneWidget);
    expect(
      find.text('Payout settlement is handled separately.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class FakeSettlementRepository implements SettlementRepository {
  @override
  Future<RiderEarningsSummary> fetchRiderEarnings() async =>
      RiderEarningsSummary(
        entries: [
          RiderEarningEntry(
            orderId: 'order-1',
            grossAmount: 1000,
            riderEarning: 100,
            createdAt: DateTime.utc(2026, 8, 14, 10),
          ),
        ],
      );

  @override
  Future<OwnerRevenueSummary> fetchOwnerRevenue() => throw UnimplementedError();
}
