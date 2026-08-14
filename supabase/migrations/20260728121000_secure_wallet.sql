-- Incremental wallet ledger and demonstration-credit RPC.
-- Demo credit is fixed at 500.00, capped at 5000.00, with a one-hour cooldown.

create table if not exists public.wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  amount numeric(12,2) not null check (amount <> 0),
  balance_after numeric(12,2) not null check (balance_after >= 0),
  kind text not null check (
    kind in ('demo_credit', 'order_debit', 'order_refund')
  ),
  order_id uuid references public.orders(id),
  created_at timestamptz not null default now()
);

create index if not exists wallet_transactions_user_created_idx
  on public.wallet_transactions(user_id, created_at desc);

create index if not exists wallet_transactions_order_idx
  on public.wallet_transactions(order_id)
  where order_id is not null;

alter table public.wallet_transactions enable row level security;

create policy "users read own wallet transactions"
  on public.wallet_transactions
  for select
  to authenticated
  using (user_id = (select auth.uid()));

revoke insert, update, delete on table public.wallet_transactions
  from authenticated, anon;
grant select on table public.wallet_transactions to authenticated;

create or replace function public.add_demo_balance()
returns table (
  transaction_id uuid,
  credited_amount numeric(12,2),
  balance_after numeric(12,2),
  kind text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_current_balance numeric(12,2);
  v_updated_balance numeric(12,2);
  v_role public.user_role;
  v_transaction_id uuid;
  v_created_at timestamptz;
  v_credit constant numeric(12,2) := 500.00;
  v_maximum_balance constant numeric(12,2) := 5000.00;
begin
  if v_user_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'authentication_required';
  end if;

  select p.wallet_balance, p.role
    into v_current_balance, v_role
  from public.profiles p
  where p.id = v_user_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'profile_not_found';
  end if;

  if v_role <> 'customer'::public.user_role then
    raise exception using
      errcode = 'P0001',
      message = 'customer_role_required';
  end if;

  if exists (
    select 1
    from public.wallet_transactions wt
    where wt.user_id = v_user_id
      and wt.kind = 'demo_credit'
      and wt.created_at > pg_catalog.statement_timestamp() - interval '1 hour'
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'demo_credit_cooldown';
  end if;

  if v_current_balance + v_credit > v_maximum_balance then
    raise exception using
      errcode = 'P0001',
      message = 'demo_wallet_cap_reached';
  end if;

  v_updated_balance := v_current_balance + v_credit;

  update public.profiles p
  set wallet_balance = v_updated_balance
  where p.id = v_user_id;

  insert into public.wallet_transactions as wt (
    user_id,
    amount,
    balance_after,
    kind
  )
  values (
    v_user_id,
    v_credit,
    v_updated_balance,
    'demo_credit'
  )
  returning wt.id, wt.created_at
    into v_transaction_id, v_created_at;

  return query
  select
    v_transaction_id,
    v_credit,
    v_updated_balance,
    'demo_credit'::text,
    v_created_at;
end;
$$;

revoke all on function public.add_demo_balance() from public;
revoke all on function public.add_demo_balance() from anon;
grant execute on function public.add_demo_balance() to authenticated;

comment on function public.add_demo_balance() is
  'Demo-only: credits a customer wallet by a fixed 500.00, up to 5000.00, once per hour.';
