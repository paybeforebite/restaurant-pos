create extension if not exists pgcrypto;
create table if not exists public.restaurants(id uuid primary key default gen_random_uuid(),name text not null,slug text not null unique,created_at timestamptz not null default now());
create table if not exists public.restaurant_members(user_id uuid primary key references auth.users(id) on delete cascade,restaurant_id uuid not null references public.restaurants(id) on delete cascade,role text not null default 'cashier' check(role in('owner','admin','cashier')),is_active boolean not null default true,created_at timestamptz not null default now());
insert into public.restaurants(id,name,slug) values('00000000-0000-0000-0000-000000000001','Customer A','customer-a') on conflict(id) do nothing;
create or replace function public.current_restaurant_id() returns uuid language sql stable security definer set search_path=public as $$select restaurant_id from public.restaurant_members where user_id=auth.uid() and is_active=true limit 1$$;
alter table public.menu_items add column if not exists restaurant_id uuid;alter table public.menu_item_history add column if not exists restaurant_id uuid;alter table public.invoices add column if not exists restaurant_id uuid;alter table public.invoice_items add column if not exists restaurant_id uuid;
update public.menu_items set restaurant_id='00000000-0000-0000-0000-000000000001' where restaurant_id is null;update public.menu_item_history h set restaurant_id=m.restaurant_id from public.menu_items m where h.menu_item_id=m.id and h.restaurant_id is null;update public.invoices set restaurant_id='00000000-0000-0000-0000-000000000001' where restaurant_id is null;update public.invoice_items ii set restaurant_id=i.restaurant_id from public.invoices i where ii.invoice_id=i.id and ii.restaurant_id is null;
alter table public.menu_items alter column restaurant_id set not null,alter column restaurant_id set default public.current_restaurant_id();alter table public.menu_item_history alter column restaurant_id set not null,alter column restaurant_id set default public.current_restaurant_id();alter table public.invoices alter column restaurant_id set not null,alter column restaurant_id set default public.current_restaurant_id();alter table public.invoice_items alter column restaurant_id set not null,alter column restaurant_id set default public.current_restaurant_id();
alter table public.invoices drop constraint if exists invoices_invoice_number_key;create unique index if not exists invoices_restaurant_invoice_number_uidx on public.invoices(restaurant_id,invoice_number);
alter table public.restaurants enable row level security;alter table public.restaurant_members enable row level security;alter table public.menu_items enable row level security;alter table public.menu_item_history enable row level security;alter table public.invoices enable row level security;alter table public.invoice_items enable row level security;
drop policy if exists restaurant_member_read on public.restaurants;create policy restaurant_member_read on public.restaurants for select to authenticated using(id=public.current_restaurant_id());
drop policy if exists restaurant_self_read on public.restaurant_members;create policy restaurant_self_read on public.restaurant_members for select to authenticated using(user_id=auth.uid());
drop policy if exists menu_read on public.menu_items;drop policy if exists menu_insert on public.menu_items;drop policy if exists menu_update on public.menu_items;drop policy if exists menu_delete on public.menu_items;create policy menu_read on public.menu_items for select to authenticated using(restaurant_id=public.current_restaurant_id());create policy menu_insert on public.menu_items for insert to authenticated with check(restaurant_id=public.current_restaurant_id());create policy menu_update on public.menu_items for update to authenticated using(restaurant_id=public.current_restaurant_id()) with check(restaurant_id=public.current_restaurant_id());create policy menu_delete on public.menu_items for delete to authenticated using(restaurant_id=public.current_restaurant_id());
drop policy if exists history_read on public.menu_item_history;create policy history_read on public.menu_item_history for select to authenticated using(restaurant_id=public.current_restaurant_id());
drop policy if exists invoice_read on public.invoices;drop policy if exists invoice_insert on public.invoices;drop policy if exists invoice_update on public.invoices;drop policy if exists invoice_delete on public.invoices;create policy invoice_read on public.invoices for select to authenticated using(restaurant_id=public.current_restaurant_id());create policy invoice_insert on public.invoices for insert to authenticated with check(restaurant_id=public.current_restaurant_id());create policy invoice_update on public.invoices for update to authenticated using(restaurant_id=public.current_restaurant_id()) with check(restaurant_id=public.current_restaurant_id());create policy invoice_delete on public.invoices for delete to authenticated using(restaurant_id=public.current_restaurant_id());
drop policy if exists item_read on public.invoice_items;drop policy if exists item_insert on public.invoice_items;create policy item_read on public.invoice_items for select to authenticated using(restaurant_id=public.current_restaurant_id());create policy item_insert on public.invoice_items for insert to authenticated with check(restaurant_id=public.current_restaurant_id() and exists(select 1 from public.invoices i where i.id=invoice_id and i.restaurant_id=public.current_restaurant_id()));


