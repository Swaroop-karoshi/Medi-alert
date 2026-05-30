-- Medicine Inventory Migration
-- Run this in Supabase SQL editor AFTER the main supabase_schema.sql
-- Adds per-patient, per-prescription-item inventory tracking

create table if not exists medicine_inventory (
  id uuid primary key default gen_random_uuid(),
  prescription_item_id uuid not null references prescription_items(id) on delete cascade,
  patient_id uuid not null references profiles(id) on delete cascade,
  unit text not null default 'tablet',           -- tablet | capsule | ml | drops | injection
  total_quantity integer not null default 0,
  current_quantity integer not null default 0,
  low_stock_threshold integer not null default 5,
  updated_at timestamptz not null default now(),
  unique(prescription_item_id, patient_id)
);

create index if not exists idx_inventory_patient on medicine_inventory(patient_id);
create index if not exists idx_inventory_item on medicine_inventory(prescription_item_id);
create index if not exists idx_inventory_low_stock
  on medicine_inventory(patient_id, current_quantity, low_stock_threshold);

-- Disable RLS for development (enable + add policies before production)
alter table medicine_inventory disable row level security;
