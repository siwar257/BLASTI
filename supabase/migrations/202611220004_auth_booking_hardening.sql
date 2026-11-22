-- Harden identity, reservation writes, and fare validation for authenticated clients.
create or replace function public.current_app_role()
returns public.app_role
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select role from public.profiles where id = auth.uid()
$$;
revoke all on function public.current_app_role() from public, anon;
grant execute on function public.current_app_role() to authenticated;

alter function public.create_passenger_profile() set search_path = pg_catalog, public;
alter function public.validate_profile_input() set search_path = pg_catalog, public;
alter function public.refresh_departure_reserved_seats() set search_path = pg_catalog, public;
alter function public.notify_driver_of_reservation() set search_path = pg_catalog, public;
alter function public.check_in_reservation(text, uuid) set search_path = pg_catalog, public;
alter function public.mark_passenger_alighted(text, text) set search_path = pg_catalog, public;
alter function public.start_departure(uuid) set search_path = pg_catalog, public;

create or replace function public.prevent_profile_role_change()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
begin
  if new.role is distinct from old.role
     and coalesce(auth.role(), '') <> 'service_role'
     and current_user not in ('postgres', 'supabase_admin') then
    raise exception 'ROLE_CHANGE_REQUIRES_TRUSTED_ADMIN';
  end if;
  return new;
end;
$$;
drop trigger if exists profiles_prevent_role_change on public.profiles;
create trigger profiles_prevent_role_change
before update of role on public.profiles
for each row execute function public.prevent_profile_role_change();
revoke all on function public.prevent_profile_role_change() from public, anon, authenticated;

update public.profiles
set full_name = left(btrim(full_name), 80)
where length(btrim(full_name)) > 80;
update public.profiles
set full_name = 'Passager BLASTI'
where length(btrim(full_name)) < 2;
alter table public.profiles
  drop constraint if exists profiles_full_name_check,
  add constraint profiles_full_name_check check (length(btrim(full_name)) between 2 and 80);

drop policy if exists "Users view own profile" on public.profiles;
drop policy if exists "Users update own profile" on public.profiles;
create policy "Users view permitted profiles" on public.profiles
for select to authenticated
using (
  id = (select auth.uid())
  or exists (
    select 1
    from public.reservations r
    join public.departures d on d.id = r.departure_id
    where r.passenger_id = profiles.id
      and d.operator_id = (select auth.uid())
  )
  or public.current_app_role() = 'admin'
);
create policy "Users update own profile name" on public.profiles
for update to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));
revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant update (full_name) on public.profiles to authenticated;

alter table public.departures
  drop constraint if exists departures_fare_check,
  add constraint departures_fare_check check (fare >= 0 and fare <= 2.50);

create or replace function public.create_departure(
  p_origin text,
  p_destination text,
  p_departure_at timestamptz,
  p_fare numeric
)
returns public.departures
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  route_row public.routes;
  vehicle_row public.vehicles;
  created public.departures;
begin
  if auth.uid() is null or (
    public.current_app_role() is distinct from 'operator'::public.app_role
    and public.current_app_role() is distinct from 'admin'::public.app_role
  ) then
    raise exception 'DRIVER_LOGIN_REQUIRED';
  end if;
  if length(btrim(coalesce(p_origin, ''))) not between 2 and 80
     or length(btrim(coalesce(p_destination, ''))) not between 2 and 80 then
    raise exception 'ROUTE_INPUT_INVALID';
  end if;
  if p_fare is null or p_fare < 0 or p_fare > 2.50 then
    raise exception 'FARE_LIMIT_2_5_DINARS';
  end if;
  if p_departure_at is null or p_departure_at <= now() then
    raise exception 'DEPARTURE_TIME_MUST_BE_FUTURE';
  end if;

  select * into route_row
  from public.routes
  where origin_name = btrim(p_origin)
    and destination = btrim(p_destination)
    and active = true
  limit 1;
  if not found then raise exception 'ROUTE_NOT_AVAILABLE'; end if;

  select * into vehicle_row
  from public.vehicles
  where operator_id = auth.uid() and active = true
  order by created_at
  limit 1
  for update;
  if not found then raise exception 'NO_ACTIVE_VEHICLE_ASSIGNED'; end if;

  insert into public.departures(route_id, vehicle_id, operator_id, departure_at, fare, status)
  values (route_row.id, vehicle_row.id, auth.uid(), p_departure_at, p_fare, 'scheduled')
  returning * into created;
  return created;
end;
$$;
revoke all on function public.create_departure(text, text, timestamptz, numeric) from public, anon;
grant execute on function public.create_departure(text, text, timestamptz, numeric) to authenticated;

create or replace function public.reserve_seat(
  p_departure_id uuid,
  p_seat_number integer,
  p_origin_stop text default null,
  p_destination_stop text default null
)
returns public.reservations
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  departure_row public.departures;
  capacity integer;
  existing_count integer;
  slot_number integer;
  start_at timestamptz;
  created public.reservations;
