-- 0018 · HỒ SƠ CANH TÁC & THU HOẠCH (VietGAP/hữu cơ/GlobalG.A.P.) · BÁN HÀNG ĐẦY ĐỦ (CRM · POS · khuyến mãi · kênh) ·
--        DU LỊCH – LƯU TRÚ – ẨM THỰC – TIỆC/MICE – TOUR (module resort) · Danh mục HỒ SƠ (records catalog)
-- ===== 1. HỒ SƠ CANH TÁC =====
-- Mùa vụ theo ô/thửa: một "hồ sơ canh tác" = 1 crop_season (giống, nguồn giống, gieo, thu dự kiến, chứng nhận) + toàn bộ crop_logs/crop_inputs/harvests trong kỳ
create table if not exists crop_seasons(
  id text primary key, farm_id text not null, code text not null, plot_id text not null, crop text not null, variety text, seed_source text, seed_lot text, seed_cert text,  -- nguồn/lô/chứng nhận giống
  area_ha numeric, sow_date date, expected_harvest date, harvest_start date, harvest_end date, cert_scheme text,   -- VIETGAP|ORGANIC_VN|EU_ORGANIC|USDA_NOP|GLOBALGAP|NONE
  conversion_stage text, -- chuyển đổi hữu cơ: C1|C2|C3|ORGANIC
  prev_crop text, soil_prep text, irrigation text, target_yield_kg numeric, actual_yield_kg numeric, status text default 'DANG_TRONG', -- KE_HOACH|DANG_TRONG|THU_HOACH|KET_THUC|HUY
  responsible_id text, note text, created_at timestamptz default now(), created_by text, unique(farm_id, code));
create index if not exists crop_seasons_plot on crop_seasons(farm_id, plot_id, status);
-- Vật tư đầu vào ruộng: phân bón / thuốc BVTV / sinh học / vôi… có thời gian cách ly PHI (như ngưng thuốc thú y)
select itran_make_event_table('crop_inputs', $$
  season_id text, plot_id text, sku text, product_name text, kind text, -- PHAN_HUU_CO|PHAN_VO_CO|THUOC_BVTV|SINH_HOC|VOI|VI_LUONG|KHAC
  qty numeric, unit text, dose_per_ha numeric, method text, target_pest text, phi_days int, safe_after date, applicator_id text, weather text, temp_c numeric, wind text, ppe_ok bool, organic_allowed bool, lot_no text, note text
$$);
-- Thu hoạch: lô thu hoạch = đơn vị truy xuất (đi vào kho K2/K5 qua inventory_moves; PHI phải qua)
select itran_make_event_table('harvests', $$
  season_id text, plot_id text, crop text, variety text, qty_kg numeric, unit text, moisture_pct numeric, grade text, brix numeric, harvest_lot text, crew text[], machine_id text, weigh_ticket_id text,
  dest_warehouse_id text, dest_lot_id text, phi_ok bool, residue_test text, buyer_partner_id text, price numeric, note text
$$);
-- Trigger PHI: chặn thu hoạch nếu ô còn trong thời gian cách ly thuốc (safe_after > ngày thu) — trừ khi phi_ok=true (đã có kết quả tồn dư)
create or replace function itran_check_phi() returns trigger language plpgsql as $$
declare d date; begin
  select max(safe_after) into d from crop_inputs where farm_id=new.farm_id and status='ACTIVE' and plot_id=new.plot_id and safe_after is not null and safe_after > new.ts::date;
  if d is not null and coalesce(new.phi_ok,false)=false then raise exception 'ERR_PHI_NOT_ELAPSED: ô % còn cách ly đến %', new.plot_id, d; end if;
  return new; end $$;
