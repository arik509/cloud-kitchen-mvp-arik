-- Incremental payment, notification, and kitchen-rating foundation.
-- Existing wallet-funded orders are preserved as demo_wallet payments.

alter table public.kitchens
  add column if not exists accepts_bkash boolean not null default false,
  add column if not exists bkash_number text,
  add column if not exists accepts_cod boolean not null default true;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'kitchens_payment_method_required'
      and conrelid = 'public.kitchens'::regclass
  ) then
    alter table public.kitchens add constraint kitchens_payment_method_required
      check (not is_active or accepts_bkash or accepts_cod) not valid;
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'kitchens_bkash_number_required'
      and conrelid = 'public.kitchens'::regclass
  ) then
    alter table public.kitchens add constraint kitchens_bkash_number_required
      check (
        (not accepts_bkash and bkash_number is null)
        or (
          accepts_bkash
          and bkash_number ~ '^(\+?88)?01[3-9][0-9]{8}$'
        )
      ) not valid;
  end if;
end
$$;

create table if not exists public.order_payments (
  order_id uuid primary key references public.orders(id) on delete cascade,
  payment_method text not null,
  payment_status text not null,
  transaction_id text,
  submitted_at timestamptz,
  verified_at timestamptz,
  verified_by uuid references public.profiles(id) on delete set null,
  collected_at timestamptz,
  collected_by uuid references public.profiles(id) on delete set null,
  refund_completed_at timestamptz,
  refund_completed_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint order_payments_method_check check (
    payment_method in ('bkash', 'cash_on_delivery', 'demo_wallet')
  ),
  constraint order_payments_status_check check (
    payment_status in (
      'awaiting_verification', 'verified', 'rejected', 'cod_pending',
      'collected', 'refund_pending', 'refunded', 'cancelled'
    )
  ),
  constraint order_payments_transaction_shape check (
    (payment_method = 'bkash' and transaction_id is not null
      and char_length(transaction_id) between 6 and 40)
    or (payment_method <> 'bkash' and transaction_id is null)
  )
);

insert into public.order_payments (
  order_id, payment_method, payment_status, submitted_at, verified_at
)
select
  o.id,
  'demo_wallet',
  case when o.status = 'rejected'::public.order_status
    then 'refunded' else 'verified' end,
  o.created_at,
  o.created_at
from public.orders o
where not exists (
  select 1 from public.order_payments op where op.order_id = o.id
);

create unique index if not exists order_payments_bkash_transaction_key
  on public.order_payments (transaction_id)
  where payment_method = 'bkash' and transaction_id is not null;
create index if not exists order_payments_status_idx
  on public.order_payments (payment_status, updated_at desc);

alter table public.order_payments enable row level security;
drop policy if exists "order participants read payments" on public.order_payments;
create policy "order participants read payments"
  on public.order_payments for select to authenticated
  using (
    exists (
      select 1
      from public.orders o
      join public.kitchens k on k.id = o.kitchen_id
      where o.id = order_id
        and (o.customer_id = (select auth.uid()) or k.owner_id = (select auth.uid()))
    )
  );
revoke all on table public.order_payments from public, anon, authenticated;
grant select on table public.order_payments to authenticated;

-- Notification events are private queue rows. Expand only the allowed event
-- vocabulary; existing chat events and delivery semantics remain unchanged.
alter table public.notification_events
  drop constraint if exists notification_events_event_type_check;
alter table public.notification_events
  add constraint notification_events_event_type_check check (
    event_type in (
      'chat_message', 'new_order', 'order_accepted', 'order_preparing',
      'order_ready', 'awaiting_rider', 'rider_assigned', 'picked_up',
      'delivered', 'order_rejected', 'bkash_awaiting_verification',
      'bkash_verified', 'bkash_rejected', 'refund_pending',
      'refund_completed', 'cod_collected'
    )
  );

create or replace function public.queue_order_status_notification()
returns trigger language plpgsql security definer set search_path = pg_catalog
as $$
declare
  v_actor uuid := auth.uid();
  v_event_type text;
  v_label text;
