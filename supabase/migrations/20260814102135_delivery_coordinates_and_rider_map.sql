-- Per-order delivery coordinates for in-app customer/rider maps.
-- Existing orders remain valid with null coordinates.

alter table public.orders
  add column if not exists delivery_latitude double precision,
  add column if not exists delivery_longitude double precision;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.orders'::regclass
      and conname = 'orders_delivery_coordinates_pair'
  ) then
    alter table public.orders
      add constraint orders_delivery_coordinates_pair
      check (
        (delivery_latitude is null and delivery_longitude is null)
        or
        (delivery_latitude is not null and delivery_longitude is not null)
      ) not valid;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.orders'::regclass
      and conname = 'orders_delivery_latitude_range'
  ) then
    alter table public.orders
      add constraint orders_delivery_latitude_range
      check (delivery_latitude is null or delivery_latitude between -90 and 90)
      not valid;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.orders'::regclass
      and conname = 'orders_delivery_longitude_range'
  ) then
    alter table public.orders
      add constraint orders_delivery_longitude_range
      check (delivery_longitude is null or delivery_longitude between -180 and 180)
      not valid;
  end if;
end
$$;

alter table public.orders validate constraint orders_delivery_coordinates_pair;
alter table public.orders validate constraint orders_delivery_latitude_range;
alter table public.orders validate constraint orders_delivery_longitude_range;

create or replace function public.place_order_v3(
  p_menu_item_id uuid,
  p_delivery_address text,
  p_payment_method text,
  p_transaction_id text,
  p_delivery_latitude double precision,
  p_delivery_longitude double precision
)
returns table (
  order_id uuid,
  authoritative_total numeric(12,2),
  payment_method text,
  payment_status text
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_customer_id uuid := auth.uid();
  v_role public.user_role;
  v_kitchen_id uuid;
  v_price numeric(12,2);
  v_total numeric(12,2);
  v_order_id uuid;
  v_address text := btrim(p_delivery_address);
  v_method text := lower(btrim(p_payment_method));
  v_transaction text := upper(regexp_replace(coalesce(p_transaction_id, ''), '\s+', '', 'g'));
  v_status text;
  v_accepts_bkash boolean;
  v_bkash_number text;
  v_accepts_cod boolean;
begin
  if v_customer_id is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;

  select p.role
  into v_role
  from public.profiles p
  where p.id = v_customer_id;

  if not found then
    raise exception using errcode = 'P0001', message = 'profile_not_found';
  end if;
  if v_role <> 'customer'::public.user_role then
    raise exception using errcode = 'P0001', message = 'customer_role_required';
  end if;
  if v_address is null or v_address = '' or char_length(v_address) > 500 then
    raise exception using errcode = 'P0001', message = 'invalid_delivery_address';
  end if;
  if p_delivery_latitude is null
     or p_delivery_longitude is null
     or p_delivery_latitude not between -90 and 90
     or p_delivery_longitude not between -180 and 180 then
    raise exception using errcode = 'P0001', message = 'invalid_delivery_location';
  end if;
  if v_method not in ('bkash', 'cash_on_delivery') then
    raise exception using errcode = 'P0001', message = 'invalid_payment_method';
  end if;

  select k.id, m.price, k.accepts_bkash, k.bkash_number, k.accepts_cod
  into v_kitchen_id, v_price, v_accepts_bkash, v_bkash_number, v_accepts_cod
  from public.menu_items m
  join public.kitchens k on k.id = m.kitchen_id
  where m.id = p_menu_item_id
    and m.is_available
    and k.is_active
  for share of m, k;

  if not found then
    raise exception using errcode = 'P0001', message = 'menu_item_unavailable';
  end if;
  if v_method = 'bkash'
     and (
       not v_accepts_bkash
       or v_bkash_number is null
       or v_bkash_number !~ '^(\+?88)?01[3-9][0-9]{8}$'
     ) then
    raise exception using errcode = 'P0001', message = 'payment_method_unavailable';
  end if;
  if v_method = 'cash_on_delivery' and not v_accepts_cod then
    raise exception using errcode = 'P0001', message = 'payment_method_unavailable';
  end if;
  if v_method = 'bkash' and v_transaction !~ '^[A-Z0-9-]{6,40}$' then
    raise exception using errcode = 'P0001', message = 'invalid_bkash_transaction_id';
  end if;

  v_total := v_price;
  v_status := case
    when v_method = 'bkash' then 'awaiting_verification'
    else 'cod_pending'
  end;

  insert into public.orders (
    customer_id,
    kitchen_id,
    status,
    final_price,
    platform_fee,
    rider_fee,
    delivery_address,
    delivery_latitude,
    delivery_longitude
  ) values (
    v_customer_id,
    v_kitchen_id,
    'pending'::public.order_status,
    v_total,
    0,
    0,
    v_address,
    p_delivery_latitude,
    p_delivery_longitude
  )
  returning id into v_order_id;

  insert into public.order_items (order_id, menu_item_id, quantity, unit_price)
  values (v_order_id, p_menu_item_id, 1, v_price);

  begin
    insert into public.order_payments (
      order_id,
      payment_method,
      payment_status,
      transaction_id,
      submitted_at
    ) values (
      v_order_id,
      v_method,
      v_status,
      case when v_method = 'bkash' then v_transaction end,
      case when v_method = 'bkash' then now() end
    );
  exception
    when unique_violation then
      raise exception using errcode = 'P0001', message = 'bkash_transaction_id_already_used';
  end;

  return query select v_order_id, v_total, v_method, v_status;
end;
$$;

revoke all on function public.place_order_v3(uuid,text,text,text,double precision,double precision)
  from public, anon;
grant execute on function public.place_order_v3(uuid,text,text,text,double precision,double precision)
  to authenticated;

create or replace function public.list_my_rider_deliveries_v3()
returns table (
  order_id uuid,
  kitchen_id uuid,
  kitchen_name text,
  kitchen_address text,
  kitchen_latitude double precision,
  kitchen_longitude double precision,
  delivery_address text,
  delivery_latitude double precision,
  delivery_longitude double precision,
  status public.order_status,
  final_price numeric(12,2),
  rider_fee numeric(12,2),
  item_name text,
  quantity integer,
  created_at timestamptz,
  payment_method text,
  payment_status text
)
language plpgsql
security definer
set search_path = pg_catalog
stable
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
    o.id,
    o.kitchen_id,
    k.name,
    k.address,
    k.latitude,
    k.longitude,
    o.delivery_address,
    o.delivery_latitude,
    o.delivery_longitude,
    o.status,
    o.final_price,
    o.rider_fee,
    coalesce(mi.name, 'Menu item'),
    coalesce(oi.quantity, 1),
    o.created_at,
    op.payment_method,
    op.payment_status
  from public.orders o
  join public.kitchens k on k.id = o.kitchen_id
  join public.order_payments op on op.order_id = o.id
  left join lateral (
    select x.menu_item_id, x.quantity
    from public.order_items x
    where x.order_id = o.id
    order by x.created_at
    limit 1
  ) oi on true
  left join public.menu_items mi on mi.id = oi.menu_item_id
  where o.rider_id = v_rider
    and o.status in ('rider_assigned', 'picked_up', 'delivered')
  order by o.created_at desc;
end;
$$;

revoke all on function public.list_my_rider_deliveries_v3() from public, anon;
grant execute on function public.list_my_rider_deliveries_v3() to authenticated;
