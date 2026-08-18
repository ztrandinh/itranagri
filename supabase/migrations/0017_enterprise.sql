-- 0017 · KHUNG DOANH NGHIỆP LỚN: hồ sơ trại chi tiết · nhà công năng · audit/lịch sử danh mục · soft-remove ·
--        module manifest · R&D · Xuất nhập khẩu · nhân rộng/franchise · tài liệu · trường tùy biến · API key/webhook · phê duyệt chung
-- Nguyên tắc: "thà thừa đóng lại" — bảng đầy đủ, RLS bật, chưa dùng thì để trống; không đập đi xây lại.

-- ===== 1. HỒ SƠ TRẠI CHI TIẾT =====
alter table farms add column if not exists profile jsonb default '{}'::jsonb;   -- tọa độ, độ cao, đất, nước, điện, đường, giấy phép, năm hoạt động, mô tả…
alter table farms add column if not exists address text, add column if not exists lat numeric, add column if not exists lng numeric, add column if not exists elevation_m numeric,
  add column if not exists land_total_ha numeric, add column if not exists land_biomass_ha numeric, add column if not exists land_core_ha numeric, add column if not exists water_ha numeric, add column if not exists land_other_ha numeric,
  add column if not exists power_kva numeric, add column if not exists solar_kwp numeric, add column if not exists water_source text, add column if not exists water_m3_day numeric, add column if not exists road_access text,
  add column if not exists licenses jsonb default '[]'::jsonb, add column if not exists opened_on date, add column if not exists manager_id text, add column if not exists phone text, add column if not exists tax_code text, add column if not exists bank_account text,
  add column if not exists design_head int, add column if not exists design_notes text, add column if not exists updated_at timestamptz default now(), add column if not exists updated_by text;
-- Nhà công năng / hạ tầng: chuồng, kho, xưởng, nhà điều hành, ao, bể biogas, trạm điện, giếng, đường nội bộ, hàng rào…
create table if not exists facilities(
  id text primary key, farm_id text not null references farms, code text not null, name text not null,
  kind text not null,                -- CHUONG|KHO|XUONG|NHA_DIEU_HANH|AO|BE_BIOGAS|TRAM_DIEN|GIENG|BE_NUOC|NHA_KINH|SAN_PHOI|CAN|CONG|DUONG|HANG_RAO|NHA_O|KHAC
  location_id text, area_m2 numeric, capacity numeric, capacity_unit text, built_year int, cost numeric, status text default 'HOAT_DONG',   -- HOAT_DONG|BAO_TRI|NGUNG|KE_HOACH
  spec jsonb default '{}'::jsonb, photos text[] default '{}', note text, active bool default true,
  created_at timestamptz default now(), created_by text, updated_at timestamptz default now(), updated_by text, unique(farm_id, code));
create index if not exists facilities_farm on facilities(farm_id, kind);
-- ===== 2. AUDIT / LỊCH SỬ THAY ĐỔI DANH MỤC (add / update / remove) → admin =====
create table if not exists audit_log(
  id bigserial primary key, ts timestamptz default now(), farm_id text, table_name text not null, pk text not null, action text not null,  -- INSERT|UPDATE|DELETE|SOFT_DELETE|IMPORT
  before jsonb, after jsonb, changed_cols text[], by_staff text, by_role text, ip text, note text);
