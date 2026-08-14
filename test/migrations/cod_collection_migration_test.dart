import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/20260814114705_fix_cod_collection_rpc.sql',
  ).readAsStringSync().toLowerCase();

  test('COD collection migration is incremental and data preserving', () {
    expect(
      sql,
      contains('create or replace function public.confirm_cod_collection'),
    );
    expect(sql, isNot(contains('truncate ')));
    expect(sql, isNot(contains('drop table')));
    expect(sql, isNot(contains('delete from')));
  });

  test('COD collection is assigned-rider and server authoritative', () {
    expect(sql, contains('v_rider uuid := auth.uid()'));
    expect(sql, contains('v_assigned is distinct from v_rider'));
    expect(sql, contains("v_method <> 'cash_on_delivery'"));
    expect(sql, contains("v_order_status <> 'picked_up'"));
    expect(sql, contains("v_payment_status = 'collected'"));
    expect(sql, contains('for update of o, op'));
    expect(sql, contains('o.final_price'));
    expect(sql, contains('where op.order_id = p_order_id'));
  });

  test('COD collection RPC uses least-privilege grants', () {
    expect(sql, contains('security definer'));
    expect(sql, contains('set search_path = pg_catalog'));
    expect(sql, contains('from public, anon'));
    expect(sql, contains('to authenticated'));
  });
}
