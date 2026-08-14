-- Incremental My Kitchen image and availability support.
-- Data-preserving and safely rerunnable. Do not run database/schema.sql.

alter table public.kitchens
  add column if not exists image_path text;

alter table public.kitchens
  add column if not exists is_active boolean not null default true;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'kitchen-images',
  'kitchen-images',
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
      and policyname = 'Public read access for kitchen images'
  ) then
    create policy "Public read access for kitchen images"
      on storage.objects
      for select
      to public
      using (storage.objects.bucket_id = 'kitchen-images');
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
      and policyname = 'Kitchen owners upload kitchen images'
  ) then
    create policy "Kitchen owners upload kitchen images"
      on storage.objects
      for insert
      to authenticated
      with check (
        storage.objects.bucket_id = 'kitchen-images'
        and (storage.foldername(storage.objects.name))[1] =
          (select auth.uid())::text
        and array_length(storage.foldername(storage.objects.name), 1) = 2
        and exists (
          select 1
          from public.profiles p
          join public.kitchens k on k.owner_id = p.id
          where p.id = (select auth.uid())
            and p.role = 'kitchen_owner'::public.user_role
            and k.id::text =
              (storage.foldername(storage.objects.name))[2]
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
      and policyname = 'Kitchen owners update kitchen images'
  ) then
    create policy "Kitchen owners update kitchen images"
      on storage.objects
      for update
      to authenticated
      using (
        storage.objects.bucket_id = 'kitchen-images'
        and (storage.foldername(storage.objects.name))[1] =
          (select auth.uid())::text
        and array_length(storage.foldername(storage.objects.name), 1) = 2
        and exists (
          select 1
          from public.profiles p
          join public.kitchens k on k.owner_id = p.id
          where p.id = (select auth.uid())
            and p.role = 'kitchen_owner'::public.user_role
            and k.id::text =
              (storage.foldername(storage.objects.name))[2]
        )
      )
      with check (
        storage.objects.bucket_id = 'kitchen-images'
        and (storage.foldername(storage.objects.name))[1] =
          (select auth.uid())::text
        and array_length(storage.foldername(storage.objects.name), 1) = 2
        and exists (
          select 1
          from public.profiles p
          join public.kitchens k on k.owner_id = p.id
          where p.id = (select auth.uid())
            and p.role = 'kitchen_owner'::public.user_role
            and k.id::text =
              (storage.foldername(storage.objects.name))[2]
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
      and policyname = 'Kitchen owners delete kitchen images'
  ) then
    create policy "Kitchen owners delete kitchen images"
      on storage.objects
      for delete
      to authenticated
      using (
        storage.objects.bucket_id = 'kitchen-images'
        and (storage.foldername(storage.objects.name))[1] =
          (select auth.uid())::text
        and array_length(storage.foldername(storage.objects.name), 1) = 2
        and exists (
          select 1
          from public.profiles p
          join public.kitchens k on k.owner_id = p.id
          where p.id = (select auth.uid())
            and p.role = 'kitchen_owner'::public.user_role
            and k.id::text =
              (storage.foldername(storage.objects.name))[2]
        )
      );
  end if;
end
$$;
