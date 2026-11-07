begin;
create temp table community_test_ids(driver uuid,rider uuid,outsider uuid,vehicle uuid,trip uuid,booking uuid,request uuid);
insert into community_test_ids select d.user_id,p.id,o.id,gen_random_uuid(),gen_random_uuid(),null,gen_random_uuid() from public.driver_profiles d cross join public.profiles p cross join public.profiles o where d.verified and p.id<>d.user_id and o.id<>d.user_id and o.id<>p.id limit 1;
grant all on community_test_ids to authenticated;
insert into public.vehicles(id,driver_id,make,model,registration,seat_capacity,approved) select vehicle,driver,'Test','Vehicle','TEST',6,true from community_test_ids;
insert into public.trips(id,vehicle_id,driver_id,origin,destination,departure_at,service_type,price_per_seat,seats_total,seats_available,pickup_point,status) select trip,vehicle,driver,'Test origin','Test destination',now()+interval '1 day','morning',500,6,6,'Test pickup','published' from community_test_ids;
set local role authenticated;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select rider from community_test_ids),'role','authenticated')::text,true);
insert into public.community_profiles(user_id,display_name,visible) select rider,'Passenger test',false from community_test_ids;
insert into public.route_watches(user_id,origin,destination) select rider,'Test origin','Test destination' from community_test_ids;
insert into public.ride_alert_settings(user_id,driver_alerts) select rider,false from community_test_ids;
insert into public.ride_requests(id,passenger_id,origin,destination,travel_date,service_type,seats,status) select request,rider,'Test origin','Test destination',((now()+interval '1 day') at time zone 'Africa/Johannesburg')::date,'morning',1,'searching' from community_test_ids;
update community_test_ids set booking=public.request_booking(trip,1,'Test pickup',false);
do $$begin
 if exists(select 1 from public.ride_messages) then raise exception 'Unexpected messages visible';end if;
 begin insert into public.ride_messages(booking_id,sender_id,body) select booking,rider,'Must be rejected before acceptance' from community_test_ids;raise exception 'Pre-acceptance chat was allowed';exception when insufficient_privilege then null;when raise_exception then if sqlerrm<>'Chat is available after acceptance only' then raise;end if;end;
 begin insert into public.ride_notifications(user_id,kind,title) select outsider,'forged','Must reject' from community_test_ids;raise exception 'Client notification spoofing was allowed';exception when insufficient_privilege then null;end;
end$$;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select driver from community_test_ids),'role','authenticated')::text,true);
do $$begin
 if (select count(*) from public.ride_notifications where kind='booking_requested')<>1 then raise exception 'Driver did not receive booking request';end if;
 perform public.publish_trip((select vehicle from community_test_ids),'Test origin','Test destination',now()+interval '1 day','morning',6,'Test pickup','Route matching test');
 perform public.accept_booking((select booking from community_test_ids));
 perform public.set_pickup_status((select booking from community_test_ids),'driver_arriving');
 insert into public.ride_messages(booking_id,sender_id,body) select booking,driver,'Accepted journey test message' from community_test_ids;
end$$;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select rider from community_test_ids),'role','authenticated')::text,true);
do $$begin
 if not exists(select 1 from public.ride_notifications where kind='ride_published') then raise exception 'Matching route did not produce an alert';end if;
 if not exists(select 1 from public.ride_requests r join community_test_ids t on r.id=t.request where r.status='already_taken') then raise exception 'Accepted booking did not close matching request';end if;
 if (select count(*) from public.ride_messages where body='Accepted journey test message')<>1 then raise exception 'Passenger cannot see accepted chat';end if;
 if (select count(*) from public.ride_notifications where kind='message')<>1 then raise exception 'Passenger did not receive chat notification';end if;
 begin perform public.set_pickup_status((select booking from community_test_ids),'picked_up');raise exception 'Passenger modified driver pickup status';exception when raise_exception then if sqlerrm='Passenger modified driver pickup status' then raise;end if;end;
end$$;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select outsider from community_test_ids),'role','authenticated')::text,true);
do $$begin
 if exists(select 1 from public.ride_messages) then raise exception 'Unrelated user can read chat';end if;
 if exists(select 1 from public.ride_notifications) then raise exception 'Unrelated user can read notifications';end if;
 begin perform public.community_person((select rider from community_test_ids));raise exception 'Private profile leaked to outsider';exception when raise_exception then if sqlerrm='Private profile leaked to outsider' then raise;end if;end;
 begin perform public.claim_ride_push('wrong-token');raise exception 'Authenticated user can access push worker';exception when insufficient_privilege then null;end;
end$$;
reset role;
select 'PASS: booking access, accepted-only chat, notification isolation, private profiles, pickup permissions, push worker restrictions' as result;
rollback;