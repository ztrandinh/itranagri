-- 0083 · MÔ-ĐUN KẾ HOẠCH (kim tự tháp Năm → S&OP tháng → bộ phận tuần → việc; vòng KH–TT–sửa)
-- 1) GIẢ ĐỊNH tự tính từ dữ liệu thật (tỷ lệ đẻ, tăng trọng, chết, năng suất/ha, mùa vụ cỏ theo tháng, giá bán/mua, định mức) — người chỉ ghi đè
-- 2) NĂNG LỰC (chuồng, hào ủ/silo, D5, người, vốn) — ràng buộc kế hoạch
-- 3) KẾ HOẠCH NĂM (mục tiêu + phiên bản + duyệt) → KẾ HOẠCH ĐÀN THEO LỨA (nhập–phối–đẻ–vỗ béo–cửa xuất) → LỊCH VỤ TRỒNG 12 tháng (cung sinh khối đều)
-- 4) S&OP THÁNG: 12 tháng × (đàn, thức ăn cần, cung sinh khối, mua bù/dư, SX D5, bán & doanh thu, chi phí, dòng tiền) → chốt phiên bản → ban hành việc theo tháng cho bộ phận
-- 5) KH–TT: so kế hoạch chốt với thực tế theo tháng, lệch %, nguyên nhân
create table if not exists plan_capacity(id text primary key, farm_id text not null references farms, kind text not null, name text, capacity numeric not null, unit text, note text, active bool default true, attrs jsonb default '{}'::jsonb);
alter table plan_capacity enable row level security; drop policy if exists p_all on plan_capacity; create policy p_all on plan_capacity for all using (can_see_farm(farm_id)) with check (true); grant select, insert, update on plan_capacity to app_user;
insert into plan_capacity(id, farm_id, kind, name, capacity, unit) select f.id||'-CAP-'||v.k, f.id, v.k, v.n, v.c, v.u from farms f, (values ('CHO_BO','Chỗ bò (nái+tơ+bê)',160,'con'),('CHO_VO_BEO','Chỗ vỗ béo',60,'con'),('CHO_DE','Chỗ dê',250,'con'),('CHO_GA_DE','Chỗ gà đẻ',3200,'con'),('CHO_GA_THIT','Chỗ gà thịt',1600,'con'),('HAO_U','Hào ủ / silo',1500000,'kg'),('D5_TAN_NGAY','Công suất D5',12,'tấn/ngày'),('DAT_SINH_KHOI','Đất sinh khối',15,'ha'),('VON_LUU_DONG','Vốn lưu động',1500000000,'đ')) v(k,n,c,u) where f.status is distinct from 'DONG' and not exists (select 1 from plan_capacity p where p.id=f.id||'-CAP-'||v.k);
-- ---------- 1) giả định ----------
create table if not exists plan_assumptions(farm_id text not null references farms, key text not null, value numeric, unit text, source text default 'AUTO', computed_at timestamptz default now(), note text, primary key(farm_id, key));
alter table plan_assumptions enable row level security; drop policy if exists p_all on plan_assumptions; create policy p_all on plan_assumptions for all using (can_see_farm(farm_id)) with check (true); grant select, insert, update on plan_assumptions to app_user;
create or replace function compute_assumptions(p_farm text) returns int language plpgsql as $$
declare n int := 0; v numeric; r record; begin
  -- chỉ ghi các key nguồn AUTO (không đè key người đã ghi đè source='MANUAL')
  create temp table _a(key text, value numeric, unit text, note text) on commit drop;
  insert into _a select 'lay_pct', round(avg((detail->>'lay_pct')::numeric),1), '%', 'TB 90 ngày SO_LUONG gà đẻ' from animal_events where farm_id=p_farm and event_type='SO_LUONG' and detail ? 'lay_pct' and ts>now()-interval '90 days';
  insert into _a select 'egg_per_hen_day', round(avg(value)/nullif(avg((detail->>'hens')::numeric),0),3), 'quả/mái/ngày', 'TB 90 ngày' from animal_events where farm_id=p_farm and event_type='SO_LUONG' and detail ? 'hens' and ts>now()-interval '90 days';
  insert into _a select 'calving_interval_days', round(avg(gap)), 'ngày', 'khoảng cách 2 lần đẻ (nái có ≥2 lứa)' from (select animal_id, ts::date - lag(ts::date) over (partition by animal_id order by ts) as gap from animal_events where farm_id=p_farm and event_type='DE') x where gap between 300 and 700;
  insert into _a select 'conception_rate_pct', round(100.0*count(*) filter (where coalesce(detail->>'result','+') in ('+','CO','DUONG'))/nullif(count(*),0),0), '%', 'khám thai dương / tổng 12 tháng' from animal_events where farm_id=p_farm and event_type='KHAM_THAI' and ts>now()-interval '12 months';
  insert into _a select 'calf_mortality_pct', round(100.0*count(*) filter (where e.event_type='CHET')/nullif((select count(*) from animals a where a.farm_id=p_farm and a.source='SINH' and a.birth_date>current_date-365),0),1), '%', 'bê chết/bê sinh 12 tháng' from animal_events e join animals a on a.id=e.animal_id where e.farm_id=p_farm and a.source='SINH' and e.ts>now()-interval '12 months';
  insert into _a select 'adg_fattening_kg', round(avg((detail->>'adg')::numeric),2), 'kg/ngày', 'tăng trọng vỗ béo (sự kiện CAN)' from animal_events where farm_id=p_farm and event_type='CAN' and detail ? 'adg' and ts>now()-interval '12 months';
  insert into _a select 'fattening_days', 180, 'ngày', 'chu kỳ vỗ béo chuẩn';
  insert into _a select 'yield_'||c.crop_code||'_kg_ha', round(avg(c.actual_yield_kg/nullif(c.area_ha,0))), 'kg/ha/vụ', 'TB các vụ đã xong' from crop_seasons c where c.farm_id=p_farm and c.status='XONG' and coalesce(c.actual_yield_kg,0)>0 group by c.crop_code;
  insert into _a select 'grass_kg_ha_month', round(sum(qty_kg)/nullif((select sum(area_ha) from plots p where p.farm_id=p_farm and p.crop_code like 'CO-%' and p.active),0)/12), 'kg/ha/tháng', 'cỏ cắt 12 tháng / ha cỏ' from crop_logs where farm_id=p_farm and activity='CAT' and ts>now()-interval '12 months';
  -- mùa vụ cỏ: hệ số tháng = sản lượng tháng / TB
  insert into _a select 'grass_season_m'||m, round(kg/nullif((select sum(qty_kg)/12 from crop_logs where farm_id=p_farm and activity='CAT' and ts>now()-interval '24 months')/2,0),2), 'x', 'hệ số mùa vụ cỏ tháng '||m from (select extract(month from ts)::int m, sum(qty_kg)/2 kg from crop_logs where farm_id=p_farm and activity='CAT' and ts>now()-interval '24 months' group by 1) x;
  insert into _a select 'price_sell_'||sku, round(avg(price)), 'đ', 'giá bán TB 90 ngày' from sales where farm_id=p_farm and ts>now()-interval '90 days' and price>0 group by sku;
  insert into _a select 'price_buy_'||sku, round(avg(unit_cost)), 'đ', 'giá mua TB 6 tháng' from inventory_moves where farm_id=p_farm and reason='NHAP_MUA' and unit_cost>0 and ts>now()-interval '6 months' group by sku;
  insert into _a select 'feed_cost_per_kg_tmr', round(sum(m.qty*coalesce(m.unit_cost, l.avg_cost, 800))/nullif(sum(m.qty),0)), 'đ/kg', 'giá thành TMR (nguyên liệu xuất cho ăn 90 ngày)' from inventory_moves m left join lots l on l.id=m.lot_id where m.farm_id=p_farm and m.reason='XUAT_CHO_AN' and m.ts>now()-interval '90 days';
  insert into _a select 'payroll_month', coalesce(sum(salary_base),0)*1.22, 'đ/tháng', 'lương + BH người SDLĐ' from staff where farm_id=p_farm and active;
  insert into _a select 'opex_other_month', round(avg(amt)), 'đ/tháng', 'chi phí khác TB 6 tháng (expense_requests)' from (select to_char(ts,'YYYY-MM') m, sum(amount) amt from expense_requests where farm_id=p_farm and status='DUYET' and ts>now()-interval '6 months' group by 1) x;
  for r in select * from _a where value is not null loop
    insert into plan_assumptions(farm_id, key, value, unit, source, note) values (p_farm, r.key, r.value, r.unit, 'AUTO', r.note)
    on conflict (farm_id, key) do update set value = case when plan_assumptions.source='MANUAL' then plan_assumptions.value else excluded.value end, unit=excluded.unit, note=excluded.note, computed_at=now();
    n := n+1;
  end loop; return n; end $$;
