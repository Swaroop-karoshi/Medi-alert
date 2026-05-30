-- Medialert schema (Supabase-only)
-- NOTE: This migration recreates core tables.

create extension if not exists pgcrypto;

drop view if exists patient_adherence_view cascade;
drop table if exists medicine_logs cascade;
drop table if exists patient_prescriptions cascade;
drop table if exists prescription_items cascade;
drop table if exists prescriptions cascade;
drop table if exists doctor_patient_map cascade;
drop table if exists doctor_patient_invites cascade;
drop table if exists meal_times cascade;
drop table if exists profiles cascade;

drop type if exists user_role cascade;
drop type if exists invite_status cascade;
drop type if exists prescription_status cascade;
drop type if exists log_status cascade;

create type user_role as enum ('doctor', 'patient');
create type invite_status as enum ('pending', 'accepted', 'rejected');
create type prescription_status as enum ('pending', 'accepted', 'rejected');
create type log_status as enum ('taken', 'missed', 'skipped');

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role user_role not null,
  name text not null,
  email text not null unique,
  short_code text not null unique check (short_code ~ '^[0-9]{6}$'),
  created_at timestamptz not null default now()
);

create table doctor_patient_invites (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references profiles(id) on delete cascade,
  patient_id uuid references profiles(id) on delete cascade,
  patient_email text not null,
  status invite_status not null default 'pending',
  created_at timestamptz not null default now()
);

create table doctor_patient_map (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references profiles(id) on delete cascade,
  patient_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (doctor_id, patient_id)
);

create table prescriptions (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references profiles(id) on delete cascade,
  title text not null,
  notes text,
  created_at timestamptz not null default now()
);

create table prescription_items (
  id uuid primary key default gen_random_uuid(),
  prescription_id uuid not null references prescriptions(id) on delete cascade,
  medicine_name text not null,
  dosage_type text not null,
  frequency_config jsonb not null,
  duration_start date not null,
  duration_end date not null,
  meal_config jsonb not null,
  created_at timestamptz not null default now()
);

create table patient_prescriptions (
  id uuid primary key default gen_random_uuid(),
  prescription_id uuid not null references prescriptions(id) on delete cascade,
  patient_id uuid not null references profiles(id) on delete cascade,
  status prescription_status not null default 'pending',
  modified_schedule jsonb,
  created_at timestamptz not null default now(),
  unique (prescription_id, patient_id)
);

create table medicine_logs (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references profiles(id) on delete cascade,
  prescription_item_id uuid not null references prescription_items(id) on delete cascade,
  scheduled_time timestamptz not null,
  taken_time timestamptz,
  status log_status not null default 'missed',
  deviation_minutes integer,
  created_at timestamptz not null default now(),
  unique (patient_id, prescription_item_id, scheduled_time)
);

create table meal_times (
  patient_id uuid primary key references profiles(id) on delete cascade,
  breakfast_time time not null default '08:00:00',
  lunch_time time not null default '13:00:00',
  dinner_time time not null default '20:00:00',
  updated_at timestamptz not null default now()
);

create index idx_profiles_role on profiles(role);
create index idx_invites_patient_email on doctor_patient_invites(patient_email);
create index idx_invites_patient_id on doctor_patient_invites(patient_id);
create index idx_invites_doctor_status on doctor_patient_invites(doctor_id, status);
create index idx_map_doctor on doctor_patient_map(doctor_id);
create index idx_map_patient on doctor_patient_map(patient_id);
create index idx_prescriptions_doctor on prescriptions(doctor_id);
create index idx_items_prescription on prescription_items(prescription_id);
create index idx_patient_prescriptions_patient_status on patient_prescriptions(patient_id, status);
create index idx_logs_patient_scheduled on medicine_logs(patient_id, scheduled_time);

create or replace view patient_adherence_view as
select
  l.patient_id,
  date_trunc('day', l.scheduled_time) as day,
  count(*) as total_doses,
  count(*) filter (where l.status = 'taken') as taken_doses,
  count(*) filter (where l.status = 'missed') as missed_doses,
  count(*) filter (where l.status = 'skipped') as skipped_doses,
  round(
    case when count(*) = 0 then 0
    else (count(*) filter (where l.status = 'taken')::numeric / count(*)::numeric) * 100
    end,
    2
  ) as adherence_percent
from medicine_logs l
group by l.patient_id, date_trunc('day', l.scheduled_time);

-- Keep open in development. Replace with RLS policies before production rollout.
alter table profiles disable row level security;
alter table doctor_patient_invites disable row level security;
alter table doctor_patient_map disable row level security;
alter table prescriptions disable row level security;
alter table prescription_items disable row level security;
alter table patient_prescriptions disable row level security;
alter table medicine_logs disable row level security;
alter table meal_times disable row level security;
