import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String sql;

  setUpAll(() {
    sql = File(
      'supabase/migrations/20260814160000_order_settlement_accounting.sql',
    ).readAsStringSync().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  });

  test('settlement migration is incremental, immutable, and balanced', () {
    expect(
      sql,
      contains('create table if not exists public.order_settlements'),
    );
    expect(sql, contains('order_id uuid not null unique'));
    expect(sql, contains('numeric(12,2)'));
    expect(
      sql,
      contains(
        'gross_amount = owner_net_amount + rider_earning + platform_fee',
      ),
    );
    expect(sql, contains('protect_order_settlements_immutable'));
    expect(sql, contains('before update or delete'));
    expect(sql, isNot(contains('drop table')));
    expect(sql, isNot(contains('truncate')));
  });

  test('uses persisted gross total and exact 85/10/5 accounting', () {
    expect(sql, contains('round(o.final_price::numeric, 2)'));
    expect(sql, contains('round(o.final_price::numeric * 0.85, 2)'));
    expect(sql, contains('round(o.final_price::numeric * 0.10, 2)'));
    expect(sql, contains('v_owner_net := round(v_gross * 0.85, 2)'));
    expect(sql, contains('v_rider_earning := round(v_gross * 0.10, 2)'));
    expect(
      sql,
      contains('v_platform_fee := v_gross - v_owner_net - v_rider_earning'),
    );
  });

  test('settles only eligible paid deliveries and only once', () {
    expect(sql, contains("o.status = 'delivered'::public.order_status"));
    expect(sql, contains("v_method = 'bkash' and v_payment = 'verified'"));
    expect(
      sql,
      contains("v_method = 'cash_on_delivery' and v_payment = 'collected'"),
    );
    expect(sql, contains('for update of o, op'));
    expect(sql, contains('on conflict (order_id) do nothing'));
    expect(sql, contains("v_current = 'delivered'::public.order_status"));
  });

  test('prevents client-controlled settlement identities and values', () {
    expect(sql, contains('v_rider uuid := auth.uid()'));
    expect(sql, contains('v_assigned is distinct from v_rider'));
    expect(sql, contains('k.owner_id'));
    expect(
      sql,
      contains(
        'revoke all on table public.order_settlements from public, anon, authenticated',
      ),
    );
    expect(
      sql,
      contains(
        'alter table public.order_settlements enable row level security',
      ),
    );
    expect(sql, isNot(contains('p_owner_net')));
    expect(sql, isNot(contains('p_rider_earning')));
    expect(sql, isNot(contains('p_platform_fee')));
  });

  test('exposes only role-scoped read RPCs', () {
    expect(sql, contains('public.list_my_rider_earnings()'));
    expect(sql, contains('where s.rider_id = v_rider'));
    expect(sql, contains('public.list_my_owner_settlements()'));
    expect(sql, contains('where s.owner_id = v_owner'));
    expect(
      sql,
      contains('revoke execute on function public.list_my_rider_earnings()'),
    );
    expect(
      sql,
      contains('revoke execute on function public.list_my_owner_settlements()'),
    );
  });
}
