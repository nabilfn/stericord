-- SteriCord Phase 1: RLS policies for tenant-scoped foundation tables
-- Critical invariant under test (master prompt section 50): Hospital A must
-- never be able to read or write Hospital B data.

alter table public.organizations enable row level security;
alter table public.departments enable row level security;
alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;

-- organizations ---------------------------------------------------------------

create policy organizations_select on public.organizations
  for select
  using (
    id = public.current_organization_id()
    or public.is_system_admin()
  );

create policy organizations_insert on public.organizations
  for insert
  with check (public.is_system_admin());

create policy organizations_update on public.organizations
  for update
  using (public.is_system_admin())
  with check (public.is_system_admin());

-- departments -------------------------------------------------------------------

create policy departments_select on public.departments
  for select
  using (
    organization_id = public.current_organization_id()
    or public.is_system_admin()
  );

create policy departments_insert on public.departments
  for insert
  with check (
    public.user_has_role(organization_id, array['HOSPITAL_ADMIN']::public.user_role[])
    or public.is_system_admin()
  );

create policy departments_update on public.departments
  for update
  using (
    organization_id = public.current_organization_id()
    and (
      public.user_has_role(organization_id, array['HOSPITAL_ADMIN']::public.user_role[])
      or public.is_system_admin()
    )
  )
  with check (
    public.user_has_role(organization_id, array['HOSPITAL_ADMIN']::public.user_role[])
    or public.is_system_admin()
  );

-- profiles ------------------------------------------------------------------------

create policy profiles_select on public.profiles
  for select
  using (
    organization_id = public.current_organization_id()
    or public.is_system_admin()
  );

create policy profiles_update_self on public.profiles
  for update
  using (id = auth.uid())
  with check (id = auth.uid() and organization_id = public.current_organization_id());

create policy profiles_update_admin on public.profiles
  for update
  using (
    organization_id = public.current_organization_id()
    and (
      public.user_has_role(organization_id, array['HOSPITAL_ADMIN']::public.user_role[])
      or public.is_system_admin()
    )
  )
  with check (
    public.user_has_role(organization_id, array['HOSPITAL_ADMIN']::public.user_role[])
    or public.is_system_admin()
  );

-- user_roles ------------------------------------------------------------------------

create policy user_roles_select on public.user_roles
  for select
  using (
    organization_id = public.current_organization_id()
    or public.is_system_admin()
  );

create policy user_roles_insert on public.user_roles
  for insert
  with check (
    (
      public.user_has_role(organization_id, array['HOSPITAL_ADMIN']::public.user_role[])
      and role <> 'SYSTEM_ADMIN'
    )
    or public.is_system_admin()
  );

create policy user_roles_update on public.user_roles
  for update
  using (
    organization_id = public.current_organization_id()
    and (
      public.user_has_role(organization_id, array['HOSPITAL_ADMIN']::public.user_role[])
      or public.is_system_admin()
    )
  )
  with check (
    (
      public.user_has_role(organization_id, array['HOSPITAL_ADMIN']::public.user_role[])
      and role <> 'SYSTEM_ADMIN'
    )
    or public.is_system_admin()
  );
