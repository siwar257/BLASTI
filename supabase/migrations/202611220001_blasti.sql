create extension if not exists pgcrypto;
create type public.app_role as enum ('passenger','operator','admin');
create type public.reservation_status as enum ('pending','confirmed','cancelled','waitlisted','checked_in','completed','expired');
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null,
 role public.app_role not null default 'passenger',
 station_id uuid,
 created_at timestamptz not null default now()
);
create table public.stations (id uuid primary key default gen_random_uuid(),name text not null,city text not null,created_at timestamptz not null default now());
create table public.routes (id uuid primary key default gen_random_uuid(),origin_station_id uuid not null references public.stations(id),destination text not null,active boolean not null default true,unique(origin_station_id,destination));
create table public.vehicles (id uuid primary key default gen_random_uuid(),station_id uuid not null references public.stations(id),label text not null,transport_type text not null check(transport_type in ('Louage','Bus','Taxi collectif')),capacity int not null check(capacity>0),active boolean not null default true);
alter table public.profiles add constraint profiles_station_fk foreign key(station_id) references public.stations(id);
create table public.departures (
 id uuid primary key default gen_random_uuid(),route_id uuid not null references public.routes(id),vehicle_id uuid not null references public.vehicles(id),operator_id uuid not null references public.profiles(id),departure_at timestamptz not null,fare numeric(8,2) not null check(fare>=0),boarding_group_size int not null default 4 check(boarding_group_size>0),boarding_window_minutes int not null default 5 check(boarding_window_minutes>0),status text not null default 'scheduled' check(status in ('scheduled','boarding','departed','cancelled')),created_at timestamptz not null default now()
);
create table public.reservations (
 id uuid primary key default gen_random_uuid(),reference text not null unique default ('BL-'||upper(substr(encode(gen_random_bytes(5),'hex'),1,5))),departure_id uuid not null references public.departures(id),passenger_id uuid not null references public.profiles(id),seat_number int,boarding_slot int,boarding_start timestamptz,boarding_end timestamptz,status public.reservation_status not null default 'pending',qr_token uuid not null default gen_random_uuid(),checked_in_at timestamptz,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),unique(departure_id,seat_number)
);
create table public.waiting_list (id uuid primary key default gen_random_uuid(),departure_id uuid not null references public.departures(id),passenger_id uuid not null references public.profiles(id),position int not null,offer_expires_at timestamptz,offered_at timestamptz,created_at timestamptz not null default now(),unique(departure_id,passenger_id),unique(departure_id,position));
create table public.notifications (id uuid primary key default gen_random_uuid(),user_id uuid not null references public.profiles(id) on delete cascade,title text not null,body text not null,kind text not null,read_at timestamptz,created_at timestamptz not null default now());
create index departures_time_idx on public.departures(departure_at) where status='scheduled';
create index reservations_departure_status_idx on public.reservations(departure_id,status);
create index reservations_passenger_idx on public.reservations(passenger_id,created_at desc);
create index waiting_list_order_idx on public.waiting_list(departure_id,position);
create index notifications_user_idx on public.notifications(user_id,created_at desc);
create or replace function public.current_app_role() returns public.app_role language sql stable security invoker set search_path=public as $$ select role from public.profiles where id=(select auth.uid()) $$;
alter table public.profiles enable row level security;
alter table public.stations enable row level security;
alter table public.routes enable row level security;
alter table public.vehicles enable row level security;
alter table public.departures enable row level security;
alter table public.reservations enable row level security;
alter table public.waiting_list enable row level security;
alter table public.notifications enable row level security;
create policy "Users view own profile" on public.profiles for select to authenticated using(id=(select auth.uid()) or public.current_app_role() in ('operator','admin'));
create policy "Users update own profile" on public.profiles for update to authenticated using(id=(select auth.uid())) with check(id=(select auth.uid()) and role=public.current_app_role());
create policy "Authenticated users read stations" on public.stations for select to authenticated using(true);
create policy "Authenticated users read routes" on public.routes for select to authenticated using(true);
create policy "Authenticated users read active vehicles" on public.vehicles for select to authenticated using(active or public.current_app_role() in ('operator','admin'));
create policy "Read scheduled departures" on public.departures for select to authenticated using(status='scheduled' or operator_id=(select auth.uid()) or public.current_app_role()='admin');
create policy "Assigned operator manages departures" on public.departures for all to authenticated using(operator_id=(select auth.uid()) or public.current_app_role()='admin') with check(operator_id=(select auth.uid()) or public.current_app_role()='admin');
create policy "Passenger views own reservations" on public.reservations for select to authenticated using(passenger_id=(select auth.uid()) or exists(select 1 from public.departures d where d.id=departure_id and (d.operator_id=(select auth.uid()) or public.current_app_role()='admin')));
create policy "Passenger inserts own reservation" on public.reservations for insert to authenticated with check(passenger_id=(select auth.uid()) and public.current_app_role()='passenger');
create policy "Passenger cancels own reservation" on public.reservations for update to authenticated using(passenger_id=(select auth.uid())) with check(passenger_id=(select auth.uid()) and status in ('confirmed','cancelled','waitlisted'));
create policy "Operators view departure waitlist" on public.waiting_list for select to authenticated using(passenger_id=(select auth.uid()) or exists(select 1 from public.departures d where d.id=departure_id and (d.operator_id=(select auth.uid()) or public.current_app_role()='admin')));
create policy "Passengers join waitlist" on public.waiting_list for insert to authenticated with check(passenger_id=(select auth.uid()) and public.current_app_role()='passenger');
create policy "Users view own notifications" on public.notifications for select to authenticated using(user_id=(select auth.uid()));
create policy "Users update own notifications" on public.notifications for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
-- Demo station and destination rows; departure/service times and fares are illustrative only.
insert into public.stations(name,city) values('Bab Bhar','Sousse');
