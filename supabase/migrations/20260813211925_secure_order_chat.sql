-- Incremental Phase 5 order-linked customer/kitchen-owner chat security.

alter table public.chats enable row level security;
alter table public.messages enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'messages_text_max_length'
      and conrelid = 'public.messages'::regclass
  ) then
    alter table public.messages
      add constraint messages_text_max_length
      check (char_length(btrim(text)) between 1 and 1000) not valid;
  end if;
end
$$;

drop policy if exists "order participants read chats" on public.chats;
create policy "order participants read chats"
  on public.chats for select to authenticated
  using (
    exists (
      select 1 from public.orders o
      join public.kitchens k on k.id = o.kitchen_id
      where o.id = chats.order_id
        and o.status in ('pending', 'accepted', 'preparing', 'ready')
        and (
          o.customer_id = (select auth.uid())
          or k.owner_id = (select auth.uid())
        )
    )
  );

drop policy if exists "order participants read messages" on public.messages;
create policy "order participants read messages"
  on public.messages for select to authenticated
  using (
    exists (
      select 1 from public.chats c
      join public.orders o on o.id = c.order_id
      join public.kitchens k on k.id = o.kitchen_id
      where c.id = messages.chat_id
        and o.status in ('pending', 'accepted', 'preparing', 'ready')
        and (
          o.customer_id = (select auth.uid())
          or k.owner_id = (select auth.uid())
        )
    )
  );

revoke all on table public.chats from anon, authenticated;
revoke all on table public.messages from anon, authenticated;
grant select on table public.chats to authenticated;
grant select on table public.messages to authenticated;

create or replace function public.open_order_chat(p_order_id uuid)
returns table (chat_id uuid, order_id uuid)
language plpgsql security definer set search_path = pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_chat_id uuid;
begin
  if v_user_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;

  if not exists (
    select 1 from public.orders o
    join public.kitchens k on k.id = o.kitchen_id
    where o.id = p_order_id
      and o.status in ('pending', 'accepted', 'preparing', 'ready')
      and (o.customer_id = v_user_id or k.owner_id = v_user_id)
  ) then
    raise exception using errcode = 'P0001', message = 'chat_access_denied';
  end if;

  insert into public.chats (order_id) values (p_order_id)
  on conflict on constraint chats_order_id_key
  do update set order_id = excluded.order_id
  returning id into v_chat_id;

  return query select v_chat_id, p_order_id;
end;
$$;

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
begin
  if v_user_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;
  if v_text is null or v_text = '' or char_length(v_text) > 1000 then
    raise exception using errcode = 'P0001', message = 'invalid_chat_message';
  end if;
  if not exists (
    select 1 from public.chats c
    join public.orders o on o.id = c.order_id
    join public.kitchens k on k.id = o.kitchen_id
    where c.id = p_chat_id
      and o.status in ('pending', 'accepted', 'preparing', 'ready')
      and (o.customer_id = v_user_id or k.owner_id = v_user_id)
  ) then
    raise exception using errcode = 'P0001', message = 'chat_access_denied';
  end if;

  return query
  insert into public.messages as m (chat_id, sender_id, text)
  values (p_chat_id, v_user_id, v_text)
  returning m.id, m.chat_id, m.sender_id, m.text, m.created_at;
end;
$$;

revoke all on function public.open_order_chat(uuid) from public, anon;
revoke all on function public.send_order_chat_message(uuid, text) from public, anon;
grant execute on function public.open_order_chat(uuid) to authenticated;
grant execute on function public.send_order_chat_message(uuid, text) to authenticated;
