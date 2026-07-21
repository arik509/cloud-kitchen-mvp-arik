-- Incremental Group B migration. Review in a non-production environment first.
-- This file is intentionally not applied by Codex.

alter table public.menu_items
  add column if not exists image_path text;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'menu-images',
  'menu-images',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Public read access for menu images'
  ) then
    create policy "Public read access for menu images"
      on storage.objects
      for select
      to public
      using (bucket_id = 'menu-images');
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Kitchen owners upload menu images'
  ) then
    create policy "Kitchen owners upload menu images"
      on storage.objects
      for insert
      to authenticated
      with check (
        bucket_id = 'menu-images'
        and (storage.foldername(name))[1] = auth.uid()::text
        and array_length(storage.foldername(name), 1) = 3
        and exists (
          select 1
          from public.profiles p
          join public.kitchens k on k.owner_id = p.id
          where p.id = auth.uid()
            and p.role = 'kitchen_owner'::public.user_role
            and k.id::text = (storage.foldername(name))[2]
        )
      );
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Kitchen owners update menu images'
  ) then
    create policy "Kitchen owners update menu images"
      on storage.objects
      for update
      to authenticated
      using (
        bucket_id = 'menu-images'
        and (storage.foldername(name))[1] = auth.uid()::text
        and array_length(storage.foldername(name), 1) = 3
        and exists (
          select 1
          from public.profiles p
          join public.kitchens k on k.owner_id = p.id
          where p.id = auth.uid()
            and p.role = 'kitchen_owner'::public.user_role
            and k.id::text = (storage.foldername(name))[2]
        )
      )
      with check (
        bucket_id = 'menu-images'
        and (storage.foldername(name))[1] = auth.uid()::text
        and array_length(storage.foldername(name), 1) = 3
        and exists (
          select 1
          from public.profiles p
          join public.kitchens k on k.owner_id = p.id
          where p.id = auth.uid()
            and p.role = 'kitchen_owner'::public.user_role
            and k.id::text = (storage.foldername(name))[2]
        )
      );
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Kitchen owners delete menu images'
  ) then
    create policy "Kitchen owners delete menu images"
      on storage.objects
      for delete
      to authenticated
      using (
        bucket_id = 'menu-images'
        and (storage.foldername(name))[1] = auth.uid()::text
        and array_length(storage.foldername(name), 1) = 3
        and exists (
          select 1
          from public.profiles p
          join public.kitchens k on k.owner_id = p.id
          where p.id = auth.uid()
            and p.role = 'kitchen_owner'::public.user_role
            and k.id::text = (storage.foldername(name))[2]
        )
      );
  end if;
end
$$;
