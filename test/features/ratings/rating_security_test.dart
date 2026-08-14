import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rating migration enforces delivered own-order one-time ratings', () {
    final sql = File(
      'supabase/migrations/20260814050000_payment_ratings_and_navigation.sql',
    ).readAsStringSync();
    expect(sql, contains("o.customer_id=v_customer"));
    expect(sql, contains("v_status<>'delivered'"));
    expect(sql, contains('ratings_one_kitchen_rating_per_order'));
    expect(sql, contains('revoke all on table public.ratings'));
  });

  test('payment RPCs derive identities and lock state', () {
    final sql = File(
      'supabase/migrations/20260814050000_payment_ratings_and_navigation.sql',
    ).readAsStringSync();
    expect(sql, contains('v_customer_id uuid := auth.uid()'));
    expect(sql, contains('v_owner uuid:=auth.uid()'));
    expect(sql, contains('v_rider uuid:=auth.uid()'));
    expect(sql, contains('for update of op'));
    expect(sql, contains('order_payments_bkash_transaction_key'));
    expect(sql, contains("v_payment<>'collected'"));
  });
}
