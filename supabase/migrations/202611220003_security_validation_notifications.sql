-- BLASTI business rules: validated inputs, fare ceiling, and driver booking alerts.
alter table public.departures drop constraint if exists departures_fare_check;
alter table public.departures add constraint departures_fare_check check (fare >= 0 and fare <= 2.50);

create or replace function public.validate_profile_input()
returns trigger language plpgsql set search_path=public,pg_temp as $$
begin
  if length(trim(new.full_name)) < 2 or length(trim(new.full_name)) > 80 then
    raise exception 'FULL_NAME_INVALID';
  end if;
  new.full_name := trim(new.full_name);
  return new;
end; $$;
drop trigger if exists profiles_validate_input on public.profiles;
create trigger profiles_validate_input before insert or update of full_name on public.profiles
for each row execute function public.validate_profile_input();

create or replace function public.create_departure(p_origin text,p_destination text,p_departure_at timestamptz,p_fare numeric)
returns public.departures language plpgsql security definer set search_path=public,pg_temp as $$
declare route_row public.routes; vehicle_row public.vehicles; created public.departures;
begin
 if auth.uid() is null or public.current_app_role() not in ('operator','admin') then raise exception 'DRIVER_LOGIN_REQUIRED'; end if;
 if p_fare is null or p_fare < 0 or p_fare > 2.50 then raise exception 'FARE_LIMIT_2_5_DINARS'; end if;
 if length(trim(coalesce(p_origin,''))) < 2 or length(trim(coalesce(p_destination,''))) < 2 then raise exception 'ROUTE_INPUT_INVALID'; end if;
 select * into route_row from public.routes where origin_name=trim(p_origin) and destination=trim(p_destination) and active=true limit 1;
 if not found then raise exception 'ROUTE_NOT_AVAILABLE'; end if;
 select * into vehicle_row from public.vehicles where operator_id=auth.uid() and active=true limit 1 for update;
 if not found then raise exception 'NO_ACTIVE_VEHICLE_ASSIGNED'; end if;
 if p_departure_at<=now() then raise exception 'DEPARTURE_TIME_MUST_BE_FUTURE'; end if;
 insert into public.departures(route_id,vehicle_id,operator_id,departure_at,fare,status)
 values(route_row.id,vehicle_row.id,auth.uid(),p_departure_at,p_fare,'scheduled') returning * into created;
 return created;
end; $$;
revoke all on function public.create_departure(text,text,timestamptz,numeric) from public,anon;
grant execute on function public.create_departure(text,text,timestamptz,numeric) to authenticated;

create or replace function public.notify_driver_of_reservation()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare driver_id uuid; destination_name text;
begin
 select d.operator_id,r.destination into driver_id,destination_name
 from public.departures d join public.routes r on r.id=d.route_id where d.id=new.departure_id;
 if driver_id is not null then
   insert into public.notifications(user_id,title,body,kind)
   values(driver_id,'Reservation jdida', 'Mousfer 7جز blasa lel '||coalesce(destination_name,'trajet')||' · code '||new.reference, 'new_reservation');
 end if;
 return new;
end; $$;
revoke all on function public.notify_driver_of_reservation() from public,anon,authenticated;
drop trigger if exists reservation_driver_notification on public.reservations;
create trigger reservation_driver_notification after insert on public.reservations
for each row when (new.status in ('pending','confirmed')) execute function public.notify_driver_of_reservation();

grant select on public.notifications to authenticated;
alter table public.notifications replica identity full;
do $$ begin alter publication supabase_realtime add table public.notifications;
exception when duplicate_object then null; when undefined_object then null; end $$;
