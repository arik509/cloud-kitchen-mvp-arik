-- Incremental order-placement RPC, participant visibility, constraints, indexes.

-- Supporting indexes for existing foreign keys and participant lookups.
create index if not exists order_items_order_idx
  on public.order_items(order_id);
create index if not exists order_items_menu_item_idx
  on public.order_items(menu_item_id);
create index if not exists messages_sender_idx
  on public.messages(sender_id);
create index if not exists ratings_rated_user_idx
  on public.ratings(rated_user_id);
create index if not exists ratings_rated_by_user_idx
  on public.ratings(rated_by_user_id);

-- New writes are checked immediately while legacy rows can be reviewed before
-- a later explicit VALIDATE CONSTRAINT maintenance operation.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_latitude_range'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_latitude_range
      check (latitude is null or latitude between -90 and 90) not valid;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_longitude_range'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_longitude_range
      check (longitude is null or longitude between -180 and 180) not valid;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_current_lat_range'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_current_lat_range
      check (current_lat is null or current_lat between -90 and 90) not valid;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_current_lng_range'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_current_lng_range
      check (current_lng is null or current_lng between -180 and 180) not valid;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'kitchens_latitude_range'
      and conrelid = 'public.kitchens'::regclass
  ) then
    alter table public.kitchens
      add constraint kitchens_latitude_range
      check (latitude is null or latitude between -90 and 90) not valid;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'kitchens_longitude_range'
      and conrelid = 'public.kitchens'::regclass
  ) then
    alter table public.kitchens
      add constraint kitchens_longitude_range
      check (longitude is null or longitude between -180 and 180) not valid;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'orders_platform_fee_nonnegative'
      and conrelid = 'public.orders'::regclass
  ) then
    alter table public.orders
      add constraint orders_platform_fee_nonnegative
      check (platform_fee >= 0) not valid;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'orders_rider_fee_nonnegative'
      and conrelid = 'public.orders'::regclass
  ) then
    alter table public.orders
      add constraint orders_rider_fee_nonnegative
      check (rider_fee >= 0) not valid;
  end if;
end
$$;

-- Order items are readable only through an order visible to the customer,
-- assigned rider, or owning kitchen owner.
alter table public.order_items enable row level security;
drop policy if exists "order items visible to participants"
  on public.order_items;

create policy "order items visible to participants"
  on public.order_items
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.orders o
      where o.id = order_id
        and (
          o.customer_id = (select auth.uid())
          or o.rider_id = (select auth.uid())
          or exists (
            select 1
            from public.kitchens k
            where k.id = o.kitchen_id
              and k.owner_id = (select auth.uid())
          )
        )
    )
  );

grant select on table public.order_items to authenticated;

-- Direct client order mutations are replaced by the server-authoritative RPC.
drop policy if exists "customers create orders" on public.orders;
revoke insert, update, delete on table public.orders
  from authenticated, anon;
revoke insert, update, delete on table public.order_items
  from authenticated, anon;

create or replace function public.place_order(
  p_menu_item_id uuid,
  p_delivery_address text
)
returns table (
  order_id uuid,
  authoritative_total numeric(12,2),
  wallet_balance numeric(12,2)
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_customer_id uuid := auth.uid();
  v_customer_role public.user_role;
  v_wallet_balance numeric(12,2);
  v_updated_balance numeric(12,2);
  v_kitchen_id uuid;
  v_unit_price numeric(12,2);
  v_platform_fee constant numeric(12,2) := 0.00;
  v_rider_fee constant numeric(12,2) := 0.00;
  v_total numeric(12,2);
  v_order_id uuid;
  v_delivery_address text := pg_catalog.btrim(p_delivery_address);
begin
  if v_customer_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'authentication_required';
  end if;

  if v_delivery_address is null
     or v_delivery_address = ''
     or pg_catalog.char_length(v_delivery_address) > 500 then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_delivery_address';
  end if;

  select p.role, p.wallet_balance
    into v_customer_role, v_wallet_balance
  from public.profiles p
  where p.id = v_customer_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'profile_not_found';
  end if;

  if v_customer_role <> 'customer'::public.user_role then
    raise exception using
      errcode = 'P0001',
      message = 'customer_role_required';
  end if;

  select k.id, m.price
    into v_kitchen_id, v_unit_price
  from public.menu_items m
  join public.kitchens k on k.id = m.kitchen_id
  where m.id = p_menu_item_id
    and m.is_available = true
  for share of m, k;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'menu_item_unavailable';
  end if;

  v_total := v_unit_price + v_platform_fee + v_rider_fee;

  if v_wallet_balance < v_total then
    raise exception using
      errcode = 'P0001',
      message = 'insufficient_wallet_balance';
  end if;

  insert into public.orders (
    customer_id,
    kitchen_id,
    rider_id,
    status,
    final_price,
    platform_fee,
    rider_fee,
    delivery_address
  )
  values (
    v_customer_id,
    v_kitchen_id,
    null,
    'pending'::public.order_status,
    v_total,
    v_platform_fee,
    v_rider_fee,
    v_delivery_address
  )
  returning id into v_order_id;

  insert into public.order_items (
    order_id,
    menu_item_id,
    quantity,
    unit_price
  )
  values (
    v_order_id,
    p_menu_item_id,
    1,
    v_unit_price
  );

  v_updated_balance := v_wallet_balance - v_total;

  update public.profiles p
  set wallet_balance = v_updated_balance
  where p.id = v_customer_id;

  insert into public.wallet_transactions (
    user_id,
    amount,
    balance_after,
    kind,
    order_id
  )
  values (
    v_customer_id,
    -v_total,
    v_updated_balance,
    'order_debit',
    v_order_id
  );

  return query
  select v_order_id, v_total, v_updated_balance;
end;
$$;

revoke all on function public.place_order(uuid, text) from public;
revoke all on function public.place_order(uuid, text) from anon;
grant execute on function public.place_order(uuid, text) to authenticated;

comment on function public.place_order(uuid, text) is
  'Places one available menu item using authoritative price, pending status, and an atomic wallet debit.';