grant execute on function compute_assumptions(text) to app_user;
create or replace function asm(p_farm text, p_key text, p_default numeric) returns numeric language sql stable as $$ select coalesce((select value from plan_assumptions where farm_id=p_farm and key=p_key), p_default) $$;
grant execute on function asm(text,text,numeric) to app_user;
-- ---------- 3) kế hoạch năm + đàn theo lứa + lịch vụ ----------
create table if not exists plan_years(
  id text primary key, farm_id text not null references farms, year int not null, version int not null default 1, name text, status text default 'NHAP' check (status in ('NHAP','TRINH','DUYET','DANG_CHAY','DONG')),
  targets jsonb default '{}'::jsonb, -- {herd_end, ha_biomass, revenue, profit, capex}
  notes text, approved_by text, approved_at timestamptz, created_at timestamptz default now(), created_by text default app_staff(), unique(farm_id, year, version));
create table if not exists plan_herd_batches(
  id text primary key, farm_id text not null references farms, plan_year_id text references plan_years, kind text not null check (kind in ('VO_BEO','NAI_MOI','GA_DE','GA_THIT','DE_THIT','LUON')), name text,
  start_date date not null, head int not null, days int, in_weight_kg numeric, out_weight_kg numeric, adg numeric, mortality_pct numeric default 2, price_in numeric, price_out numeric, feed_kg_head_day numeric,
  status text default 'KE_HOACH' check (status in ('KE_HOACH','DANG_CHAY','XONG','HUY')), note text, created_at timestamptz default now(), created_by text default app_staff());
