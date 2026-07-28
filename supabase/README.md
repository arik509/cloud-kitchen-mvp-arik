# Supabase migration workflow

`database/schema.sql` is a legacy snapshot of the schema originally used to
bootstrap the project. It is documentation only and must not be run again on
the existing Supabase project.

Every database change after that snapshot is an incremental, timestamp-named
migration in `supabase/migrations/`. Do not create a baseline migration that
recreates the live schema, and do not recreate existing tables, enums,
triggers, or policies without first auditing the live project.

Migrations must be reviewed and applied in filename order:

1. `20260721133000_menu_images_storage.sql`
2. `20260728120000_secure_profiles_and_roles.sql`
3. `20260728121000_secure_wallet.sql`
4. `20260728122000_place_order.sql`

These files are not applied automatically by the Flutter application. Apply
them manually to a non-production environment first, verify the resulting
policies and functions, and only then repeat the reviewed sequence against the
intended project.