begin
  if old.status = new.status or v_actor is null or v_actor = new.customer_id then
    return new;
  end if;
  v_event_type := case new.status
    when 'accepted'::public.order_status then 'order_accepted'
    when 'preparing'::public.order_status then 'order_preparing'
    when 'ready'::public.order_status then 'order_ready'
    when 'awaiting_rider'::public.order_status then 'awaiting_rider'
    when 'rider_assigned'::public.order_status then 'rider_assigned'
    when 'picked_up'::public.order_status then 'picked_up'
    when 'delivered'::public.order_status then 'delivered'
    when 'rejected'::public.order_status then 'order_rejected'
    else null
  end;
  if v_event_type is null then return new; end if;
  v_label := replace(initcap(replace(v_event_type, '_', ' ')), 'Bkash', 'bKash');
  insert into public.notification_events (
    event_type, sender_id, recipient_id, order_id, title, body, data
  ) values (
    v_event_type, v_actor, new.customer_id, new.id, 'Cloud Kitchen',
    v_label || ' for Order #' || left(new.id::text, 8),
    jsonb_build_object('type', v_event_type, 'order_id', new.id::text)
  );
  return new;
end;
$$;
revoke all on function public.queue_order_status_notification() from public, anon, authenticated;

drop trigger if exists queue_order_status_notification on public.orders;
create trigger queue_order_status_notification
after update of status on public.orders
for each row execute function public.queue_order_status_notification();

create or replace function public.queue_payment_notification()
returns trigger language plpgsql security definer set search_path = pg_catalog
as $$
declare
  v_actor uuid := auth.uid();
  v_customer uuid;
  v_owner uuid;
  v_event_type text;
  v_recipient uuid;
  v_body text;
begin
  if tg_op = 'UPDATE' and old.payment_status = new.payment_status then return new; end if;
  select o.customer_id, k.owner_id into v_customer, v_owner
  from public.orders o join public.kitchens k on k.id = o.kitchen_id
  where o.id = new.order_id;
  if new.payment_method = 'bkash' and new.payment_status = 'awaiting_verification' then
    v_event_type := 'bkash_awaiting_verification';
    v_recipient := v_owner;
    v_body := 'bKash payment awaiting verification for Order #' || left(new.order_id::text, 8);
  elsif new.payment_method = 'cash_on_delivery' and new.payment_status = 'cod_pending' and tg_op = 'INSERT' then
    v_event_type := 'new_order';
    v_recipient := v_owner;
    v_body := 'New cash-on-delivery Order #' || left(new.order_id::text, 8);
  elsif new.payment_status = 'verified' and new.payment_method = 'bkash' then
    v_event_type := 'bkash_verified'; v_recipient := v_customer;
    v_body := 'Your bKash payment was verified.';
  elsif new.payment_status = 'rejected' then
    v_event_type := 'bkash_rejected'; v_recipient := v_customer;
    v_body := 'Your bKash Transaction ID was rejected. Submit a corrected ID.';
  elsif new.payment_status = 'refund_pending' then
    v_event_type := 'refund_pending'; v_recipient := v_customer;
    v_body := 'Your manual bKash refund is pending.';
  elsif new.payment_status = 'refunded' and new.payment_method = 'bkash' then
    v_event_type := 'refund_completed'; v_recipient := v_customer;
    v_body := 'Your manual bKash refund was marked completed.';
  elsif new.payment_status = 'collected' then
    v_event_type := 'cod_collected'; v_recipient := v_customer;
    v_body := 'Cash on Delivery payment collected.';
  else
    return new;
  end if;
  if v_actor is null or v_recipient is null or v_actor = v_recipient then return new; end if;
  insert into public.notification_events (
    event_type, sender_id, recipient_id, order_id, title, body, data
  ) values (
    v_event_type, v_actor, v_recipient, new.order_id, 'Cloud Kitchen', v_body,
    jsonb_build_object('type', v_event_type, 'order_id', new.order_id::text)
  );
  return new;
end;
$$;
revoke all on function public.queue_payment_notification() from public, anon, authenticated;

drop trigger if exists queue_payment_notification on public.order_payments;
create trigger queue_payment_notification
after insert or update of payment_status on public.order_payments
for each row execute function public.queue_payment_notification();