drop trigger if exists harvests_phi on harvests; create trigger harvests_phi before insert on harvests for each row execute function itran_check_phi();
-- Hồ sơ canh tác tổng hợp (1 dòng/mùa vụ) — nền của "Nhật ký sản xuất" xuất cho VietGAP/hữu cơ/GlobalG.A.P.
create or replace view v_crop_dossier as
select s.*, p.name as plot_name, p.area_ha as plot_area_ha,
  (select count(*) from crop_logs l where l.farm_id=s.farm_id and l.plot_id=s.plot_id and l.status='ACTIVE' and l.ts::date between s.sow_date and coalesce(s.harvest_end, current_date)) as logs_n,
  (select count(*) from crop_inputs i where i.farm_id=s.farm_id and (i.season_id=s.id or (i.plot_id=s.plot_id and i.ts::date between s.sow_date and coalesce(s.harvest_end, current_date))) and i.status='ACTIVE') as inputs_n,
  (select coalesce(sum(qty),0) from crop_inputs i where i.farm_id=s.farm_id and (i.season_id=s.id or (i.plot_id=s.plot_id and i.ts::date between s.sow_date and coalesce(s.harvest_end, current_date))) and i.status='ACTIVE' and i.kind like 'PHAN%') as fert_qty,
  (select count(*) from crop_inputs i where i.farm_id=s.farm_id and (i.season_id=s.id or (i.plot_id=s.plot_id and i.ts::date between s.sow_date and coalesce(s.harvest_end, current_date))) and i.status='ACTIVE' and i.kind='THUOC_BVTV') as pesticide_n,
  (select max(safe_after) from crop_inputs i where i.farm_id=s.farm_id and i.plot_id=s.plot_id and i.status='ACTIVE') as phi_until,
  (select coalesce(sum(qty_kg),0) from harvests h where h.farm_id=s.farm_id and (h.season_id=s.id or (h.plot_id=s.plot_id and h.ts::date between s.sow_date and coalesce(s.harvest_end, current_date))) and h.status='ACTIVE') as harvested_kg,
  (select count(*) from harvests h where h.farm_id=s.farm_id and (h.season_id=s.id or (h.plot_id=s.plot_id and h.ts::date between s.sow_date and coalesce(s.harvest_end, current_date))) and h.status='ACTIVE') as harvests_n,
  (select count(*) from lab_samples x where x.farm_id=s.farm_id and x.subject_ref in (s.id, s.plot_id)) as lab_n
from crop_seasons s left join plots p on p.id=s.plot_id;
grant select on v_crop_dossier to app_user;
-- ===== 2. BÁN HÀNG ĐẦY ĐỦ: CRM · kênh · khuyến mãi · POS =====
alter table sales add column if not exists channel_code text, add column if not exists detail jsonb default '{}'::jsonb, add column if not exists promotion_id text, add column if not exists discount numeric;
alter table tasks add column if not exists ref_table text, add column if not exists ref_id text;
create table if not exists sales_channels(code text primary key, name text not null, kind text, -- B2B|B2C|POS|ONLINE|EXPORT|RESORT
  fee_pct numeric default 0, active bool default true);
insert into sales_channels(code,name,kind) values ('DAI_LY','Đại lý / phân phối','B2B'),('SIEU_THI','Siêu thị / chuỗi','B2B'),('NHA_HANG','Nhà hàng / khách sạn (HORECA)','B2B'),('CHE_BIEN','Nhà máy chế biến','B2B'),('POS','Cửa hàng tại trại','POS'),('ONLINE','Online (web/Zalo/Shopee/TikTok)','ONLINE'),('NHAN_NUOI','Khách nhận nuôi / chăm sóc hộ','B2C'),('XUAT_KHAU','Xuất khẩu','EXPORT'),('RESORT','Farmstay / nhà hàng trại','RESORT') on conflict do nothing;
create table if not exists crm_leads(id text primary key, farm_id text, org_id text default 'ITRAN', name text not null, company text, phone text, email text, source text, -- HOI_CHO|GIOI_THIEU|WEB|ZALO|GOI_DEN|SU_KIEN
  segment text, channel_code text, interest text, est_value numeric, stage text default 'MOI', -- MOI|LIEN_HE|BAO_GIA|DAM_PHAN|THANG|THUA
  owner_id text, partner_id text, next_action text, next_at timestamptz, lost_reason text, created_at timestamptz default now(), created_by text, updated_at timestamptz default now());
create table if not exists crm_activities(id uuid primary key default gen_random_uuid(), farm_id text, lead_id text, partner_id text, kind text, -- GOI|GAP|EMAIL|ZALO|THAM_TRAI|BAO_GIA|MAU
  ts timestamptz default now(), summary text, outcome text, next_at timestamptz, by_staff text, status text default 'ACTIVE');