create index if not exists audit_log_tbl on audit_log(table_name, pk, ts desc); create index if not exists audit_log_ts on audit_log(ts desc);
create or replace function itran_audit() returns trigger language plpgsql security definer as $$
declare pkv text; fid text; cols text[]; act text := TG_OP; b jsonb; a jsonb;
begin
  b := case when TG_OP='INSERT' then null else to_jsonb(old) end; a := case when TG_OP='DELETE' then null else to_jsonb(new) end;
  pkv := coalesce(a->>'id', a->>'sku', a->>'code', b->>'id', b->>'sku', b->>'code', '?'); fid := coalesce(a->>'farm_id', b->>'farm_id');
  if TG_OP='UPDATE' then select array_agg(k) into cols from jsonb_object_keys(a) k where a->k is distinct from b->k;
    if cols is null then return new; end if;
    if (a->>'active')='false' and (b->>'active') is distinct from 'false' then act := 'SOFT_DELETE'; end if;
    if (a->>'status') in ('ARCHIVED','NGUNG') and (b->>'status') is distinct from (a->>'status') then act := 'SOFT_DELETE'; end if;
  end if;
  insert into audit_log(farm_id, table_name, pk, action, before, after, changed_cols, by_staff, by_role)
    values (fid, TG_TABLE_NAME, pkv, act, b, a, cols, nullif(current_setting('app.staff_id', true),''), nullif(current_setting('app.role', true),''));
  -- gửi sự kiện cho admin (owner/it_engineer) khi thay đổi danh mục
  perform publish_event(fid, 'master.changed', jsonb_build_object('table', TG_TABLE_NAME, 'pk', pkv, 'action', act, 'by', nullif(current_setting('app.staff_id', true),''), 'cols', cols));
  return coalesce(new, old);
end $$;
do $$ declare t text; begin
  foreach t in array array['farms','regions','staff','products','partners','warehouses','locations','plots','devices','recipes','sops','cost_centers','facilities','animal_groups','settings','norms','price_list','alert_rules','rc_rules','kpi_defs','vaccine_schedules','treatment_protocols','contracts','custody_contracts','funds']
  loop
    if to_regclass(t) is not null then execute format('drop trigger if exists audit_%1$s on %1$s; create trigger audit_%1$s after insert or update or delete on %1$s for each row execute function itran_audit()', t); end if;
  end loop; end $$;
-- Soft-remove: bảng danh mục nào chưa có cờ active thì thêm (không xóa cứng dữ liệu nghiệp vụ)
alter table warehouses add column if not exists active bool default true; alter table locations add column if not exists active bool default true; alter table plots add column if not exists active bool default true;
alter table devices add column if not exists active bool default true; alter table recipes add column if not exists active bool default true; alter table cost_centers add column if not exists active bool default true;
alter table animal_groups add column if not exists active bool default true; alter table regions add column if not exists active bool default true;
alter table staff add column if not exists hired_on date, add column if not exists left_on date, add column if not exists id_number text, add column if not exists dob date, add column if not exists address text, add column if not exists emergency_contact text, add column if not exists salary_base numeric, add column if not exists contract_kind text, add column if not exists photo text, add column if not exists note text;
-- ===== 3. MODULE MANIFEST (bật/tắt theo trại, phụ thuộc, phiên bản) =====
create table if not exists module_manifest(code text primary key, name text not null, description text, depends text[] default '{}', default_on bool default false, nav jsonb default '[]'::jsonb, tables text[] default '{}', version text default '1.0');
insert into module_manifest(code,name,description,depends,default_on,tables) values
 ('core','Lõi (đàn·kho·việc·đối soát·cảnh báo·số liệu)','Bắt buộc','{}',true,'{animals,inventory_moves,tasks,alerts}'),
 ('bo','Bò sinh sản + vỗ béo','Định danh cá thể, sinh sản, cân, ngưng thuốc','{core}',true,'{animal_events}'),
 ('ga','Gà 2 khối','Đẻ, thịt, băng chuyền trứng','{core}',true,'{}'),
 ('ras','RAS / ao / bè','Cá, DO/pH, cho ăn','{core}',false,'{}'),
 ('de','Dê','Định danh cá thể','{core}',false,'{}'),
 ('trun','Trùn · BSF · biogas · compost','Mẻ khu D','{core}',true,'{batch_logs}'),
 ('d5','Xưởng thức ăn D5','Công thức, mẻ TMR, sai số','{core}',true,'{feed_logs,recipes}'),
 ('cb','Chế biến','Sản phẩm, QC, truy xuất','{core}',false,'{}'),
 ('kd','Bán hàng · marketing','Đơn, HĐ, công nợ, kênh','{core}',true,'{sales,orders,contracts}'),
 ('resort','Resort / MICE / du lịch','Booking, sự kiện, dịch vụ','{core}',false,'{}'),
 ('rnd','R&D','Thử nghiệm, lô đối chứng, mẫu lab, tri thức','{core}',false,'{rd_trials,rd_observations,lab_samples}'),
 ('xnk','Xuất nhập khẩu','Thị trường, HĐ ngoại, lô hàng, chứng từ, hải quan, tỷ giá','{core,kd}',false,'{trade_contracts,shipments,trade_documents}'),
 ('custody','Chăm sóc hộ · nhận nuôi · xem live','Portal khách','{core,bo}',true,'{custody_contracts}'),
 ('vien','Kinh tế viền','Liên kết hộ, thu mua','{core}',false,'{}'),
 ('franchise','Nhân rộng · nhượng quyền','Gói mẫu trại, checklist chuyển giao, phí','{core}',false,'{franchise_packages,franchise_sites}')