create or replace function public.place_order_v2(
  p_menu_item_id uuid,
  p_delivery_address text,
  p_payment_method text,
  p_transaction_id text default null
)
returns table (
  order_id uuid,
  authoritative_total numeric(12,2),
  payment_method text,
  payment_status text
)
language plpgsql security definer set search_path = pg_catalog
as $$
declare
  v_customer_id uuid := auth.uid();
  v_role public.user_role;
  v_kitchen_id uuid;
  v_owner_id uuid;
  v_price numeric(12,2);
  v_total numeric(12,2);
  v_order_id uuid;
  v_address text := btrim(p_delivery_address);
  v_method text := lower(btrim(p_payment_method));
  v_transaction text := upper(regexp_replace(coalesce(p_transaction_id, ''), '\s+', '', 'g'));
  v_status text;
  v_accepts_bkash boolean;
  v_accepts_cod boolean;
begin
  if v_customer_id is null then raise exception using errcode='P0001',message='authentication_required'; end if;
  select p.role into v_role from public.profiles p where p.id=v_customer_id;
  if not found then raise exception using errcode='P0001',message='profile_not_found'; end if;
  if v_role <> 'customer'::public.user_role then raise exception using errcode='P0001',message='customer_role_required'; end if;
  if v_address is null or v_address='' or char_length(v_address)>500 then
    raise exception using errcode='P0001',message='invalid_delivery_address';
  end if;
  if v_method not in ('bkash','cash_on_delivery') then
    raise exception using errcode='P0001',message='invalid_payment_method';
  end if;
  select k.id,k.owner_id,m.price,k.accepts_bkash,k.accepts_cod
  into v_kitchen_id,v_owner_id,v_price,v_accepts_bkash,v_accepts_cod
  from public.menu_items m join public.kitchens k on k.id=m.kitchen_id
  where m.id=p_menu_item_id and m.is_available and k.is_active
  for share of m,k;
  if not found then raise exception using errcode='P0001',message='menu_item_unavailable'; end if;
  if v_method='bkash' and not v_accepts_bkash then raise exception using errcode='P0001',message='payment_method_unavailable'; end if;
  if v_method='cash_on_delivery' and not v_accepts_cod then raise exception using errcode='P0001',message='payment_method_unavailable'; end if;
  if v_method='bkash' and (v_transaction !~ '^[A-Z0-9-]{6,40}$') then
    raise exception using errcode='P0001',message='invalid_bkash_transaction_id';
  end if;
  v_total := v_price;
  v_status := case when v_method='bkash' then 'awaiting_verification' else 'cod_pending' end;
  insert into public.orders(customer_id,kitchen_id,status,final_price,platform_fee,rider_fee,delivery_address)
  values(v_customer_id,v_kitchen_id,'pending'::public.order_status,v_total,0,0,v_address)
  returning id into v_order_id;
  insert into public.order_items(order_id,menu_item_id,quantity,unit_price)
  values(v_order_id,p_menu_item_id,1,v_price);
  begin
    insert into public.order_payments(order_id,payment_method,payment_status,transaction_id,submitted_at)
    values(v_order_id,v_method,v_status,case when v_method='bkash' then v_transaction end,
      case when v_method='bkash' then now() end);
  exception when unique_violation then
    raise exception using errcode='P0001',message='bkash_transaction_id_already_used';
  end;
  return query select v_order_id,v_total,v_method,v_status;
end;
$$;
revoke all on function public.place_order_v2(uuid,text,text,text) from public,anon;
grant execute on function public.place_order_v2(uuid,text,text,text) to authenticated;

create or replace function public.submit_bkash_transaction(p_order_id uuid,p_transaction_id text)
returns table(order_id uuid,payment_status text,transaction_id text,submitted_at timestamptz)
language plpgsql security definer set search_path = pg_catalog
as $$
declare
  v_user uuid:=auth.uid(); v_customer uuid; v_method text; v_status text;
  v_transaction text:=upper(regexp_replace(coalesce(p_transaction_id,''),'\s+','','g'));
