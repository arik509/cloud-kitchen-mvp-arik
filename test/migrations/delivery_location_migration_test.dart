import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/20260814102135_delivery_coordinates_and_rider_map.sql',
  ).readAsStringSync().toLowerCase();

  test('delivery migration is incremental and range constrained', () {
    expect(sql, contains('add column if not exists delivery_latitude'));
    expect(sql, contains('add column if not exists delivery_longitude'));
    expect(sql, contains('between -90 and 90'));
    expect(sql, contains('between -180 and 180'));
    expect(sql, isNot(contains('drop table')));
    expect(sql, isNot(contains('truncate')));
  });

  test('new order RPC derives identity and accepts no protected fields', () {
    expect(sql, contains('v_customer_id uuid := auth.uid()'));
    expect(sql, contains('create or replace function public.place_order_v3'));
    expect(sql, contains('invalid_delivery_location'));
    expect(sql, isNot(contains('p_customer_id')));
    expect(sql, isNot(contains('p_kitchen_id')));
    expect(sql, isNot(contains('p_price')));
    expect(sql, isNot(contains('p_rider_id')));
  });

  test('rider coordinate RPC is assigned-rider scoped', () {
    expect(
      sql,
      contains('create or replace function public.list_my_rider_deliveries_v3'),
    );
    expect(sql, contains('where o.rider_id = v_rider'));
    expect(sql, contains('delivery_latitude'));
    expect(sql, contains('delivery_longitude'));
  });
}