begin
  if auth.uid() is null or public.current_app_role() is distinct from 'passenger'::public.app_role then
    raise exception 'PASSENGER_LOGIN_REQUIRED';
  end if;
  if p_departure_id is null or p_seat_number is null or p_seat_number < 1 then
    raise exception 'RESERVATION_INPUT_INVALID';
  end if;
  if (p_origin_stop is not null and length(btrim(p_origin_stop)) not between 2 and 80)
     or (p_destination_stop is not null and length(btrim(p_destination_stop)) not between 2 and 80) then
    raise exception 'STOP_INPUT_INVALID';
  end if;

  select * into departure_row
  from public.departures
  where id = p_departure_id and status in ('scheduled', 'boarding')
  for update;
  if not found then raise exception 'DEPARTURE_NOT_AVAILABLE'; end if;
  select v.capacity into capacity from public.vehicles v where v.id = departure_row.vehicle_id;
  if p_seat_number > capacity then raise exception 'INVALID_SEAT'; end if;
  if exists (
    select 1 from public.reservations
    where departure_id = p_departure_id
      and passenger_id = auth.uid()
      and status in ('pending', 'confirmed', 'checked_in')
  ) then raise exception 'ACTIVE_RESERVATION_EXISTS'; end if;
  if exists (
    select 1 from public.reservations
    where departure_id = p_departure_id
      and seat_number = p_seat_number
      and status in ('pending', 'confirmed', 'checked_in')
  ) then raise exception 'SEAT_ALREADY_TAKEN'; end if;

  select count(*)::integer into existing_count
  from public.reservations
  where departure_id = p_departure_id and status in ('confirmed', 'checked_in');
  slot_number := existing_count / greatest(departure_row.boarding_group_size, 1);
  start_at := departure_row.departure_at
    - make_interval(mins => 10)
    + make_interval(mins => slot_number * greatest(departure_row.boarding_window_minutes, 1));
  insert into public.reservations(
    departure_id, passenger_id, seat_number, boarding_slot, boarding_start, boarding_end, status
  )
  values (
    departure_row.id, auth.uid(), p_seat_number, slot_number, start_at,
    start_at + make_interval(mins => greatest(departure_row.boarding_window_minutes, 1)), 'confirmed'
  )
  returning * into created;
  update public.reservations
  set origin_stop = coalesce(nullif(btrim(p_origin_stop), ''), departure_row.current_stop),
      destination_stop = nullif(btrim(p_destination_stop), '')
  where id = created.id
  returning * into created;
  return created;
end;
$$;
revoke all on function public.reserve_seat(uuid, integer, text, text) from public, anon;
grant execute on function public.reserve_seat(uuid, integer, text, text) to authenticated;

create or replace function public.cancel_reservation(p_reference text)
returns public.reservations
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare changed public.reservations;
begin
  if auth.uid() is null or public.current_app_role() is distinct from 'passenger'::public.app_role then
    raise exception 'PASSENGER_LOGIN_REQUIRED';
  end if;
  update public.reservations
  set status = 'cancelled', updated_at = now()
  where reference = upper(btrim(coalesce(p_reference, '')))
    and passenger_id = auth.uid()
    and status in ('confirmed', 'waitlisted')
  returning * into changed;
  if not found then raise exception 'RESERVATION_NOT_CANCELLABLE'; end if;
  return changed;
end;
$$;
revoke all on function public.cancel_reservation(text) from public, anon;
grant execute on function public.cancel_reservation(text) to authenticated;

create or replace function public.join_waiting_list(p_departure_id uuid)
returns public.waiting_list
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  departure_row public.departures;
  created public.waiting_list;
  next_position integer;
begin
  if auth.uid() is null or public.current_app_role() is distinct from 'passenger'::public.app_role then
    raise exception 'PASSENGER_LOGIN_REQUIRED';
  end if;
  select * into departure_row
  from public.departures
  where id = p_departure_id and status in ('scheduled', 'boarding')
  for update;
  if not found then raise exception 'DEPARTURE_NOT_AVAILABLE'; end if;
  if exists (
    select 1 from public.reservations
    where departure_id = p_departure_id
      and passenger_id = auth.uid()
      and status in ('pending', 'confirmed', 'checked_in')
  ) then raise exception 'ACTIVE_RESERVATION_EXISTS'; end if;
  select coalesce(max(position), 0) + 1 into next_position
  from public.waiting_list where departure_id = p_departure_id;
  insert into public.waiting_list(departure_id, passenger_id, position)
  values (p_departure_id, auth.uid(), next_position)
  returning * into created;
  return created;
end;
$$;
revoke all on function public.join_waiting_list(uuid) from public, anon;
grant execute on function public.join_waiting_list(uuid) to authenticated;

revoke insert, update, delete on public.reservations from anon, authenticated;
grant select on public.reservations to authenticated;
revoke insert, update, delete on public.waiting_list from anon, authenticated;
grant select on public.waiting_list to authenticated;

drop policy if exists "Users update own notifications" on public.notifications;
create policy "Users mark own notifications read" on public.notifications
for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));
revoke all on public.notifications from anon, authenticated;
grant select on public.notifications to authenticated;
grant update (read_at) on public.notifications to authenticated;
alter table public.notifications replica identity full;
do $$ begin
  alter publication supabase_realtime add table public.notifications;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;
