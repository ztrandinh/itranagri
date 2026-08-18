-- 0002 · EVENT TABLES (append-only) · cột chung EventBase
-- id, farm_id, ts (occurred), created_at (recorded), created_by, device_id, source, is_backfill, paper_serial, client_ref, supersedes_id, status

create or replace function itran_no_update_delete() returns trigger language plpgsql as $$
begin raise exception 'ERR_APPEND_ONLY: % is append-only (use supersede/adjustment)', tg_table_name; end $$;

create or replace function itran_paper_check() returns trigger language plpgsql as $$
begin
  if new.source = 'PAPER' and new.paper_serial is null then raise exception 'ERR_PAPER_SERIAL_REQUIRED'; end if;
  if new.supersedes_id is not null then
    execute format('update %I set status=''SUPERSEDED'' where id=$1 and status=''ACTIVE''', tg_table_name) using new.supersedes_id;
  end if;
  return new;
end $$;

-- helper để tạo bảng sự kiện đồng nhất
create or replace function itran_make_event_table(p_table text, p_cols text) returns void language plpgsql as $$
begin
  execute format($f$
    create table if not exists %1$I (
      id uuid primary key default gen_random_uuid(),
      farm_id text not null references farms,
      ts timestamptz not null default now(),
      created_at timestamptz not null default now(),
      created_by text, device_id text,
      source text not null default 'APP' check (source in ('APP','DEVICE','IMPORT','BACKFILL','PAPER','API')),
      is_backfill bool not null default false,
      paper_serial text, client_ref text, supersedes_id uuid, status text not null default 'ACTIVE' check (status in ('ACTIVE','SUPERSEDED','VOID')),
      %2$s
    );
    create unique index if not exists %1$s_client_ref_ux on %1$I(farm_id, client_ref) where client_ref is not null;
    create index if not exists %1$s_farm_ts_ix on %1$I(farm_id, ts desc);
    drop trigger if exists %1$s_bi on %1$I;
    create trigger %1$s_bi before insert on %1$I for each row execute function itran_paper_check();
    drop trigger if exists %1$s_bud on %1$I;
    create trigger %1$s_bud before delete on %1$I for each row execute function itran_no_update_delete();
  $f$, p_table, p_cols);
end $$;