-- Tenant-isolation hardening: remove any legacy/permissive policies and recreate only member-scoped policies.
DO $$
DECLARE p record;
BEGIN
  FOR p IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('restaurants','restaurant_members','menu_items','menu_item_history','invoices','invoice_items')
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', p.policyname, p.schemaname, p.tablename);
  END LOOP;
END $$;

CREATE POLICY restaurant_member_read ON public.restaurants
  FOR SELECT TO authenticated
  USING (id = public.current_restaurant_id());

CREATE POLICY restaurant_self_read ON public.restaurant_members
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() AND is_active = true);

CREATE POLICY menu_tenant_select ON public.menu_items
  FOR SELECT TO authenticated
  USING (restaurant_id = public.current_restaurant_id());
CREATE POLICY menu_tenant_insert ON public.menu_items
  FOR INSERT TO authenticated
  WITH CHECK (restaurant_id = public.current_restaurant_id());
CREATE POLICY menu_tenant_update ON public.menu_items
  FOR UPDATE TO authenticated
  USING (restaurant_id = public.current_restaurant_id())
  WITH CHECK (restaurant_id = public.current_restaurant_id());
CREATE POLICY menu_tenant_delete ON public.menu_items
  FOR DELETE TO authenticated
  USING (restaurant_id = public.current_restaurant_id());

CREATE POLICY history_tenant_select ON public.menu_item_history
  FOR SELECT TO authenticated
  USING (restaurant_id = public.current_restaurant_id());

CREATE POLICY invoice_tenant_select ON public.invoices
  FOR SELECT TO authenticated
  USING (restaurant_id = public.current_restaurant_id());
CREATE POLICY invoice_tenant_insert ON public.invoices
  FOR INSERT TO authenticated
  WITH CHECK (restaurant_id = public.current_restaurant_id());
CREATE POLICY invoice_tenant_update ON public.invoices
  FOR UPDATE TO authenticated
  USING (restaurant_id = public.current_restaurant_id())
  WITH CHECK (restaurant_id = public.current_restaurant_id());
CREATE POLICY invoice_tenant_delete ON public.invoices
  FOR DELETE TO authenticated
  USING (restaurant_id = public.current_restaurant_id());

CREATE POLICY invoice_item_tenant_select ON public.invoice_items
  FOR SELECT TO authenticated
  USING (restaurant_id = public.current_restaurant_id());
CREATE POLICY invoice_item_tenant_insert ON public.invoice_items
  FOR INSERT TO authenticated
  WITH CHECK (
    restaurant_id = public.current_restaurant_id()
    AND EXISTS (
      SELECT 1 FROM public.invoices i
      WHERE i.id = invoice_id
        AND i.restaurant_id = public.current_restaurant_id()
    )
  );


-- PayBeforeBite customer onboarding
alter table public.restaurants
  add column if not exists status text not null default 'pending'
    check (status in ('pending','active','suspended','cancelled')),
  add column if not exists plan text not null default 'basic',
  add column if not exists owner_name text,
  add column if not exists owner_email text,
  add column if not exists phone text,
  add column if not exists activated_at timestamptz;

alter table public.restaurant_members
  add column if not exists invited_email text,
  add column if not exists invited_at timestamptz,
  add column if not exists activated_at timestamptz;

create index if not exists restaurants_status_idx on public.restaurants(status);
create index if not exists restaurant_members_restaurant_idx on public.restaurant_members(restaurant_id);


-- Helper for role-aware UI/API access without recursive RLS evaluation.
create or replace function public.current_restaurant_role()
returns text
language sql
stable
security definer
set search_path=public
as $$
  select role
  from public.restaurant_members
  where user_id = auth.uid()
    and is_active = true
  limit 1
$$;

create policy restaurant_admin_member_read on public.restaurant_members
  for select to authenticated
  using (
    restaurant_id = public.current_restaurant_id()
    and public.current_restaurant_role() in ('owner','admin')
  );

create policy restaurant_admin_manage_read on public.restaurants
  for select to authenticated
  using (
    id = public.current_restaurant_id()
    and public.current_restaurant_role() in ('owner','admin')
  );


-- PayBeforeBite platform admin
create table if not exists public.platform_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.platform_admins enable row level security;

drop policy if exists platform_admin_self_read on public.platform_admins;
create policy platform_admin_self_read on public.platform_admins
  for select to authenticated
  using (user_id = auth.uid() and is_active = true);

create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path=public
as $$
  select exists (
    select 1
    from public.platform_admins
    where user_id = auth.uid()
      and is_active = true
  )
$$;

create index if not exists platform_admins_active_idx
  on public.platform_admins(user_id)
  where is_active = true;