begin
  if v_user is null then raise exception using errcode='P0001',message='authentication_required'; end if;
  select o.customer_id,op.payment_method,op.payment_status into v_customer,v_method,v_status
  from public.orders o join public.order_payments op on op.order_id=o.id
  where o.id=p_order_id for update of op;
  if not found then raise exception using errcode='P0001',message='order_not_found'; end if;
  if v_customer<>v_user then raise exception using errcode='P0001',message='order_access_denied'; end if;
  if v_method<>'bkash' or v_status<>'rejected' then raise exception using errcode='P0001',message='invalid_payment_transition'; end if;
  if v_transaction !~ '^[A-Z0-9-]{6,40}$' then raise exception using errcode='P0001',message='invalid_bkash_transaction_id'; end if;
  begin
    update public.order_payments set transaction_id=v_transaction,payment_status='awaiting_verification',
      submitted_at=now(),verified_at=null,verified_by=null,updated_at=now()
    where order_id=p_order_id;
  exception when unique_violation then
    raise exception using errcode='P0001',message='bkash_transaction_id_already_used';
  end;
  return query select p_order_id,'awaiting_verification'::text,v_transaction,now();
end;
$$;
revoke all on function public.submit_bkash_transaction(uuid,text) from public,anon;
grant execute on function public.submit_bkash_transaction(uuid,text) to authenticated;

create or replace function public.review_bkash_payment(p_order_id uuid,p_action text)
returns table(order_id uuid,payment_status text)
language plpgsql security definer set search_path = pg_catalog
as $$
declare
  v_owner uuid:=auth.uid(); v_kitchen uuid; v_method text; v_status text; v_next text;
begin
  if v_owner is null then raise exception using errcode='P0001',message='authentication_required'; end if;
  select o.kitchen_id,op.payment_method,op.payment_status into v_kitchen,v_method,v_status
  from public.orders o join public.order_payments op on op.order_id=o.id
  where o.id=p_order_id for update of op;
  if not found then raise exception using errcode='P0001',message='order_not_found'; end if;
  if not exists(select 1 from public.kitchens k where k.id=v_kitchen and k.owner_id=v_owner)
    then raise exception using errcode='P0001',message='order_access_denied'; end if;
  if v_method<>'bkash' or v_status<>'awaiting_verification' or lower(btrim(p_action)) not in ('verify','reject')
    then raise exception using errcode='P0001',message='invalid_payment_transition'; end if;
  v_next:=case when lower(btrim(p_action))='verify' then 'verified' else 'rejected' end;
  update public.order_payments set payment_status=v_next,
    verified_at=case when v_next='verified' then now() end,
    verified_by=case when v_next='verified' then v_owner end,updated_at=now()
  where order_id=p_order_id;
  return query select p_order_id,v_next;
end;
$$;
revoke all on function public.review_bkash_payment(uuid,text) from public,anon;
grant execute on function public.review_bkash_payment(uuid,text) to authenticated;

create or replace function public.confirm_cod_collection(p_order_id uuid)
returns table(order_id uuid,payment_status text,authoritative_amount numeric(12,2))
language plpgsql security definer set search_path = pg_catalog
as $$
declare
  v_rider uuid:=auth.uid(); v_assigned uuid; v_order_status public.order_status;
  v_method text; v_payment_status text; v_amount numeric(12,2);
begin
  if v_rider is null then raise exception using errcode='P0001',message='authentication_required'; end if;
  select o.rider_id,o.status,o.final_price,op.payment_method,op.payment_status
  into v_assigned,v_order_status,v_amount,v_method,v_payment_status
  from public.orders o join public.order_payments op on op.order_id=o.id
  where o.id=p_order_id for update of o,op;
  if not found then raise exception using errcode='P0001',message='order_not_found'; end if;
  if v_assigned is distinct from v_rider then raise exception using errcode='P0001',message='delivery_access_denied'; end if;
  if v_method<>'cash_on_delivery' or v_payment_status<>'cod_pending' or v_order_status<>'picked_up'::public.order_status
    then raise exception using errcode='P0001',message='invalid_payment_transition'; end if;
  update public.order_payments set payment_status='collected',collected_at=now(),collected_by=v_rider,updated_at=now()
  where order_id=p_order_id;
  return query select p_order_id,'collected'::text,v_amount;
end;
$$;
revoke all on function public.confirm_cod_collection(uuid) from public,anon;
grant execute on function public.confirm_cod_collection(uuid) to authenticated;

