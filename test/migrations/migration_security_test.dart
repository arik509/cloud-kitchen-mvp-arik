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

  test('Phase 4 order status RPC is owner-scoped and atomically refunds', () {
    final sql = File(
      'supabase/migrations/20260813200213_kitchen_order_status.sql',
    ).readAsStringSync().toLowerCase();

    expect(sql, contains('function public.update_kitchen_order_status'));
    expect(sql, contains('security definer'));
    expect(sql, contains('set search_path = pg_catalog'));
    expect(sql, contains("v_owner_id uuid := auth.uid()"));
    expect(sql, contains("'kitchen_owner'::public.user_role"));
    expect(sql, contains('k.owner_id = v_owner_id'));
    expect(sql, contains('from public.orders o'));
    expect(sql, contains('for update'));
    expect(sql, contains('update public.orders'));
    expect(sql, contains('update public.profiles'));
    expect(sql, contains('insert into public.wallet_transactions'));
    expect(sql, contains("wt.kind = 'order_refund'"));
    expect(sql, contains('wallet_transactions_order_refund_unique_idx'));
    expect(sql, contains('invalid_order_status_transition'));
    expect(sql, contains('order_access_denied'));
    expect(
      sql,
      contains(
        'revoke all on function public.update_kitchen_order_status(uuid, text)\n  from public',
      ),
    );
    expect(
      sql,
      contains(
        'revoke all on function public.update_kitchen_order_status(uuid, text)\n  from anon',
      ),
    );
    expect(
      sql,
      contains(
        'grant execute on function public.update_kitchen_order_status(uuid, text)\n  to authenticated',
      ),
    );
    expect(sql, isNot(contains('alter table public.orders')));
    expect(sql, isNot(contains('create table')));
    expect(sql, isNot(contains('truncate')));
    expect(sql, isNot(contains('drop table')));
  });

  test('Phase 5 chat migration derives participants and prevents spoofing', () {
    final sql = File(
      'supabase/migrations/20260813211925_secure_order_chat.sql',
    ).readAsStringSync().toLowerCase();
    expect(sql, contains('alter table public.chats enable row level security'));
    expect(
      sql,
      contains('alter table public.messages enable row level security'),
    );
    expect(sql, contains('order participants read chats'));
    expect(sql, contains('order participants read messages'));
    expect(sql, contains('o.customer_id = (select auth.uid())'));
    expect(sql, contains('k.owner_id = (select auth.uid())'));
    expect(
      sql,
      contains("o.status in ('pending', 'accepted', 'preparing', 'ready')"),
    );
    expect(sql, contains('function public.open_order_chat'));
    expect(sql, contains('function public.send_order_chat_message'));
    expect(sql, contains('on conflict on constraint chats_order_id_key'));
    expect(sql, contains('v_user_id uuid := auth.uid()'));
    expect(sql, contains('values (p_chat_id, v_user_id, v_text)'));
    expect(sql, contains('char_length(v_text) > 1000'));
    expect(
      sql,
      contains('revoke all on table public.messages from anon, authenticated'),
    );
    expect(sql, isNot(contains('create table')));
    expect(sql, isNot(contains('truncate')));
    expect(sql, isNot(contains('drop table')));
  });

  test('Phase 5 corrective migration safely qualifies the chat upsert', () {
    final sql = File(
      'supabase/migrations/20260813213343_fix_open_order_chat_conflict.sql',
    ).readAsStringSync().toLowerCase();
    expect(sql, contains('create or replace function public.open_order_chat'));
    expect(sql, contains('on conflict on constraint chats_order_id_key'));
    expect(sql, contains('set search_path = pg_catalog'));
    expect(sql, isNot(contains('create table')));
    expect(sql, isNot(contains('drop table')));
  });

  test('Phase 6 rider migration is role-scoped, atomic, and incremental', () {
    final sql = File(
      'supabase/migrations/20260813223000_secure_rider_delivery_flow.sql',
    ).readAsStringSync().toLowerCase();

    expect(sql, contains('function public.list_available_deliveries'));
    expect(sql, contains('function public.list_my_rider_deliveries'));
    expect(sql, contains('function public.claim_delivery'));
    expect(sql, contains('function public.update_rider_delivery_status'));
    expect(sql, contains('v_rider_id uuid := auth.uid()'));
    expect(sql, contains("p.role = 'rider'::public.user_role"));
    expect(sql, contains('for update'));
    expect(sql, contains('delivery_already_claimed'));
    expect(sql, contains('v_existing_rider is not null'));
    expect(sql, contains('v_assigned_rider is distinct from v_rider_id'));
    expect(
      sql,
      contains("v_current_status = 'rider_assigned'::public.order_status and"),
    );
    expect(
      sql,
      contains("v_current_status = 'picked_up'::public.order_status and"),
    );
    expect(sql, contains("v_target_status = 'delivered'::public.order_status"));
    expect(sql, contains("v_current_status = 'ready'::public.order_status"));
    expect(sql, contains('set search_path = pg_catalog'));
    expect(sql, contains('revoke all on table public.orders'));
    expect(sql, isNot(contains('create table')));
    expect(sql, isNot(contains('create type')));
    expect(sql, isNot(contains('alter type')));
    expect(sql, isNot(contains('truncate')));
    expect(sql, isNot(contains('delete from')));
    expect(sql, isNot(contains('drop table')));
  });
}