on conflict (code) do update set name=excluded.name, description=excluded.description, depends=excluded.depends;
-- ===== 4. R&D =====
create table if not exists rd_trials(id text primary key, farm_id text not null, code text not null, title text not null, hypothesis text, domain text, -- GIONG|THUC_AN|THU_Y|TRONG_TROT|SINH_HOC|CHE_BIEN|CONG_NGHE
  status text default 'DE_XUAT', -- DE_XUAT|DUYET|DANG_CHAY|KET_THUC|HUY
  start_date date, end_date date, budget numeric, owner_id text, protocol text, kpis jsonb default '[]'::jsonb, result_summary text, decision text, created_at timestamptz default now(), created_by text);
create table if not exists rd_trial_arms(id text primary key, trial_id text references rd_trials, name text not null, is_control bool default false, group_id text, plot_id text, treatment jsonb default '{}'::jsonb, n int);
create table if not exists rd_observations(id uuid primary key default gen_random_uuid(), farm_id text not null, trial_id text references rd_trials, arm_id text, ts timestamptz default now(), metric text not null, value numeric, unit text, subject_id text, note text, photo text, created_by text, status text default 'ACTIVE');
create table if not exists lab_samples(id text primary key, farm_id text not null, code text not null, kind text, -- DAT|NUOC|TA|SUA|MAU|PHAN|SAN_PHAM
  taken_at timestamptz, taken_by text, subject_ref text, lab_partner text, sent_at timestamptz, result_at timestamptz, results jsonb default '{}'::jsonb, verdict text, file text, trial_id text, status text default 'DA_LAY');
create table if not exists knowledge_articles(id text primary key, org_id text default 'ITRAN', title text not null, domain text, body_md text, tags text[] default '{}', source text, trial_id text, version int default 1, status text default 'NHAP', created_at timestamptz default now(), created_by text);
-- ===== 5. XUẤT NHẬP KHẨU =====
create table if not exists market_profiles(id text primary key, country text not null, name text, requirements jsonb default '{}'::jsonb, -- chứng nhận, dư lượng, nhãn, halal, GlobalGAP…
  tariffs jsonb default '{}'::jsonb, incoterm_default text, currency text, notes text, updated_at timestamptz default now());
create table if not exists trade_partners(id text primary key, org_id text default 'ITRAN', kind text, -- NHA_NHAP_KHAU|NHA_XUAT_KHAU|FORWARDER|BROKER|NGAN_HANG|KIEM_DINH
  name text not null, country text, tax_id text, contact jsonb default '{}'::jsonb, rating text, docs jsonb default '[]'::jsonb, active bool default true);
create table if not exists trade_contracts(id text primary key, farm_id text, org_id text default 'ITRAN', code text not null, direction text not null, -- XUAT|NHAP
  partner_id text, market_id text, incoterm text, currency text, fx_rate numeric, total_value numeric, payment_terms text, lc_number text, signed_on date, delivery_from date, delivery_to date, status text default 'NHAP', lines jsonb default '[]'::jsonb, terms jsonb default '{}'::jsonb, created_at timestamptz default now(), created_by text);