create table if not exists promotions(id text primary key, farm_id text, name text not null, kind text, -- GIAM_PCT|GIAM_TIEN|MUA_X_TANG_Y|COMBO|VOUCHER
  value numeric, min_qty numeric, min_amount numeric, skus text[] default '{}', channels text[] default '{}', starts_on date, ends_on date, budget numeric, used_count int default 0, active bool default true, created_by text);
create table if not exists pos_shifts(id text primary key, farm_id text not null, location_id text, opened_at timestamptz default now(), opened_by text, closed_at timestamptz, closed_by text, cash_open numeric default 0, cash_close numeric, cash_expected numeric, diff numeric, note text, status text default 'MO');
select itran_make_event_table('pos_receipts', $$
  shift_id text, receipt_no text, partner_id text, lines jsonb, subtotal numeric, discount numeric, promotion_id text, tax numeric, total numeric, payment text, paid numeric, change_due numeric, channel_code text default 'POS', note text
$$);
-- Mỗi hóa đơn POS → sinh sales (append-only) qua trigger để doanh thu về 1 chỗ
create or replace function itran_pos_to_sales() returns trigger language plpgsql as $$
declare l jsonb; begin
  for l in select * from jsonb_array_elements(coalesce(new.lines,'[]'::jsonb)) loop
    insert into sales(farm_id, created_by, client_ref, ts, partner_id, sku, qty, price, amount, channel, channel_code, payment, paid, source, promotion_id, detail)
    values (new.farm_id, new.created_by, new.client_ref||':'||coalesce(l->>'sku','?'), new.ts, new.partner_id, l->>'sku', (l->>'qty')::numeric, (l->>'price')::numeric, coalesce((l->>'amount')::numeric,(l->>'qty')::numeric*(l->>'price')::numeric), 3, 'POS', new.payment, true, 'APP', new.promotion_id, jsonb_build_object('receipt', new.receipt_no, 'shift', new.shift_id))
    on conflict do nothing;
  end loop; return new; end $$;
drop trigger if exists pos_receipts_sales on pos_receipts; create trigger pos_receipts_sales after insert on pos_receipts for each row execute function itran_pos_to_sales();
create or replace view v_crm_pipeline as select farm_id, stage, count(*) as n, coalesce(sum(est_value),0) as value from crm_leads group by 1,2;
grant select on v_crm_pipeline to app_user;
-- ===== 3. DU LỊCH · LƯU TRÚ · ẨM THỰC · TIỆC/MICE · TOUR =====
create table if not exists hosp_room_types(id text primary key, farm_id text not null, code text not null, name text not null, capacity int, base_price numeric, weekend_price numeric, amenities text[] default '{}', description text, active bool default true);
create table if not exists hosp_rooms(id text primary key, farm_id text not null, room_type_id text references hosp_room_types, code text not null, name text, floor text, facility_id text, status text default 'SAN_SANG', -- SAN_SANG|DANG_O|DON_DEP|BAO_TRI|KHOA
  active bool default true);
create table if not exists hosp_services(id text primary key, farm_id text not null, code text not null, name text not null, kind text not null, -- TOUR|TRAI_NGHIEM|AN_UONG|TIEC|HOI_NGHI|SPA|THUE_XE|KHAC
  unit text, price numeric, duration_min int, capacity int, description text, sku text, active bool default true);
create table if not exists hosp_menus(id text primary key, farm_id text not null, name text not null, kind text, -- A_LA_CARTE|SET|BUFFET|TIEC
  price_per_pax numeric, items jsonb default '[]'::jsonb, -- [{name, sku, qty_per_pax, price}] — farm-to-table gắn SKU
  active bool default true);
create table if not exists hosp_bookings(id text primary key, farm_id text not null, code text not null, guest_partner_id text, guest_name text, guest_phone text, guest_email text, guest_id_number text, nationality text, pax_adult int default 1, pax_child int default 0,
  check_in date not null, check_out date not null, room_id text, room_type_id text, rate numeric, nights int, channel text, -- TRUC_TIEP|OTA|CTY_LU_HANH|ZALO|WEB
  ota_ref text, status text default 'GIU_CHO', -- GIU_CHO|XAC_NHAN|DA_NHAN|DA_TRA|HUY|NO_SHOW
  deposit numeric default 0, total numeric, paid numeric default 0, special_requests text, source_lead_id text, created_at timestamptz default now(), created_by text, updated_at timestamptz default now());
