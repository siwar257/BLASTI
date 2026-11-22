-- Live seat counts and approximate pilot-map points for Sousse.
-- Coordinates below are illustrative city/station approximations; never use as dispatch-grade GPS.
alter table public.routes add column if not exists origin_name text not null default 'Bab Bhar';
alter table public.routes add column if not exists origin_lat double precision not null default 35.8254;
alter table public.routes add column if not exists origin_lng double precision not null default 10.6370;
alter table public.routes add column if not exists destination_lat double precision not null default 35.7290;
alter table public.routes add column if not exists destination_lng double precision not null default 10.5800;
alter table public.vehicles add column if not exists operator_id uuid references public.profiles(id);
alter table public.departures add column if not exists reserved_seats integer not null default 0 check(reserved_seats>=0);
alter table public.departures add column if not exists current_stop text;
alter table public.departures add column if not exists current_lat double precision;
alter table public.departures add column if not exists current_lng double precision;
alter table public.reservations add column if not exists alighted_at timestamptz;
alter table public.reservations add column if not exists alighted_at_stop text;
alter table public.reservations add column if not exists origin_stop text;
alter table public.reservations add column if not exists destination_stop text;

create or replace function public.create_passenger_profile()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
 insert into public.profiles(id,full_name,role)
 values(new.id,coalesce(nullif(trim(new.raw_user_meta_data->>'full_name'),''),split_part(coalesce(new.email,''),'@',1)),'passenger')
 on conflict(id) do nothing;
 return new;
end; $$;
revoke all on function public.create_passenger_profile() from public,anon,authenticated;
drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile after insert on auth.users for each row execute function public.create_passenger_profile();

-- Replace the original all-status uniqueness rule so a completed passenger's seat can be reused.
alter table public.reservations drop constraint if exists reservations_departure_id_seat_number_key;
create unique index if not exists reservations_active_seat_unique on public.reservations(departure_id,seat_number) where seat_number is not null and status in ('pending','confirmed','checked_in');
create index if not exists vehicles_operator_active_idx on public.vehicles(operator_id) where active;

insert into public.stations(name,city) values
 ('Bab Bhar','Sousse'),('M''saken','Sousse'),('Monastir','Monastir'),('Sahloul','Sousse'),('Hergla','Sousse')
on conflict do nothing;

insert into public.routes(origin_station_id,destination,origin_name,origin_lat,origin_lng,destination_lat,destination_lng)
select o.id,d.destination,'Bab Bhar',35.8254,10.6370,d.lat,d.lng
from public.stations o cross join (values
 ('M''saken',35.7290,10.5800),('Monastir',35.7770,10.8260),('Sahloul',35.8370,10.6100),('Hergla',36.0290,10.5090)
) as d(destination,lat,lng)
where o.name='Bab Bhar' and o.city='Sousse'
on conflict(origin_station_id,destination) do update set origin_name=excluded.origin_name,origin_lat=excluded.origin_lat,origin_lng=excluded.origin_lng,destination_lat=excluded.destination_lat,destination_lng=excluded.destination_lng;

update public.departures d set reserved_seats=s.n
from (select departure_id,count(*)::integer as n from public.reservations where status in ('confirmed','checked_in') group by departure_id) s
where d.id=s.departure_id;

create or replace function public.refresh_departure_reserved_seats()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare target_id uuid;
begin
 target_id:=coalesce(new.departure_id,old.departure_id);
 update public.departures d set reserved_seats=(select count(*)::integer from public.reservations r where r.departure_id=target_id and r.status in ('confirmed','checked_in')) where d.id=target_id;
 if TG_OP='DELETE' then return old; else return new; end if;
end; $$;
revoke all on function public.refresh_departure_reserved_seats() from public,anon,authenticated;
drop trigger if exists reservations_refresh_live_count on public.reservations;
create trigger reservations_refresh_live_count after insert or update of status,departure_id or delete on public.reservations for each row execute function public.refresh_departure_reserved_seats();

