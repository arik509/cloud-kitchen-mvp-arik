-- Fix COD collection ambiguity while preserving all existing payment data.

create or replace function public.confirm_cod_collection(p_order_id uuid)
returns table (
  order_id uuid,
  payment_status text,
  authoritative_amount numeric(12,2)
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_rider uuid := auth.uid();
  v_assigned uuid;
  v_order_status public.order_status;
  v_method text;
  v_payment_status text;
  v_amount numeric(12,2);
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

  select
    o.rider_id,
    o.status,
    o.final_price,
    op.payment_method,
    op.payment_status
  into
    v_assigned,
    v_order_status,
    v_amount,
    v_method,
    v_payment_status
  from public.orders o
  join public.order_payments op on op.order_id = o.id
  where o.id = p_order_id
  for update of o, op;

  if not found then
    raise exception using errcode = 'P0001', message = 'order_not_found';
  end if;
  if v_assigned is distinct from v_rider then
    raise exception using errcode = 'P0001', message = 'delivery_access_denied';
  end if;
  if v_method <> 'cash_on_delivery' then
    raise exception using errcode = 'P0001', message = 'cod_payment_required';
  end if;
  if v_payment_status = 'collected' then
    raise exception using errcode = 'P0001', message = 'cash_already_collected';
  end if;
  if v_order_status <> 'picked_up'::public.order_status then
    raise exception using errcode = 'P0001', message = 'pickup_required';
  end if;
  if v_payment_status <> 'cod_pending' then
    raise exception using errcode = 'P0001', message = 'invalid_payment_transition';
  end if;

  update public.order_payments as op
  set
    payment_status = 'collected',
    collected_at = now(),
    collected_by = v_rider,
    updated_at = now()
  where op.order_id = p_order_id;

  return query
  select p_order_id, 'collected'::text, v_amount;
end;
$$;

revoke all on function public.confirm_cod_collection(uuid) from public, anon;
grant execute on function public.confirm_cod_collection(uuid) to authenticated;

comment on function public.confirm_cod_collection(uuid) is
  'Assigned riders atomically record authoritative COD collection after pickup.';
