-- 0046 · TRỒNG TRỌT BỔ SUNG: thời tiết + ET0 (FAO-56 Hargreaves), Kc theo giai đoạn (FAO-56 bảng 12), nhật ký tưới, cân bằng nước,
--        phân tích đất, điều tra dịch hại IPM (ngưỡng), kế hoạch luân canh nhiều năm (kiểm tra cùng họ), hợp đồng liên kết hộ theo ô

-- 1) Thời tiết ngày (nguồn: trạm trại / API / nhập tay) — 1 dòng/trại/ngày, cho phép sửa (không phải sự kiện vận hành)
create table if not exists weather_daily(
  farm_id text not null references farms, day date not null,
  tmin numeric, tmax numeric, tavg numeric, rain_mm numeric default 0, rh_pct numeric, wind_ms numeric, solar_mj numeric, sunshine_h numeric,
  et0_mm numeric, source text default 'MANUAL', note text, updated_at timestamptz default now(), updated_by text,
  primary key(farm_id, day));
alter table weather_daily enable row level security; drop policy if exists p_all on weather_daily; create policy p_all on weather_daily for all using (can_see_farm(farm_id)) with check (true); grant select, insert, update on weather_daily to app_user;

-- ET0 Hargreaves-Samani (FAO-56 eq. 52): ET0 = 0.0023 * Ra * (Tmean+17.8) * sqrt(Tmax-Tmin); Ra (MJ/m2/d) theo vĩ độ + ngày trong năm (FAO-56 eq. 21–25)
create or replace function et0_hargreaves(p_lat numeric, p_day date, p_tmin numeric, p_tmax numeric) returns numeric language plpgsql immutable as $$
declare j int := extract(doy from p_day); phi numeric := radians(coalesce(p_lat, 10.5)); dr numeric; dlt numeric; ws numeric; ra numeric; tm numeric;
begin
  if p_tmin is null or p_tmax is null then return null; end if;
  dr := 1 + 0.033*cos(2*pi()*j/365.0); dlt := 0.409*sin(2*pi()*j/365.0 - 1.39);
  ws := acos(greatest(-1, least(1, -tan(phi)*tan(dlt))));
  ra := (24*60/pi())*0.0820*dr*(ws*sin(phi)*sin(dlt) + cos(phi)*cos(dlt)*sin(ws));
  tm := (p_tmin+p_tmax)/2;
  return round((0.0023*ra*(tm+17.8)*sqrt(greatest(p_tmax-p_tmin, 0)))::numeric, 2);
end $$;
create or replace function trg_weather_et0() returns trigger language plpgsql as $$
declare v_lat numeric; begin
  select lat into v_lat from farms where id = new.farm_id;
  if new.tavg is null and new.tmin is not null and new.tmax is not null then new.tavg := (new.tmin+new.tmax)/2; end if;
  if new.et0_mm is null then new.et0_mm := et0_hargreaves(v_lat, new.day, new.tmin, new.tmax); end if;
  new.updated_at := now(); new.updated_by := app_staff(); return new; end $$;
drop trigger if exists weather_daily_et0 on weather_daily; create trigger weather_daily_et0 before insert or update on weather_daily for each row execute function trg_weather_et0();

-- 2) Kc theo giai đoạn (FAO-56 Irrigation & Drainage Paper 56, Table 12 — giá trị chuẩn, không bịa; điều chỉnh theo vùng ở settings)
create table if not exists crop_kc(crop_code text not null, stage text not null check (stage in ('INI','DEV','MID','END')), kc numeric not null, days int, source text default 'FAO-56 Table 12', primary key(crop_code, stage));
grant select on crop_kc to app_user;
insert into crop_kc(crop_code, stage, kc, days) values
 ('NGO','INI',0.30,20),('NGO','DEV',0.75,35),('NGO','MID',1.20,40),('NGO','END',0.60,30),
 ('LUA','INI',1.05,30),('LUA','DEV',1.10,30),('LUA','MID',1.20,60),('LUA','END',0.90,30),
 ('CO','INI',0.40,10),('CO','DEV',0.70,20),('CO','MID',1.00,30),('CO','END',0.85,10),
 ('MIA','INI',0.40,35),('MIA','DEV',0.80,60),('MIA','MID',1.25,190),('MIA','END',0.75,120),
 ('SAN','INI',0.30,20),('SAN','DEV',0.55,40),('SAN','MID',0.80,90),('SAN','END',0.30,60),
 ('CHUOI','INI',0.50,120),('CHUOI','DEV',0.80,60),('CHUOI','MID',1.10,180),('CHUOI','END',1.00,5),
 ('DAU','INI',0.40,20),('DAU','DEV',0.75,30),('DAU','MID',1.15,40),('DAU','END',0.35,20),
 ('RAU','INI',0.70,20),('RAU','DEV',0.85,30),('RAU','MID',1.05,30),('RAU','END',0.95,10)