create index if not exists hosp_bookings_dates on hosp_bookings(farm_id, check_in, check_out);
create table if not exists hosp_events(id text primary key, farm_id text not null, code text not null, name text not null, kind text, -- TIEC_CUOI|SINH_NHAT|HOI_NGHI|TEAM_BUILDING|GALA|LOP_HOC|KHAC
  customer_partner_id text, contact_name text, contact_phone text, event_date date not null, start_time time, end_time time, pax int, venue_facility_id text, menu_id text, price_per_pax numeric, services jsonb default '[]'::jsonb,
  quote numeric, deposit numeric default 0, total numeric, paid numeric default 0, status text default 'BAO_GIA', -- BAO_GIA|XAC_NHAN|DANG_CHUAN_BI|DA_DIEN_RA|HOAN_TAT|HUY
  brief text, checklist jsonb default '[]'::jsonb, created_at timestamptz default now(), created_by text);
create table if not exists hosp_tours(id text primary key, farm_id text not null, service_id text references hosp_services, name text not null, tour_date date not null, start_time time, guide_id text, capacity int, booked int default 0, price numeric, route text, status text default 'MO'); -- MO|DAY|DANG_DI|XONG|HUY
create table if not exists hosp_tour_bookings(id uuid primary key default gen_random_uuid(), farm_id text not null, tour_id text references hosp_tours, booking_id text, guest_name text, guest_phone text, pax int default 1, amount numeric, paid bool default false, status text default 'XAC_NHAN', created_at timestamptz default now(), created_by text);
-- Folio: mọi khoản thu của khách (phòng, ăn uống, dịch vụ, tiệc) — append-only; thanh toán → sales (kênh RESORT)
select itran_make_event_table('hosp_folio', $$
  booking_id text, event_id text, tour_booking_id text, guest_partner_id text, kind text, -- PHONG|AN_UONG|DICH_VU|TIEC|TOUR|PHU_THU|GIAM_GIA|THANH_TOAN
  description text, service_id text, menu_id text, sku text, qty numeric, unit_price numeric, amount numeric, payment text, note text
$$);
create or replace function itran_folio_to_sales() returns trigger language plpgsql as $$
begin
  if new.kind='THANH_TOAN' then
    insert into sales(farm_id, created_by, client_ref, ts, partner_id, sku, qty, price, amount, channel, channel_code, payment, paid, source, detail)
    values (new.farm_id, new.created_by, new.client_ref||':pay', new.ts, new.guest_partner_id, new.sku, 1, new.amount, new.amount, 3, 'RESORT', coalesce(new.payment,'TM'), true, 'APP', jsonb_build_object('booking', new.booking_id, 'event', new.event_id, 'tour', new.tour_booking_id))
    on conflict do nothing;
  end if; return new; end $$;
drop trigger if exists hosp_folio_sales on hosp_folio; create trigger hosp_folio_sales after insert on hosp_folio for each row execute function itran_folio_to_sales();
-- Housekeeping = tasks kind 'DON_PHONG' (dùng task engine sẵn có) — hàm sinh việc dọn phòng khi trả phòng
create or replace function itran_hosp_checkout() returns trigger language plpgsql as $$
begin
  if new.status='DA_TRA' and old.status is distinct from 'DA_TRA' and new.room_id is not null then
    update hosp_rooms set status='DON_DEP' where id=new.room_id;
    insert into tasks(farm_id, kind, title, role_hint, priority, due_at, ref_table, ref_id) values (new.farm_id, 'DON_PHONG', 'Dọn phòng '||(select code from hosp_rooms where id=new.room_id)||' sau khách '||coalesce(new.guest_name,''), 'worker', 'CAO', now() + interval '3 hours', 'hosp_bookings', new.id);
  end if;
  if new.status='DA_NHAN' and old.status is distinct from 'DA_NHAN' and new.room_id is not null then update hosp_rooms set status='DANG_O' where id=new.room_id; end if;
  return new; end $$;