select itran_make_event_table('animal_events', $$
  animal_id text references animals, group_id text references animal_groups,
  event_type text not null, -- NHAP|CACH_LY_VAO|CACH_LY_RA|PHOI|DONG_DUC|KHAM_THAI|DE|CAI_SUA|PHAN_LOAI|CAN|BENH|DIEU_TRI|VACCINE|CHUYEN|CHET|LOAI|XUAT|SO_LUONG|GHI_CHU
  value numeric, unit text, detail jsonb default '{}'::jsonb, withdrawal_until date, photo_urls text[] default '{}'
$$);
select itran_make_event_table('feed_logs', $$
  batch_ref text, recipe_id text, recipe_version int, dest_location_id text, dest_group_id text,
  planned_kg numeric, qty_kg numeric not null, meal text, leftover_pct numeric, photo_urls text[] default '{}'
$$);
select itran_make_event_table('crop_logs', $$
  plot_id text references plots, activity text not null, -- LAM_DAT|GIEO|BON|PHUN|TUOI|CAT|THU|GIEO_LAI|NDVI
  variety text, input_lots jsonb default '[]'::jsonb, qty_kg numeric, moisture_pct numeric, machine_id text, machine_hours numeric, fuel_l numeric,
  water_source text, water_m3 numeric, weigh_ticket_id uuid, ndvi_url text, chemical bool default false, director_order text, phi_until date, photo_urls text[] default '{}'
$$);
select itran_make_event_table('batch_logs', $$
  batch_code text unique, line text not null, -- D5_TMR|D5_VIEN|U_CHUA|TRUN_NAP|TRUN_THU|BSF|BIOGAS|COMPOST|IMO_EM|ANOLYTE|SO_CHE|SAY|DONG_GOI|EP_MO_CAU|THAN
  recipe_id text, recipe_version int, location_id text, inputs jsonb default '[]'::jsonb, outputs jsonb default '[]'::jsonb,
  qc jsonb default '{}'::jsonb, ccp_readings jsonb default '[]'::jsonb, temp_c numeric, moisture_pct numeric, batch_status text default 'DONG'
$$);
select itran_make_event_table('inventory_moves', $$
  warehouse_id text references warehouses, sku text references products, lot_id text references lots, direction int not null check (direction in (1,-1)),
  qty numeric not null check (qty > 0), unit text, unit_cost numeric, reason text, -- NHAP_MUA|NHAP_SX|XUAT_SX|XUAT_CHO_AN|XUAT_BAN|CHUYEN|TRA|HUY|DIEU_CHINH
  from_to text, weigh_point text, weigh_ticket_id uuid, ref_type text, ref_id text
$$);
select itran_make_event_table('weigh_tickets', $$
  scale_device_id text, plate text, gross_kg numeric, tare_kg numeric, net_kg numeric, purpose text, sku text, partner_id text, photo_urls text[] default '{}'
$$);
select itran_make_event_table('gate_logs', $$
  plate text, direction text, weighed bool default false, weigh_ticket_id uuid, anolyte_wash bool default false, purpose text, driver text, photo_urls text[] default '{}'
$$);
select itran_make_event_table('sales', $$
  order_id uuid, partner_id text references partners, sku text references products, lot_id text, qty numeric not null, unit text, price numeric, amount numeric,
  channel int check (channel between 1 and 5), payment text, paid bool default false, invoice_no text, delivered_at timestamptz, customer_sign_url text
$$);
select itran_make_event_table('checklist_runs', $$
  sop_code text references sops, sop_version int, shift text, results jsonb default '[]'::jsonb, all_green bool default false, note text, approved_by text, approved_at timestamptz
$$);
select itran_make_event_table('incidents', $$
  code text, kind text not null, severity text not null, description text, location_id text, classification text, five_why jsonb, capa jsonb, sop_fixed text, closed_at timestamptz, photo_urls text[] default '{}'
$$);
select itran_make_event_table('adjustments', $$
  target_table text not null, target_id uuid, warehouse_id text, sku text, lot_id text, delta numeric, reason text not null,
  requested_by text, approved_by text, approved_at timestamptz, adj_status text default 'CHO_DUYET' check (adj_status in ('CHO_DUYET','DUYET','TU_CHOI'))
$$);
select itran_make_event_table('stocktakes', $$
  warehouse_id text, counted_by text, lines jsonb default '[]'::jsonb, camera_count int, diff_pct numeric, note text
$$);
select itran_make_event_table('calibrations', $$
  target_device_id text references devices, method text, before_val numeric, after_val numeric, result text, next_due date
$$);
select itran_make_event_table('paper_scans', $$
  form_code text not null, serial text not null unique, photo_url text, uploaded_by text,
  digitized bool default false, digitized_by text, digitized_ts timestamptz, linked_ids jsonb default '[]'::jsonb, anomaly text
$$);
-- paper_scans được phép cập nhật cờ digitized (không phải bảng nghiệp vụ gốc) → tách trigger:
drop trigger if exists paper_scans_bud on paper_scans;
create trigger paper_scans_bd before delete on paper_scans for each row execute function itran_no_update_delete();

-- sensor_reads: bảng lớn, partition theo tháng
create table if not exists sensor_reads(
  ts timestamptz not null, farm_id text not null, device_id text not null, metric text not null, value numeric, quality text default 'OK'
) partition by range (ts);
create table if not exists sensor_reads_default partition of sensor_reads default;
create index if not exists sensor_reads_ix on sensor_reads(farm_id, device_id, metric, ts desc);

-- alerts / rules / kpi / rc (config có phiên bản)
create table if not exists alert_rules(
  code text, version int default 1, farm_id text not null default 'GLOBAL', name text, source text, expr jsonb, level text, recipients text[], channels text[], sop_code text, cooldown_min int default 60,
  active bool default true, updated_by text, updated_at timestamptz default now(), reason text, primary key(code, version, farm_id));
create table if not exists alerts(
  id uuid primary key default gen_random_uuid(), farm_id text not null, rule_code text, level text, subject text, payload jsonb, sent_to text[],
  ts timestamptz default now(), acked_by text, acked_at timestamptz, resolved_at timestamptz, incident_id uuid);