on conflict do nothing;

-- 3) Nhật ký tưới (sự kiện append-only)
select itran_make_event_table('irrigation_logs', $$
  plot_id text references plots, season_id text references crop_seasons, method text, -- NHO_GIOT|PHUN_MUA|TRAN|RANH|BOM_TAY|DRONE
  minutes numeric, volume_m3 numeric, flow_m3h numeric, water_source text, pump_id text, energy_kwh numeric, ec_water numeric, ph_water numeric, note text, photo_urls text[] default '{}'
$$);
-- 4) Điều tra dịch hại IPM (sự kiện): mật độ vs ngưỡng → mức xử lý
select itran_make_event_table('pest_scouting', $$
  plot_id text references plots, season_id text references crop_seasons, pest text not null, pest_kind text, -- SAU|BENH|CO_DAI|CHUOT|OC|KHAC
  stage text, density numeric, unit text, threshold numeric, sample_points int, incidence_pct numeric, severity int check (severity between 0 and 5),
  natural_enemies text, ipm_level text, -- THEO_DOI|SINH_HOC|CO_HOC|HOA_HOC_CUC_BO
  action text, action_due date, note text, photo_urls text[] default '{}'
$$);
do $$ declare t text; begin
  foreach t in array array['irrigation_logs','pest_scouting'] loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists p_sel on %I', t); execute format('create policy p_sel on %I for select using (can_see_farm(farm_id))', t);
    execute format('drop policy if exists p_ins on %I', t); execute format('create policy p_ins on %I for insert with check (farm_id = app_farm() and app_role() not in (''auditor'',''anon''))', t);
    execute format('drop policy if exists p_upd on %I', t); execute format('create policy p_upd on %I for update using (farm_id = app_farm() and app_role() not in (''auditor'',''anon'',''worker''))', t);
    execute format('drop policy if exists p_del on %I', t); execute format('create policy p_del on %I for delete using (false)', t);
    execute format('grant select, insert, update on %I to app_user', t);
  end loop; end $$;

-- 5) Phân tích đất (danh mục có sửa, kèm file kết quả)
create table if not exists soil_tests(
  id text primary key, farm_id text not null references farms, plot_id text references plots, sampled_at date not null, depth_cm int default 20,
  ph numeric, om_pct numeric, n_total_pct numeric, p_avail_mgkg numeric, k_avail_mgkg numeric, ec_dsm numeric, cec numeric, texture text, ca_mgkg numeric, mg_mgkg numeric, s_mgkg numeric, b_mgkg numeric, zn_mgkg numeric,
  heavy_metals jsonb default '{}'::jsonb, lab text, report_url text, recommendation text, next_due date, status text default 'ACTIVE', created_at timestamptz default now(), created_by text default app_staff(), attrs jsonb default '{}'::jsonb);
alter table soil_tests enable row level security; drop policy if exists p_all on soil_tests; create policy p_all on soil_tests for all using (can_see_farm(farm_id)) with check (true); grant select, insert, update on soil_tests to app_user;
-- 6) Kế hoạch luân canh nhiều năm theo ô
create table if not exists crop_rotation_plans(
  id text primary key, farm_id text not null references farms, plot_id text not null references plots, year int not null, season_no int not null default 1,
  crop_code text, crop_family text, -- HOA_THAO|DAU|CA|BAU_BI|THAP_TU|HANH|KHOAI|CO_LAU_NAM|PHU_XANH|BO_HOANG
  purpose text, planned_start date, planned_end date, status text default 'KE_HOACH', note text, created_at timestamptz default now(), created_by text default app_staff(), attrs jsonb default '{}'::jsonb,
  unique(plot_id, year, season_no));