create or replace function public.mark_bkash_refund_completed(p_order_id uuid)
returns table(order_id uuid,payment_status text)
language plpgsql security definer set search_path = pg_catalog
as $$
declare v_owner uuid:=auth.uid(); v_kitchen uuid; v_status text;
begin
  if v_owner is null then raise exception using errcode='P0001',message='authentication_required'; end if;
  select o.kitchen_id,op.payment_status into v_kitchen,v_status
  from public.orders o join public.order_payments op on op.order_id=o.id
  where o.id=p_order_id and op.payment_method='bkash' for update of op;
  if not found then raise exception using errcode='P0001',message='order_not_found'; end if;
  if not exists(select 1 from public.kitchens k where k.id=v_kitchen and k.owner_id=v_owner)
    then raise exception using errcode='P0001',message='order_access_denied'; end if;
  if v_status<>'refund_pending' then raise exception using errcode='P0001',message='invalid_payment_transition'; end if;
  update public.order_payments set payment_status='refunded',refund_completed_at=now(),
    refund_completed_by=v_owner,updated_at=now() where order_id=p_order_id;
  return query select p_order_id,'refunded'::text;
end;
$$;
revoke all on function public.mark_bkash_refund_completed(uuid) from public,anon;
grant execute on function public.mark_bkash_refund_completed(uuid) to authenticated;

-- Replace existing order workflow bodies without changing their signatures.
create or replace function public.update_kitchen_order_status(p_order_id uuid,p_new_status text)
returns table(order_id uuid,status public.order_status,refunded_amount numeric(12,2),wallet_balance numeric(12,2))
language plpgsql security definer set search_path = pg_catalog
as $$
declare
  v_owner uuid:=auth.uid(); v_customer uuid; v_kitchen uuid; v_current public.order_status;
  v_target public.order_status; v_total numeric(12,2); v_method text; v_payment text;
  v_balance numeric(12,2); v_refund numeric(12,2):=0;
begin
  if v_owner is null then raise exception using errcode='P0001',message='authentication_required'; end if;
  if not exists(select 1 from public.profiles p where p.id=v_owner and p.role='kitchen_owner'::public.user_role)
    then raise exception using errcode='P0001',message='kitchen_owner_role_required'; end if;
  if p_new_status is null or p_new_status not in ('accepted','rejected','preparing','ready','awaiting_rider')
    then raise exception using errcode='P0001',message='invalid_order_status_transition'; end if;
  v_target:=p_new_status::public.order_status;
  select o.customer_id,o.kitchen_id,o.status,o.final_price,op.payment_method,op.payment_status
  into v_customer,v_kitchen,v_current,v_total,v_method,v_payment
  from public.orders o join public.order_payments op on op.order_id=o.id
  where o.id=p_order_id for update of o,op;
  if not found then raise exception using errcode='P0001',message='order_not_found'; end if;
  if not exists(select 1 from public.kitchens k where k.id=v_kitchen and k.owner_id=v_owner)
    then raise exception using errcode='P0001',message='order_access_denied'; end if;
  if v_target='accepted'::public.order_status and not (
    v_payment='verified' or (v_method='cash_on_delivery' and v_payment='cod_pending')
  ) then raise exception using errcode='P0001',message='payment_not_ready'; end if;
  if not ((v_current='pending' and v_target in ('accepted','rejected')) or
    (v_current='accepted' and v_target='preparing') or
    (v_current='preparing' and v_target='ready') or
    (v_current='ready' and v_target='awaiting_rider'))
    then raise exception using errcode='P0001',message='invalid_order_status_transition'; end if;
  if v_target='rejected'::public.order_status then
    if v_method='demo_wallet' then
      select p.wallet_balance into v_balance from public.profiles p where p.id=v_customer for update;
      if exists(select 1 from public.wallet_transactions wt where wt.order_id=p_order_id and wt.kind='order_refund')
        then raise exception using errcode='P0001',message='order_already_refunded'; end if;
      v_balance:=v_balance+v_total; v_refund:=v_total;
      update public.profiles set wallet_balance=v_balance where id=v_customer;
      insert into public.wallet_transactions(user_id,amount,balance_after,kind,order_id)
      values(v_customer,v_refund,v_balance,'order_refund',p_order_id);
      update public.order_payments set payment_status='refunded',updated_at=now() where order_id=p_order_id;
    elsif v_method='bkash' and v_payment='verified' then
      update public.order_payments set payment_status='refund_pending',updated_at=now() where order_id=p_order_id;
    else
      update public.order_payments set payment_status='cancelled',updated_at=now() where order_id=p_order_id;
    end if;
  end if;
  update public.orders set status=v_target where id=p_order_id;
  return query select p_order_id,v_target,v_refund,case when v_method='demo_wallet' and v_target='rejected' then v_balance end;
