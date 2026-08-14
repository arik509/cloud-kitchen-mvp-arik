-- v1.1.1 incremental patch: re-declare settlement RPCs idempotently.
-- Safe to run on top of 20260814160000_order_settlement_accounting.sql.
-- Uses CREATE OR REPLACE so no data is lost and no errors if already applied.

-- Re-declare list_my_rider_earnings with identical signature for safety.
create or replace function public.list_my_rider_earnings()
returns table (
  order_id uuid,
  gross_amount numeric,
  rider_earning numeric,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = 'pg_catalog'
as $$
declare
  v_rider uuid := auth.uid();
begin
  if v_rider is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;
  if not exists (
    select 1
    from public.profiles p
    where p.id = v_rider
      and p.role = 'rider'::public.user_role
  ) then
    raise exception using errcode = 'P0001', message = 'rider_role_required';
  end if;

  return query
  select
    s.order_id,
    s.gross_amount,
    s.rider_earning,
    s.created_at
  from public.order_settlements s
  where s.rider_id = v_rider
  order by s.created_at desc, s.order_id;
end;
$$;

revoke execute on function public.list_my_rider_earnings()
  from public, anon;
grant execute on function public.list_my_rider_earnings()
  to authenticated;

-- Re-declare list_my_owner_settlements for parity.
create or replace function public.list_my_owner_settlements()
returns table (
  order_id uuid,
  gross_amount numeric,
  owner_net_amount numeric,
  rider_earning numeric,
  platform_fee numeric,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = 'pg_catalog'
as $$
declare
  v_owner uuid := auth.uid();
begin
  if v_owner is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;
  if not exists (
    select 1
    from public.profiles p
    where p.id = v_owner
      and p.role = 'kitchen_owner'::public.user_role
  ) then
    raise exception using errcode = 'P0001', message = 'owner_role_required';
  end if;

  return query
  select
    s.order_id,
    s.gross_amount,
    s.owner_net_amount,
    s.rider_earning,
    s.platform_fee,
    s.created_at
  from public.order_settlements s
  where s.owner_id = v_owner
  order by s.created_at desc, s.order_id;
end;
$$;

revoke execute on function public.list_my_owner_settlements()
  from public, anon;
grant execute on function public.list_my_owner_settlements()
  to authenticated;

-- Re-declare update_rider_delivery_status to ensure settlement insert is present.
create or replace function public.update_rider_delivery_status(
  p_order_id uuid,
  p_new_status text
)
returns table (
  order_id uuid,
  status public.order_status,
  rider_id uuid
)
language plpgsql
security definer
set search_path = 'pg_catalog'
as $$
declare
  v_rider uuid := auth.uid();
  v_assigned uuid;
  v_current public.order_status;
  v_target public.order_status;
  v_method text;
  v_payment text;
  v_kitchen uuid;
  v_owner uuid;
  v_gross numeric(12,2);
  v_owner_net numeric(12,2);
  v_rider_earning numeric(12,2);
  v_platform_fee numeric(12,2);
begin
  if v_rider is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;
  if not exists (
    select 1
    from public.profiles p
    where p.id = v_rider
      and p.role = 'rider'::public.user_role
  ) then
    raise exception using errcode = 'P0001', message = 'rider_role_required';
  end if;
  if p_new_status is null or p_new_status not in ('picked_up', 'delivered') then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_delivery_status_transition';
  end if;

  v_target := p_new_status::public.order_status;

  select
    o.rider_id,
    o.status,
    op.payment_method,
    op.payment_status,
    o.kitchen_id,
    k.owner_id,
    round(o.final_price::numeric, 2)
  into
    v_assigned,
    v_current,
    v_method,
    v_payment,
    v_kitchen,
    v_owner,
    v_gross
  from public.orders o
  join public.kitchens k on k.id = o.kitchen_id
  join public.order_payments op on op.order_id = o.id
  where o.id = p_order_id
  for update of o, op;

  if not found then
    raise exception using errcode = 'P0001', message = 'order_not_found';
  end if;
  if v_assigned is distinct from v_rider then
    raise exception using errcode = 'P0001', message = 'delivery_access_denied';
  end if;

  if v_current = 'delivered'::public.order_status
     and v_target = 'delivered'::public.order_status
     and exists (
       select 1
       from public.order_settlements s
       where s.order_id = p_order_id
         and s.rider_id = v_rider
     ) then
    return query select p_order_id, v_current, v_rider;
    return;
  end if;

  if not (
    (v_current = 'rider_assigned'::public.order_status
      and v_target = 'picked_up'::public.order_status)
    or
    (v_current = 'picked_up'::public.order_status
      and v_target = 'delivered'::public.order_status)
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_delivery_status_transition';
  end if;

  if v_target = 'delivered'::public.order_status then
    if not (
      (v_method = 'bkash' and v_payment = 'verified')
      or (v_method = 'cash_on_delivery' and v_payment = 'collected')
    ) then
      raise exception using
        errcode = 'P0001',
        message = 'payment_requirements_not_satisfied';
    end if;

    v_owner_net := round(v_gross * 0.85, 2);
    v_rider_earning := round(v_gross * 0.10, 2);
    v_platform_fee := v_gross - v_owner_net - v_rider_earning;

    insert into public.order_settlements (
      order_id,
      kitchen_id,
      owner_id,
      rider_id,
      payment_method,
      gross_amount,
      owner_net_amount,
      rider_earning,
      platform_fee
    ) values (
      p_order_id,
      v_kitchen,
      v_owner,
      v_rider,
      v_method,
      v_gross,
      v_owner_net,
      v_rider_earning,
      v_platform_fee
    )
    on conflict (order_id) do nothing;

    update public.orders as o
    set
      status = v_target,
      rider_fee = v_rider_earning,
      platform_fee = v_platform_fee
    where o.id = p_order_id;
  else
    update public.orders as o
    set status = v_target
    where o.id = p_order_id;
  end if;

  return query select p_order_id, v_target, v_rider;
end;
$$;

revoke execute on function public.update_rider_delivery_status(uuid, text)
  from public, anon;
grant execute on function public.update_rider_delivery_status(uuid, text)
  to authenticated;
