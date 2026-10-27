-- VendaRides administrator access. Grant role only via trusted Supabase Auth admin tools.
-- Never set administrator privileges using user_metadata or browser code.
create or replace function public.is_vendarides_admin()
returns boolean language sql stable security invoker set search_path = ''
as $$ select coalesce((auth.jwt() -> 'app_metadata' ->> 'vendarides_role') = 'admin', false) $$;
revoke all on function public.is_vendarides_admin() from public, anon;
grant execute on function public.is_vendarides_admin() to authenticated;

-- Admins can review applications, vehicles, trips, bookings and incident reports.
create policy "admin_read_driver_profiles" on public.driver_profiles for select to authenticated using (public.is_vendarides_admin());
create policy "admin_read_vehicles" on public.vehicles for select to authenticated using (public.is_vendarides_admin());
create policy "admin_read_profiles" on public.profiles for select to authenticated using (public.is_vendarides_admin());
create policy "admin_read_trips" on public.trips for select to authenticated using (public.is_vendarides_admin());
create policy "admin_read_bookings" on public.bookings for select to authenticated using (public.is_vendarides_admin());
create policy "admin_read_incidents" on public.incident_reports for select to authenticated using (public.is_vendarides_admin());

-- Admin activity audit, visible only to administrators.
create table if not exists public.admin_audit_log (
 id bigint generated always as identity primary key,
 actor_id uuid not null references auth.users(id),
 action text not null check (action in ('approve_driver','revoke_driver','approve_vehicle','revoke_vehicle')),
 target_id uuid not null,
 created_at timestamptz not null default now()
);
alter table public.admin_audit_log enable row level security;
create policy "admin_read_audit" on public.admin_audit_log for select to authenticated using (public.is_vendarides_admin());

-- Restrict direct edits to verification flags. Admin uses controlled RPC below.
-- Existing self-edit policies, if any, cannot grant verification via direct updates.
create or replace function public.set_driver_approval(p_user_id uuid, p_approved boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.is_vendarides_admin() then raise exception 'Not authorized'; end if;
 if not exists(select 1 from public.driver_profiles where user_id=p_user_id) then raise exception 'Driver not found'; end if;
 update public.driver_profiles set verified=p_approved where user_id=p_user_id;
 insert into public.admin_audit_log(actor_id,action,target_id) values (auth.uid(),case when p_approved then 'approve_driver' else 'revoke_driver' end,p_user_id);
end $$;
create or replace function public.set_vehicle_approval(p_vehicle_id uuid, p_approved boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.is_vendarides_admin() then raise exception 'Not authorized'; end if;
 if not exists(select 1 from public.vehicles where id=p_vehicle_id) then raise exception 'Vehicle not found'; end if;
 update public.vehicles set approved=p_approved where id=p_vehicle_id;
 insert into public.admin_audit_log(actor_id,action,target_id) values (auth.uid(),case when p_approved then 'approve_vehicle' else 'revoke_vehicle' end,p_vehicle_id);
end $$;
revoke all on function public.set_driver_approval(uuid,boolean) from public,anon;
revoke all on function public.set_vehicle_approval(uuid,boolean) from public,anon;
grant execute on function public.set_driver_approval(uuid,boolean) to authenticated;
grant execute on function public.set_vehicle_approval(uuid,boolean) to authenticated;
