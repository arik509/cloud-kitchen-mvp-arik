-- Add server-authoritative single-item quantity support and harden the
-- existing manual bKash review functions. This migration is data-preserving.

create or replace function public.place_order_v4(
  p_menu_item_id uuid,
  p_quantity integer,
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
  v_transaction text := upper(
    regexp_replace(coalesce(p_transaction_id, ''), '\s+', '', 'g')
  );
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
  from public.profiles as p
  where p.id = v_customer_id;

  if not found then
    raise exception using errcode = 'P0001', message = 'profile_not_found';
  end if;
  if v_role <> 'customer'::public.user_role then
    raise exception using errcode = 'P0001', message = 'customer_role_required';
  end if;
  if p_quantity is null or p_quantity < 1 or p_quantity > 20 then
    raise exception using errcode = 'P0001', message = 'invalid_order_quantity';
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
  from public.menu_items as m
  join public.kitchens as k on k.id = m.kitchen_id
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

  v_total := v_price * p_quantity;
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
  values (v_order_id, p_menu_item_id, p_quantity, v_price);

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
      raise exception using
        errcode = 'P0001',
        message = 'bkash_transaction_id_already_used';
  end;

  return query select v_order_id, v_total, v_method, v_status;
end;
$$;

revoke all on function public.place_order_v4(
  uuid, integer, text, text, text, double precision, double precision
) from public, anon;
grant execute on function public.place_order_v4(
  uuid, integer, text, text, text, double precision, double precision
) to authenticated;

create or replace function public.submit_bkash_transaction(
  p_order_id uuid,
  p_transaction_id text
)
returns table (
  order_id uuid,
  payment_status text,
  transaction_id text,
  submitted_at timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_user uuid := auth.uid();
  v_customer uuid;
  v_method text;
  v_status text;
  v_submitted_at timestamptz;
  v_transaction text := upper(
    regexp_replace(coalesce(p_transaction_id, ''), '\s+', '', 'g')
  );
begin
  if v_user is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;
  if not exists (
    select 1 from public.profiles as p
    where p.id = v_user and p.role = 'customer'::public.user_role
  ) then
    raise exception using errcode = 'P0001', message = 'customer_role_required';
  end if;

  select o.customer_id, op.payment_method, op.payment_status
  into v_customer, v_method, v_status
  from public.orders as o
  join public.order_payments as op on op.order_id = o.id
  where o.id = p_order_id
  for update of op;

  if not found then
    raise exception using errcode = 'P0001', message = 'order_not_found';
  end if;
  if v_customer <> v_user then
    raise exception using errcode = 'P0001', message = 'order_access_denied';
  end if;
  if v_method <> 'bkash' or v_status <> 'rejected' then
    raise exception using errcode = 'P0001', message = 'invalid_payment_transition';
  end if;
  if v_transaction !~ '^[A-Z0-9-]{6,40}$' then
    raise exception using errcode = 'P0001', message = 'invalid_bkash_transaction_id';
  end if;

  v_submitted_at := now();
  begin
    update public.order_payments as op
    set transaction_id = v_transaction,
        payment_status = 'awaiting_verification',
        submitted_at = v_submitted_at,
        verified_at = null,
        verified_by = null,
        updated_at = v_submitted_at
    where op.order_id = p_order_id;
  exception
    when unique_violation then
      raise exception using
        errcode = 'P0001',
        message = 'bkash_transaction_id_already_used';
  end;

  return query
  select p_order_id, 'awaiting_verification'::text, v_transaction, v_submitted_at;
end;
$$;

revoke all on function public.submit_bkash_transaction(uuid, text)
  from public, anon;
grant execute on function public.submit_bkash_transaction(uuid, text)
  to authenticated;

create or replace function public.review_bkash_payment(
  p_order_id uuid,
  p_action text
)
returns table (order_id uuid, payment_status text)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_owner uuid := auth.uid();
  v_kitchen uuid;
  v_method text;
  v_status text;
  v_next text;
begin
  if v_owner is null then
    raise exception using errcode = 'P0001', message = 'authentication_required';
  end if;
  if not exists (
    select 1 from public.profiles as p
    where p.id = v_owner and p.role = 'kitchen_owner'::public.user_role
  ) then
    raise exception using errcode = 'P0001', message = 'kitchen_owner_role_required';
  end if;

  select o.kitchen_id, op.payment_method, op.payment_status
  into v_kitchen, v_method, v_status
  from public.orders as o
  join public.order_payments as op on op.order_id = o.id
  where o.id = p_order_id
  for update of op;

  if not found then
    raise exception using errcode = 'P0001', message = 'order_not_found';
  end if;
  if not exists (
    select 1 from public.kitchens as k
    where k.id = v_kitchen and k.owner_id = v_owner
  ) then
    raise exception using errcode = 'P0001', message = 'order_access_denied';
  end if;
  if v_method <> 'bkash'
     or v_status <> 'awaiting_verification'
     or lower(btrim(p_action)) not in ('verify', 'reject') then
    raise exception using errcode = 'P0001', message = 'invalid_payment_transition';
  end if;

  v_next := case
    when lower(btrim(p_action)) = 'verify' then 'verified'
    else 'rejected'
  end;

  update public.order_payments as op
  set payment_status = v_next,
      verified_at = case when v_next = 'verified' then now() end,
      verified_by = case when v_next = 'verified' then v_owner end,
      updated_at = now()
  where op.order_id = p_order_id;

  return query select p_order_id, v_next;
end;
$$;

revoke all on function public.review_bkash_payment(uuid, text)
  from public, anon;
grant execute on function public.review_bkash_payment(uuid, text)
  to authenticated;
