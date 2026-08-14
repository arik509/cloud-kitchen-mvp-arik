-- FoodCircle final settlement accounting.
-- Incremental, data-preserving, and safe for the existing live schema.

create table if not exists public.order_settlements (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(id),
  kitchen_id uuid not null references public.kitchens(id),
  owner_id uuid not null references public.profiles(id),
  rider_id uuid not null references public.profiles(id),
  payment_method text not null,
  gross_amount numeric(12,2) not null,
  owner_net_amount numeric(12,2) not null,
  rider_earning numeric(12,2) not null,
  platform_fee numeric(12,2) not null,
  created_at timestamptz not null default now(),
  constraint order_settlements_payment_method_check
    check (payment_method in ('bkash', 'cash_on_delivery')),
  constraint order_settlements_amounts_nonnegative_check
    check (
      gross_amount > 0
      and owner_net_amount >= 0
      and rider_earning >= 0
      and platform_fee >= 0
    ),
  constraint order_settlements_balanced_check
    check (
      gross_amount = owner_net_amount + rider_earning + platform_fee
    )
);

alter table public.order_settlements enable row level security;

revoke all on table public.order_settlements from public, anon, authenticated;
grant select on table public.order_settlements to service_role;

create index if not exists order_settlements_owner_created_idx
  on public.order_settlements (owner_id, created_at desc);

create index if not exists order_settlements_rider_created_idx
  on public.order_settlements (rider_id, created_at desc);

create index if not exists order_settlements_kitchen_idx
  on public.order_settlements (kitchen_id);

create or replace function public.prevent_order_settlement_mutation()
returns trigger
language plpgsql
set search_path = 'pg_catalog'
as $$
begin
  raise exception using
    errcode = 'P0001',
    message = 'order_settlements_are_immutable';
end;
$$;

revoke execute on function public.prevent_order_settlement_mutation()
  from public, anon, authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_catalog.pg_trigger t
    where t.tgname = 'protect_order_settlements_immutable'
      and t.tgrelid = 'public.order_settlements'::regclass
      and not t.tgisinternal
  ) then
    create trigger protect_order_settlements_immutable
      before update or delete on public.order_settlements
      for each row execute function public.prevent_order_settlement_mutation();
  end if;
end;
$$;

-- Backfill only real, eligible bKash/COD deliveries. Historical demo-wallet
-- records intentionally remain outside production settlement accounting.
insert into public.order_settlements (
  order_id,
  kitchen_id,
  owner_id,
  rider_id,
  payment_method,
  gross_amount,
  owner_net_amount,
  rider_earning,
  platform_fee,
  created_at
)
select
  o.id,
  o.kitchen_id,
  k.owner_id,
  o.rider_id,
  op.payment_method,
  round(o.final_price::numeric, 2),
  round(o.final_price::numeric * 0.85, 2),
  round(o.final_price::numeric * 0.10, 2),
  round(o.final_price::numeric, 2)
    - round(o.final_price::numeric * 0.85, 2)
    - round(o.final_price::numeric * 0.10, 2),
  coalesce(op.collected_at, op.verified_at, o.updated_at, now())
from public.orders o
join public.kitchens k on k.id = o.kitchen_id
join public.order_payments op on op.order_id = o.id
where o.status = 'delivered'::public.order_status
  and o.rider_id is not null
  and (
    (op.payment_method = 'bkash' and op.payment_status = 'verified')
    or (
      op.payment_method = 'cash_on_delivery'
      and op.payment_status = 'collected'
    )
  )
on conflict (order_id) do nothing;

update public.orders as o
set
  rider_fee = s.rider_earning,
  platform_fee = s.platform_fee
from public.order_settlements s
where s.order_id = o.id
  and (
    o.rider_fee is distinct from s.rider_earning
    or o.platform_fee is distinct from s.platform_fee
  );

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
