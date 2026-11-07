-- Additive community features. Existing bookings, driver approval and auth stay intact.
create schema if not exists vr_private;
revoke all on schema vr_private from public,anon,authenticated;
grant usage on schema vr_private to authenticated;
create table public.community_profiles (
 user_id uuid primary key references public.profiles(id) on delete cascade,
 display_name text not null check(length(display_name) between 1 and 90),
 bio text not null default '' check(length(bio)<=300),
 photo_path text check(photo_path is null or photo_path=user_id::text||'/avatar.jpg'),
 visible boolean not null default false, updated_at timestamptz not null default now()
);
create table public.vehicle_photos (
 vehicle_id uuid primary key references public.vehicles(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 photo_path text not null check(photo_path=user_id::text||'/'||vehicle_id::text||'.jpg')
);
create table public.ride_alert_settings (
 user_id uuid primary key references public.profiles(id) on delete cascade,
 driver_alerts boolean not null default false, push_enabled boolean not null default false
);
create table public.route_watches (
 id uuid primary key default gen_random_uuid(),user_id uuid not null references public.profiles(id) on delete cascade,
 origin text not null check(length(origin) between 1 and 100),destination text not null check(length(destination) between 1 and 100),
 travel_date date,created_at timestamptz not null default now(),unique(user_id,origin,destination,travel_date)
);
create table public.ride_notifications (
 id uuid primary key default gen_random_uuid(),user_id uuid not null references public.profiles(id) on delete cascade,
 kind text not null,title text not null,body text not null default '',trip_id uuid references public.trips(id) on delete cascade,
 booking_id uuid references public.bookings(id) on delete cascade,request_id uuid references public.ride_requests(id) on delete cascade,
 created_at timestamptz not null default now(),read_at timestamptz,push_sent_at timestamptz,push_claimed_at timestamptz,push_attempts int not null default 0,
 dedupe_key text unique
);
create index ride_notifications_inbox on public.ride_notifications(user_id,created_at desc);
create index route_watches_routes on public.route_watches(origin,destination,travel_date);
create table public.ride_messages (
 id uuid primary key default gen_random_uuid(),booking_id uuid not null references public.bookings(id) on delete cascade,
 sender_id uuid not null references public.profiles(id) on delete cascade,
 body text not null check(length(trim(body)) between 1 and 2000),created_at timestamptz not null default now()
);
create index ride_messages_booking on public.ride_messages(booking_id,created_at);
create table public.push_subscriptions (
 id uuid primary key default gen_random_uuid(),user_id uuid not null references public.profiles(id) on delete cascade,
 endpoint text not null check(length(endpoint)<2048 and endpoint ~ '^https://'),p256dh text not null check(length(p256dh)<256),
 auth text not null check(length(auth)<128),created_at timestamptz not null default now(),unique(user_id,endpoint)
);
alter table public.bookings add column pickup_status text not null default 'waiting' check(pickup_status in ('waiting','driver_arriving','picked_up','no_show'));
create or replace function vr_private.booking_party(bid uuid,accepted_only boolean default false) returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.bookings b join public.trips t on t.id=b.trip_id
 where b.id=bid and (b.passenger_id=auth.uid() or t.driver_id=auth.uid()) and (not accepted_only or b.status in ('confirmed','completed')));
