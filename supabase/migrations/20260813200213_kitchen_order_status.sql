-- Incremental Phase 4 kitchen-owner status transitions and atomic refunds.

-- A rejected order can have at most one refund ledger entry. This also guards
-- against retries and concurrent attempts independently of the RPC lock.
create unique index if not exists wallet_transactions_order_refund_unique_idx
  on public.wallet_transactions (order_id)
  where kind = 'order_refund';

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
  v_current_status public.order_status;
  v_target_status public.order_status;
  v_order_total numeric(12,2);
  v_updated_balance numeric(12,2);
  v_refunded_amount numeric(12,2) := 0.00;
begin
  if v_owner_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'authentication_required';
  end if;

  select p.role
    into v_owner_role
  from public.profiles p
  where p.id = v_owner_id;

  if not found or v_owner_role <> 'kitchen_owner'::public.user_role then
    raise exception using
      errcode = 'P0001',
      message = 'kitchen_owner_role_required';
  end if;

  if p_new_status is null
     or p_new_status not in ('accepted', 'rejected', 'preparing', 'ready') then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_order_status_transition';
  end if;

  v_target_status := p_new_status::public.order_status;

  -- Lock the order first. Ownership is verified from the authoritative
  -- kitchen relationship, never from a caller-provided kitchen or owner ID.
  select o.customer_id, o.status, o.final_price
    into v_customer_id, v_current_status, v_order_total
  from public.orders o
  where o.id = p_order_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'order_not_found';
  end if;

  if not exists (
    select 1
    from public.kitchens k
    where k.id = (
      select o.kitchen_id from public.orders o where o.id = p_order_id
    )
      and k.owner_id = v_owner_id
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'order_access_denied';
  end if;

  if not (
    (v_current_status = 'pending'::public.order_status
      and v_target_status in (
        'accepted'::public.order_status,
        'rejected'::public.order_status
      ))
    or (v_current_status = 'accepted'::public.order_status
      and v_target_status = 'preparing'::public.order_status)
    or (v_current_status = 'preparing'::public.order_status
      and v_target_status = 'ready'::public.order_status)
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_order_status_transition';
  end if;

  if v_target_status = 'rejected'::public.order_status then
    -- Locking the customer profile serializes wallet updates with place_order,
    -- demo credits, and any other wallet mutation.
    select p.wallet_balance
      into v_updated_balance
    from public.profiles p
    where p.id = v_customer_id
    for update;

    if not found then
      raise exception using
        errcode = 'P0001',
        message = 'customer_profile_not_found';
    end if;

    if exists (
      select 1
      from public.wallet_transactions wt
      where wt.order_id = p_order_id
        and wt.kind = 'order_refund'
    ) then
      raise exception using
        errcode = 'P0001',
        message = 'order_already_refunded';
    end if;

    v_updated_balance := v_updated_balance + v_order_total;
    v_refunded_amount := v_order_total;

    update public.profiles p
    set wallet_balance = v_updated_balance
    where p.id = v_customer_id;

    insert into public.wallet_transactions (
      user_id,
      amount,
      balance_after,
      kind,
      order_id
    ) values (
      v_customer_id,
      v_refunded_amount,
      v_updated_balance,
      'order_refund',
      p_order_id
    );
  end if;

  update public.orders o
  set status = v_target_status
  where o.id = p_order_id;

  return query
  select
    p_order_id,
    v_target_status,
    v_refunded_amount,
    case
      when v_target_status = 'rejected'::public.order_status
        then v_updated_balance
      else null::numeric(12,2)
    end;
end;
$$;

revoke all on function public.update_kitchen_order_status(uuid, text)
  from public;
revoke all on function public.update_kitchen_order_status(uuid, text)
  from anon;
grant execute on function public.update_kitchen_order_status(uuid, text)
  to authenticated;

comment on function public.update_kitchen_order_status(uuid, text) is
  'Allows an authenticated owning kitchen_owner to perform legal Phase 4 order transitions and atomically refund a rejected pending order.';