alter table crop_rotation_plans enable row level security; drop policy if exists p_all on crop_rotation_plans; create policy p_all on crop_rotation_plans for all using (can_see_farm(farm_id)) with check (true); grant select, insert, update on crop_rotation_plans to app_user;
create or replace view v_rotation_check as
select r.*, p.name as plot_name,
  lag(r.crop_family) over (partition by r.plot_id order by r.year, r.season_no) as prev_family,
  case when r.crop_family is not null and r.crop_family = lag(r.crop_family) over (partition by r.plot_id order by r.year, r.season_no) and r.crop_family not in ('CO_LAU_NAM') then 'CUNG_HO_LIEN_TIEP' else null end as warning
from crop_rotation_plans r join plots p on p.id=r.plot_id where r.status<>'HUY';
grant select on v_rotation_check to app_user;
-- 7) Hợp đồng liên kết hộ / thuê đất theo ô
create table if not exists plot_contracts(
  id text primary key, farm_id text not null references farms, plot_id text not null references plots, partner_id text references partners, kind text not null default 'LIEN_KET', -- LIEN_KET|THUE_DAT|BAO_TIEU|GIA_CONG
  start_date date, end_date date, area_ha numeric, price_terms text, share_pct numeric, min_price numeric, inputs_by text, -- TRAI|HO|CHIA
  tech_support bool default true, status text default 'HIEU_LUC', contract_no text, doc_url text, note text, created_at timestamptz default now(), created_by text default app_staff(), attrs jsonb default '{}'::jsonb);
alter table plot_contracts enable row level security; drop policy if exists p_all on plot_contracts; create policy p_all on plot_contracts for all using (can_see_farm(farm_id)) with check (true); grant select, insert, update on plot_contracts to app_user;

-- 8) Cân bằng nước theo mùa vụ (mm): mưa + tưới − ETc (ET0×Kc theo giai đoạn tính từ ngày gieo)
create or replace function kc_on(p_crop text, p_days int) returns numeric language sql stable as $$
  with s as (select stage, kc, days, sum(days) over (order by array_position(array['INI','DEV','MID','END'], stage)) as cum from crop_kc where crop_code=p_crop)
  select coalesce((select kc from s where p_days < cum order by cum limit 1), (select kc from s where stage='END'), 1.0) $$;
create or replace view v_water_balance as
select cs.id as season_id, cs.farm_id, cs.code, cs.plot_id, cs.crop, cs.crop_code, cs.sow_date, cs.area_ha,
  coalesce((select sum(w.rain_mm) from weather_daily w where w.farm_id=cs.farm_id and w.day between cs.sow_date and coalesce(cs.harvest_end, current_date)),0) as rain_mm,
  coalesce((select sum(w.et0_mm * kc_on(cs.crop_code, (w.day - cs.sow_date)::int)) from weather_daily w where w.farm_id=cs.farm_id and w.day between cs.sow_date and coalesce(cs.harvest_end, current_date)),0) as etc_mm,
  coalesce((select sum(i.volume_m3) from irrigation_logs i where i.season_id=cs.id and i.status='ACTIVE'),0) as irrigation_m3,
  case when coalesce(cs.area_ha,0)>0 then round(coalesce((select sum(i.volume_m3) from irrigation_logs i where i.season_id=cs.id and i.status='ACTIVE'),0) / cs.area_ha / 10, 1) else null end as irrigation_mm,
  (select count(*) from pest_scouting ps where ps.season_id=cs.id and ps.status='ACTIVE' and ps.density is not null and ps.threshold is not null and ps.density >= ps.threshold) as pests_over_threshold
from crop_seasons cs where cs.status not in ('HUY');
grant select on v_water_balance to app_user;
-- ràng buộc: bảng thời tiết/đất/luân canh/liên kết ghi audit như danh mục
do $$ declare t text; begin
  foreach t in array array['weather_daily','soil_tests','crop_rotation_plans','plot_contracts'] loop
    execute format('drop trigger if exists %s_audit on %I', t, t);
    execute format('create trigger %s_audit after insert or update or delete on %I for each row execute function itran_audit()', t, t);
  end loop; end $$;
-- event topics
insert into event_topics(topic, description, producer_dept, consumer_depts) values
 ('irrigation.logged','Nhật ký tưới ghi','TT','{CNTB,KTCN}'),
 ('pest.over_threshold','Dịch hại vượt ngưỡng IPM','TT','{KTCN,QA}'),
 ('weather.alert','Cảnh báo thời tiết (mưa lớn/nắng nóng)','CNTB','{TT,CCU,GDT}')
on conflict (topic) do nothing;