create table if not exists shipments(id text primary key, farm_id text, contract_id text references trade_contracts, code text not null, mode text, -- SEA|AIR|ROAD|RAIL
  container_no text, bl_number text, etd date, eta date, atd date, ata date, port_load text, port_discharge text, forwarder_id text, status text default 'KE_HOACH', -- KE_HOACH|DONG_HANG|DA_XUAT|TREN_DUONG|THONG_QUAN|GIAO_XONG
  lots jsonb default '[]'::jsonb, temp_log jsonb default '[]'::jsonb, weight_kg numeric, volume_m3 numeric, created_at timestamptz default now());
create table if not exists trade_documents(id uuid primary key default gen_random_uuid(), shipment_id text references shipments, contract_id text, kind text not null, -- INVOICE|PACKING_LIST|CO|PHYTO|HEALTH_CERT|HALAL|BL|INSURANCE|LC|CUSTOMS_DECL|COA
  number text, issued_on date, expires_on date, file text, status text default 'NHAP', note text, created_at timestamptz default now(), created_by text);
create table if not exists customs_declarations(id text primary key, shipment_id text references shipments, number text, declared_on date, hs_codes jsonb default '[]'::jsonb, duties numeric, vat numeric, status text default 'NHAP', officer text, cleared_on date);
create table if not exists import_permits(id text primary key, org_id text default 'ITRAN', kind text, -- GIONG|THUC_AN|THUOC|MAY_MOC
  number text, issuer text, issued_on date, expires_on date, scope text, file text, status text default 'HIEU_LUC');
create table if not exists fx_rates(day date not null, currency text not null, rate numeric not null, source text, primary key(day, currency));
create table if not exists intl_payments(id uuid primary key default gen_random_uuid(), contract_id text references trade_contracts, shipment_id text, direction text, amount numeric, currency text, fx_rate numeric, amount_vnd numeric, method text, -- TT|LC|DP|DA
  paid_on date, bank_ref text, note text, created_at timestamptz default now(), created_by text);
create table if not exists landed_costs(id uuid primary key default gen_random_uuid(), shipment_id text references shipments, kind text, -- HANG|CUOC|BAO_HIEM|THUE|PHI_CANG|KIEM_DINH|KHAC
  amount numeric, currency text, amount_vnd numeric, note text);
-- ===== 6. NHÂN RỘNG / FRANCHISE =====
create table if not exists franchise_packages(id text primary key, name text not null, scale_band text, description text, includes jsonb default '{}'::jsonb, -- SOP, BM, KPI, thiết kế, đào tạo
  fee_initial numeric, fee_royalty_pct numeric, version text default '1.0', status text default 'NHAP');
create table if not exists franchise_sites(id text primary key, package_id text references franchise_packages, farm_id text, partner_name text, province text, s_ha numeric, stage text default 'TIEP_CAN', -- TIEP_CAN|KHAO_SAT|KY_HD|XAY_DUNG|CHUYEN_GIAO|VAN_HANH
  contract_no text, signed_on date, go_live date, checklist jsonb default '[]'::jsonb, notes text, created_at timestamptz default now());
create table if not exists transfer_checklists(id uuid primary key default gen_random_uuid(), site_id text references franchise_sites, item text not null, category text, done bool default false, done_at timestamptz, done_by text, evidence text);
-- ===== 7. TÀI LIỆU · TRƯỜNG TÙY BIẾN · TÍCH HỢP · PHÊ DUYỆT CHUNG =====
create table if not exists documents(id uuid primary key default gen_random_uuid(), farm_id text, org_id text default 'ITRAN', ref_table text, ref_id text, kind text, title text not null, file text not null, mime text, size_bytes bigint, sha256 text, tags text[] default '{}', expires_on date, uploaded_by text, created_at timestamptz default now(), status text default 'ACTIVE');
create index if not exists documents_ref on documents(ref_table, ref_id);
create table if not exists custom_fields(id serial primary key, org_id text default 'ITRAN', table_name text not null, field text not null, label text not null, type text not null default 'text', -- text|number|date|bool|select
  options jsonb, required bool default false, position int default 0, active bool default true, unique(table_name, field));
