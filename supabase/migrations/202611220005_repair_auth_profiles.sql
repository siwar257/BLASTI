-- Ensure new Auth users receive a passenger profile, and repair users created
-- before the profile trigger was installed.
create or replace function public.create_passenger_profile()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  profile_name text;
begin
  profile_name := left(btrim(coalesce(new.raw_user_meta_data->>'full_name', '')), 80);
  if length(profile_name) < 2 then
    profile_name := left(btrim(split_part(coalesce(new.email, ''), '@', 1)), 80);
  end if;
  if length(profile_name) < 2 then
    profile_name := 'Passager BLASTI';
  end if;

  insert into public.profiles(id, full_name, role)
  values (new.id, profile_name, 'passenger')
  on conflict (id) do nothing;
  return new;
end;
$$;
revoke all on function public.create_passenger_profile() from public, anon, authenticated;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
after insert on auth.users
for each row execute function public.create_passenger_profile();

insert into public.profiles(id, full_name, role)
select
  u.id,
  case
    when length(left(btrim(coalesce(u.raw_user_meta_data->>'full_name', '')), 80)) >= 2
      then left(btrim(u.raw_user_meta_data->>'full_name'), 80)
    when length(left(btrim(split_part(coalesce(u.email, ''), '@', 1)), 80)) >= 2
      then left(btrim(split_part(coalesce(u.email, ''), '@', 1)), 80)
    else 'Passager BLASTI'
  end,
  'passenger'::public.app_role
from auth.users u
where not exists (
  select 1 from public.profiles p where p.id = u.id
)
on conflict (id) do nothing;
