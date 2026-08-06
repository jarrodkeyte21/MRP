-- 1. Tighten app_state so only logged-in users can read/write it (previously anyone with the anon key could).
drop policy if exists "Allow anon read/write" on app_state;
create policy "Authenticated read/write" on app_state
  for all
  to authenticated
  using (true)
  with check (true);

-- 2. Logins: which Supabase Auth account maps to which role, and (for floor staff) which person in the app.
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  role text not null default 'floor' check (role in ('manager','floor','sales')),
  person_id text,
  created_at timestamptz not null default now()
);

alter table profiles enable row level security;

-- Helper function so "is this user a manager" can be checked from a policy on profiles itself without
-- triggering infinite recursion (a policy that queries its own table directly hits that error in Postgres).
create or replace function is_manager()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'manager');
$$;

drop policy if exists "read own profile" on profiles;
create policy "read own profile" on profiles
  for select to authenticated
  using (auth.uid() = id);

drop policy if exists "managers read all profiles" on profiles;
create policy "managers read all profiles" on profiles
  for select to authenticated
  using (is_manager());

drop policy if exists "managers manage profiles" on profiles;
create policy "managers manage profiles" on profiles
  for all to authenticated
  using (is_manager())
  with check (is_manager());

-- 3. Added later: a "sales" role (Schedule & Builds and Stock only) alongside manager/floor. If profiles
-- already existed with the old manager/floor-only check, run this once to widen it — safe to re-run.
alter table profiles drop constraint if exists profiles_role_check;
alter table profiles add constraint profiles_role_check check (role in ('manager','floor','sales'));