$$;
create or replace function vr_private.can_view_person(uid uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and (uid=auth.uid() or exists(select 1 from public.community_profiles c where c.user_id=uid and c.visible)
 or exists(select 1 from public.driver_profiles d where d.user_id=uid and d.verified)
 or exists(select 1 from public.bookings b join public.trips t on t.id=b.trip_id where b.status in ('requested','confirmed','completed') and
 ((b.passenger_id=auth.uid() and t.driver_id=uid) or (t.driver_id=auth.uid() and b.passenger_id=uid))));
$$;
revoke all on function vr_private.booking_party(uuid,boolean),vr_private.can_view_person(uuid) from public,anon;
grant execute on function vr_private.booking_party(uuid,boolean),vr_private.can_view_person(uuid) to authenticated;
alter table public.community_profiles enable row level security;
alter table public.vehicle_photos enable row level security;
alter table public.ride_alert_settings enable row level security;
alter table public.route_watches enable row level security;
alter table public.ride_notifications enable row level security;
alter table public.ride_messages enable row level security;
alter table public.push_subscriptions enable row level security;
create policy community_read on public.community_profiles for select to authenticated using(vr_private.can_view_person(user_id));
create policy community_create on public.community_profiles for insert to authenticated with check(user_id=(select auth.uid()));
create policy community_edit on public.community_profiles for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy vehicle_photo_read on public.vehicle_photos for select to authenticated using(vr_private.can_view_person(user_id));
create policy vehicle_photo_create on public.vehicle_photos for insert to authenticated with check(user_id=(select auth.uid()) and exists(select 1 from public.vehicles v where v.id=vehicle_id and v.driver_id=(select auth.uid())));
create policy vehicle_photo_edit on public.vehicle_photos for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()) and exists(select 1 from public.vehicles v where v.id=vehicle_id and v.driver_id=(select auth.uid())));
create policy alert_settings_own on public.ride_alert_settings for all to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy watches_own on public.route_watches for all to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy notifications_read on public.ride_notifications for select to authenticated using(user_id=(select auth.uid()));
create policy notifications_mark on public.ride_notifications for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy messages_read on public.ride_messages for select to authenticated using(vr_private.booking_party(booking_id,true));
create policy messages_create on public.ride_messages for insert to authenticated with check(sender_id=(select auth.uid()) and vr_private.booking_party(booking_id,true) and exists(select 1 from public.bookings b where b.id=booking_id and b.status='confirmed'));
create policy subscriptions_own on public.push_subscriptions for all to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy drivers_open_requests on public.ride_requests for select to authenticated using(exists(select 1 from public.driver_profiles d where d.user_id=(select auth.uid()) and d.verified) and (status='searching' or exists(select 1 from public.ride_notifications n where n.request_id=ride_requests.id and n.user_id=(select auth.uid()))));
grant select,insert,update on public.community_profiles,public.vehicle_photos,public.ride_alert_settings,public.route_watches,public.push_subscriptions to authenticated;
grant delete on public.route_watches,public.push_subscriptions to authenticated;
grant select on public.ride_notifications to authenticated;
grant update(read_at) on public.ride_notifications to authenticated;
grant select,insert on public.ride_messages to authenticated;
-- Phone numbers, email addresses and registration plates are never in the community directory.
create function public.community_person(p_user_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;begin
 if not vr_private.can_view_person(p_user_id) then raise exception 'Profile unavailable';end if;
 select jsonb_build_object('user_id',p.id,'display_name',coalesce(c.display_name,nullif(d.display_name,''),nullif(p.first_name,''),'Community member'),
 'bio',coalesce(c.bio,d.bio,''),'photo_path',c.photo_path,'driver',d.user_id is not null,'verified',coalesce(d.verified,false),
 'vehicles',coalesce((select jsonb_agg(jsonb_build_object('id',v.id,'make',v.make,'model',v.model,'seats',v.seat_capacity,'photo_path',vp.photo_path,'approved',v.approved))
 from public.vehicles v left join public.vehicle_photos vp on vp.vehicle_id=v.id where v.driver_id=p.id and (v.approved or p.id=auth.uid())),'[]'::jsonb)) into result
 from public.profiles p left join public.community_profiles c on c.user_id=p.id left join public.driver_profiles d on d.user_id=p.id where p.id=p_user_id;
 return result;
end$$;
revoke all on function public.community_person(uuid) from public,anon;grant execute on function public.community_person(uuid) to authenticated;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('ride-photos','ride-photos',false,3145728,array['image/jpeg']) on conflict(id) do nothing;
create policy ride_photo_read on storage.objects for select to authenticated using(bucket_id='ride-photos' and case when (storage.foldername(name))[1] ~ '^[0-9a-f-]{36}$' then vr_private.can_view_person(((storage.foldername(name))[1])::uuid) else false end);
create policy ride_photo_insert on storage.objects for insert to authenticated with check(bucket_id='ride-photos' and (storage.foldername(name))[1]=(select auth.uid())::text and lower(storage.extension(name))='jpg');
create policy ride_photo_update on storage.objects for update to authenticated using(bucket_id='ride-photos' and (storage.foldername(name))[1]=(select auth.uid())::text) with check(bucket_id='ride-photos' and (storage.foldername(name))[1]=(select auth.uid())::text and lower(storage.extension(name))='jpg');
create policy ride_photo_delete on storage.objects for delete to authenticated using(bucket_id='ride-photos' and (storage.foldername(name))[1]=(select auth.uid())::text);
-- Notifications are generated by trusted triggers, never arbitrary client inserts.
create function vr_private.notify_ride_changes() returns trigger language plpgsql security definer set search_path='' as $$
declare driver uuid;begin
 if tg_table_name='trips' then
  if new.status<>'published' or new.departure_at<=now() then return new;end if;
  if tg_op='UPDATE' and old.status='published' then return new;end if;
  insert into public.ride_notifications(user_id,kind,title,body,trip_id,dedupe_key)
  select u,'ride_published','A ride matches your route',new.origin||' → '||new.destination,new.id,'ride:'||new.id||':'||u from (
   select w.user_id u from public.route_watches w where w.origin=new.origin and w.destination=new.destination and (w.travel_date is null or w.travel_date=(new.departure_at at time zone 'Africa/Johannesburg')::date)
   union select r.passenger_id from public.ride_requests r where r.status='searching' and r.origin=new.origin and r.destination=new.destination and r.travel_date=(new.departure_at at time zone 'Africa/Johannesburg')::date
  ) q where u<>new.driver_id on conflict(dedupe_key) do nothing;
 elsif tg_table_name='ride_requests' then
  if tg_op='INSERT' then
   insert into public.ride_notifications(user_id,kind,title,body,request_id,dedupe_key)
   select d.user_id,'ride_request','A passenger is looking for a ride',new.origin||' → '||new.destination,new.id,'request:'||new.id||':'||d.user_id
   from public.driver_profiles d join public.ride_alert_settings s on s.user_id=d.user_id where d.verified and s.driver_alerts and d.user_id<>new.passenger_id on conflict(dedupe_key) do nothing;
  elsif old.status is distinct from new.status then
   insert into public.ride_notifications(user_id,kind,title,body,request_id,dedupe_key)
   select distinct n.user_id,'request_closed','Passenger request updated','This request is now '||replace(new.status,'_',' '),new.id,'request:'||new.id||':'||new.status||':'||n.user_id from public.ride_notifications n where n.request_id=new.id on conflict(dedupe_key) do nothing;
  end if;
 elsif tg_table_name='bookings' then
  select driver_id into driver from public.trips where id=new.trip_id;
  if tg_op='INSERT' then
   insert into public.ride_notifications(user_id,kind,title,body,trip_id,booking_id) values(driver,'booking_requested','New seat request','Review the passenger and accept or decline.',new.trip_id,new.id);
  elsif old.status is distinct from new.status or old.pickup_status is distinct from new.pickup_status then
   insert into public.ride_notifications(user_id,kind,title,body,trip_id,booking_id)
   select u,'booking_updated','Your journey has an update',case when old.pickup_status is distinct from new.pickup_status then 'Pickup status: '||replace(new.pickup_status,'_',' ') else 'Booking '||new.status end,new.trip_id,new.id from unnest(array[driver,new.passenger_id]) u;
   if new.status='confirmed' and old.status<>'confirmed' then
    update public.ride_requests r set status='already_taken' from public.trips t where t.id=new.trip_id and r.passenger_id=new.passenger_id and r.status='searching' and r.origin=t.origin and r.destination=t.destination and r.travel_date=(t.departure_at at time zone 'Africa/Johannesburg')::date;
   end if;
  end if;
 end if;return new;
end$$;
create trigger community_trip_notice after insert or update on public.trips for each row execute function vr_private.notify_ride_changes();
create trigger community_request_notice after insert or update on public.ride_requests for each row execute function vr_private.notify_ride_changes();
create trigger community_booking_notice after insert or update on public.bookings for each row execute function vr_private.notify_ride_changes();
create function vr_private.message_notice() returns trigger language plpgsql security definer set search_path='' as $$
declare target uuid;begin
 if (select count(*) from public.ride_messages where sender_id=new.sender_id and created_at>now()-interval '1 minute')>=30 then raise exception 'Please wait before sending another message';end if;
 select case when b.passenger_id=new.sender_id then t.driver_id else b.passenger_id end into target from public.bookings b join public.trips t on t.id=b.trip_id where b.id=new.booking_id and b.status='confirmed' and new.sender_id in (b.passenger_id,t.driver_id);
 if target is null then raise exception 'Chat is available after acceptance only';end if;
 insert into public.ride_notifications(user_id,kind,title,body,booking_id) values(target,'message','New journey message','Open your accepted booking to read and reply.',new.booking_id);
 return new;
end$$;
create trigger community_message_notice before insert on public.ride_messages for each row execute function vr_private.message_notice();
create function public.set_pickup_status(p_booking_id uuid,p_status text) returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or p_status not in ('waiting','driver_arriving','picked_up','no_show') then raise exception 'Invalid pickup status';end if;
 update public.bookings b set pickup_status=p_status from public.trips t where b.id=p_booking_id and t.id=b.trip_id and t.driver_id=auth.uid() and b.status='confirmed';
 if not found then raise exception 'Only the assigned driver may update an accepted pickup';end if;
end$$;
revoke all on function public.set_pickup_status(uuid,text) from public,anon;grant execute on function public.set_pickup_status(uuid,text) to authenticated;
-- Expose only the rows each subscriber can read via their RLS policies.
do $$declare t text;begin foreach t in array array['trips','bookings','ride_requests','ride_notifications','ride_messages'] loop
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename=t) then execute format('alter publication supabase_realtime add table public.%I',t);end if;
end loop;end$$;
-- A narrowly scoped token authorizes the push worker, without a service-role key.
create table vr_private.push_worker_config(id boolean primary key default true check(id),token_sha256 text not null);
create function public.claim_ride_push(p_token text) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;begin
 if not exists(select 1 from vr_private.push_worker_config where token_sha256=encode(extensions.digest(p_token,'sha256'),'hex')) then raise exception 'Not authorized';end if;
 -- Departure reminders are deduplicated even when multiple workers run.
 insert into public.ride_notifications(user_id,kind,title,body,booking_id,trip_id,dedupe_key)
 select u,'departure_reminder','Your ride departs soon','Open your booking to confirm the pickup.',b.id,t.id,'departure:'||b.id||':'||u
 from public.bookings b join public.trips t on t.id=b.trip_id cross join lateral unnest(array[b.passenger_id,t.driver_id]) u
 where b.status='confirmed' and b.pickup_status='waiting' and t.departure_at between now() and now()+interval '30 minutes' on conflict(dedupe_key) do nothing;
 with picked as (select n.id from public.ride_notifications n where n.push_sent_at is null and n.push_attempts<3 and n.created_at>now()-interval '1 day' and (n.push_claimed_at is null or n.push_claimed_at<now()-interval '5 minutes')
 and exists(select 1 from public.ride_alert_settings s where s.user_id=n.user_id and s.push_enabled) and exists(select 1 from public.push_subscriptions s where s.user_id=n.user_id)
 order by n.created_at for update skip locked limit 40),claimed as (update public.ride_notifications n set push_claimed_at=now(),push_attempts=push_attempts+1 from picked where n.id=picked.id returning n.*)
 select coalesce(jsonb_agg(jsonb_build_object('id',n.id,'title',n.title,'body',n.body,'kind',n.kind,'subscriptions',(select jsonb_agg(jsonb_build_object('id',s.id,'endpoint',s.endpoint,'keys',jsonb_build_object('p256dh',s.p256dh,'auth',s.auth))) from public.push_subscriptions s where s.user_id=n.user_id))),'[]'::jsonb) into result from claimed n;
 return result;