create table if not exists plan_crop_calendar(
  id text primary key, farm_id text not null references farms, plan_year_id text references plan_years, plot_id text not null references plots, crop_code text not null references crops, sow_date date not null, cycle_days int, cuts int default 1,
  expected_yield_kg_ha numeric, area_ha numeric, purpose text default 'SINH_KHOI', status text default 'KE_HOACH' check (status in ('KE_HOACH','DANG_TRONG','XONG','HUY')), note text, created_by text default app_staff());
create table if not exists plan_monthly(
  id bigserial primary key, farm_id text not null references farms, plan_year_id text references plan_years, version int default 1, month date not null, line text not null, value numeric, unit text, detail jsonb, created_at timestamptz default now(), unique(farm_id, plan_year_id, version, month, line));
do $$ declare t text; begin
  foreach t in array array['plan_years','plan_herd_batches','plan_crop_calendar','plan_monthly'] loop
    execute format('alter table %I enable row level security', t); execute format('drop policy if exists p_all on %I', t); execute format('create policy p_all on %I for all using (can_see_farm(farm_id)) with check (true)', t); execute format('grant select, insert, update, delete on %I to app_user', t);
  end loop; end $$;
grant usage on sequence plan_monthly_id_seq to app_user;
-- ---------- 4) S&OP tháng: hàm dựng 12 tháng từ đàn thật + lứa kế hoạch + lịch vụ + giả định ----------
create or replace function sop_monthly(p_farm text, p_from date default date_trunc('month', current_date)::date, p_months int default 12) returns table(month date, line text, value numeric, unit text, detail jsonb) language plpgsql stable as $$
declare m date; i int; hb record; d numeric; base_head jsonb; kgday numeric; grass numeric; corn numeric; straw numeric; demand_bap numeric; demand_co numeric; demand_rom numeric; supply_co numeric; supply_bap numeric; supply_rom numeric; eggs numeric; hens numeric; rev numeric; cost numeric; buy numeric; heads jsonb; nfat int; nsow int; nbe int; nto int; nde int; nga int; ngt int; born numeric; exits_fat int; rev_fat numeric; tmr_kg numeric; vien_kg numeric; capfat numeric; capbo numeric; begin
  select capacity into capfat from plan_capacity where farm_id=p_farm and kind='CHO_VO_BEO' and active; select capacity into capbo from plan_capacity where farm_id=p_farm and kind='CHO_BO' and active;
  for i in 0..p_months-1 loop m := (p_from + (i||' months')::interval)::date;
    -- đàn thật tại mốc (dự báo hạng theo tuổi + đẻ dự kiến) — herd_forecast theo số ngày tới mốc
    d := greatest(0, m - current_date);
    select coalesce(sum(head_forecast) filter (where class_code='BO-VO-BEO'),0), coalesce(sum(head_forecast) filter (where class_code in ('BO-CAI-SS','BO-DUC-GIONG')),0), coalesce(sum(head_forecast) filter (where class_code='BO-BE'),0), coalesce(sum(head_forecast) filter (where class_code='BO-TO'),0), coalesce(sum(head_forecast) filter (where class_code like 'DE-%'),0), coalesce(sum(head_forecast) filter (where class_code='GA-DE'),0), coalesce(sum(head_forecast) filter (where class_code='GA-THIT'),0), coalesce(sum(births),0)
      into nfat, nsow, nbe, nto, nde, nga, ngt, born from herd_forecast(p_farm, least(d,365)::int);
    -- lứa kế hoạch chồng lên (nhập trong tháng hoặc đang chạy)
    exits_fat := 0; rev_fat := 0;
    for hb in select * from plan_herd_batches b where b.farm_id=p_farm and b.status in ('KE_HOACH','DANG_CHAY') and b.start_date <= (m + interval '1 month')::date and (b.start_date + coalesce(b.days, 180)) >= m loop
      case hb.kind when 'VO_BEO' then nfat := nfat + hb.head; when 'NAI_MOI' then nsow := nsow + hb.head; when 'GA_DE' then nga := nga + hb.head; when 'GA_THIT' then ngt := ngt + hb.head; when 'DE_THIT' then nde := nde + hb.head; else null; end case;
      if (hb.start_date + coalesce(hb.days,180)) >= m and (hb.start_date + coalesce(hb.days,180)) < (m + interval '1 month')::date then exits_fat := exits_fat + round(hb.head*(1-coalesce(hb.mortality_pct,2)/100)); rev_fat := rev_fat + round(hb.head*(1-coalesce(hb.mortality_pct,2)/100)) * coalesce(hb.out_weight_kg,430) * coalesce(hb.price_out, asm(p_farm,'price_sell_SKU-BO-HOI',82000)); end if;
    end loop;
    -- xuất bán vỗ béo từ đàn thật (đủ ngày trong tháng) — ước: đàn vỗ béo hiện có chia đều theo fattening_days
    heads := jsonb_build_object('vo_beo', nfat, 'nai', nsow, 'be', nbe, 'to', nto, 'de', nde, 'ga_de', nga, 'ga_thit', ngt, 'sinh_du_kien', born, 'xuat_vo_beo_ke_hoach', exits_fat, 'cap_vo_beo', capfat, 'cap_bo', capbo, 'over_cap', (nfat > coalesce(capfat, 1e9) or nsow+nbe+nto > coalesce(capbo,1e9)));
    month := m; line := 'DAN'; value := nfat+nsow+nbe+nto; unit := 'con bò'; detail := heads; return next;
    -- thức ăn cần (kg/ngày × ngày trong tháng)
    kgday := nfat*asm(p_farm,'norm_TA_KG_VB',35) + nsow*32 + nbe*8 + nto*20; tmr_kg := kgday * extract(day from (m + interval '1 month - 1 day'));
    vien_kg := (nga*0.115 + ngt*0.09) * extract(day from (m + interval '1 month - 1 day'));
    month := m; line := 'TMR_KG'; value := round(tmr_kg); unit := 'kg'; detail := jsonb_build_object('kg_day', round(kgday), 'vien_kg', round(vien_kg), 'de_kg', round(nde*3.5*30)); return next;
    demand_bap := tmr_kg*0.45 + vien_kg*0.55; demand_co := tmr_kg*0.08 + nde*3.5*30*0.7; demand_rom := tmr_kg*0.15 + vien_kg*0.10;
    -- cung sinh khối: cỏ = ha cỏ × kg/ha/tháng × hệ số mùa; bắp = thu hoạch dự kiến (mùa vụ mở + lịch vụ kế hoạch) rơi trong tháng
    grass := coalesce((select sum(area_ha) from plots p where p.farm_id=p_farm and p.crop_code like 'CO-%' and p.active),0) * asm(p_farm,'grass_kg_ha_month',15000) * asm(p_farm,'grass_season_m'||extract(month from m)::int, 1);
    corn := coalesce((select sum(greatest(coalesce(target_yield_kg,0)-coalesce(actual_yield_kg,0),0)) from crop_seasons cs where cs.farm_id=p_farm and cs.status in ('DANG_TRONG','THU_HOACH') and cs.crop_code='BAP-SK' and coalesce(cs.expected_harvest, cs.sow_date+85) >= m and coalesce(cs.expected_harvest, cs.sow_date+85) < (m + interval '1 month')::date),0)
          + coalesce((select sum(coalesce(c.area_ha,(select area_ha from plots where id=c.plot_id)) * coalesce(c.expected_yield_kg_ha, asm(p_farm,'yield_BAP-SK_kg_ha',45000))) from plan_crop_calendar c where c.farm_id=p_farm and c.status in ('KE_HOACH','DANG_TRONG') and c.crop_code in ('BAP-SK','CAO-LUONG') and (c.sow_date + coalesce(c.cycle_days,85)) >= m and (c.sow_date + coalesce(c.cycle_days,85)) < (m + interval '1 month')::date),0);
    straw := coalesce((select sum(coalesce(area_ha,2.5) * coalesce(actual_yield_kg, target_yield_kg, 15000)/2.5*1.0) from crop_seasons cs where cs.farm_id=p_farm and cs.crop_code='LUA' and cs.status in ('DANG_TRONG','THU_HOACH') and coalesce(cs.expected_harvest, cs.sow_date+105) >= m and coalesce(cs.expected_harvest, cs.sow_date+105) < (m + interval '1 month')::date),0);
    month := m; line := 'CUNG_CO'; value := round(grass); unit := 'kg'; detail := jsonb_build_object('demand', round(demand_co), 'gap', round(grass-demand_co)); return next;
    month := m; line := 'CUNG_BAP'; value := round(corn/1.18); unit := 'kg ủ'; detail := jsonb_build_object('demand', round(demand_bap), 'gap', round(corn/1.18-demand_bap), 'fresh', round(corn)); return next;
    month := m; line := 'CUNG_ROM'; value := round(straw); unit := 'kg'; detail := jsonb_build_object('demand', round(demand_rom), 'gap', round(straw-demand_rom)); return next;
    -- mua bù (bã bia, rỉ mật, khoáng luôn mua + thiếu bắp/rơm/cỏ)
    buy := (tmr_kg*0.25 + vien_kg*0.25) * asm(p_farm,'price_buy_NL-BA-BIA',1200) + (tmr_kg*0.04+vien_kg*0.05)*asm(p_farm,'price_buy_NL-RI-MAT',6500) + (tmr_kg*0.03+vien_kg*0.05)*asm(p_farm,'price_buy_NL-KHOANG',18000)
         + greatest(demand_rom-straw,0)*asm(p_farm,'price_buy_NL-ROM',1500) + greatest(demand_bap-corn/1.18,0)*900 + greatest(demand_co-grass,0)*600;
    month := m; line := 'MUA_DONG'; value := round(buy); unit := 'đ'; detail := jsonb_build_object('ba_bia_kg', round(tmr_kg*0.25+vien_kg*0.25), 'rom_bu_kg', round(greatest(demand_rom-straw,0)), 'bap_bu_kg', round(greatest(demand_bap-corn/1.18,0)), 'co_bu_kg', round(greatest(demand_co-grass,0))); return next;
    -- SX D5
    month := m; line := 'SX_D5_KG'; value := round(tmr_kg + vien_kg); unit := 'kg'; detail := jsonb_build_object('tan_ngay', round((tmr_kg+vien_kg)/30/1000,1), 'cap_tan_ngay', (select capacity from plan_capacity where farm_id=p_farm and kind='D5_TAN_NGAY')); return next;
    -- bán: trứng, bò hơi, phân trùn, TMR bao (hợp đồng), dê, gà thịt
    eggs := nga * asm(p_farm,'egg_per_hen_day',0.8) * 30 / 10; rev := eggs * asm(p_farm,'price_sell_SKU-TRUNG-10',42000) + rev_fat + 170*asm(p_farm,'price_sell_SKU-PTR-25',78000) + 430*asm(p_farm,'price_sell_SKU-TMR-25',101200)
         + coalesce((select sum(planned_qty*coalesce(price,0)) from v_contract_schedule cs where cs.farm_id=p_farm and cs.planned_date>=m and cs.planned_date<(m+interval '1 month')::date and cs.status<>'DA_GIAO'),0)*0
         + case when extract(month from m)::int % 3 = 0 then 8*32*asm(p_farm,'price_sell_SKU-DE-HOI',145000) + 1400*2.1*asm(p_farm,'price_sell_SKU-GA-THIT',68000) else 0 end;
    month := m; line := 'DOANH_THU'; value := round(rev); unit := 'đ'; detail := jsonb_build_object('trung_vi', round(eggs), 'bo_hoi', rev_fat, 'xuat_vo_beo', exits_fat); return next;
    cost := buy + asm(p_farm,'payroll_month',350000000) + asm(p_farm,'opex_other_month',60000000) + tmr_kg*0 ;
    month := m; line := 'CHI_PHI'; value := round(cost); unit := 'đ'; detail := jsonb_build_object('mua', round(buy), 'luong', asm(p_farm,'payroll_month',0), 'khac', asm(p_farm,'opex_other_month',0)); return next;
    month := m; line := 'LAI_GOP'; value := round(rev-cost); unit := 'đ'; detail := '{}'::jsonb; return next;
    month := m; line := 'DONG_TIEN'; value := round(rev-cost - coalesce((select sum(s.principal+s.interest) from loan_schedule s join loans l on l.id=s.loan_id where l.farm_id=p_farm and s.status<>'DA_TRA' and s.due_date>=m and s.due_date<(m+interval '1 month')::date),0)); unit := 'đ'; detail := jsonb_build_object('tra_no', coalesce((select sum(s.principal+s.interest) from loan_schedule s join loans l on l.id=s.loan_id where l.farm_id=p_farm and s.status<>'DA_TRA' and s.due_date>=m and s.due_date<(m+interval '1 month')::date),0)); return next;
  end loop; end $$;
