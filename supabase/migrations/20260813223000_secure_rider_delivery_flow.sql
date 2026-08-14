-- Incremental Phase 6 rider assignment and delivery-state security.
-- Reuses orders.rider_id, orders.rider_fee, and the existing order_status enum.

create index if not exists orders_available_delivery_idx
  on public.orders (created_at desc)
  where status = 'awaiting_rider'::public.order_status and rider_id is null;

-- Orders remain read-only through the Data API. All workflow mutations use
-- role-checked, server-authoritative RPCs below.
revoke all on table public.orders from anon, authenticated;
grant select on table public.orders to authenticated;

create or replace function public.update_kitchen_order_status(
  p_order_id uuid,
  p_new_status text
)
returns table (
  order_id uuid,
  status public.order_status,
  refunded_amount numeric(12,2),
  wallet_balance numeric(12,2)
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_owner_id uuid := auth.uid();
  v_owner_role public.user_role;
  v_customer_id uuid;
  v_kitchen_id uuid;
  v_current_status public.order_status;
  v_target_status public.order_status;
  v_order_total numeric(12,2);
  v_updated_balance numeric(12,2);
  v_refunded_amount numeric(12,2) := 0.00;
begin
  if v_owner_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;

  select p.role into v_owner_role
  from public.profiles p where p.id = v_owner_id;
  if not found or v_owner_role <> 'kitchen_owner'::public.user_role then
    raise exception using errcode = 'P0001', message = 'kitchen_owner_role_required';
  end if;

  if p_new_status is null or p_new_status not in (
    'accepted', 'rejected', 'preparing', 'ready', 'awaiting_rider'
  ) then
    raise exception using errcode = 'P0001', message = 'invalid_order_status_transition';
  end if;
  v_target_status := p_new_status::public.order_status;

  select o.customer_id, o.kitchen_id, o.status, o.final_price
    into v_customer_id, v_kitchen_id, v_current_status, v_order_total
  from public.orders o where o.id = p_order_id for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'order_not_found';
  end if;
  if not exists (
    select 1 from public.kitchens k
    where k.id = v_kitchen_id and k.owner_id = v_owner_id
  ) then
    raise exception using errcode = 'P0001', message = 'order_access_denied';
  end if;

  if not (
    (v_current_status = 'pending'::public.order_status and
      v_target_status in ('accepted'::public.order_status, 'rejected'::public.order_status))
    or (v_current_status = 'accepted'::public.order_status and
      v_target_status = 'preparing'::public.order_status)
    or (v_current_status = 'preparing'::public.order_status and
      v_target_status = 'ready'::public.order_status)
    or (v_current_status = 'ready'::public.order_status and
      v_target_status = 'awaiting_rider'::public.order_status)
  ) then
    raise exception using errcode = 'P0001', message = 'invalid_order_status_transition';
  end if;

  if v_target_status = 'rejected'::public.order_status then
    select p.wallet_balance into v_updated_balance
    from public.profiles p where p.id = v_customer_id for update;
    if not found then
      raise exception using errcode = 'P0001', message = 'customer_profile_not_found';
    end if;
    if exists (
      select 1 from public.wallet_transactions wt
      where wt.order_id = p_order_id and wt.kind = 'order_refund'
    ) then
      raise exception using errcode = 'P0001', message = 'order_already_refunded';
    end if;
    v_updated_balance := v_updated_balance + v_order_total;
    v_refunded_amount := v_order_total;
    update public.profiles p set wallet_balance = v_updated_balance
      where p.id = v_customer_id;
    insert into public.wallet_transactions (
      user_id, amount, balance_after, kind, order_id
    ) values (
      v_customer_id, v_refunded_amount, v_updated_balance, 'order_refund', p_order_id
    );
  end if;

  update public.orders o set status = v_target_status where o.id = p_order_id;
  return query select p_order_id, v_target_status, v_refunded_amount,
    case when v_target_status = 'rejected'::public.order_status
      then v_updated_balance else null::numeric(12,2) end;
end;
$$;

create or replace function public.list_available_deliveries()
returns table (
  order_id uuid, kitchen_id uuid, kitchen_name text, kitchen_address text,
  kitchen_latitude double precision, kitchen_longitude double precision,
  delivery_address text, status public.order_status, final_price numeric(12,2),
  rider_fee numeric(12,2), item_name text, quantity integer, created_at timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog
stable
as $$
declare
  v_rider_id uuid := auth.uid();
begin
  if v_rider_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = v_rider_id and p.role = 'rider'::public.user_role
  ) then
    raise exception using errcode = 'P0001', message = 'rider_role_required';
  end if;
  return query
  select o.id, o.kitchen_id, k.name, k.address, k.latitude, k.longitude,
    o.delivery_address, o.status, o.final_price, o.rider_fee,
    coalesce(mi.name, 'Menu item'), coalesce(oi.quantity, 1), o.created_at
  from public.orders o
  join public.kitchens k on k.id = o.kitchen_id
  left join lateral (
    select x.menu_item_id, x.quantity from public.order_items x
    where x.order_id = o.id order by x.created_at limit 1
  ) oi on true
  left join public.menu_items mi on mi.id = oi.menu_item_id
  where o.status = 'awaiting_rider'::public.order_status and o.rider_id is null
  order by o.created_at;
end;
$$;

create or replace function public.list_my_rider_deliveries()
returns table (
  order_id uuid, kitchen_id uuid, kitchen_name text, kitchen_address text,
  kitchen_latitude double precision, kitchen_longitude double precision,
  delivery_address text, status public.order_status, final_price numeric(12,2),
  rider_fee numeric(12,2), item_name text, quantity integer, created_at timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog
stable
as $$
declare
  v_rider_id uuid := auth.uid();
begin
  if v_rider_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = v_rider_id and p.role = 'rider'::public.user_role
  ) then
    raise exception using errcode = 'P0001', message = 'rider_role_required';
  end if;
  return query
  select o.id, o.kitchen_id, k.name, k.address, k.latitude, k.longitude,
    o.delivery_address, o.status, o.final_price, o.rider_fee,
    coalesce(mi.name, 'Menu item'), coalesce(oi.quantity, 1), o.created_at
  from public.orders o
  join public.kitchens k on k.id = o.kitchen_id
  left join lateral (
    select x.menu_item_id, x.quantity from public.order_items x
    where x.order_id = o.id order by x.created_at limit 1
  ) oi on true
  left join public.menu_items mi on mi.id = oi.menu_item_id
  where o.rider_id = v_rider_id
    and o.status in (
      'rider_assigned'::public.order_status,
      'picked_up'::public.order_status,
      'delivered'::public.order_status
    )
  order by o.created_at desc;
end;
$$;

create or replace function public.claim_delivery(p_order_id uuid)
returns table (order_id uuid, status public.order_status, rider_id uuid)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_rider_id uuid := auth.uid();
  v_status public.order_status;
  v_existing_rider uuid;
begin
  if v_rider_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = v_rider_id and p.role = 'rider'::public.user_role
  ) then
    raise exception using errcode = 'P0001', message = 'rider_role_required';
  end if;

  -- The row lock serializes simultaneous claims. The second transaction sees
  -- the committed assignment and fails instead of overwriting rider_id.
  select o.status, o.rider_id into v_status, v_existing_rider
  from public.orders o where o.id = p_order_id for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'order_not_found';
  end if;
  if v_status <> 'awaiting_rider'::public.order_status or v_existing_rider is not null then
    raise exception using errcode = 'P0001', message = 'delivery_already_claimed';
  end if;

  update public.orders o
  set rider_id = v_rider_id, status = 'rider_assigned'::public.order_status
  where o.id = p_order_id;
  return query select p_order_id, 'rider_assigned'::public.order_status, v_rider_id;