end$$;
create function public.settle_ride_push(p_token text,p_id uuid,p_sent boolean,p_expired uuid[] default '{}') returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from vr_private.push_worker_config where token_sha256=encode(extensions.digest(p_token,'sha256'),'hex')) then raise exception 'Not authorized';end if;
 update public.ride_notifications set push_sent_at=case when p_sent then now() else null end where id=p_id;
 delete from public.push_subscriptions where id=any(p_expired);
end$$;
revoke all on function public.claim_ride_push(text),public.settle_ride_push(text,uuid,boolean,uuid[]) from public;
grant execute on function public.claim_ride_push(text),public.settle_ride_push(text,uuid,boolean,uuid[]) to anon;
revoke all on all functions in schema vr_private from public,anon;

create or replace function vr_private.can_view_person(uid uuid) returns boolean
language sql stable security definer set search_path='' as $$
select auth.uid() is not null and (uid=auth.uid() or exists(select 1 from public.community_profiles c where c.user_id=uid and c.visible)
or exists(select 1 from public.driver_profiles d where d.user_id=uid and d.verified)
or exists(select 1 from public.bookings b join public.trips t on t.id=b.trip_id where b.status in ('requested','confirmed','completed') and ((b.passenger_id=auth.uid() and t.driver_id=uid) or (t.driver_id=auth.uid() and b.passenger_id=uid)))
or (exists(select 1 from public.driver_profiles d where d.user_id=auth.uid() and d.verified) and exists(select 1 from public.ride_requests r where r.passenger_id=uid and r.status='searching' and r.travel_date>=current_date)));
$$;
create function public.refresh_departure_reminders() returns void language plpgsql security definer set search_path='' as $$
begin
if auth.uid() is null then raise exception 'Sign in required';end if;
insert into public.ride_notifications(user_id,kind,title,body,booking_id,trip_id,dedupe_key)
select auth.uid(),'departure_reminder','Your ride departs soon','Open your booking to confirm the pickup.',b.id,t.id,'departure:'||b.id||':'||auth.uid()
from public.bookings b join public.trips t on t.id=b.trip_id where auth.uid() in (b.passenger_id,t.driver_id)
and b.status='confirmed' and b.pickup_status='waiting' and t.departure_at between now() and now()+interval '30 minutes' on conflict(dedupe_key) do nothing;
end$$;
revoke all on function public.refresh_departure_reminders() from public,anon;grant execute on function public.refresh_departure_reminders() to authenticated;
revoke all on function public.claim_ride_push(text),public.settle_ride_push(text,uuid,boolean,uuid[]) from anon,authenticated;