grant execute on function sop_monthly(text,date,int) to app_user;
-- chốt phiên bản kế hoạch → plan_monthly; ban hành → việc theo tháng cho bộ phận
create or replace function close_plan(p_year_id text) returns int language plpgsql as $$
declare y record; n int := 0; r record; ver int; begin
  select * into y from plan_years where id=p_year_id; if not found then raise exception 'ERR_NOT_FOUND'; end if;
  ver := coalesce((select max(version) from plan_monthly where plan_year_id=p_year_id),0)+1;
  for r in select * from sop_monthly(y.farm_id, make_date(y.year,1,1), 12) loop
    insert into plan_monthly(farm_id, plan_year_id, version, month, line, value, unit, detail) values (y.farm_id, p_year_id, ver, r.month, r.line, r.value, r.unit, r.detail); n := n+1;
  end loop;
  update plan_years set version=ver, status=case when status='NHAP' then 'TRINH' else status end where id=p_year_id;
  return n; end $$;
grant execute on function close_plan(text) to app_user;
create or replace function publish_year_plan(p_year_id text) returns int language plpgsql as $$
declare y record; r record; n int := 0; m date; begin
  select * into y from plan_years where id=p_year_id; if not found then raise exception 'ERR_NOT_FOUND'; end if;
  update plan_years set status='DANG_CHAY', approved_by=coalesce(approved_by, app_staff()), approved_at=coalesce(approved_at, now()) where id=p_year_id;
  -- việc: lứa đàn (nhập/xuất), gieo theo lịch vụ, mua theo tháng thiếu, D5 công suất, tháng cung âm
  for r in select * from plan_herd_batches where farm_id=y.farm_id and plan_year_id=p_year_id and status='KE_HOACH' and start_date >= current_date - 7 loop
    insert into tasks(id, farm_id, kind, title, detail, due_at, role_hint, target_type, target_id, status, source, priority) values (gen_random_uuid(), y.farm_id, 'KE_HOACH_DAN', 'Nhập lứa '||coalesce(r.name, r.kind)||' '||r.head||' con ('||r.start_date||')', jsonb_build_object('batch_id', r.id, 'kind', r.kind, 'head', r.head, 'text', 'Chuẩn bị chuồng cách ly 21 ngày, PO giống, vaccine, thức ăn'), (r.start_date - 14)::timestamptz + interval '8 hours', 'tech_head', 'plan_herd_batch', r.id, 'MO', 'PLAN', 'CAO') on conflict do nothing; n := n+1;
    insert into tasks(id, farm_id, kind, title, detail, due_at, role_hint, target_type, target_id, status, source, priority) values (gen_random_uuid(), y.farm_id, 'KE_HOACH_XUAT', 'Cửa xuất '||coalesce(r.name, r.kind)||' '||r.head||' con ('||(r.start_date + coalesce(r.days,180))||') — chốt khách/giá', jsonb_build_object('batch_id', r.id, 'text', 'Kinh doanh chốt hợp đồng trước 30 ngày; thú y hồ sơ ngưng thuốc'), (r.start_date + coalesce(r.days,180) - 30)::timestamptz + interval '8 hours', 'director', 'plan_herd_batch', r.id, 'MO', 'PLAN', 'CAO') on conflict do nothing; n := n+1;
  end loop;
  for r in select c.*, p.name as plot_name from plan_crop_calendar c join plots p on p.id=c.plot_id where c.farm_id=y.farm_id and c.plan_year_id=p_year_id and c.status='KE_HOACH' and c.sow_date >= current_date - 7 loop
    insert into tasks(id, farm_id, kind, title, detail, due_at, role_hint, target_type, target_id, status, source, priority) values (gen_random_uuid(), y.farm_id, 'KE_HOACH_GIEO', 'Gieo '||r.crop_code||' ô '||r.plot_name||' ('||r.sow_date||') — làm đất, giống, phân', jsonb_build_object('calendar_id', r.id, 'plot_id', r.plot_id, 'crop_code', r.crop_code, 'text', 'Mở mùa vụ trên app; giống/phân đặt trước 10 ngày'), (r.sow_date - 10)::timestamptz + interval '8 hours', 'tech_head', 'plan_crop_calendar', r.id, 'MO', 'PLAN', 'CAO') on conflict do nothing; n := n+1;
  end loop;
  for r in select month, line, value, detail from plan_monthly where plan_year_id=p_year_id and version=y.version and line in ('CUNG_BAP','CUNG_CO','CUNG_ROM','SX_D5_KG') and month >= date_trunc('month', current_date) loop
    if r.line like 'CUNG_%' and (r.detail->>'gap')::numeric < 0 then
      insert into tasks(id, farm_id, kind, title, detail, due_at, role_hint, target_type, target_id, status, source, priority) values (gen_random_uuid(), y.farm_id, 'KE_HOACH_MUA', 'Tháng '||to_char(r.month,'MM/YYYY')||': thiếu '||replace(r.line,'CUNG_','')||' '||abs((r.detail->>'gap')::numeric)||' kg — lên PO/hợp đồng mua trước 30 ngày', r.detail || jsonb_build_object('month', r.month, 'line', r.line), (r.month - 30)::timestamptz + interval '8 hours', 'accountant', 'plan_month', p_year_id||'/'||r.month, 'MO', 'PLAN', 'CAO') on conflict do nothing; n := n+1;
    end if;
    if r.line='SX_D5_KG' and (r.detail->>'cap_tan_ngay') is not null and (r.detail->>'tan_ngay')::numeric > (r.detail->>'cap_tan_ngay')::numeric then
      insert into tasks(id, farm_id, kind, title, detail, due_at, role_hint, target_type, target_id, status, source, priority) values (gen_random_uuid(), y.farm_id, 'KE_HOACH_SX', 'Tháng '||to_char(r.month,'MM/YYYY')||': D5 cần '||(r.detail->>'tan_ngay')||' t/ngày > công suất '||(r.detail->>'cap_tan_ngay')||' — thêm ca/mua TMR', r.detail, (r.month - 45)::timestamptz + interval '8 hours', 'tech_head', 'plan_month', p_year_id||'/'||r.month||'/D5', 'MO', 'PLAN', 'CAO') on conflict do nothing; n := n+1;
    end if;
  end loop;
  perform publish_event(y.farm_id, 'plan.published', jsonb_build_object('plan_year_id', p_year_id, 'year', y.year, 'version', y.version, 'tasks', n));
  return n; end $$;
