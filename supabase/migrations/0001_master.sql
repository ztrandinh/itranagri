-- ITRAN OS · SPEC-01 v1.1 · 0001 master data (Postgres 17 / Supabase compatible)
create extension if not exists pgcrypto;
create extension if not exists "uuid-ossp";

-- ===== ROLES (app connects as app_user; RLS applies) =====
do $$ begin
  if not exists (select 1 from pg_roles where rolname='app_user') then
    create role app_user login password 'app_user_pw';
  end if;
end $$;

-- ===== ORG / REGION / FARM =====
create table if not exists orgs(
  id text primary key, name text not null, brand text, settings jsonb default '{}'::jsonb,
  created_at timestamptz default now());
create table if not exists regions(
  id text primary key, org_id text not null references orgs, name text not null,
  provinces text[] default '{}', params jsonb default '{}'::jsonb, -- giống, lịch vụ, vaccine, giá vùng, cốt lũ...
  created_at timestamptz default now());
create table if not exists farms(
  id text primary key,                       -- F01
  org_id text not null references orgs, region_id text references regions,
  legal_entity text, kind text not null default 'CAMPUS' check (kind in ('HUB','CAMPUS','VE_TINH','SANDBOX')),
  name text not null, province text, tz text default 'Asia/Ho_Chi_Minh',
  s_ha numeric, k_factor numeric, scale_band text, hub_farm_id text references farms,
  modules jsonb default '{}'::jsonb, status text default 'ACTIVE', created_at timestamptz default now());

-- ===== STAFF / AUTH =====
create table if not exists staff(
  id text primary key,                        -- NS-014
  org_id text not null references orgs, farm_id text references farms, -- null = HQ
  full_name text not null, role text not null check (role in ('worker','team_lead','tech_head','director','owner','auditor','accountant','it_engineer')),
  dept text, position text, phone text unique, login text unique, pin_hash text,
  farm_ids text[] default '{}',               -- các trại được xem (owner/auditor/HQ)
  sop_certs jsonb default '[]'::jsonb, health_check_due date, food_safety_training_due date,
  active bool default true, created_at timestamptz default now());
create table if not exists sessions(
  id uuid primary key default gen_random_uuid(), staff_id text references staff, farm_id text,
  device_id text, created_at timestamptz default now(), expires_at timestamptz, revoked_at timestamptz);

-- ===== CONFIG (P8: không hard-code) =====
create table if not exists settings(
  farm_id text references farms, key text, value jsonb not null, version int default 1,
  effective_from date default current_date, updated_by text, updated_at timestamptz default now(),
  primary key(farm_id, key, version));
create table if not exists norms(
  id text primary key, org_id text references orgs, farm_id text references farms, -- null farm = GLOBAL
  kind text not null, subject text, value numeric not null, unit text, version int default 1,
  effective_from date default current_date, note text);

-- ===== MASTER =====
create table if not exists cost_centers(id text primary key, farm_id text references farms, name text, parent_id text, kind text default 'PHAN_HE');
create table if not exists locations(
  id text primary key, farm_id text references farms, code text, name text, kind text, parent_id text,
  elevation_tier text, capacity numeric, geom jsonb);
create table if not exists products(                     -- SKU + vật tư + nguyên liệu (gộp items)
  sku text primary key, org_id text references orgs, name text not null, kind text not null
    check (kind in ('THANH_PHAM','BAN_TP','NGUYEN_LIEU','VAT_TU','THUOC','VACCINE','NHIEN_LIEU','BAO_BI','DICH_VU','GIONG')),
  unit text not null, unit2 text, value_tier int, shelf_life_days int, default_warehouse text,
  lot_tracked bool default true, coa_required bool default false, halal_ok bool, gtin text,
  spec jsonb default '{}'::jsonb, std_passport jsonb default '{}'::jsonb, active bool default true);
create table if not exists partners(
  id text primary key, org_id text references orgs, farm_id text references farms, kind text not null check (kind in ('KH','NCC','KH_NCC','THU_Y','LAB','KHAC')),
  name text not null, tax_code text, phone text, address text, channel int, credit_limit numeric, credit_days int,
  approved bool default false, approved_at date, review_due date, coa_docs jsonb default '[]'::jsonb, consent jsonb, active bool default true);
create table if not exists devices(
  id text primary key, farm_id text references farms, kind text, name text, brand text, model text, serial text,
  location_id text, machine_hours numeric default 0, maint_cycle_h numeric, fuel_l_per_h numeric,
  calib_due date, mqtt_topic text, status text default 'ACTIVE');
create table if not exists recipes(
  id text primary key, farm_id text references farms, name text, species_phase text, version int not null default 1,
  components jsonb not null default '[]'::jsonb, protein_pct numeric, energy numeric, halal_ok bool, no_bsf bool default false,
  tolerance_pct numeric default 2, approved_by text, approved_at timestamptz, active bool default false,
  unique(id, version));