end;
$$;

create or replace function public.update_rider_delivery_status(p_order_id uuid,p_new_status text)
returns table(order_id uuid,status public.order_status,rider_id uuid)
language plpgsql security definer set search_path = pg_catalog
as $$
declare
  v_rider uuid:=auth.uid(); v_assigned uuid; v_current public.order_status;
  v_target public.order_status; v_method text; v_payment text;
begin
  if v_rider is null then raise exception using errcode='P0001',message='authentication_required'; end if;
  if not exists(select 1 from public.profiles p where p.id=v_rider and p.role='rider'::public.user_role)
    then raise exception using errcode='P0001',message='rider_role_required'; end if;
  if p_new_status is null or p_new_status not in ('picked_up','delivered')
    then raise exception using errcode='P0001',message='invalid_delivery_status_transition'; end if;
  v_target:=p_new_status::public.order_status;
  select o.rider_id,o.status,op.payment_method,op.payment_status
  into v_assigned,v_current,v_method,v_payment
  from public.orders o join public.order_payments op on op.order_id=o.id
  where o.id=p_order_id for update of o,op;
  if not found then raise exception using errcode='P0001',message='order_not_found'; end if;
  if v_assigned is distinct from v_rider then raise exception using errcode='P0001',message='delivery_access_denied'; end if;
  if not ((v_current='rider_assigned' and v_target='picked_up') or (v_current='picked_up' and v_target='delivered'))
    then raise exception using errcode='P0001',message='invalid_delivery_status_transition'; end if;
  if v_target='delivered'::public.order_status and v_method='cash_on_delivery' and v_payment<>'collected'
    then raise exception using errcode='P0001',message='cod_collection_required'; end if;
  update public.orders set status=v_target where id=p_order_id;
  return query select p_order_id,v_target,v_rider;
end;
$$;

create or replace function public.list_available_deliveries_v2()
returns table(order_id uuid,kitchen_id uuid,kitchen_name text,kitchen_address text,
  kitchen_latitude double precision,kitchen_longitude double precision,delivery_address text,
  status public.order_status,final_price numeric(12,2),rider_fee numeric(12,2),item_name text,
  quantity integer,created_at timestamptz,payment_method text,payment_status text)
language plpgsql security definer set search_path=pg_catalog stable
as $$
declare v_rider uuid:=auth.uid();
begin
  if v_rider is null then raise exception using errcode='P0001',message='authentication_required'; end if;
  if not exists(select 1 from public.profiles p where p.id=v_rider and p.role='rider'::public.user_role)
    then raise exception using errcode='P0001',message='rider_role_required'; end if;
  return query select o.id,o.kitchen_id,k.name,k.address,k.latitude,k.longitude,o.delivery_address,
    o.status,o.final_price,o.rider_fee,coalesce(mi.name,'Menu item'),coalesce(oi.quantity,1),o.created_at,
    op.payment_method,op.payment_status
  from public.orders o join public.kitchens k on k.id=o.kitchen_id
  join public.order_payments op on op.order_id=o.id
  left join lateral(select x.menu_item_id,x.quantity from public.order_items x where x.order_id=o.id order by x.created_at limit 1) oi on true
  left join public.menu_items mi on mi.id=oi.menu_item_id
  where o.status='awaiting_rider' and o.rider_id is null order by o.created_at;
end;
$$;

create or replace function public.list_my_rider_deliveries_v2()
returns table(order_id uuid,kitchen_id uuid,kitchen_name text,kitchen_address text,
  kitchen_latitude double precision,kitchen_longitude double precision,delivery_address text,
  status public.order_status,final_price numeric(12,2),rider_fee numeric(12,2),item_name text,
  quantity integer,created_at timestamptz,payment_method text,payment_status text)
