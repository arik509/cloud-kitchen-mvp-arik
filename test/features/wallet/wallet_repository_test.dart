import 'package:cloud_kitchen_mvp/features/wallet/data/wallet_repository.dart';
import 'package:cloud_kitchen_mvp/features/wallet/domain/wallet_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'parses current balance and demo-credit RPC using a fake source',
    () async {
      final source = FakeWalletRemoteDataSource(
        balance: {'wallet_balance': 1250},
        demoResponse: [
          {
            'transaction_id': 'transaction-1',
            'credited_amount': 500,
            'balance_after': 1750,
            'kind': 'demo_credit',
            'created_at': '2026-07-28T12:00:00Z',
          },
        ],
      );
      final repository = SupabaseWalletRepository.withDataSource(source);

      final balance = await repository.fetchCurrentBalance();
      final result = await repository.addDemoBalance();

      expect(balance.amount, 1250);
      expect(result.transactionId, 'transaction-1');
      expect(result.creditedAmount, 500);
      expect(result.balanceAfter, 1750);
      expect(result.kind, WalletTransactionKind.demoCredit);
      expect(source.demoCalls, 1);
    },
  );

  test('maps wallet backend failures to safe typed errors', () {
    expect(
      WalletRepositoryException.fromBackend(
        message: 'demo_credit_cooldown',
      ).code,
      WalletFailureCode.cooldown,
    );
    expect(
      WalletRepositoryException.fromBackend(
        message: 'demo_wallet_cap_reached',
      ).code,
      WalletFailureCode.capReached,
    );
    expect(
      WalletRepositoryException.fromBackend(
        message: 'internal relation details',
      ).message,
      isNot(contains('relation')),
    );
  });

  test('rejects malformed wallet RPC responses', () async {
    final repository = SupabaseWalletRepository.withDataSource(
      FakeWalletRemoteDataSource(balance: const {}, demoResponse: const []),
    );

    await expectLater(
      repository.addDemoBalance(),
      throwsA(
        isA<WalletRepositoryException>().having(
          (error) => error.code,
          'code',
          WalletFailureCode.invalidResponse,
        ),
      ),
    );
  });
}

class FakeWalletRemoteDataSource implements WalletRemoteDataSource {
  FakeWalletRemoteDataSource({
    required this.balance,
    required this.demoResponse,
  });

  final Map<String, dynamic> balance;
  final Object? demoResponse;
  int demoCalls = 0;

  @override
  Future<Object?> addDemoBalance() async {
    demoCalls++;
    return demoResponse;
  }

  @override
  Future<Map<String, dynamic>> fetchCurrentBalance() async => balance;
}