create table if not exists api_keys(id uuid primary key default gen_random_uuid(), org_id text default 'ITRAN', farm_id text, name text not null, key_hash text not null, scopes text[] default '{read}', created_by text, created_at timestamptz default now(), last_used_at timestamptz, revoked_at timestamptz);
create table if not exists webhooks(id uuid primary key default gen_random_uuid(), org_id text default 'ITRAN', farm_id text, name text, url text not null, topics text[] default '{}', secret text, active bool default true, created_at timestamptz default now(), last_status int, last_at timestamptz, fail_count int default 0);
create table if not exists webhook_deliveries(id bigserial primary key, webhook_id uuid references webhooks, event_id bigint, ts timestamptz default now(), status int, response text, attempts int default 1);
create table if not exists integrations(id text primary key, org_id text default 'ITRAN', farm_id text, kind text not null, -- ZALO_OA|SMS|EMAIL|BANK|MISA|GIS|MQTT|ERP
  config jsonb default '{}'::jsonb, secret_ref text, active bool default false, last_sync timestamptz, note text);
create table if not exists approvals(id uuid primary key default gen_random_uuid(), farm_id text, ref_table text not null, ref_id text not null, step int default 1, required_role text, decided_by text, decision text, -- DUYET|TU_CHOI
  decided_at timestamptz, note text, created_at timestamptz default now());
create index if not exists approvals_ref on approvals(ref_table, ref_id);
-- Nhật ký nhập liệu (import CSV) để truy vết & hoàn tác
create table if not exists import_batches(id uuid primary key default gen_random_uuid(), farm_id text, table_name text not null, file_name text, rows_total int, rows_ok int, rows_err int, errors jsonb default '[]'::jsonb, mode text default 'INSERT', by_staff text, ts timestamptz default now(), reverted_at timestamptz);
-- ===== RLS + GRANT cho toàn bộ bảng mới =====
do $$ declare t text; begin
  foreach t in array array['facilities','audit_log','module_manifest','rd_trials','rd_trial_arms','rd_observations','lab_samples','knowledge_articles','market_profiles','trade_partners','trade_contracts','shipments','trade_documents','customs_declarations','import_permits','fx_rates','intl_payments','landed_costs','franchise_packages','franchise_sites','transfer_checklists','documents','custom_fields','api_keys','webhooks','webhook_deliveries','integrations','approvals','import_batches']
  loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists p_all on %I', t);
    if t in ('facilities','rd_trials','rd_observations','lab_samples','trade_contracts','shipments','documents','approvals','import_batches','api_keys','webhooks','integrations','audit_log') then
      execute format('create policy p_all on %I for all using (farm_id is null or can_see_farm(farm_id)) with check (true)', t);
    else
      execute format('create policy p_all on %I for all using (true) with check (true)', t);
    end if;
    execute format('grant select, insert, update on %I to app_user', t);
  end loop;
  grant usage, select on all sequences in schema public to app_user;
end $$;
-- audit_log: chỉ admin/quản lý xem; không ai sửa/xóa
revoke update, delete on audit_log from app_user;
drop policy if exists p_all on audit_log; create policy p_sel on audit_log for select using (app_role() in ('owner','director','it_engineer','auditor','accountant','tech_head'));
create policy p_ins on audit_log for insert with check (true);
-- View: hồ sơ trại tổng hợp (thông số + đếm hạ tầng + nhân sự + đàn + kho)
create or replace view v_farm_profile as
select f.*, r.name as region_name,
  (select count(*) from facilities x where x.farm_id=f.id and x.active) as facilities_n,
  (select coalesce(sum(area_m2),0) from facilities x where x.farm_id=f.id and x.active) as facilities_m2,
  (select count(*) from staff s where s.active and (s.farm_id=f.id or f.id = any(s.farm_ids))) as staff_n,
  (select count(*) from animals a where a.farm_id=f.id and a.status='ALIVE') as animals_alive,
  (select count(*) from plots p where p.farm_id=f.id and coalesce(p.active,true)) as plots_n,
  (select coalesce(sum(area_ha),0) from plots p where p.farm_id=f.id and coalesce(p.active,true)) as plots_ha,
  (select count(*) from warehouses w where w.farm_id=f.id and coalesce(w.active,true)) as warehouses_n,
  (select count(*) from locations l where l.farm_id=f.id and coalesce(l.active,true)) as locations_n,
  (select count(*) from devices d where d.farm_id=f.id and coalesce(d.active,true)) as devices_n