create or replace function public.reserve_seat(p_departure_id uuid,p_seat_number integer,p_origin_stop text default null,p_destination_stop text default null)
returns public.reservations language plpgsql security definer set search_path=public,pg_temp as $$
declare d public.departures; existing integer; slot_no integer; start_at timestamptz; created public.reservations;
begin
 if auth.uid() is null or public.current_app_role()<>'passenger' then raise exception 'PASSENGER_LOGIN_REQUIRED'; end if;
 select * into d from public.departures where id=p_departure_id and status in ('scheduled','boarding') for update;
 if not found then raise exception 'DEPARTURE_NOT_AVAILABLE'; end if;
 if p_seat_number<1 or p_seat_number>(select capacity from public.vehicles where id=d.vehicle_id) then raise exception 'INVALID_SEAT'; end if;
 select count(*)::integer into existing from public.reservations where departure_id=d.id and status in ('confirmed','checked_in');
 if exists(select 1 from public.reservations where departure_id=d.id and seat_number=p_seat_number and status in ('pending','confirmed','checked_in')) then raise exception 'SEAT_ALREADY_TAKEN'; end if;
 slot_no:=existing/greatest(d.boarding_group_size,1);
 start_at:=d.departure_at- make_interval(mins=>10)+make_interval(mins=>slot_no*greatest(d.boarding_window_minutes,1));
 insert into public.reservations(departure_id,passenger_id,seat_number,boarding_slot,boarding_start,boarding_end,status)
 values(d.id,auth.uid(),p_seat_number,slot_no,start_at,start_at+make_interval(mins=>greatest(d.boarding_window_minutes,1)),'confirmed') returning * into created;
 update public.reservations set origin_stop=coalesce(nullif(trim(p_origin_stop),''),d.current_stop),destination_stop=nullif(trim(p_destination_stop),'') where id=created.id returning * into created;
 return created;
end; $$;
revoke all on function public.reserve_seat(uuid,integer,text,text) from public,anon;
grant execute on function public.reserve_seat(uuid,integer,text,text) to authenticated;

create or replace function public.check_in_reservation(p_reference text,p_departure_id uuid)
returns public.reservations language plpgsql security definer set search_path=public,pg_temp as $$
declare found_row public.reservations;
begin
 if auth.uid() is null or public.current_app_role() not in ('operator','admin') then raise exception 'DRIVER_LOGIN_REQUIRED'; end if;
 update public.reservations r set status='checked_in',checked_in_at=now(),updated_at=now()
 where r.reference=upper(trim(p_reference)) and r.departure_id=p_departure_id and r.status='confirmed'
 and exists(select 1 from public.departures d where d.id=r.departure_id and (d.operator_id=auth.uid() or public.current_app_role()='admin'))
 returning r.* into found_row;
 if not found then raise exception 'TICKET_NOT_VALID_FOR_THIS_TRIP'; end if;
 return found_row;
end; $$;
revoke all on function public.check_in_reservation(text,uuid) from public,anon;
grant execute on function public.check_in_reservation(text,uuid) to authenticated;

create or replace function public.mark_passenger_alighted(p_reference text,p_stop text)
returns public.reservations language plpgsql security definer set search_path=public,pg_temp as $$
declare found_row public.reservations;
begin
 if auth.uid() is null or public.current_app_role() not in ('operator','admin') then raise exception 'DRIVER_LOGIN_REQUIRED'; end if;
 if length(trim(coalesce(p_stop,'')))<2 then raise exception 'STOP_REQUIRED'; end if;
 update public.reservations r set status='completed',alighted_at=now(),alighted_at_stop=trim(p_stop),updated_at=now()
 where r.reference=upper(trim(p_reference)) and r.status='checked_in'
 and exists(select 1 from public.departures d where d.id=r.departure_id and (d.operator_id=auth.uid() or public.current_app_role()='admin'))
 returning r.* into found_row;
 if not found then raise exception 'PASSENGER_NOT_ON_BOARD'; end if;
 update public.departures d set current_stop=trim(p_stop),current_lat=case trim(p_stop) when 'Bab Bhar' then 35.8254 when 'M''saken' then 35.7290 when 'Monastir' then 35.7770 when 'Sahloul' then 35.8370 when 'Hergla' then 36.0290 else d.current_lat end,current_lng=case trim(p_stop) when 'Bab Bhar' then 10.6370 when 'M''saken' then 10.5800 when 'Monastir' then 10.8260 when 'Sahloul' then 10.6100 when 'Hergla' then 10.5090 else d.current_lng end where d.id=found_row.departure_id;
 return found_row;