create table if not exists kpi_defs(
  code text, version int default 1, name text, formula_sql text, unit text, target numeric, yellow numeric, red numeric, period text, scope text, pay_layer int,
  active bool default true, primary key(code, version));
create table if not exists kpi_values(id uuid primary key default gen_random_uuid(), farm_id text, kpi_code text, kpi_version int, subject text, period date, value numeric, inputs jsonb, computed_at timestamptz default now());
create table if not exists rc_rules(
  code text primary key, name text, side_a_sql text, side_b_sql text, threshold_pct numeric, threshold_mode text default 'PCT', level text default 'VANG', recipients text[], active bool default true, version int default 1);
create table if not exists recon_results(
  id uuid primary key default gen_random_uuid(), farm_id text not null, rule_code text, period date, expected numeric, actual numeric, diff_pct numeric,
  status text, detail jsonb, ts timestamptz default now(), acked_by text, incident_id uuid);
drop trigger if exists recon_results_bud on recon_results;
create trigger recon_results_bud before delete on recon_results for each row execute function itran_no_update_delete();

-- audit anchor (hash chain rẻ theo ngày)
create table if not exists audit_anchors(farm_id text, day date, table_name text, row_count bigint, digest text, prev_digest text, created_at timestamptz default now(), primary key(farm_id, day, table_name));

-- ngưng thuốc: cập nhật animals.withdrawal_until & chặn XUAT
create or replace function itran_animal_event_after() returns trigger language plpgsql as $$
begin
  if new.animal_id is null then return new; end if;
  if new.event_type in ('DIEU_TRI','VACCINE') and new.withdrawal_until is not null then
    update animals set withdrawal_until = greatest(coalesce(withdrawal_until, new.withdrawal_until), new.withdrawal_until) where id = new.animal_id;
  elsif new.event_type = 'CAN' then
    update animals set last_weight_kg = new.value, last_weight_at = new.ts::date where id = new.animal_id;
  elsif new.event_type = 'CHET' then update animals set status='CHET' where id=new.animal_id;
  elsif new.event_type = 'XUAT' then update animals set status='XUAT' where id=new.animal_id;
  elsif new.event_type = 'CHUYEN' and new.detail ? 'to_location' then update animals set location_id = new.detail->>'to_location' where id=new.animal_id;
  elsif new.event_type in ('PHOI','KHAM_THAI','DE','CAI_SUA','PHAN_LOAI','CACH_LY_VAO','CACH_LY_RA') and new.detail ? 'new_status' then
    update animals set status = new.detail->>'new_status' where id=new.animal_id;
  end if;
  return new;
end $$;
create or replace function itran_animal_event_before() returns trigger language plpgsql as $$
declare w date; begin
  if new.event_type = 'XUAT' and new.animal_id is not null then
    select withdrawal_until into w from animals where id = new.animal_id;
    if w is not null and w > new.ts::date and coalesce(new.detail->>'override_by','') = '' then
      raise exception 'ERR_WITHDRAWAL_ACTIVE: animal % under withdrawal until %', new.animal_id, w;
    end if;
  end if;
  return new;
end $$;
drop trigger if exists animal_events_wd on animal_events;
create trigger animal_events_wd before insert on animal_events for each row execute function itran_animal_event_before();
drop trigger if exists animal_events_ai on animal_events;
create trigger animal_events_ai after insert on animal_events for each row execute function itran_animal_event_after();

-- lots: khi nhập mua có lô mới tự tạo (helper)
create or replace function ensure_lot(p_farm text, p_sku text, p_lot_no text, p_supplier text default null, p_expiry date default null) returns text language plpgsql as $$
declare v_id text; begin
  select id into v_id from lots where farm_id=p_farm and sku=p_sku and lot_no=p_lot_no;
  if v_id is null then
    v_id := p_farm||'-LOT-'||p_sku||'-'||p_lot_no;
    insert into lots(id,farm_id,sku,lot_no,supplier_id,expiry_date) values (v_id,p_farm,p_sku,p_lot_no,p_supplier,p_expiry);
  end if;
  return v_id;
end $$;
