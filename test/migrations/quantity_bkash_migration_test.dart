import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String sql;

  setUpAll(() {
    sql = File(
      'supabase/migrations/20260814135758_secure_order_quantity_and_bkash.sql',
    ).readAsStringSync().toLowerCase();
  });

  test('quantity RPC calculates total from current database price', () {
    expect(sql, contains('create or replace function public.place_order_v4'));
    expect(sql, contains('p_quantity integer'));
    expect(sql, contains('p_quantity < 1 or p_quantity > 20'));
    expect(sql, contains('v_total := v_price * p_quantity'));
    expect(
      sql,
      contains('values (v_order_id, p_menu_item_id, p_quantity, v_price)'),
    );
    expect(sql, contains('for share of m, k'));
    expect(sql, isNot(contains('p_total')));
    expect(sql, isNot(contains('p_unit_price')));
  });

  test('quantity RPC is customer-only and least-privileged', () {
    expect(sql, contains("v_role <> 'customer'::public.user_role"));
    expect(sql, contains('security definer'));
    expect(sql, contains('set search_path = pg_catalog'));
    expect(sql, contains('from public, anon'));
    expect(sql, contains('to authenticated'));
  });

  test('bKash correction and review use qualified owner-scoped updates', () {
    expect(
      sql,
      contains('create or replace function public.submit_bkash_transaction'),
    );
    expect(sql, contains("p.role = 'customer'::public.user_role"));
    expect(sql, contains('where op.order_id = p_order_id'));
    expect(
      sql,
      contains('create or replace function public.review_bkash_payment'),
    );
    expect(sql, contains("p.role = 'kitchen_owner'::public.user_role"));
    expect(sql, contains('k.owner_id = v_owner'));
    expect(sql, contains("v_status <> 'awaiting_verification'"));
    expect(sql, contains('bkash_transaction_id_already_used'));
  });

  test('migration is incremental and data preserving', () {
    expect(sql, isNot(contains('drop table')));
    expect(sql, isNot(contains('truncate')));
    expect(sql, isNot(contains('delete from')));
    expect(sql, isNot(contains('create table public.orders')));
  });
}
