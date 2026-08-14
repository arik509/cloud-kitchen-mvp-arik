-- Correct the Phase 5 chat upsert after the original migration was applied.
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

revoke all on function public.open_order_chat(uuid) from public, anon;
grant execute on function public.open_order_chat(uuid) to authenticated;