drop trigger if exists hosp_bookings_checkout on hosp_bookings; create trigger hosp_bookings_checkout after update on hosp_bookings for each row execute function itran_hosp_checkout();
-- KPI lưu trú: công suất phòng, ADR, RevPAR theo ngày; F&B; tiệc
create or replace view v_hosp_occupancy as
select b.farm_id, d::date as day, count(distinct b.room_id) as rooms_sold, (select count(*) from hosp_rooms r where r.farm_id=b.farm_id and r.active) as rooms_total,
  round(count(distinct b.room_id)::numeric / nullif((select count(*) from hosp_rooms r where r.farm_id=b.farm_id and r.active),0) * 100, 1) as occ_pct,
  round(avg(b.rate),0) as adr, round(sum(b.rate) / nullif((select count(*) from hosp_rooms r where r.farm_id=b.farm_id and r.active),0), 0) as revpar
from hosp_bookings b cross join lateral generate_series(b.check_in, b.check_out - 1, interval '1 day') d where b.status in ('XAC_NHAN','DA_NHAN','DA_TRA') group by 1,2;
create or replace view v_hosp_today as
select f.id as farm_id,
  (select count(*) from hosp_bookings b where b.farm_id=f.id and b.check_in=current_date and b.status in ('GIU_CHO','XAC_NHAN')) as arrivals,
  (select count(*) from hosp_bookings b where b.farm_id=f.id and b.check_out=current_date and b.status='DA_NHAN') as departures,
  (select count(*) from hosp_bookings b where b.farm_id=f.id and b.status='DA_NHAN') as in_house,
  (select count(*) from hosp_rooms r where r.farm_id=f.id and r.status='DON_DEP') as rooms_dirty,
  (select count(*) from hosp_events e where e.farm_id=f.id and e.event_date between current_date and current_date+7 and e.status in ('XAC_NHAN','DANG_CHUAN_BI')) as events_7d,
  (select coalesce(sum(pax),0) from hosp_events e where e.farm_id=f.id and e.event_date between current_date and current_date+7 and e.status in ('XAC_NHAN','DANG_CHUAN_BI')) as event_pax_7d,
  (select count(*) from hosp_tours t where t.farm_id=f.id and t.tour_date=current_date and t.status in ('MO','DAY','DANG_DI')) as tours_today,
  (select coalesce(sum(amount),0) from hosp_folio x where x.farm_id=f.id and x.status='ACTIVE' and x.kind='THANH_TOAN' and x.ts::date=current_date) as revenue_today