end; $$;
revoke all on function public.mark_passenger_alighted(text,text) from public,anon;
grant execute on function public.mark_passenger_alighted(text,text) to authenticated;

create or replace function public.create_departure(p_origin text,p_destination text,p_departure_at timestamptz,p_fare numeric)
returns public.departures language plpgsql security definer set search_path=public,pg_temp as $$
declare route_row public.routes; vehicle_row public.vehicles; created public.departures;
begin
 if auth.uid() is null or public.current_app_role() not in ('operator','admin') then raise exception 'DRIVER_LOGIN_REQUIRED'; end if;
 select * into route_row from public.routes where origin_name=trim(p_origin) and destination=trim(p_destination) and active=true limit 1;
 if not found then raise exception 'ROUTE_NOT_AVAILABLE'; end if;
 select * into vehicle_row from public.vehicles where operator_id=auth.uid() and active=true limit 1 for update;
 if not found then raise exception 'NO_ACTIVE_VEHICLE_ASSIGNED'; end if;
 if p_departure_at<=now() then raise exception 'DEPARTURE_TIME_MUST_BE_FUTURE'; end if;
 insert into public.departures(route_id,vehicle_id,operator_id,departure_at,fare,status)
 values(route_row.id,vehicle_row.id,auth.uid(),p_departure_at,greatest(p_fare,0),'scheduled') returning * into created;
 return created;
end; $$;
revoke all on function public.create_departure(text,text,timestamptz,numeric) from public,anon;
grant execute on function public.create_departure(text,text,timestamptz,numeric) to authenticated;

create or replace function public.start_departure(p_departure_id uuid)
returns public.departures language plpgsql security definer set search_path=public,pg_temp as $$
declare changed public.departures;
begin
 if auth.uid() is null or public.current_app_role() not in ('operator','admin') then raise exception 'DRIVER_LOGIN_REQUIRED'; end if;
 update public.departures set status='boarding',current_stop=coalesce(current_stop,(select origin_name from public.routes where id=route_id)),updated_at=now()
 where id=p_departure_id and status='scheduled' and (operator_id=auth.uid() or public.current_app_role()='admin') returning * into changed;
 if not found then raise exception 'DEPARTURE_NOT_AVAILABLE'; end if;
 return changed;
end; $$;
revoke all on function public.start_departure(uuid) from public,anon;
grant execute on function public.start_departure(uuid) to authenticated;

-- All live counts, route rows, and departure status changes are available to signed-in app users.
grant select on public.stations,public.routes,public.vehicles,public.departures to authenticated;
grant select,insert,update on public.reservations to authenticated;
grant select,insert,update on public.waiting_list to authenticated;
alter table public.departures enable row level security;
create policy "Authenticated users read pilot routes" on public.routes for select to authenticated using(true);
create policy "Drivers manage assigned vehicles" on public.vehicles for all to authenticated using(operator_id=(select auth.uid()) or public.current_app_role()='admin') with check(operator_id=(select auth.uid()) or public.current_app_role()='admin');
create policy "Drivers insert their departures" on public.departures for insert to authenticated with check(operator_id=(select auth.uid()) and public.current_app_role() in ('operator','admin'));
create policy "Passengers view active departures and drivers see assigned" on public.departures for select to authenticated using(status in ('scheduled','boarding') or operator_id=(select auth.uid()) or public.current_app_role()='admin');
create policy "Passengers see own rows and operators see assigned riders" on public.reservations for select to authenticated using(passenger_id=(select auth.uid()) or exists(select 1 from public.departures d where d.id=departure_id and (d.operator_id=(select auth.uid()) or public.current_app_role()='admin')));
drop policy if exists "Passenger inserts own reservation" on public.reservations;
alter table public.reservations replica identity full;
alter table public.departures replica identity full;
alter table public.vehicles replica identity full;
do $$ begin
 alter publication supabase_realtime add table public.departures;
exception when duplicate_object then null; when undefined_object then null; end $$;
do $$ begin
 alter publication supabase_realtime add table public.reservations;
exception when duplicate_object then null; when undefined_object then null; end $$;
do $$ begin
 alter publication supabase_realtime add table public.vehicles;
exception when duplicate_object then null; when undefined_object then null; end $$;