end;
$$;

create or replace function public.update_rider_delivery_status(
  p_order_id uuid, p_new_status text
)
returns table (order_id uuid, status public.order_status, rider_id uuid)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_rider_id uuid := auth.uid();
  v_assigned_rider uuid;
  v_current_status public.order_status;
  v_target_status public.order_status;
begin
  if v_rider_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = v_rider_id and p.role = 'rider'::public.user_role
  ) then
    raise exception using errcode = 'P0001', message = 'rider_role_required';
  end if;
  if p_new_status is null or p_new_status not in ('picked_up', 'delivered') then
    raise exception using errcode = 'P0001', message = 'invalid_delivery_status_transition';
  end if;
  v_target_status := p_new_status::public.order_status;

  select o.rider_id, o.status into v_assigned_rider, v_current_status
  from public.orders o where o.id = p_order_id for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'order_not_found';
  end if;
  if v_assigned_rider is distinct from v_rider_id then
    raise exception using errcode = 'P0001', message = 'delivery_access_denied';
  end if;
  if not (
    (v_current_status = 'rider_assigned'::public.order_status and
      v_target_status = 'picked_up'::public.order_status)
    or (v_current_status = 'picked_up'::public.order_status and
      v_target_status = 'delivered'::public.order_status)
  ) then
    raise exception using errcode = 'P0001', message = 'invalid_delivery_status_transition';
  end if;

  update public.orders o set status = v_target_status where o.id = p_order_id;
  return query select p_order_id, v_target_status, v_rider_id;
end;
$$;

revoke all on function public.update_kitchen_order_status(uuid, text) from public, anon;
revoke all on function public.list_available_deliveries() from public, anon;
revoke all on function public.list_my_rider_deliveries() from public, anon;
revoke all on function public.claim_delivery(uuid) from public, anon;
revoke all on function public.update_rider_delivery_status(uuid, text) from public, anon;
grant execute on function public.update_kitchen_order_status(uuid, text) to authenticated;
grant execute on function public.list_available_deliveries() to authenticated;
grant execute on function public.list_my_rider_deliveries() to authenticated;
grant execute on function public.claim_delivery(uuid) to authenticated;
grant execute on function public.update_rider_delivery_status(uuid, text) to authenticated;