create table if not exists sops(
  code text primary key, org_id text references orgs, title text not null, dept text, l1_chain text, l2_group text, status text default 'DRAFT');
create table if not exists sop_versions(
  id uuid primary key default gen_random_uuid(), sop_code text references sops, version int not null,
  purpose text, allowed_roles text[], tools text, frequency text, steps jsonb default '[]'::jsonb, pass_criteria text,
  common_errors text, evidence text, safety text, video_url text, std_clause text, ccp jsonb,
  author text, standardized_by text, signed_by text, signed_at timestamptz, review_due date, status text default 'DRAFT',
  unique(sop_code, version));
create table if not exists sop_distributions(
  id uuid primary key default gen_random_uuid(), sop_version_id uuid references sop_versions, farm_id text references farms,
  sent_at timestamptz default now(), acked_by text, acked_at timestamptz);
create table if not exists warehouses(
  id text primary key, farm_id text references farms, code text not null, name text, unit_kind text, count_cycle text, temp_monitored bool default false);
create table if not exists plots(
  id text primary key, farm_id text references farms, name text, geom jsonb, area_ha numeric, elevation_tier text,
  kind text default 'HOA_MAU', rotation_group text, current_crop text, status text default 'ACTIVE');
create table if not exists paper_form_templates(
  code text primary key, version int default 1, name text, target_table text, column_map jsonb, print_url text);

-- ===== ID SEQUENCES (mã nghiệp vụ, sinh offline TMP-… rồi đổi khi sync) =====
create table if not exists id_sequences(farm_id text references farms, type text, last_no bigint default 0, primary key(farm_id,type));
create or replace function next_code(p_farm text, p_type text, p_width int default 5) returns text language plpgsql as $$
declare n bigint; begin
  insert into id_sequences(farm_id,type,last_no) values (p_farm,p_type,1)
  on conflict (farm_id,type) do update set last_no = id_sequences.last_no + 1 returning last_no into n;
  return p_farm || '-' || p_type || '-' || lpad(n::text, p_width, '0');
end $$;

-- ===== ĐỊNH DANH VẬT NUÔI 3 CẤP =====
create table if not exists animal_groups(               -- đàn/lô gia cầm, bể RAS, ao, lồng, nhóm dê
  id text primary key, farm_id text references farms, species text not null, kind text, block text, -- GA_DE|GA_THIT|RAS|AO|BE|DE|BO_NHOM
  name text, location_id text, head_count int default 0, biomass_kg numeric, started_at date, all_in_all_out bool default false,
  status text default 'ACTIVE');
create table if not exists intake_lots(                  -- lô nhập / cohort
  id text primary key, farm_id text references farms, kind text not null check (kind in ('MUA','SINH','CAI_SUA','CHUYEN_TRAI')),
  date date not null, source_partner_id text, source_farm_id text, quarantine_until date, vet_cert_no text, price numeric, head_count int, note text);
create table if not exists animals(
  id text primary key, farm_id text references farms, species text not null, breed text, sex text, birth_date date,
  dam_id text references animals, sire_code text, rfid text unique, visual_tag text, qr_token text unique default encode(gen_random_bytes(8),'hex'),
  source text check (source in ('SINH','MUA','CHUYEN_TRAI')), intake_lot_id text references intake_lots, group_id text references animal_groups,
  status text not null default 'HAU_BI', location_id text, last_weight_kg numeric, last_weight_at date, withdrawal_until date,
  unit_value numeric, cost_center text, owner_type text default 'TRAI' check (owner_type in ('TRAI','KHACH','DONG_SO_HUU')),
  photos jsonb default '[]'::jsonb, created_at timestamptz default now(),
  constraint animals_identity check (rfid is not null or visual_tag is not null));
create table if not exists animal_ownership(
  id uuid primary key default gen_random_uuid(), animal_id text references animals, partner_id text references partners,
  pct numeric not null default 100, contract_id uuid, from_date date default current_date, to_date date);
create table if not exists group_membership(
  id uuid primary key default gen_random_uuid(), animal_id text references animals, group_id text references animal_groups,
  from_ts timestamptz default now(), to_ts timestamptz);
create table if not exists lots(                          -- lô hàng/vật tư (K1..K9)
  id text primary key, farm_id text references farms, sku text references products, lot_no text, supplier_id text,
  mfg_date date, expiry_date date, coa_url text, status text default 'KHA_DUNG' check (status in ('KHA_DUNG','CO_LAP','THU_HOI','HET')),
  avg_cost numeric, created_at timestamptz default now(), unique(farm_id, sku, lot_no));

-- ===== SCHEMA MIGRATIONS BOOKKEEPING =====
create table if not exists schema_migrations(name text primary key, applied_at timestamptz default now());
