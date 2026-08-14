enum WalletTransactionKind { demoCredit, orderDebit, orderRefund }

WalletTransactionKind parseWalletTransactionKind(Object? value) =>
    switch (value) {
      'demo_credit' => WalletTransactionKind.demoCredit,
      'order_debit' => WalletTransactionKind.orderDebit,
      'order_refund' => WalletTransactionKind.orderRefund,
      _ => throw FormatException('Unsupported wallet transaction kind: $value'),
    };

class WalletBalance {
  const WalletBalance(this.amount);

  final double amount;

  factory WalletBalance.fromMap(Map<String, dynamic> map) =>
      WalletBalance((map['wallet_balance'] as num).toDouble());
}

class AddDemoBalanceResult {
  const AddDemoBalanceResult({
    required this.transactionId,
    required this.creditedAmount,
    required this.balanceAfter,
    required this.kind,
    required this.createdAt,
  });

  final String transactionId;
  final double creditedAmount;
  final double balanceAfter;
  final WalletTransactionKind kind;
  final DateTime createdAt;

  factory AddDemoBalanceResult.fromRpc(Map<String, dynamic> map) =>
      AddDemoBalanceResult(
        transactionId: map['transaction_id'] as String,
        creditedAmount: (map['credited_amount'] as num).toDouble(),
        balanceAfter: (map['balance_after'] as num).toDouble(),
        kind: parseWalletTransactionKind(map['kind']),
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