from farms f;
grant select on v_hosp_occupancy, v_hosp_today to app_user;
-- ===== 4. DANH MỤC HỒ SƠ (records catalog) — "hồ sơ nào cần đưa vào" = dữ liệu, không hard-code =====
create table if not exists records_catalog(code text primary key, name text not null, domain text not null, legal_basis text, tables text[] default '{}', export_kind text, retention_years int, owner_role text, required_for text[] default '{}', description text, position int default 0);
insert into records_catalog(code,name,domain,legal_basis,tables,export_kind,retention_years,owner_role,required_for,description,position) values
 ('HS-CANH-TAC','Hồ sơ canh tác / Nhật ký sản xuất trồng trọt','TRONG_TROT','TCVN 11892-1:2017 (VietGAP), NĐ 109/2018 (hữu cơ), GlobalG.A.P. IFA','{crop_seasons,crop_logs,crop_inputs,plots}','crop-dossier',3,'tech_head','{VIETGAP,ORGANIC,GLOBALGAP,XUAT_KHAU}','Giống & nguồn giống, làm đất, gieo, phân bón, thuốc BVTV (PHI), tưới, thời tiết, người thực hiện',1),
 ('HS-THU-HOACH','Hồ sơ thu hoạch & sơ chế','TRONG_TROT','VietGAP mục thu hoạch; ATTP','{harvests,weigh_tickets,inventory_moves,lots}','harvest-log',3,'team_lead','{VIETGAP,ORGANIC,XUAT_KHAU}','Ngày thu, ô, lô, kg, ẩm độ, phẩm cấp, PHI, tồn dư, kho đích, người thu',2),
 ('HS-DAT-NUOC','Hồ sơ đất – nước – môi trường','TRONG_TROT','VietGAP; QCVN 08/09; NĐ 109 hữu cơ','{lab_samples,sensor_reads,documents}','table:lab_samples',5,'tech_head','{VIETGAP,ORGANIC}','Phân tích đất/nước định kỳ, nguồn nước tưới, quan trắc',3),
 ('HS-SO-DAN','Sổ đàn & định danh cá thể','CHAN_NUOI','Luật Chăn nuôi 2018; TT 20/2019; QCVN 01-14','{animals,animal_tags,intake_lots,animal_groups,animal_events}','herd',5,'tech_head','{TRUY_XUAT,XUAT_KHAU,NHAN_NUOI}','Mã cá thể, nguồn gốc, lô nhập, di chuyển, cân, sinh sản, chết/loại',4),
 ('HS-THU-Y','Sổ theo dõi dịch bệnh – thuốc thú y – vaccine','CHAN_NUOI','Luật Thú y 2015; TT 12/2020; TT 13/2016','{animal_events,vaccine_schedules,treatment_protocols}','medicine-book',5,'tech_head','{TRUY_XUAT,ATTP,XUAT_KHAU}','Bệnh, điều trị, thuốc, liều, ngưng thuốc, vaccine, người thực hiện',5),
 ('HS-THUC-AN','Hồ sơ thức ăn & công thức','CHAN_NUOI','NĐ 13/2020 (TACN); ATTP','{feed_logs,recipes,batch_logs,inventory_moves}','table:feed_logs',3,'tech_head','{TRUY_XUAT,ORGANIC}','Nguyên liệu, công thức, mẻ trộn, sai số, nguồn gốc',6),
 ('HS-ATTP','Hồ sơ ATTP / HACCP / vệ sinh','CHE_BIEN','Luật ATTP; TT 38/2018; ISO 22000; HACCP','{checklist_runs,batch_logs,calibrations,incidents}','table:checklist_runs',3,'tech_head','{ATTP,XUAT_KHAU,HORECA}','Checklist vệ sinh, CCP, nhiệt độ kho lạnh, hiệu chuẩn, sự cố',7),
 ('HS-KHO','Thẻ kho – kiểm kê – FEFO – nhập xuất tồn','KHO','Chế độ kế toán TT 200/133; ATTP lô/hạn','{inventory_moves,stocktakes,adjustments,lots}','stock-ledger',10,'accountant','{THUE,KIEM_TOAN}','Nhập/xuất/tồn theo lô, hạn dùng, kiểm kê, chênh lệch',8),
 ('HS-TRUY-XUAT','Hồ sơ truy xuất nguồn gốc lô','CHE_BIEN','TT 74/2011; TT 25/2019; EPCIS 2.0/GS1','{lots,inventory_moves,batch_logs,sales}','epcis',5,'tech_head','{XUAT_KHAU,SIEU_THI}','Từ giống/nguyên liệu → mẻ → SKU → khách hàng, mã QR',9),
 ('HS-MOI-TRUONG','Hồ sơ môi trường – chất thải – biogas','MOI_TRUONG','Luật BVMT 2020; NĐ 08/2022; giấy phép MT','{batch_logs,sensor_reads,documents,incidents}','table:batch_logs',5,'tech_head','{GIAY_PHEP_MT}','Lượng phân/nước thải xử lý, biogas, compost, quan trắc, sự cố',10),
 ('HS-THIET-BI','Hồ sơ thiết bị – bảo trì – hiệu chuẩn','KY_THUAT','ISO 9001; hiệu chuẩn cân (ĐLVN)','{devices,calibrations,tasks}','table:calibrations',5,'it_engineer','{ATTP,KIEM_TOAN}','Lý lịch máy, giờ máy, bảo trì, hiệu chuẩn cân/cảm biến',11),
 ('HS-NHAN-SU','Hồ sơ nhân sự – đào tạo – sức khỏe','NHAN_SU','BLLĐ 2019; ATTP (khám SK, tập huấn)','{staff,kpi_results,checklist_runs}','table:staff',10,'director','{ATTP,GLOBALGAP}','Hợp đồng, chứng chỉ SOP, khám sức khỏe, tập huấn ATTP, KPI',12),
 ('HS-BAN-HANG','Hồ sơ bán hàng – hợp đồng – công nợ','KINH_DOANH','Luật Thương mại; TT 78/2021 HĐĐT','{sales,orders,contracts,partners,pos_receipts}','sales-tax',10,'accountant','{THUE,KIEM_TOAN}','Đơn, HĐ, hóa đơn, thu tiền, công nợ, kênh',13),
 ('HS-KE-TOAN','Sổ kế toán – chi phí – P&L phân hệ','KE_TOAN','TT 200/2014, TT 133/2016','{expense_requests,cc_fixed_costs,bank_statement_lines,funds}','table:expense_requests',10,'accountant','{THUE,KIEM_TOAN}','Chi, quỹ, giá vốn, đối chiếu ngân hàng',14),
 ('HS-XNK','Hồ sơ xuất nhập khẩu','XNK','Luật Hải quan; TT 39/2018; CO/Phyto/Health cert','{trade_contracts,shipments,trade_documents,customs_declarations,import_permits}','table:shipments',10,'director','{XUAT_KHAU}','HĐ ngoại, LC, vận đơn, CO, kiểm dịch, tờ khai, thanh toán',15),
 ('HS-PHAP-LY','Hồ sơ pháp lý – giấy phép – chứng nhận','PHAP_LY','ĐKKD; giấy phép MT; VietGAP/hữu cơ/GlobalG.A.P.; ATTP; PCCC','{farms,documents}','table:documents',99,'owner','{}','Giấy tờ pháp nhân, đất, giấy phép, chứng nhận (hạn, tái đánh giá)',16),
 ('HS-RD','Hồ sơ R&D – thử nghiệm','RD','Nội bộ; SHTT','{rd_trials,rd_observations,lab_samples,knowledge_articles}','table:rd_trials',10,'tech_head','{}','Giả thuyết, nhánh đối chứng, quan sát, kết luận',17),
 ('HS-DU-LICH','Hồ sơ lưu trú – khách – tiệc','DU_LICH','Luật Du lịch 2017; NĐ 168/2017; khai báo lưu trú','{hosp_bookings,hosp_events,hosp_folio}','table:hosp_bookings',5,'director','{}','Khách lưu trú (khai báo), tiệc/sự kiện, doanh thu dịch vụ',18),
 ('HS-NHAN-NUOI','Hồ sơ chăm sóc hộ / nhận nuôi','KINH_DOANH','Hợp đồng dân sự','{custody_contracts,animals,animal_events,customer_messages}','herd',5,'director','{NHAN_NUOI}','HĐ, cá thể, lịch sử chăm sóc, ảnh/live, tin nhắn',19),
 ('HS-AUDIT','Gói audit toàn bộ (kiểm toán/kế toán/cơ quan)','QUAN_TRI','Kiểm toán độc lập; thanh tra','{audit_log,recon_results,alerts,job_runs}','audit-pack',10,'auditor','{KIEM_TOAN}','Toàn bộ sự kiện + đối soát + cảnh báo + vết thay đổi (sha256)',20)
