-- AutoPassaporte V16 — banco de dados
-- Execute este script no Supabase > SQL Editor > New query.

create extension if not exists pgcrypto;

create table if not exists public.vehicles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  year text,
  version text,
  fuel text,
  gear text,
  plate text,
  current_km integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.maintenance_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  service text not null,
  date date,
  km integer,
  value numeric(12,2) not null default 0,
  proof_type text,
  shop text,
  notes text,
  proof_name text,
  proof_type_file text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists vehicles_user_id_idx on public.vehicles(user_id);
create index if not exists maintenance_user_id_idx on public.maintenance_records(user_id);
create index if not exists maintenance_vehicle_id_idx on public.maintenance_records(vehicle_id);

alter table public.vehicles enable row level security;
alter table public.maintenance_records enable row level security;

drop policy if exists "Users can view own vehicles" on public.vehicles;
drop policy if exists "Users can insert own vehicles" on public.vehicles;
drop policy if exists "Users can update own vehicles" on public.vehicles;
drop policy if exists "Users can delete own vehicles" on public.vehicles;

create policy "Users can view own vehicles" on public.vehicles for select using (auth.uid() = user_id);
create policy "Users can insert own vehicles" on public.vehicles for insert with check (auth.uid() = user_id);
create policy "Users can update own vehicles" on public.vehicles for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users can delete own vehicles" on public.vehicles for delete using (auth.uid() = user_id);

drop policy if exists "Users can view own maintenance" on public.maintenance_records;
drop policy if exists "Users can insert own maintenance" on public.maintenance_records;
drop policy if exists "Users can update own maintenance" on public.maintenance_records;
drop policy if exists "Users can delete own maintenance" on public.maintenance_records;

create policy "Users can view own maintenance" on public.maintenance_records for select using (auth.uid() = user_id);
create policy "Users can insert own maintenance" on public.maintenance_records for insert with check (auth.uid() = user_id);
create policy "Users can update own maintenance" on public.maintenance_records for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users can delete own maintenance" on public.maintenance_records for delete using (auth.uid() = user_id);

-- Garante que um registro de manutenção só possa apontar para um veículo do próprio usuário.
create or replace function public.check_maintenance_vehicle_owner()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from public.vehicles v where v.id = new.vehicle_id and v.user_id = new.user_id) then
    raise exception 'vehicle_not_owned';
  end if;
  return new;
end;
$$;

drop trigger if exists maintenance_vehicle_owner on public.maintenance_records;
create trigger maintenance_vehicle_owner
before insert or update on public.maintenance_records
for each row execute function public.check_maintenance_vehicle_owner();

-- Atualização simples de updated_at.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists vehicles_updated_at on public.vehicles;
create trigger vehicles_updated_at before update on public.vehicles for each row execute function public.set_updated_at();
drop trigger if exists maintenance_updated_at on public.maintenance_records;
create trigger maintenance_updated_at before update on public.maintenance_records for each row execute function public.set_updated_at();
