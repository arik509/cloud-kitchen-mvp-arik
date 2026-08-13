-- Incremental Phase 7 push-notification foundation.
-- Stores private device tokens, queues one event per stored chat message,
-- and preserves chat delivery when downstream push dispatch fails.

create table if not exists public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null,
  platform text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  constraint push_tokens_token_length check (char_length(token) between 20 and 4096),
  constraint push_tokens_platform_check check (platform in ('android', 'ios', 'web')),
  constraint push_tokens_token_key unique (token)
);

create index if not exists push_tokens_user_id_idx
  on public.push_tokens (user_id);

alter table public.push_tokens enable row level security;

drop policy if exists "users read own push tokens" on public.push_tokens;
create policy "users read own push tokens"
  on public.push_tokens for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "users insert own push tokens" on public.push_tokens;
create policy "users insert own push tokens"
  on public.push_tokens for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "users update own push tokens" on public.push_tokens;
create policy "users update own push tokens"
  on public.push_tokens for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "users delete own push tokens" on public.push_tokens;
create policy "users delete own push tokens"
  on public.push_tokens for delete to authenticated
  using ((select auth.uid()) = user_id);

revoke all on table public.push_tokens from public, anon;
grant select, insert, update, delete on table public.push_tokens to authenticated;

create table if not exists public.notification_events (
  id uuid primary key default gen_random_uuid(),
  event_type text not null,
  source_message_id uuid references public.messages(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  order_id uuid not null references public.orders(id) on delete cascade,
  title text not null,
  body text not null,
  data jsonb not null default '{}'::jsonb,
  status text not null default 'pending',
  attempts integer not null default 0,
  processing_started_at timestamptz,
  dispatched_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint notification_events_event_type_check check (
    event_type in (
      'chat_message',
      'order_accepted',
      'order_preparing',
      'order_ready',
      'awaiting_rider',
      'rider_assigned',
      'picked_up',
      'delivered'
    )
  ),
  constraint notification_events_status_check check (
    status in ('pending', 'processing', 'sent', 'failed')
  ),
  constraint notification_events_distinct_participants check (sender_id <> recipient_id),
  constraint notification_events_source_message_key unique (source_message_id)
);

create index if not exists notification_events_recipient_created_idx
  on public.notification_events (recipient_id, created_at desc);
create index if not exists notification_events_pending_idx
  on public.notification_events (status, created_at)
  where status in ('pending', 'failed');

alter table public.notification_events enable row level security;
revoke all on table public.notification_events from public, anon, authenticated;

create or replace function public.register_push_token(
  p_token text,
  p_platform text
)
returns void
language plpgsql security definer set search_path = pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_token text := btrim(p_token);
  v_platform text := lower(btrim(p_platform));
begin
  if v_user_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;
  if v_token is null or char_length(v_token) not between 20 and 4096 then
    raise exception using errcode = 'P0001', message = 'invalid_push_token';
  end if;
  if v_platform not in ('android', 'ios', 'web') then
    raise exception using errcode = 'P0001', message = 'invalid_push_platform';
  end if;

  insert into public.push_tokens as pt (
    user_id,
    token,
    platform,
    updated_at,
    last_seen_at
  ) values (
    v_user_id,
    v_token,
    v_platform,
    now(),
    now()
  )
  on conflict on constraint push_tokens_token_key do update
  set user_id = excluded.user_id,
      platform = excluded.platform,
      updated_at = now(),
      last_seen_at = now();
end;
$$;

create or replace function public.unregister_push_token(p_token text)
returns void
language plpgsql security definer set search_path = pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;
  delete from public.push_tokens
  where user_id = v_user_id and token = btrim(p_token);
end;
$$;

revoke all on function public.register_push_token(text, text) from public, anon;
revoke all on function public.unregister_push_token(text) from public, anon;
grant execute on function public.register_push_token(text, text) to authenticated;
grant execute on function public.unregister_push_token(text) to authenticated;

create or replace function public.send_order_chat_message(
  p_chat_id uuid,
  p_text text
)
returns table (
  message_id uuid,
  chat_id uuid,
  sender_id uuid,
  message_text text,
  created_at timestamptz
)
language plpgsql security definer set search_path = pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_text text := btrim(p_text);
  v_message_id uuid;
  v_created_at timestamptz;
  v_order_id uuid;
  v_customer_id uuid;
  v_owner_id uuid;
  v_recipient_id uuid;
  v_kitchen_name text;
  v_body text;
begin
  if v_user_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;
  if v_text is null or v_text = '' or char_length(v_text) > 1000 then
    raise exception using errcode = 'P0001', message = 'invalid_chat_message';
  end if;

  select o.id, o.customer_id, k.owner_id, k.name
  into v_order_id, v_customer_id, v_owner_id, v_kitchen_name
  from public.chats c
  join public.orders o on o.id = c.order_id
  join public.kitchens k on k.id = o.kitchen_id
  where c.id = p_chat_id
    and o.status in ('pending', 'accepted', 'preparing', 'ready')
    and (o.customer_id = v_user_id or k.owner_id = v_user_id);

  if v_order_id is null then
    raise exception using errcode = 'P0001', message = 'chat_access_denied';
  end if;

  insert into public.messages as m (chat_id, sender_id, text)
  values (p_chat_id, v_user_id, v_text)
  returning m.id, m.created_at into v_message_id, v_created_at;

  if v_user_id = v_customer_id then
    v_recipient_id := v_owner_id;
    v_body := 'New customer message for Order #' || left(v_order_id::text, 8);
  else
    v_recipient_id := v_customer_id;
    v_body := 'New message from ' || left(v_kitchen_name, 80);
  end if;

  if v_recipient_id is distinct from v_user_id then
    insert into public.notification_events (
      event_type,
      source_message_id,
      sender_id,
      recipient_id,
      order_id,
      title,
      body,
      data
    ) values (
      'chat_message',
      v_message_id,
      v_user_id,
      v_recipient_id,
      v_order_id,
      'Cloud Kitchen',
      v_body,
      pg_catalog.jsonb_build_object(
        'type', 'chat_message',
        'order_id', v_order_id::text,
        'kitchen_name', left(v_kitchen_name, 80),
        'message_id', v_message_id::text
      )
    ) on conflict on constraint notification_events_source_message_key do nothing;
  end if;

  return query select v_message_id, p_chat_id, v_user_id, v_text, v_created_at;
end;
$$;

revoke all on function public.send_order_chat_message(uuid, text) from public, anon;
grant execute on function public.send_order_chat_message(uuid, text) to authenticated;