on conflict (code) do update set name=excluded.name, tables=excluded.tables, export_kind=excluded.export_kind, description=excluded.description, legal_basis=excluded.legal_basis;
-- ===== RLS + GRANT =====
do $$ declare t text; begin
  foreach t in array array['crop_seasons','sales_channels','crm_leads','crm_activities','promotions','pos_shifts','hosp_room_types','hosp_rooms','hosp_services','hosp_menus','hosp_bookings','hosp_events','hosp_tours','hosp_tour_bookings','records_catalog']
  loop
    execute format('alter table %I enable row level security', t); execute format('drop policy if exists p_all on %I', t);
    if t in ('sales_channels','records_catalog') then execute format('create policy p_all on %I for all using (true) with check (true)', t);
    else execute format('create policy p_all on %I for all using (farm_id is null or can_see_farm(farm_id)) with check (true)', t); end if;
    execute format('grant select, insert, update on %I to app_user', t);
  end loop;
end $$;
-- audit trigger cho danh mục mới
do $$ declare t text; begin foreach t in array array['crop_seasons','sales_channels','crm_leads','promotions','hosp_room_types','hosp_rooms','hosp_services','hosp_menus','hosp_bookings','hosp_events','hosp_tours','records_catalog'] loop
  execute format('drop trigger if exists audit_%1$s on %1$s; create trigger audit_%1$s after insert or update or delete on %1$s for each row execute function itran_audit()', t); end loop; end $$;
