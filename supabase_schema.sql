-- ============================================================
-- TripJio Supabase Schema — Run this in Supabase SQL Editor
-- ============================================================

-- USERS table
create table if not exists public.users (
  id text primary key,                  -- Firebase UID
  phone text not null,
  name text not null,
  user_type text not null check (user_type in ('driver', 'load_owner')),
  company_name text,
  city text,
  profile_photo_url text,
  created_at timestamptz not null default now()
);

-- DRIVERS table
create table if not exists public.drivers (
  user_id text primary key references public.users(id) on delete cascade,
  license_number text not null,
  experience text not null,
  is_online boolean not null default false,
  latitude double precision,
  longitude double precision,
  rating numeric(3,2) not null default 0.0,
  total_trips integer not null default 0,
  updated_at timestamptz not null default now()
);

-- VEHICLES table
create table if not exists public.vehicles (
  id text primary key,
  user_id text not null references public.users(id) on delete cascade,
  vehicle_number text not null,
  vehicle_type text not null check (vehicle_type in ('Mini Truck','LCV','HCV','Container')),
  photo_url text,
  created_at timestamptz not null default now()
);

-- TRIPS table
create table if not exists public.trips (
  id uuid primary key default gen_random_uuid(),
  load_owner_id text not null references public.users(id),
  driver_id text not null references public.users(id),
  pickup_address text not null,
  drop_address text not null,
  pickup_lat double precision not null,
  pickup_lng double precision not null,
  drop_lat double precision not null,
  drop_lng double precision not null,
  status text not null default 'pending'
    check (status in ('pending','accepted','in_progress','completed','cancelled')),
  distance_km numeric(8,2),
  goods_description text,
  weight_kg numeric(8,2),
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  pickup_confirmed_at timestamptz
);

-- REQUESTS table
create table if not exists public.requests (
  id uuid primary key default gen_random_uuid(),
  load_owner_id text not null references public.users(id),
  driver_id text not null references public.users(id),
  pickup_address text not null,
  drop_address text not null,
  pickup_lat double precision not null,
  pickup_lng double precision not null,
  drop_lat double precision not null,
  drop_lng double precision not null,
  goods_description text,
  weight_kg numeric(8,2),
  status text not null default 'pending'
    check (status in ('pending','accepted','rejected','expired')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '2 minutes')
);

-- ============================================================
-- Row Level Security (RLS) — Enable for all tables
-- ============================================================
alter table public.users enable row level security;
alter table public.drivers enable row level security;
alter table public.vehicles enable row level security;
alter table public.trips enable row level security;
alter table public.requests enable row level security;

-- ============================================================
-- NO POLICIES ARE DEFINED HERE ON PURPOSE.
--
-- RLS is enabled above, which means until real policies exist,
-- authenticated/anon requests get zero rows — a safe default.
--
-- The real, owner-scoped policies + hardened RPCs live in
-- `supabase_auth_hardening.sql` (run LAST). Do not add
-- `USING (true)` policies here as a temporary shortcut: they
-- expose every user's data to any anon-key holder.
-- ============================================================
