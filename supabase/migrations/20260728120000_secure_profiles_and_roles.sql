-- Incremental profile privacy and owner-role hardening.
-- This migration assumes the audited live schema already exists.

-- A signed-in user can read only their own complete profile row.
drop policy if exists "profiles readable" on public.profiles;
drop policy if exists "users update own profile" on public.profiles;

create policy "users read own profile"
  on public.profiles
  for select
  to authenticated
  using (id = (select auth.uid()));

create policy "users update own editable profile"
  on public.profiles
  for update
  to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- RLS limits rows; column grants prevent role, wallet, identity, and audit-field
-- mutation even when an authenticated user owns the row.
revoke insert, delete, update on table public.profiles from authenticated;
grant select on table public.profiles to authenticated;
grant update (
  name,
  phone,
  address,
  latitude,
  longitude,
  current_lat,
  current_lng
) on table public.profiles to authenticated;

-- Invalid or absent signup metadata defaults safely to customer. The existing
-- on_auth_user_created trigger continues to call this function; it is not
-- dropped or recreated.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_role public.user_role := 'customer'::public.user_role;
  v_role_text text := new.raw_user_meta_data ->> 'role';
begin
  if v_role_text in ('customer', 'kitchen_owner', 'rider') then
    v_role := v_role_text::public.user_role;
  end if;

  insert into public.profiles (
    id,
    role,
    name,
    phone,
    address
  )
  values (
    new.id,
    v_role,
    coalesce(new.raw_user_meta_data ->> 'name', ''),
    coalesce(new.raw_user_meta_data ->> 'phone', ''),
    coalesce(new.raw_user_meta_data ->> 'address', '')
  );

  return new;
end;
$$;

revoke all on function public.handle_new_user() from public;
revoke all on function public.handle_new_user() from anon;
revoke all on function public.handle_new_user() from authenticated;

-- Preserve the existing updated-at triggers while fixing their function's
-- search path and removing direct client execution.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  new.updated_at := pg_catalog.now();
  return new;
end;
$$;

revoke all on function public.set_updated_at() from public;
revoke all on function public.set_updated_at() from anon;
revoke all on function public.set_updated_at() from authenticated;

-- Kitchen writes require both ownership and the immutable kitchen_owner role.
drop policy if exists "owners manage kitchen" on public.kitchens;

create policy "kitchen owners insert own kitchen"
  on public.kitchens
  for insert
  to authenticated
  with check (
    owner_id = (select auth.uid())
    and exists (
      select 1
      from public.profiles p
      where p.id = (select auth.uid())
        and p.role = 'kitchen_owner'::public.user_role
    )
  );

create policy "kitchen owners update own kitchen"
  on public.kitchens
  for update
  to authenticated
  using (
    owner_id = (select auth.uid())
    and exists (
      select 1
      from public.profiles p
      where p.id = (select auth.uid())
        and p.role = 'kitchen_owner'::public.user_role
    )
  )
  with check (
    owner_id = (select auth.uid())
    and exists (
      select 1
      from public.profiles p
      where p.id = (select auth.uid())
        and p.role = 'kitchen_owner'::public.user_role
    )
  );

create policy "kitchen owners delete own kitchen"
  on public.kitchens
  for delete
  to authenticated
  using (
    owner_id = (select auth.uid())
    and exists (
      select 1
      from public.profiles p
      where p.id = (select auth.uid())
        and p.role = 'kitchen_owner'::public.user_role
    )
  );

-- Menu writes require ownership of the parent kitchen and kitchen_owner role.
drop policy if exists "owners manage menu" on public.menu_items;

create policy "kitchen owners insert own menu items"
  on public.menu_items
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.kitchens k
      join public.profiles p on p.id = k.owner_id
      where k.id = kitchen_id
        and k.owner_id = (select auth.uid())
        and p.role = 'kitchen_owner'::public.user_role
    )
  );

create policy "kitchen owners update own menu items"
  on public.menu_items
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.kitchens k
      join public.profiles p on p.id = k.owner_id
      where k.id = kitchen_id
        and k.owner_id = (select auth.uid())
        and p.role = 'kitchen_owner'::public.user_role
    )
  )
  with check (
    exists (
      select 1
      from public.kitchens k
      join public.profiles p on p.id = k.owner_id
      where k.id = kitchen_id
        and k.owner_id = (select auth.uid())
        and p.role = 'kitchen_owner'::public.user_role
    )
  );

create policy "kitchen owners delete own menu items"
  on public.menu_items
  for delete
  to authenticated
  using (
    exists (
      select 1
      from public.kitchens k
      join public.profiles p on p.id = k.owner_id
      where k.id = kitchen_id
        and k.owner_id = (select auth.uid())
        and p.role = 'kitchen_owner'::public.user_role
    )
  );