language plpgsql security definer set search_path=pg_catalog stable
as $$
declare v_rider uuid:=auth.uid();
begin
  if v_rider is null then raise exception using errcode='P0001',message='authentication_required'; end if;
  if not exists(select 1 from public.profiles p where p.id=v_rider and p.role='rider'::public.user_role)
    then raise exception using errcode='P0001',message='rider_role_required'; end if;
  return query select o.id,o.kitchen_id,k.name,k.address,k.latitude,k.longitude,o.delivery_address,
    o.status,o.final_price,o.rider_fee,coalesce(mi.name,'Menu item'),coalesce(oi.quantity,1),o.created_at,
    op.payment_method,op.payment_status
  from public.orders o join public.kitchens k on k.id=o.kitchen_id
  join public.order_payments op on op.order_id=o.id
  left join lateral(select x.menu_item_id,x.quantity from public.order_items x where x.order_id=o.id order by x.created_at limit 1) oi on true
  left join public.menu_items mi on mi.id=oi.menu_item_id
  where o.rider_id=v_rider and o.status in ('rider_assigned','picked_up','delivered') order by o.created_at desc;
end;
$$;
revoke all on function public.list_available_deliveries_v2() from public,anon;
revoke all on function public.list_my_rider_deliveries_v2() from public,anon;
grant execute on function public.list_available_deliveries_v2() to authenticated;
grant execute on function public.list_my_rider_deliveries_v2() to authenticated;

-- Existing ratings table is retained and tied directly to the rated kitchen.
alter table public.ratings add column if not exists kitchen_id uuid references public.kitchens(id) on delete cascade;
create unique index if not exists ratings_one_kitchen_rating_per_order
  on public.ratings(order_id) where rating_type='kitchen'::public.rating_type;
create index if not exists ratings_kitchen_created_idx on public.ratings(kitchen_id,created_at desc);
alter table public.ratings enable row level security;
drop policy if exists "customers read own kitchen ratings" on public.ratings;
create policy "customers read own kitchen ratings" on public.ratings for select to authenticated
  using (rated_by_user_id=(select auth.uid()));
revoke all on table public.ratings from public,anon,authenticated;
grant select on table public.ratings to authenticated;

create or replace function public.submit_kitchen_rating(p_order_id uuid,p_stars integer,p_review_text text default null)
returns table(rating_id uuid,kitchen_id uuid,stars smallint,review_text text)
language plpgsql security definer set search_path=pg_catalog
as $$
declare
  v_customer uuid:=auth.uid(); v_kitchen uuid; v_owner uuid; v_status public.order_status;
  v_review text:=nullif(btrim(p_review_text),''); v_rating uuid;
begin
  if v_customer is null then raise exception using errcode='P0001',message='authentication_required'; end if;
  if p_stars not between 1 and 5 then raise exception using errcode='P0001',message='invalid_rating_stars'; end if;
  if v_review is not null and char_length(v_review)>1000 then raise exception using errcode='P0001',message='invalid_review_text'; end if;
  select o.kitchen_id,k.owner_id,o.status into v_kitchen,v_owner,v_status
  from public.orders o join public.kitchens k on k.id=o.kitchen_id
  where o.id=p_order_id and o.customer_id=v_customer for share of o,k;
  if not found then raise exception using errcode='P0001',message='order_access_denied'; end if;
  if v_status<>'delivered'::public.order_status then raise exception using errcode='P0001',message='delivered_order_required'; end if;
  begin
    insert into public.ratings(order_id,kitchen_id,rated_user_id,rated_by_user_id,rating_type,stars,review_text)
    values(p_order_id,v_kitchen,v_owner,v_customer,'kitchen',p_stars::smallint,v_review)
    returning id into v_rating;
  exception when unique_violation then
    raise exception using errcode='P0001',message='order_already_rated';
  end;
  return query select v_rating,v_kitchen,p_stars::smallint,v_review;
end;
$$;

create or replace function public.list_kitchen_rating_summaries()
returns table(kitchen_id uuid,average_rating numeric(3,2),rating_count bigint)
language sql security definer set search_path=pg_catalog stable
as $$
  select r.kitchen_id,round(avg(r.stars)::numeric,2),count(*)
  from public.ratings r
  where r.rating_type='kitchen'::public.rating_type and r.kitchen_id is not null
  group by r.kitchen_id
$$;
revoke all on function public.submit_kitchen_rating(uuid,integer,text) from public,anon;
revoke all on function public.list_kitchen_rating_summaries() from public,anon;
grant execute on function public.submit_kitchen_rating(uuid,integer,text) to authenticated;
grant execute on function public.list_kitchen_rating_summaries() to authenticated;

comment on table public.order_payments is
  'One server-authoritative payment record per order. bKash verification/refunds are manual in this MVP.';