-- Seed mẫu F01: mùa vụ, phòng, dịch vụ, menu (để màn hình có dữ liệu)
insert into crop_seasons(id,farm_id,code,plot_id,crop,variety,seed_source,area_ha,sow_date,expected_harvest,cert_scheme,conversion_stage,status,created_by)
select 'F01-CS-'||substr(p.id, length(p.id)-3), 'F01', 'CS-'||substr(p.id, length(p.id)-3), p.id, coalesce(p.current_crop,'Cỏ Mombasa'), case when p.current_crop ilike '%bắp%' or p.current_crop ilike '%ngô%' then 'NK7328' else 'Mombasa' end, 'Cty giống Đông Nam Bộ', p.area_ha, current_date-60, current_date+30, 'VIETGAP', 'C1', 'DANG_TRONG', 'SYSTEM' from plots p where p.farm_id='F01' on conflict do nothing;
insert into hosp_room_types(id,farm_id,code,name,capacity,base_price,weekend_price,amenities) values ('F01-RT-BUNGALOW','F01','BUNGALOW','Bungalow vườn',2,900000,1200000,'{máy lạnh,wifi,bữa sáng}'),('F01-RT-FAMILY','F01','FAMILY','Nhà gia đình',6,2200000,2800000,'{bếp,sân,BBQ}'),('F01-RT-DORM','F01','DORM','Dorm học sinh',12,150000,150000,'{giường tầng}') on conflict do nothing;
insert into hosp_rooms(id,farm_id,room_type_id,code,name) select 'F01-RM-B'||g, 'F01','F01-RT-BUNGALOW','B'||g,'Bungalow '||g from generate_series(1,6) g on conflict do nothing;
insert into hosp_rooms(id,farm_id,room_type_id,code,name) values ('F01-RM-FAM1','F01','F01-RT-FAMILY','FAM1','Nhà gia đình 1'),('F01-RM-FAM2','F01','F01-RT-FAMILY','FAM2','Nhà gia đình 2'),('F01-RM-DORM1','F01','F01-RT-DORM','DORM1','Dorm 1') on conflict do nothing;
insert into hosp_services(id,farm_id,code,name,kind,unit,price,duration_min,capacity) values ('F01-SV-TOUR-TRAI','F01','TOUR-TRAI','Tour tham quan trại tuần hoàn (2h)','TOUR','khách',120000,120,30),('F01-SV-CHO-BO-AN','F01','CHO-BO-AN','Trải nghiệm cho bò ăn – vắt sữa dê','TRAI_NGHIEM','khách',80000,60,20),('F01-SV-BBQ','F01','BBQ','BBQ farm-to-table','AN_UONG','suất',250000,120,60),('F01-SV-HOI-TRUONG','F01','HOI-TRUONG','Thuê hội trường 100 chỗ','HOI_NGHI','buổi',3000000,240,100),('F01-SV-XE-DIEN','F01','XE-DIEN','Xe điện tham quan','THUE_XE','giờ',150000,60,6) on conflict do nothing;
insert into hosp_menus(id,farm_id,name,kind,price_per_pax,items) values ('F01-MN-SET-TRAI','F01','Set trại 6 món','SET',220000,'[{"name":"Gà thả vườn nướng","sku":"SKU-GA-1","qty_per_pax":0.3},{"name":"Trứng gà ta chiên lá hẹ","sku":"SKU-TRUNG-10","qty_per_pax":0.2},{"name":"Rau vườn luộc","qty_per_pax":0.2},{"name":"Cá RAS kho","sku":"SKU-CA-1","qty_per_pax":0.25},{"name":"Canh chua","qty_per_pax":0.2},{"name":"Cơm gạo lứt","qty_per_pax":0.15}]'),('F01-MN-TIEC-A','F01','Tiệc A (10 món)','TIEC',350000,'[]') on conflict do nothing;
