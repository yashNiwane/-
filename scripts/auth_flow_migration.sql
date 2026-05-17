-- Auth flow support columns
alter table if exists public.profiles
  add column if not exists login_id text,
  add column if not exists created_by_admin boolean not null default false,
  add column if not exists payment_exempt boolean not null default false,
  add column if not exists prompt_password_change boolean not null default false,
  add column if not exists created_by uuid;

create unique index if not exists profiles_login_id_unique_idx
  on public.profiles (login_id)
  where login_id is not null;

-- Optional: convenience index for payment-access checks.
create index if not exists profiles_payment_access_idx
  on public.profiles (is_paid, payment_exempt, created_by_admin);

-- NOTE:
-- Admin user creation should happen in a secure Supabase Edge Function.
-- Suggested function name: admin-create-user-profile
-- It should:
-- 1) create auth user via admin API using service_role
-- 2) upsert public.profiles with:
--    created_by_admin=true, payment_exempt=true, prompt_password_change=true
-- 3) set login_id and email fields in public.profiles
