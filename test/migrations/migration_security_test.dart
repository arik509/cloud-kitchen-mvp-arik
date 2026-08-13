import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migrationDirectory = Directory('supabase/migrations');
  final migrationFiles =
      migrationDirectory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.sql'))
          .toList()
        ..sort((left, right) => left.path.compareTo(right.path));

  test('all migrations use timestamp filenames and avoid destructive resets', () {
    expect(migrationFiles, isNotEmpty);
    final forbidden = RegExp(
      r'\b(drop\s+table|truncate(?:\s+table)?|drop\s+schema|delete\s+from\s+auth\.users|create\s+type\s+public\.user_role|create\s+trigger\s+on_auth_user_created)\b',
      caseSensitive: false,
    );

    for (final file in migrationFiles) {
      final name = file.uri.pathSegments.last;
      expect(name, matches(RegExp(r'^\d{14}_[a-z0-9_]+\.sql$')));
      expect(file.readAsStringSync(), isNot(matches(forbidden)), reason: name);
    }
  });

  test('Group B Storage migration is incremental and owner scoped', () {
    final sql = File(
      'supabase/migrations/20260721133000_menu_images_storage.sql',
    ).readAsStringSync().toLowerCase();

    expect(sql, contains('add column if not exists image_path'));
    expect(sql, contains("'menu-images'"));
    expect(sql, isNot(contains('create table public.menu_items')));
    expect(sql, isNot(contains('create type')));
    expect(sql, isNot(contains('create trigger')));
    expect(
      sql,
      contains(
        '(storage.foldername(storage.objects.name))[1] = '
        '(select auth.uid())::text',
      ),
    );
    expect(sql, contains("p.role = 'kitchen_owner'::public.user_role"));
    expect(sql, contains("k.owner_id = p.id"));
    expect(
      sql,
      contains('k.id::text = (storage.foldername(storage.objects.name))[2]'),
    );
    expect(sql, isNot(contains('storage.foldername(name)')));
    expect(
      RegExp(r'(?<!storage\.objects\.)\bbucket_id\b').hasMatch(sql),
      isFalse,
    );
  });

  test(
    'profile migration preserves the signup trigger and locks protected fields',
    () {
      final sql = File(
        'supabase/migrations/20260728120000_secure_profiles_and_roles.sql',
      ).readAsStringSync().toLowerCase();

      expect(
        sql,
        contains('create or replace function public.handle_new_user()'),
      );
      expect(sql, isNot(contains('drop trigger')));
      expect(sql, contains('users read own profile'));
      expect(sql, contains('revoke insert, delete, update'));
      expect(sql, contains("v_role public.user_role := 'customer'"));
    },
  );

  test('wallet migration exposes only a fixed, locked demo-credit RPC', () {
    final sql = File(
      'supabase/migrations/20260728121000_secure_wallet.sql',
    ).readAsStringSync().toLowerCase();

    expect(sql, contains('function public.add_demo_balance()'));
    expect(sql, contains('security definer'));
    expect(sql, contains('set search_path = pg_catalog'));
    expect(sql, contains('v_credit constant numeric(12,2) := 500.00'));
    expect(
      sql,
      contains('v_maximum_balance constant numeric(12,2) := 5000.00'),
    );
    expect(sql, contains("interval '1 hour'"));
    expect(sql, contains('for update'));
    expect(sql, contains('revoke all on function public.add_demo_balance()'));
  });

  test('order migration removes direct writes and records an atomic debit', () {
    final sql = File(
      'supabase/migrations/20260728122000_place_order.sql',
    ).readAsStringSync().toLowerCase();

    expect(sql, contains('drop policy if exists "customers create orders"'));
    expect(
      sql,
      contains('revoke insert, update, delete on table public.orders'),
    );
    expect(sql, contains('insert into public.orders'));
    expect(sql, contains('insert into public.order_items'));
    expect(sql, contains('update public.profiles'));
    expect(sql, contains('insert into public.wallet_transactions'));
    expect(sql, contains('security definer'));
    expect(sql, contains('set search_path = pg_catalog'));
  });
  test(
    'place_order accepts no client price, identity, status, or fee parameters',
    () {
      final sql = File(
        'supabase/migrations/20260728122000_place_order.sql',
      ).readAsStringSync().toLowerCase();
      final signature = RegExp(
        r'place_order\s*\((.*?)\)\s*returns table',
        dotAll: true,
      ).firstMatch(sql)!.group(1)!;

      expect(signature, contains('p_menu_item_id uuid'));
      expect(signature, contains('p_delivery_address text'));
      expect(
        signature,
        isNot(
          matches(
            RegExp(r'p_(price|customer|kitchen|status|fee|rider|quantity)'),
          ),
        ),
      );
      expect(sql, contains("'pending'::public.order_status"));
      expect(sql, contains('quantity,\n    unit_price'));
      expect(sql, contains("'order_debit'"));
    },
  );

  test('My Kitchen migration is incremental and owner scoped', () {
    final sql = File(
      'supabase/migrations/20260813181738_my_kitchen_images_and_status.sql',
    ).readAsStringSync().toLowerCase();

    expect(sql, contains('add column if not exists image_path text'));
    expect(sql, contains('add column if not exists is_active boolean'));
    expect(sql, contains("'kitchen-images'"));
    expect(sql, contains('5242880'));
    expect(sql, contains("array['image/jpeg', 'image/png', 'image/webp']"));
    expect(sql, isNot(contains('create table public.kitchens')));
    expect(sql, isNot(contains('create type')));
    expect(sql, isNot(contains('create trigger')));
    expect(sql, contains('for select\n      to public'));
    expect(sql, contains('for insert\n      to authenticated'));
    expect(sql, contains('for update\n      to authenticated'));
    expect(sql, contains('for delete\n      to authenticated'));
    expect(
      sql,
      contains(
        '(storage.foldername(storage.objects.name))[1] =\n'
        '          (select auth.uid())::text',
      ),
    );
    expect(sql, contains("p.role = 'kitchen_owner'::public.user_role"));
    expect(sql, contains('k.owner_id = p.id'));
    expect(
      sql,
      contains(
        'k.id::text =\n'
        '              (storage.foldername(storage.objects.name))[2]',
      ),
    );
    expect(sql, isNot(contains('storage.foldername(name)')));
    expect(
      RegExp(r'(?<!storage\.objects\.)\bbucket_id\b').hasMatch(sql),
      isFalse,
    );
  });
}
