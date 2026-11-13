-- Parkline dashboard schema for the Smart Parking Supabase project.
-- Run this in that project's SQL Editor only after confirming the project ref.
-- The local Flask dashboard uses a server-side secret key; keep it out of Git.

create table if not exists public.parking_users (
  id uuid primary key default gen_random_uuid(),
  full_name text not null check (char_length(btrim(full_name)) between 2 and 120),
  email text,
  phone text,
  vehicle_plate text not null check (char_length(btrim(vehicle_plate)) between 2 and 24),
  rfid_uid text not null unique check (char_length(btrim(rfid_uid)) between 4 and 40),
  is_active boolean not null default true,
  current_status text not null default 'OUTSIDE' check (current_status in ('INSIDE', 'OUTSIDE')),
  created_at timestamptz not null default now()
);

create table if not exists public.parking_events (
  id uuid primary key default gen_random_uuid(),
  parking_user_id uuid references public.parking_users(id) on delete set null,
  user_name text,
  vehicle_plate text,
  card_uid text not null,
  direction text not null check (direction in ('ENTRY', 'EXIT')),
  access_status text not null default 'GRANTED' check (access_status in ('GRANTED', 'DENIED')),
  card_tapped_at timestamptz not null default now(),
  vehicle_passed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists parking_users_created_at_idx
  on public.parking_users (created_at desc);
create index if not exists parking_users_current_status_idx
  on public.parking_users (current_status);
create index if not exists parking_events_card_tapped_at_idx
  on public.parking_events (card_tapped_at desc);
create index if not exists parking_events_direction_card_tapped_at_idx
  on public.parking_events (direction, card_tapped_at desc);
create index if not exists parking_events_card_uid_idx
  on public.parking_events (card_uid);

alter table public.parking_users enable row level security;
alter table public.parking_events enable row level security;

-- No anon/authenticated policies are created. Dashboard access goes through
-- the Flask backend and a server-side Supabase secret key.
grant select, insert, update on public.parking_users to service_role;
grant select, insert, update on public.parking_events to service_role;
grant usage on schema public to service_role;

create or replace function public.sync_parking_user_status_from_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.parking_user_id is not null
     and new.access_status = 'GRANTED'
     and new.vehicle_passed_at is not null then
    update public.parking_users
       set current_status = case new.direction
                              when 'ENTRY' then 'INSIDE'
                              else 'OUTSIDE'
                            end
     where id = new.parking_user_id;
  end if;
  return new;
end;
$$;

revoke all on function public.sync_parking_user_status_from_event() from public;
grant execute on function public.sync_parking_user_status_from_event() to service_role;

drop trigger if exists parking_event_sync_user_status on public.parking_events;
create trigger parking_event_sync_user_status
  after insert or update of access_status, vehicle_passed_at
  on public.parking_events
  for each row execute function public.sync_parking_user_status_from_event();