from farms f left join regions r on r.id=f.region_id;
grant select on v_farm_profile to app_user;
-- Bổ sung hồ sơ mẫu cho F01 (nhà công năng theo bộ gốc lõi 1,2 ha)
insert into facilities(id,farm_id,code,name,kind,area_m2,capacity,capacity_unit,built_year,status,created_by) values
 ('F01-FC-CHUONG-BO','F01','CHUONG-BO','Chuồng bò 2 dãy (khu C)','CHUONG',1800,120,'con',2026,'HOAT_DONG','SYSTEM'),
 ('F01-FC-CHUONG-GA','F01','CHUONG-GA','Chuồng gà 2 khối','CHUONG',600,2000,'con',2026,'HOAT_DONG','SYSTEM'),
 ('F01-FC-D5','F01','D5','Xưởng thức ăn D5','XUONG',400,5,'tấn/ngày',2026,'HOAT_DONG','SYSTEM'),
 ('F01-FC-KHO-K1','F01','KHO-K1','Kho vật tư – thuốc (K1)','KHO',80,null,null,2026,'HOAT_DONG','SYSTEM'),
 ('F01-FC-KHO-K3','F01','KHO-K3','Hố ủ chua (K3)','KHO',600,400,'tấn',2026,'HOAT_DONG','SYSTEM'),
 ('F01-FC-BIOGAS','F01','BIOGAS','Bể biogas HDPE','BE_BIOGAS',300,150,'m3',2026,'HOAT_DONG','SYSTEM'),
 ('F01-FC-TRUN','F01','TRUN','Nhà nuôi trùn – BSF (khu D)','XUONG',500,null,null,2026,'HOAT_DONG','SYSTEM'),
 ('F01-FC-NDH','F01','NDH','Nhà điều hành + phòng lab nhỏ','NHA_DIEU_HANH',150,null,null,2026,'HOAT_DONG','SYSTEM'),
 ('F01-FC-CAN','F01','CAN','Trạm cân 40 tấn + cổng','CAN',60,40,'tấn',2026,'HOAT_DONG','SYSTEM'),
 ('F01-FC-AO','F01','AO','Ao RAS/ao lắng','AO',3000,null,null,2026,'KE_HOACH','SYSTEM'),
 ('F01-FC-GIENG','F01','GIENG','Giếng khoan + bể 50 m3','GIENG',30,50,'m3',2026,'HOAT_DONG','SYSTEM'),
 ('F01-FC-TRAM-DIEN','F01','TRAM-DIEN','Trạm biến áp 250 kVA + solar 50 kWp','TRAM_DIEN',40,250,'kVA',2026,'HOAT_DONG','SYSTEM')
on conflict do nothing;
update farms set land_total_ha=coalesce(land_total_ha,s_ha), land_biomass_ha=coalesce(land_biomass_ha,round(s_ha*0.55,2)), land_core_ha=coalesce(land_core_ha,1.2), water_ha=coalesce(water_ha,round(s_ha*0.1,2)), power_kva=coalesce(power_kva,250), solar_kwp=coalesce(solar_kwp,50), water_source=coalesce(water_source,'Giếng khoan + hồ chứa'), road_access=coalesce(road_access,'Đường bê tông 6 m, xe 40 tấn vào được'), design_head=coalesce(design_head,120) where id='F01' and s_ha is not null;
