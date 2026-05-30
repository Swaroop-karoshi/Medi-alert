-- Drop the old patient-centric inventory table
drop table if exists medicine_inventory cascade;

-- Create the new doctor-centric inventory table
create table doctor_inventory (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references profiles(id) on delete cascade,
  medicine_name text not null,
  unit text not null default 'tablet',
  total_quantity integer not null default 0,
  current_quantity integer not null default 0,
  price_per_unit numeric not null default 0.0,
  low_stock_threshold integer not null default 5,
  updated_at timestamptz not null default now(),
  unique(doctor_id, medicine_name)
);

-- Alter prescription_items to include cost and link to inventory
alter table prescription_items 
  add column inventory_item_id uuid references doctor_inventory(id) on delete set null,
  add column prescribed_quantity integer not null default 0,
  add column price_per_unit numeric not null default 0.0;

-- Indices for performance
create index idx_doctor_inventory on doctor_inventory(doctor_id);

-- Disable RLS for MVP
alter table doctor_inventory disable row level security;

-- RPC for purchasing a prescription item
create or replace function deduct_inventory(item_id uuid, qty_to_deduct integer)
returns void as $$
begin
  update doctor_inventory
  set current_quantity = current_quantity - qty_to_deduct
  where id = item_id and current_quantity >= qty_to_deduct;
end;
$$ language plpgsql security definer;