grant execute on function publish_year_plan(text) to app_user;
-- ---------- 5) KH–TT theo tháng ----------
create or replace view v_plan_vs_actual as
with pm as (select p.farm_id, p.plan_year_id, p.month, p.line, p.value as plan from plan_monthly p join plan_years y on y.id=p.plan_year_id and y.version=p.version),
act as (
  select farm_id, date_trunc('month', ts)::date as month, 'DOANH_THU' as line, sum(amount) as actual from sales where status='ACTIVE' group by 1,2
  union all select farm_id, date_trunc('month', ts)::date, 'CHI_PHI', sum(amount) from expense_requests where status='DUYET' group by 1,2
  union all select farm_id, date_trunc('month', ts)::date, 'TMR_KG', sum(qty_kg) from feed_logs where status='ACTIVE' and recipe_id like 'RC-TMR%' group by 1,2
  union all select farm_id, date_trunc('month', ts)::date, 'CUNG_CO', sum(qty_kg) from crop_logs where status='ACTIVE' and activity='CAT' group by 1,2
  union all select farm_id, date_trunc('month', ts)::date, 'CUNG_BAP', sum(qty_kg)/1.18 from harvests where status='ACTIVE' and crop='BAP' group by 1,2
  union all select farm_id, date_trunc('month', ts)::date, 'MUA_DONG', sum(qty*coalesce(unit_cost,0)) from inventory_moves where status='ACTIVE' and reason='NHAP_MUA' group by 1,2
  union all select farm_id, date_trunc('month', ts)::date, 'SX_D5_KG', sum((o->>'kg')::numeric) from batch_logs b, jsonb_array_elements(b.outputs) o where b.status='ACTIVE' and b.line in ('D5_VIEN','D5_TMR') group by 1,2
  union all select farm_id, day, 'DAN', sum(head) from herd_daily where species='BO' and day = (date_trunc('month', day) + interval '1 month - 1 day')::date group by 1,2)
select pm.farm_id, pm.plan_year_id, pm.month, pm.line, pm.plan, a.actual, case when pm.plan<>0 then round(100.0*(coalesce(a.actual,0)-pm.plan)/pm.plan,1) end as diff_pct
from pm left join act a on a.farm_id=pm.farm_id and a.line=pm.line and date_trunc('month', a.month)=pm.month where pm.month <= date_trunc('month', current_date);
grant select on v_plan_vs_actual to app_user;
insert into event_topics(topic, description, producer_dept, consumer_depts, source_table, wired) values ('plan.year','Kế hoạch năm ban hành','BGD','{*}','plan_years',true) on conflict (topic) do nothing;
