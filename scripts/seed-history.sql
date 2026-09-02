-- ================================================================================================
-- SEED "TRẠI ĐÃ VẬN HÀNH 30 THÁNG" — F01 (dữ liệu ảo nhưng nhất quán: đàn ↔ khẩu phần ↔ kho ↔ ruộng ↔ bán hàng ↔ GL)
-- Chạy: pnpm db:seed:history  (idempotent theo client_ref/id; có thể chạy lại)
-- ================================================================================================
set client_min_messages = warning;
select set_config('app.org_id','ITRAN',false), set_config('app.farm_id',:'farm',false), set_config('app.role','it_engineer',false), set_config('app.staff_id','NS-001',false);
-- ---------- RESET dữ liệu seed cũ (client_ref 'h-%', id '%-H%'/'-V%'/'-BE-H%'/'-DE-%') để chạy lại sạch (bỏ qua trigger append-only bằng replica role — chỉ superuser) ----------
set session_replication_role = replica;
delete from journal_entries where farm_id=:'farm' and ref_table='sales' and ref_id in (select id::text from sales where farm_id=:'farm' and client_ref like 'h-%');
delete from loyalty_ledger where farm_id=:'farm' and ref_type='sales' and ref_id in (select id::text from sales where farm_id=:'farm' and client_ref like 'h-%');
delete from sales where farm_id=:'farm' and client_ref like 'h-%';
delete from inventory_moves where farm_id=:'farm' and (client_ref like 'h-%' or client_ref like 'croplog-%' or client_ref like 'harvest-%');
delete from harvests where farm_id=:'farm' and client_ref like 'h-%'; delete from crop_logs where farm_id=:'farm' and client_ref like 'h-%'; delete from crop_inputs where farm_id=:'farm' and client_ref like 'h-%'; delete from irrigation_logs where farm_id=:'farm' and client_ref like 'h-%'; delete from pest_scouting where farm_id=:'farm' and client_ref like 'h-%';
delete from animal_events where farm_id=:'farm' and (client_ref like 'h-%' or animal_id like (:'farm'||'-BE-H%') or animal_id like (:'farm'||'-BO-H%') or animal_id like (:'farm'||'-BO-V%') or animal_id like (:'farm'||'-BO-D%') or animal_id like (:'farm'||'-DE-%'));
delete from animals where farm_id=:'farm' and (id like (:'farm'||'-BE-H%') or id like (:'farm'||'-BO-H%') or id like (:'farm'||'-BO-V%') or id like (:'farm'||'-BO-D%') or id like (:'farm'||'-DE-%'));
delete from crop_seasons where farm_id=:'farm' and id like (:'farm'||'-LO-%-CS-%');
delete from purchase_orders where farm_id=:'farm' and id like (:'farm'||'-PO-H%'); delete from weather_daily where farm_id=:'farm' and source='IMPORT';
delete from lots where farm_id=:'farm' and (lot_no like 'H2%' or lot_no like 'V2%' or lot_no like 'PT2%' or lot_no like 'TMR2%' or lot_no like 'RAU2%' or lot_no like 'LUA2%' or lot_no like 'BAP-2%' or lot_no ~ '^2[0-9]{5}-TRA$' or lot_no ~ '^2[0-9]{3}-F01-LO-') and not exists (select 1 from inventory_moves m where m.lot_id=lots.id);
set session_replication_role = origin;
update warehouses set capacity = case code when 'K1' then 4000 when 'K2' then 300000 when 'K3' then 1500000 when 'K4' then 50000 when 'K5' then 30000 when 'K6' then 5000 when 'K7' then 20000 when 'K9' then 40000 else capacity end where farm_id=:'farm';
do $$
declare F text := :'farm'; U text := coalesce((select id from staff where farm_id=:'farm' and role in ('team_lead','tech_head') and active order by id limit 1),'NS-001'); M int := 30; d0 date := (date_trunc('month', current_date) - interval '30 months')::date; d date; i int; k int; n int; r record; v_id text; v_lot text; wh record;
  cows int; base numeric; qty numeric; hens int := 3000; lay numeric; egg int; trays int; eggLot text; ptLot text; tmrLot text; s numeric; y numeric; season_id text; sow date; hv date;
  dam text; dams text[]; goats text[]; sires text[]; ids text[]; plotc text[] := array[(F||'-LO-K01'),(F||'-LO-K02'),(F||'-LO-K03'),(F||'-LO-K04'),(F||'-LO-K05'),(F||'-LO-K06')];
  KC record;
begin
  insert into locations(id, farm_id, code, name, kind, active) values (F||'-CH-NAI-1',F,'CH-NAI-1','Dãy nái 1','CHUONG',true),(F||'-CH-VO-1',F,'CH-VO-1','Chuồng vỗ béo 1','CHUONG',true),(F||'-CH-CL',F,'CH-CL','Chuồng cách ly','CHUONG',true),(F||'-KHU-C',F,'KHU-C','Khu chuồng bò/dê','KHU',true),(F||'-KHU-D',F,'KHU-D','Khu D sinh học','KHU',true),(F||'-GA-DE',F,'GA-DE','Khối gà đẻ','CHUONG',true),(F||'-GA-THIT',F,'GA-THIT','Khối gà thịt','CHUONG',true),(F||'-D5',F,'D5','Xưởng D5','NHA',true),(F||'-RAS',F,'RAS','Nhà RAS','KHU',true) on conflict (id) do nothing;
  insert into animal_groups(id, farm_id, species, kind, name, location_id, head_count, status, class_code) values (F||'-DAN-NAI-01',F,'BO','BO_NHOM','Đàn nái dãy 1',F||'-CH-NAI-1',0,'ACTIVE','BO-CAI-SS'),(F||'-DAN-VO-01',F,'BO','BO_NHOM','Đàn vỗ béo 1',F||'-CH-VO-1',0,'ACTIVE','BO-VO-BEO'),(F||'-GA-L01',F,'GA','GA_DE','Gà đẻ lứa 01 (3.000 mái)',F||'-GA-DE',2917,'ACTIVE','GA-DE'),(F||'-GT-L01',F,'GA','GA_THIT','Gà thịt lứa 01',F||'-GA-THIT',1500,'ACTIVE','GA-THIT') on conflict (id) do nothing;
  insert into plots(id, farm_id, name, area_ha, kind, current_crop, crop_code, status, active) values (F||'-LO-G1A',F,'Lô G1A bắp sinh khối',2.0,'RUONG','BAP','BAP-SK','DANG_TRONG',true),(F||'-LO-G2A',F,'Lô G2A bắp/mì',2.0,'RUONG','SAN','KHOAI-MI','DANG_TRONG',true),(F||'-LO-K01',F,'Ô cỏ K01 Mombasa',0.5,'DONG_CO','CO','CO-MOMBASA','DANG_TRONG',true),(F||'-LO-K02',F,'Ô cỏ K02 Mulato',0.5,'DONG_CO','CO','CO-RUZI','DANG_TRONG',true) on conflict (id) do nothing;
  insert into devices(id, farm_id, kind, name, active) values (F||'-TB-002',F,'MAY_THU','Máy thu sinh khối tự nạp',true) on conflict (id) do nothing;
  insert into warehouses(id, farm_id, code, name, unit_kind, count_cycle, block, area, active) select F||'-KCC-'||v.k, F, 'KCC-'||v.k, v.n, 'CAI','THANG','CONG_CU', v.a, true from (values ('A','Kho công cụ khu A','Khu A'),('D','Kho công cụ khu D','Khu D'),('R','Kho công cụ ruộng','Nhà máy'),('CB','Kho công cụ chế biến','Nhà chế biến')) v(k,n,a) where not exists (select 1 from warehouses w where w.farm_id=F and w.code='KCC-'||v.k);
  update warehouses set block = case code when 'K5' then 'DAU_RA' when 'K6' then 'DAU_RA' when 'K8' then 'KHAC' else coalesce(block,'DAU_VAO') end where farm_id=F and block is null;
  update warehouses set capacity = case code when 'K1' then 4000 when 'K2' then 300000 when 'K3' then 1500000 when 'K4' then 50000 when 'K5' then 30000 when 'K6' then 5000 when 'K7' then 20000 when 'K9' then 40000 else capacity end where farm_id=F and capacity is null;
  select id as k1 into wh from warehouses where farm_id=F and code='K1';
  -- ---------- 0. ô ruộng: cỏ 6 ô × 0.5 ha = 3 ha, bắp 4 ô × 2 ha = 8 ha, lúa 2 × 2.5 = 5 ha, mì 2.5 ha, rau 0.5, chuối viền 0.4 ----------
  insert into plots(id, farm_id, name, area_ha, kind, current_crop, crop_code, status, active) values
   ((F||'-LO-K03'),F,'Ô cỏ K03 Mombasa',0.5,'DONG_CO','CO','CO-MOMBASA','DANG_TRONG',true),((F||'-LO-K04'),F,'Ô cỏ K04 VA06',0.5,'DONG_CO','CO','CO-VA06','DANG_TRONG',true),((F||'-LO-K05'),F,'Ô cỏ K05 Ruzi',0.5,'DONG_CO','CO','CO-RUZI','DANG_TRONG',true),((F||'-LO-K06'),F,'Ô cỏ K06 Mombasa',0.5,'DONG_CO','CO','CO-MOMBASA','DANG_TRONG',true),
   ((F||'-LO-G1B'),F,'Lô G1B bắp sinh khối',2.0,'RUONG','BAP','BAP-SK','DANG_TRONG',true),((F||'-LO-G2B'),F,'Lô G2B bắp sinh khối',2.0,'RUONG','BAP','BAP-SK','DANG_TRONG',true),
   ((F||'-LO-L01'),F,'Ruộng lúa L01',2.5,'RUONG','LUA','LUA','DANG_TRONG',true),((F||'-LO-L02'),F,'Ruộng lúa L02',2.5,'RUONG','LUA','LUA','DANG_TRONG',true),
   ((F||'-LO-R01'),F,'Nhà lưới rau R01',0.5,'NHA_LUOI','RAU','RAU-AN-LA','DANG_TRONG',true)
  on conflict (id) do nothing;
  update plots set area_ha=2.0, crop_code='BAP-SK' where id=(F||'-LO-G1A'); update plots set area_ha=2.0 where id=(F||'-LO-G2A'); update plots set area_ha=0.5 where id in ((F||'-LO-K01'),(F||'-LO-K02'));
  -- ---------- 1. ĐÀN BÒ: 45 nái (mua từ 30 tháng trước theo 3 đợt), 3 đực giống, vỗ béo 30 con/lứa 6 tháng (mua tơ 200 kg → bán 420 kg), bê sinh từ nái ----------
  for i in 1..45 loop
    v_id := F||'-BO-H'||lpad(i::text,3,'0');
    insert into animals(id, farm_id, species, breed, sex, birth_date, source, status, location_id, class_code, visual_tag, group_id, created_at, unit_value)
    values (v_id, F, 'BO', case when i%3=0 then 'Brahman lai' when i%3=1 then 'Lai Sind' else 'BBB lai' end, 'F', (d0 - ((900 + i*7)||' days')::interval)::date, 'MUA', 'CHO_PHOI', (F||'-CH-NAI-1'), 'BO-CAI-SS', 'N'||lpad(i::text,3,'0'), (F||'-DAN-NAI-01'), d0 + ((i/16)*90 || ' days')::interval, 28000000)
    on conflict (id) do nothing;
  end loop;
  for i in 1..3 loop v_id := F||'-BO-D'||i; insert into animals(id, farm_id, species, breed, sex, birth_date, source, status, location_id, class_code, visual_tag, group_id, created_at, unit_value) values (v_id, F, 'BO', 'Brahman', 'M', (d0 - interval '1200 days')::date, 'MUA', 'CHO_PHOI', (F||'-CH-NAI-1'), 'BO-DUC-GIONG', 'D'||i, (F||'-DAN-NAI-01'), d0, 60000000) on conflict (id) do nothing; end loop;
  select array_agg(id order by id) into dams from animals where farm_id=F and id like F||'-BO-H%';
  -- sự kiện nhập + cách ly 21 ngày cho nái
  insert into animal_events(farm_id, ts, created_by, source, client_ref, animal_id, event_type, detail)
  select F, a.created_at, U, 'IMPORT', 'h-nhap-'||a.id, a.id, 'NHAP', '{"note":"nhập đàn nái"}' from animals a where a.farm_id=F and a.id like F||'-BO-%' and a.status<>'XUAT' and not exists (select 1 from animal_events e where e.client_ref='h-nhap-'||a.id);
  insert into animal_events(farm_id, ts, created_by, source, client_ref, animal_id, event_type, detail)
  select F, a.created_at + interval '21 days', U, 'IMPORT', 'h-clra-'||a.id, a.id, 'CACH_LY_RA', '{}' from animals a where a.farm_id=F and a.id like F||'-BO-%' and a.status<>'XUAT' and not exists (select 1 from animal_events e where e.client_ref='h-clra-'||a.id);
  -- chu kỳ sinh sản: mỗi nái phối lần 1 sau 60–120 ngày về; đẻ sau 283 ngày (85% đậu); tái phối 90 ngày sau đẻ → ~2 lứa/30 tháng
  for i in 1..45 loop
    dam := dams[i]; d := (select created_at::date from animals where id=dam) + (60 + (i*13)%60);
    for k in 1..3 loop
      exit when d + 283 > current_date + 200;
      insert into animal_events(farm_id, ts, created_by, source, client_ref, animal_id, event_type, detail) values (F, d + time '08:30', U, 'IMPORT', 'h-phoi-'||dam||'-'||k, dam, 'PHOI', jsonb_build_object('semen_lot','TINH-BRAHMAN/LOT-'||(20+k),'sire_id',sires[1])) on conflict do nothing;
      insert into animal_events(farm_id, ts, created_by, source, client_ref, animal_id, event_type, detail) values (F, d + 60 + time '09:00', U, 'IMPORT', 'h-kt-'||dam||'-'||k, dam, 'KHAM_THAI', case when (i*7+k)%7=0 then '{"result":"-"}'::jsonb else '{"result":"+","new_status":"MANG_THAI"}'::jsonb end) on conflict do nothing;
      if (i*7+k)%7=0 then d := d + 80; continue; end if; -- không đậu → phối lại
      if d + 283 <= current_date then
        insert into animal_events(farm_id, ts, created_by, source, client_ref, animal_id, event_type, detail) values (F, d + 283 + time '05:30', U, 'IMPORT', 'h-de-'||dam||'-'||k, dam, 'DE', jsonb_build_object('calf_sex', case when (i+k)%2=0 then 'F' else 'M' end, 'calf_id', F||'-BE-H'||lpad(i::text,3,'0')||k, 'calf_tag', 'B'||lpad(i::text,3,'0')||k, 'birth_weight_kg', 26+(i%9))) on conflict do nothing;
      end if;
      d := d + 283 + 90;
    end loop;
  end loop;
  -- bê: sau 180 ngày cai sữa; bê đực >540 ngày → vỗ béo → bán; ghi trạng thái theo tuổi (class suy từ tuổi trong app)
  update animals set status='CHO_PHOI' where farm_id=F and id like F||'-BE-H%' and birth_date <= current_date-180 and status='THEO_ME';
  -- vỗ béo: 4 lứa × 30 con, mỗi lứa 180 ngày, mua tơ đực 18 tháng 220 kg, bán 430 kg (lứa 1–3 đã bán, lứa 4 đang nuôi)
  for k in 1..4 loop
    d := d0 + ((k-1)*180 || ' days')::interval;
    ids := '{}'::text[]; -- gom cá thể lứa này để bán qua sell_livestock() thay vì insert sales rời (0200: sale_animals trống lịch sử vì seed cũ không nối)
    for i in 1..30 loop
      v_id := F||'-BO-V'||k||lpad(i::text,2,'0');
      insert into animals(id, farm_id, species, breed, sex, birth_date, source, status, location_id, class_code, visual_tag, group_id, created_at, unit_value, last_weight_kg, last_weight_at)
      values (v_id, F, 'BO', 'Lai Sind/Brahman', 'M', (d - interval '540 days')::date, 'MUA', 'CHO_PHOI', (F||'-CH-VO-1'), 'BO-VO-BEO', 'V'||k||lpad(i::text,2,'0'), (F||'-DAN-VO-01'), d, 22000000, case when k<4 then 430 else 220 + (current_date - d)*0.9 end, case when k<4 then d + 180 else current_date end)
      on conflict (id) do nothing;
      continue when (select status from animals where id=v_id) = 'XUAT'; -- chạy lại (idempotent): lứa này đã bán ở lần trước, ids rỗng → không gọi sell_livestock lần nữa
      insert into animal_events(farm_id, ts, created_by, source, client_ref, animal_id, event_type, value, unit, detail) values (F, d + time '08:00', U, 'IMPORT', 'h-vnhap-'||v_id, v_id, 'NHAP', 220+(i%15), 'kg', '{"note":"nhập vỗ béo"}') on conflict do nothing;
      -- cân mỗi 30 ngày
      n := 0; while d + n*30 <= least(current_date, d + 180) loop
        insert into animal_events(farm_id, ts, created_by, source, client_ref, animal_id, event_type, value, unit, detail) values (F, d + n*30 + time '07:30', U, 'IMPORT', 'h-vcan-'||v_id||'-'||n, v_id, 'CAN', 220 + (i%15) + n*35 + (i%5), 'kg', jsonb_build_object('adg', 1.05+(i%5)*0.03)) on conflict do nothing; n := n+1; end loop;
      if k<4 then ids := ids || v_id; end if; -- XUAT + sales + sale_animals đều do sell_livestock() sinh (dùng animals.last_weight_kg thật từ vòng cân trên, cập nhật qua trigger animal_events)
    end loop;
    -- bán bò hơi lứa k: sell_livestock() tự sinh 1 đơn sales cho cả lô + sự kiện XUAT từng con + nối sale_animals
    -- p_ts = ngày thật cuối chu kỳ vỗ béo (0205) — trước đây hard-code now(), làm ngày bán luôn là "hôm nay" seed chạy
    if k<4 and array_length(ids,1) > 0 then perform sell_livestock(F, U, ids, 'KH-0002', 82000, 'SKU-BO-HOI', d + interval '180 days'); end if;
  end loop;
  -- ---------- 2. DÊ: 40 cái SS + 4 đực + con ----------
  for i in 1..40 loop v_id := F||'-DE-C'||lpad(i::text,3,'0'); insert into animals(id, farm_id, species, breed, sex, birth_date, source, status, location_id, class_code, visual_tag, created_at, unit_value) values (v_id, F, 'DE', case when i%2=0 then 'Boer lai' else 'Bách Thảo' end, 'F', (d0 - ((400 + i*5)||' days')::interval)::date, 'MUA', 'CHO_PHOI', (F||'-KHU-C'), 'DE-CAI-SS', 'DC'||i, d0 + interval '90 days', 6500000) on conflict do nothing; end loop;
  for i in 1..4 loop v_id := F||'-DE-D'||i; insert into animals(id, farm_id, species, breed, sex, birth_date, source, status, location_id, class_code, visual_tag, created_at, unit_value) values (v_id, F, 'DE', 'Boer', 'M', (d0 - interval '700 days')::date, 'MUA', 'CHO_PHOI', (F||'-KHU-C'), 'DE-THIT', 'DD'||i, d0 + interval '90 days', 12000000) on conflict do nothing; end loop;
  -- dê đẻ: chu kỳ 8 tháng, 1.6 con/lứa → 2–3 lứa; con đực bán thịt 8 tháng qua sell_livestock() (0205)
  -- — trước đây gán status='XUAT' thẳng lúc INSERT + 1 dòng sales rời KHÔNG nối cá thể nào (không
  -- sale_animals, không animal_events XUAT), cùng lỗ hổng "sale_animals trống lịch sử" đã vá cho bò
  -- (dòng ~76 trên) nhưng bỏ sót ở dê. Nay đực tới 240 ngày được CÂN thật (animal_events CAN, cập nhật
  -- last_weight_kg qua trigger sẵn có) rồi bán qua sell_livestock() — sinh đủ sales+sale_animals+XUAT
  -- thật, p_ts đúng ngày lịch sử tới tuổi (không phải "hôm nay" seed chạy).
  for i in 1..40 loop
    d := d0 + 90 + 150 + (i*3);
    for k in 1..3 loop
      exit when d > current_date;
      for n in 1..(case when (i+k)%5=0 then 1 else 2 end) loop
        v_id := F||'-DE-K'||lpad(i::text,3,'0')||k||n;
        insert into animals(id, farm_id, species, breed, sex, birth_date, dam_id, source, status, location_id, class_code, visual_tag, created_at, unit_value)
        values (v_id, F, 'DE', 'Boer lai', case when n=1 then 'M' else 'F' end, d, F||'-DE-C'||lpad(i::text,3,'0'), 'SINH', case when d <= current_date-120 then 'CHO_PHOI' else 'THEO_ME' end, (F||'-KHU-C'), case when d <= current_date-120 then (case when n=1 then 'DE-THIT' else 'DE-CAI-SS' end) else 'DE-CON' end, 'DK'||i||k||n, d, 1500000) on conflict do nothing;
        if n=1 and d <= current_date-240 and (select status from animals where id=v_id) <> 'XUAT' then
          insert into animal_events(farm_id, ts, created_by, source, client_ref, animal_id, event_type, value, unit, detail) values (F, d + interval '240 days' + time '07:00', U, 'IMPORT', 'h-decan-'||v_id, v_id, 'CAN', 32, 'kg', '{"note":"cân trước xuất"}') on conflict do nothing;
          perform sell_livestock(F, U, array[v_id], 'KH-0003', 145000, 'SKU-DE-HOI', d + interval '240 days');
        end if;
      end loop;
      insert into animal_events(farm_id, ts, created_by, source, client_ref, animal_id, event_type, detail) values (F, d + time '06:00', U, 'IMPORT', 'h-dede-'||i||'-'||k, F||'-DE-C'||lpad(i::text,3,'0'), 'DE', jsonb_build_object('create_calf', false, 'kids', case when (i+k)%5=0 then 1 else 2 end)) on conflict do nothing;
      d := d + 240;
    end loop;
  end loop;
  -- ---------- 3. GÀ: đẻ 3.000 mái/lứa 15 tháng (2 lứa), thịt 1.500/lứa 3 tháng; RAS lươn 2 bể ----------
  update animal_groups set head_count=2917, started_at=(d0 + interval '15 months')::date where id=(F||'-GA-L01');
  insert into animal_groups(id, farm_id, species, kind, name, location_id, head_count, started_at, all_in_all_out, status, class_code) values ((F||'-GA-L00'), F, 'GA', 'GA_DE', 'Gà đẻ lứa 00 (đã loại)', (F||'-GA-DE'), 0, d0, true, 'DONG', 'GA-DE') on conflict do nothing;
  -- ---------- 4. THỜI TIẾT 30 tháng (mùa mưa 5–10) ----------
  for i in 0..(current_date - d0) loop d := d0 + i;
    insert into weather_daily(farm_id, day, tmin, tmax, rain_mm, rh_pct, wind_ms, sunshine_h, source) values (F, d,
      22 + 3*sin((extract(doy from d)-100)/58.0) + (i%5)*0.4, 30 + 4*sin((extract(doy from d)-100)/58.0) + (i%7)*0.5,
      case when extract(month from d) between 5 and 10 then (case when (i*7919)%10 < 6 then ((i*104729)%40) else 0 end) else (case when (i*7919)%10 < 1 then ((i*104729)%15) else 0 end) end,
      70 + (case when extract(month from d) between 5 and 10 then 12 else 0 end) + (i%9), 1.5 + (i%6)*0.4, case when extract(month from d) between 5 and 10 then 5.5 else 8 end + (i%4)*0.4, 'IMPORT') on conflict (farm_id, day) do nothing;
  end loop;
  -- ---------- 5. MÙA VỤ + THU HOẠCH: bắp 3 vụ/năm/ô (85 ngày, 45 t/ha), lúa 2 vụ (105 ngày, 6 t/ha thóc + rơm), cỏ cắt 45 ngày/lứa (180 t/ha/năm ≈ 25 t/ha/lứa), mì 1 vụ (25 t/ha) ----------
  foreach v_id in array array[(F||'-LO-G1A'),(F||'-LO-G1B'),(F||'-LO-G2A'),(F||'-LO-G2B')] loop
    for k in 0..(M/8) loop
      sow := d0 + (k*240 + (case v_id when (F||'-LO-G1A') then 0 when (F||'-LO-G1B') then 60 when (F||'-LO-G2A') then 120 else 180 end)); hv := sow + 85; exit when sow > current_date;
      season_id := v_id||'-CS-'||to_char(sow,'YYMM');
      insert into crop_seasons(id, farm_id, code, plot_id, crop, crop_code, variety, seed_source, area_ha, sow_date, expected_harvest, harvest_start, harvest_end, cert_scheme, target_yield_kg, actual_yield_kg, status, responsible_id, created_by)
      values (season_id, F, 'CS-'||right(v_id,3)||'-'||to_char(sow,'YYMM'), v_id, 'BAP', 'BAP-SK', 'NK7328', 'Cty giống Đông Nam Bộ', 2.0, sow, hv, case when hv<=current_date then hv end, case when hv<=current_date then hv+3 end, 'VIETGAP', 2.0*45000, case when hv<=current_date then 2.0*(42000+(k*997)%6000) else 0 end, case when hv<=current_date then 'XONG' else 'DANG_TRONG' end, U, U) on conflict do nothing;
      insert into crop_logs(farm_id, ts, created_by, source, client_ref, plot_id, activity, variety, machine_id, machine_hours, fuel_l) values (F, sow + time '07:00', U, 'IMPORT', 'h-gieo-'||season_id, v_id, 'GIEO', 'NK7328', (F||'-TB-002'), 6, 84) on conflict do nothing;
      insert into crop_inputs(farm_id, ts, created_by, source, client_ref, season_id, plot_id, sku, product_name, kind, qty, unit, dose_per_ha, method, organic_allowed) values (F, sow + 20 + time '08:00', U, 'IMPORT', 'h-bon-'||season_id, season_id, v_id, 'PB-HUU-CO', 'Phân hữu cơ ủ hoai', 'PHAN_HUU_CO', 8000, 'kg', 4000, 'bón gốc', true) on conflict do nothing;
      if hv <= current_date then
        insert into harvests(farm_id, ts, created_by, source, client_ref, season_id, plot_id, crop, variety, qty_kg, unit, moisture_pct, grade, harvest_lot, machine_id, phi_ok) values (F, hv + time '09:00', U, 'IMPORT', 'h-thu-'||season_id, season_id, v_id, 'BAP', 'NK7328', 2.0*(42000+(k*997)%6000), 'kg', 68, 'A', 'BAP-'||to_char(hv,'YYMMDD')||'-'||right(v_id,3), (F||'-TB-002'), true) on conflict do nothing;
      end if;
    end loop;
  end loop;
  foreach v_id in array array[(F||'-LO-L01'),(F||'-LO-L02')] loop
    for k in 0..(M/6) loop
      sow := d0 + (k*182 + (case v_id when (F||'-LO-L01') then 0 else 15 end)); hv := sow + 105; exit when sow > current_date;
      season_id := v_id||'-CS-'||to_char(sow,'YYMM');
      insert into crop_seasons(id, farm_id, code, plot_id, crop, crop_code, variety, area_ha, sow_date, expected_harvest, harvest_start, cert_scheme, target_yield_kg, actual_yield_kg, status, responsible_id, created_by)
      values (season_id, F, 'CS-'||right(v_id,3)||'-'||to_char(sow,'YYMM'), v_id, 'LUA', 'LUA', 'ST25', 2.5, sow, hv, case when hv<=current_date then hv end, 'VIETGAP', 2.5*6000, case when hv<=current_date then 2.5*(5600+(k*331)%900) else 0 end, case when hv<=current_date then 'XONG' else 'DANG_TRONG' end, U, U) on conflict do nothing;
      if hv <= current_date then
        -- thóc → K5 SKU-LUA (nhập trực tiếp), rơm → trigger harvests (LUA→NL-ROM K3) : ghi harvest qty = rơm
        insert into harvests(farm_id, ts, created_by, source, client_ref, season_id, plot_id, crop, variety, qty_kg, unit, moisture_pct, grade, harvest_lot, phi_ok, note) values (F, hv + time '09:00', U, 'IMPORT', 'h-thu-'||season_id, season_id, v_id, 'LUA', 'ST25', 2.5*(5600+(k*331)%900), 'kg', 14, 'A', 'LUA-'||to_char(hv,'YYMMDD')||'-'||right(v_id,3), true, 'thóc; rơm cuộn tương đương nhập K3') on conflict do nothing;
        v_lot := ensure_lot(F, 'SKU-LUA', 'LUA-'||to_char(hv,'YYMM')||'-'||right(v_id,3), null, hv + 365);
        insert into inventory_moves(farm_id, ts, created_by, source, client_ref, warehouse_id, sku, lot_id, direction, qty, unit, unit_cost, reason, from_to) select F, hv + time '15:00', U, 'IMPORT', 'h-thoc-'||season_id, w.id, 'SKU-LUA', v_lot, 1, 2.5*(5600+(k*331)%900), 'kg', 6500, 'NHAP_SX', v_id from warehouses w where w.farm_id=F and w.code='K5' on conflict do nothing;
      end if;
    end loop;
  end loop;
  -- cỏ: mùa vụ lâu năm 1 dòng/ô/năm + cắt mỗi 45 ngày (0.5 ha × 25 t/ha = 12.5 t/lứa) → trigger nhập K3 NL-CO-TUOI
  foreach v_id in array plotc loop
    for k in 0..(M/12) loop sow := d0 + (k*365); exit when sow > current_date;
      insert into crop_seasons(id, farm_id, code, plot_id, crop, crop_code, variety, area_ha, sow_date, expected_harvest, cert_scheme, target_yield_kg, status, responsible_id, created_by) values (v_id||'-CS-'||to_char(sow,'YY'), F, 'CS-'||right(v_id,3)||'-'||to_char(sow,'YY'), v_id, 'CO', (select crop_code from plots where id=v_id), 'Mombasa/VA06/Ruzi', 0.5, sow, sow+365, 'VIETGAP', 0.5*180000, case when sow+365<=current_date then 'XONG' else 'DANG_TRONG' end, U, U) on conflict do nothing; end loop;
    for k in 0..(M*30/45) loop d := d0 + 45 + k*45 + (array_position(plotc, v_id)*6); exit when d > current_date;
      insert into crop_logs(farm_id, ts, created_by, source, client_ref, plot_id, activity, variety, qty_kg, moisture_pct, machine_id, machine_hours, fuel_l) values (F, d + time '08:00', U, 'IMPORT', 'h-cat-'||v_id||'-'||k, v_id, 'CAT', 'Mombasa', 11500 + (k*613)%2500, 74, (F||'-TB-002'), 2.5, 35) on conflict do nothing;
    end loop;
  end loop;
  -- mì G2A? (giữ như seed cũ) — rau: bán hằng tuần 150 kg
  -- ---------- 6. KHO: mua theo tháng (bã bia, rỉ mật, khoáng, thuốc, dầu, bao bì) + xuất cho ăn theo tuần + D5 sản xuất TMR/viên ----------
  for k in 0..(M-1) loop d := d0 + (k||' months')::interval; d := (d + interval '3 days')::date;
    -- PO + nhập mua
    insert into purchase_orders(id, farm_id, supplier_id, ts, created_by, lines, total, po_status, approved_by, approved_at, expected_at, received_at, paid_at, paid_amount, kind, invoice_no)
    values (F||'-PO-H'||lpad(k::text,3,'0'), F, 'NCC-0002', d, U, '[{"sku":"NL-BA-BIA","qty":26000,"price":1200},{"sku":"NL-RI-MAT","qty":4200,"price":6500},{"sku":"NL-KHOANG","qty":3300,"price":18000},{"sku":"NL-ROM","qty":14000,"price":1500}]', 26000*1200+4200*6500+3300*18000+14000*1500, 'DA_NHAN', U, d, d+2, d+2, case when k < M-2 then d+17 end, case when k < M-2 then 26000*1200+4200*6500+3300*18000+14000*1500 else 0 end, 'VAT_TU', 'HD-'||to_char(d,'YYMM')||'-BIA') on conflict do nothing;
    for r in select * from (values ('NL-BA-BIA',26000,1200,'K2'),('NL-RI-MAT',4200,6500,'K2'),('NL-KHOANG',3300,18000,'K2'),('NL-ROM',14000,1500,'K2'),('NL-DAU',900,21000,'K7'),('BB-TEM',3000,120,'K9'),('BB-BAO-25',400,3500,'K9')) t(sku,q,p,wc) loop
      v_lot := ensure_lot(F, r.sku, 'H'||to_char(d,'YYMM'), case r.sku when 'NL-BA-BIA' then 'NCC-0002' when 'NL-ROM' then 'NCC-0001' else null end, d + 120);
      insert into inventory_moves(farm_id, ts, created_by, source, client_ref, warehouse_id, sku, lot_id, direction, qty, unit, unit_cost, reason, from_to, ref_type, ref_id) select F, d + time '10:00', U, 'IMPORT', 'h-mua-'||r.sku||'-'||k, w.id, r.sku, v_lot, 1, r.q, (select unit from products where sku=r.sku), r.p, 'NHAP_MUA', 'NCC', 'purchase_orders', F||'-PO-H'||lpad(k::text,3,'0') from warehouses w where w.farm_id=F and w.code=r.wc on conflict do nothing;
    end loop;
    -- thuốc/vaccine quý
    if k%3=0 then v_lot := ensure_lot(F, 'TH-OXY', 'H'||to_char(d,'YYMM'), 'NCC-0003', d+540); insert into inventory_moves(farm_id, ts, created_by, source, client_ref, warehouse_id, sku, lot_id, direction, qty, unit, unit_cost, reason, from_to) values (F, d + time '10:00', U, 'IMPORT', 'h-mua-oxy-'||k, wh.k1, 'TH-OXY', v_lot, 1, 12, 'lo', 85000, 'NHAP_MUA', 'NCC-0003') on conflict do nothing;
      v_lot := ensure_lot(F, 'VX-LMLM', 'H'||to_char(d,'YYMM'), 'NCC-0003', d+365); insert into inventory_moves(farm_id, ts, created_by, source, client_ref, warehouse_id, sku, lot_id, direction, qty, unit, unit_cost, reason, from_to) values (F, d + time '10:00', U, 'IMPORT', 'h-mua-vx-'||k, wh.k1, 'VX-LMLM', v_lot, 1, 150, 'lieu', 32000, 'NHAP_MUA', 'NCC-0003') on conflict do nothing; end if;
  end loop;
  -- xuất cho ăn theo tuần: đàn bò ≈ (45 nái×32 + vỗ 30×35 + bê) ≈ 2.700 kg TMR/ngày → 45% bắp ủ, 15% rơm, 25% bã bia, 8% cỏ, 4% rỉ mật, 3% khoáng ; gà 345 kg viên/ngày (từ K4)
  for k in 0..(M*30/7) loop d := d0 + k*7; exit when d > current_date;
    select coalesce(sum(case when d - a.birth_date <= 180 then 8 when d - a.birth_date <= 540 then 20 else 32 end),0) into base from animals a where a.farm_id=F and a.id like F||'-BE-H%' and a.birth_date <= d; qty := 7 * (45*32 + 30*35 + base + (select count(*)*1.2 from animals a where a.farm_id=F and a.species='DE' and a.created_at::date <= d and a.status<>'XUAT'));
    for r in select * from (values ('NL-BAP-U',0.45,'K3'),('NL-ROM',0.15,'K2'),('NL-BA-BIA',0.25,'K2'),('NL-CO-TUOI',0.08,'K3'),('NL-RI-MAT',0.04,'K2'),('NL-KHOANG',0.03,'K2')) t(sku,pct,wc) loop
      insert into inventory_moves(farm_id, ts, created_by, source, client_ref, warehouse_id, sku, direction, qty, unit, reason, from_to, weigh_point) select F, d + time '06:00', U, 'IMPORT', 'h-choan-'||r.sku||'-'||k, w.id, r.sku, -1, round(qty*r.pct), 'kg', 'XUAT_CHO_AN', (F||'-DAN-NAI-01'), 'CAN_CAU_D' from warehouses w where w.farm_id=F and w.code=r.wc on conflict do nothing;
    end loop;
    -- cỏ dư → ủ (xuất K3 cỏ tươi thêm 30% để ủ chua vào NL-BAP-U? giữ đơn giản: xuất bớt cỏ cho dê)
    insert into inventory_moves(farm_id, ts, created_by, source, client_ref, warehouse_id, sku, direction, qty, unit, reason, from_to) select F, d + time '07:00', U, 'IMPORT', 'h-code-'||k, w.id, 'NL-CO-TUOI', -1, 7*60*3.5*0.7, 'kg', 'XUAT_CHO_AN', 'DE' from warehouses w where w.farm_id=F and w.code='K3' on conflict do nothing;
    -- D5: viên gà 350 kg/ngày × 7 (nhập K4, xuất nguyên liệu K2/K3), xuất cho gà
    tmrLot := ensure_lot(F, 'TA-VIEN-GA', 'V'||to_char(d,'YYMM'), null, d+60);
    insert into inventory_moves(farm_id, ts, created_by, source, client_ref, warehouse_id, sku, lot_id, direction, qty, unit, unit_cost, reason, from_to) select F, d + time '05:30', U, 'IMPORT', 'h-vien-in-'||k, w.id, 'TA-VIEN-GA', tmrLot, 1, 2450, 'kg', 9500, 'NHAP_SX', 'D5' from warehouses w where w.farm_id=F and w.code='K4' on conflict do nothing;
    insert into inventory_moves(farm_id, ts, created_by, source, client_ref, warehouse_id, sku, lot_id, direction, qty, unit, reason, from_to) select F, d + time '06:30', U, 'IMPORT', 'h-vien-out-'||k, w.id, 'TA-VIEN-GA', tmrLot, -1, 2400, 'kg', 'XUAT_CHO_AN', 'GA-DE' from warehouses w where w.farm_id=F and w.code='K4' on conflict do nothing;
    for r in select * from (values ('NL-BAP-U',0.55,'K3'),('NL-BA-BIA',0.25,'K2'),('NL-KHOANG',0.05,'K2'),('NL-RI-MAT',0.05,'K2'),('NL-ROM',0.10,'K2')) t(sku,pct,wc) loop
      insert into inventory_moves(farm_id, ts, created_by, source, client_ref, warehouse_id, sku, direction, qty, unit, reason, from_to) select F, d + time '05:00', U, 'IMPORT', 'h-viennl-'||r.sku||'-'||k, w.id, r.sku, -1, round(2450*r.pct), 'kg', 'XUAT_SX', 'D5' from warehouses w where w.farm_id=F and w.code=r.wc on conflict do nothing;
    end loop;
    -- dầu 90 L/tuần
    insert into inventory_moves(farm_id, ts, created_by, source, client_ref, warehouse_id, sku, direction, qty, unit, reason, from_to) select F, d + time '07:00', U, 'IMPORT', 'h-dau-'||k, w.id, 'NL-DAU', -1, 90 + (k%5)*8, 'l', 'XUAT_SX', (F||'-TB-002') from warehouses w where w.farm_id=F and w.code='K7' on conflict do nothing;
    -- phân trùn: 1.100 kg/tuần → 44 bao → K5, bán 40 bao/tuần
    ptLot := ensure_lot(F, 'SKU-PTR-25', 'PT'||to_char(d,'YYMM'), null, d+365);
    insert into inventory_moves(farm_id, ts, created_by, source, client_ref, warehouse_id, sku, lot_id, direction, qty, unit, unit_cost, reason, from_to) select F, d + 5 + time '15:00', U, 'IMPORT', 'h-pt-in-'||k, w.id, 'SKU-PTR-25', ptLot, 1, 44, 'bao', 60000, 'NHAP_SX', 'KHU-D' from warehouses w where w.farm_id=F and w.code='K5' on conflict do nothing;
    insert into inventory_moves(farm_id, ts, created_by, source, client_ref, warehouse_id, sku, lot_id, direction, qty, unit, reason, from_to) select F, d + 6 + time '10:00', U, 'IMPORT', 'h-pt-out-'||k, w.id, 'SKU-PTR-25', ptLot, -1, 40, 'bao', 'XUAT_BAN', 'KH-0002' from warehouses w where w.farm_id=F and w.code='K5' on conflict do nothing;
    insert into sales(farm_id, ts, created_by, source, client_ref, partner_id, sku, lot_id, qty, unit, price, amount, channel, payment, paid) values (F, d + 6 + time '10:30', U, 'IMPORT', 'h-sale-pt-'||k, 'KH-0002', 'SKU-PTR-25', ptLot, 40, 'bao', 78000, 40*78000, 1, 'CK', true) on conflict do nothing;
    -- TMR bao bán 100 bao/tuần cho hộ liên kết
    v_lot := ensure_lot(F, 'SKU-TMR-25', 'TMR'||to_char(d,'YYMM'), null, d+90);
    insert into inventory_moves(farm_id, ts, created_by, source, client_ref, warehouse_id, sku, lot_id, direction, qty, unit, unit_cost, reason, from_to) select F, d + 4 + time '14:00', U, 'IMPORT', 'h-tmr-in-'||k, w.id, 'SKU-TMR-25', v_lot, 1, 110, 'bao', 62000, 'NHAP_SX', 'D5' from warehouses w where w.farm_id=F and w.code='K5' on conflict do nothing;
    insert into inventory_moves(farm_id, ts, created_by, source, client_ref, warehouse_id, sku, lot_id, direction, qty, unit, reason, from_to) select F, d + 5 + time '09:00', U, 'IMPORT', 'h-tmr-out-'||k, w.id, 'SKU-TMR-25', v_lot, -1, 100, 'bao', 'XUAT_BAN', 'KH-0001' from warehouses w where w.farm_id=F and w.code='K5' on conflict do nothing;
    insert into sales(farm_id, ts, created_by, source, client_ref, partner_id, sku, lot_id, qty, unit, price, amount, channel, payment, paid) values (F, d + 5 + time '09:30', U, 'IMPORT', 'h-sale-tmr-'||k, 'KH-0001', 'SKU-TMR-25', v_lot, 100, 'bao', 101200, 100*101200, 1, case when k%4=0 then 'CONG_NO' else 'CK' end, k%4<>0) on conflict do nothing;
    -- rau 150 kg/tuần
    v_lot := ensure_lot(F, 'SKU-RAU', 'RAU'||to_char(d,'YYMM'), null, d+5);
    insert into inventory_moves(farm_id, ts, created_by, source, client_ref, warehouse_id, sku, lot_id, direction, qty, unit, unit_cost, reason, from_to) select F, d + 2 + time '06:00', U, 'IMPORT', 'h-rau-in-'||k, w.id, 'SKU-RAU', v_lot, 1, 150, 'kg', 8000, 'NHAP_SX', (F||'-LO-R01') from warehouses w where w.farm_id=F and w.code='K5' on conflict do nothing;
    insert into inventory_moves(farm_id, ts, created_by, source, client_ref, warehouse_id, sku, lot_id, direction, qty, unit, reason, from_to) select F, d + 2 + time '08:00', U, 'IMPORT', 'h-rau-out-'||k, w.id, 'SKU-RAU', v_lot, -1, 145, 'kg', 'XUAT_BAN', 'KH-0004' from warehouses w where w.farm_id=F and w.code='K5' on conflict do nothing;
    insert into sales(farm_id, ts, created_by, source, client_ref, partner_id, sku, lot_id, qty, unit, price, amount, channel, payment, paid) values (F, d + 2 + time '08:30', U, 'IMPORT', 'h-sale-rau-'||k, 'KH-0004', 'SKU-RAU', v_lot, 145, 'kg', 18000, 145*18000, 3, 'POS', true) on conflict do nothing;
  end loop;
  -- ---------- 7. GÀ ĐẺ hằng ngày 30 tháng: lứa 00 (d0 → d0+15th, tỷ lệ đẻ 20% tuần 20 → 92% đỉnh → 70% cuối), lứa 01 từ d0+15th ----------
  for i in 0..(current_date - d0) loop d := d0 + i;
    k := case when d < d0 + interval '15 months' then i else i - 456 end; -- ngày trong lứa
    lay := least(0.92, greatest(0, 0.2 + k*0.012)) - greatest(0, (k-250))*0.001; if lay < 0.2 then lay := 0.2; end if;
    hens := case when d < d0 + interval '15 months' then 3000 - (i/9) else 3000 - ((i-456)/9) end;
    egg := round(hens * lay * (1 + ((i*31)%7 - 3)*0.01)); trays := egg/10;
    insert into animal_events(farm_id, ts, created_by, source, client_ref, group_id, event_type, value, unit, detail) values (F, d + time '16:00', U, 'IMPORT', 'h-egg-'||i, case when d < d0 + interval '15 months' then (F||'-GA-L00') else (F||'-GA-L01') end, 'SO_LUONG', egg, 'qua', jsonb_build_object('metric','eggs_counted','hens',hens,'lay_pct',round(lay*100,1))) on conflict do nothing;
    if (i*7)%11=0 then insert into animal_events(farm_id, ts, created_by, source, client_ref, group_id, event_type, value, unit, detail) values (F, d + time '07:00', U, 'IMPORT', 'h-gachet-'||i, case when d < d0 + interval '15 months' then (F||'-GA-L00') else (F||'-GA-L01') end, 'CHET', 1 + (i%2), 'con', '{"note":"chết lẻ"}') on conflict do nothing; end if;
    eggLot := ensure_lot(F, 'SKU-TRUNG-10', to_char(d,'YYMMDD')||'-TRA', null, d+21);
    insert into inventory_moves(farm_id, ts, created_by, source, client_ref, warehouse_id, sku, lot_id, direction, qty, unit, unit_cost, reason, from_to) select F, d + time '17:00', U, 'IMPORT', 'h-egg-in-'||i, w.id, 'SKU-TRUNG-10', eggLot, 1, trays, 'vi', 22000, 'NHAP_SX', 'GA-DE' from warehouses w where w.farm_id=F and w.code='K5' on conflict do nothing;
    insert into inventory_moves(farm_id, ts, created_by, source, client_ref, warehouse_id, sku, lot_id, direction, qty, unit, reason, from_to) select F, d + time '17:30', U, 'IMPORT', 'h-egg-out-'||i, w.id, 'SKU-TRUNG-10', eggLot, -1, greatest(trays-2,0), 'vi', 'XUAT_BAN', 'KH' from warehouses w where w.farm_id=F and w.code='K5' on conflict do nothing;
    insert into sales(farm_id, ts, created_by, source, client_ref, partner_id, sku, lot_id, qty, unit, price, amount, channel, payment, paid) values (F, d + time '17:45', U, 'IMPORT', 'h-sale-egg-'||i, case when i%3=0 then 'KH-0003' when i%3=1 then 'KH-0004' else 'KH-0001' end, 'SKU-TRUNG-10', eggLot, greatest(trays-2,0), 'vi', case when i%3=2 then 45000 else 40000 end, greatest(trays-2,0)*(case when i%3=2 then 45000 else 40000 end), case when i%3=0 then 2 when i%3=1 then 3 else 1 end, case when i%3=2 then 'CONG_NO' else 'CK' end, i%3<>2 or d < current_date-15) on conflict do nothing;
    -- gà thịt: 3 tháng/lứa, bán 1.400 con × 2.1 kg cuối lứa
    if i>0 and i%91=90 then insert into sales(farm_id, ts, created_by, source, client_ref, partner_id, sku, qty, unit, price, amount, channel, payment, paid) values (F, d + time '08:00', U, 'IMPORT', 'h-sale-gathit-'||i, 'KH-0003', 'SKU-GA-THIT', 1400*2.1, 'kg', 68000, 1400*2.1*68000, 1, 'CK', true) on conflict do nothing; end if;
  end loop;
  -- ---------- 8. cân nái tháng, dê tháng (nhẹ) ----------
  for i in 1..45 loop for k in 0..(M-1) loop d := (d0 + (k||' months')::interval)::date + 5; if d > (select created_at::date from animals where id=dams[i]) and d <= current_date then
    insert into animal_events(farm_id, ts, created_by, source, client_ref, animal_id, event_type, value, unit) values (F, d + time '07:30', U, 'IMPORT', 'h-can-'||dams[i]||'-'||k, dams[i], 'CAN', 380 + (i%9)*5 + least(k,12)*4 + ((i*k)%3), 'kg') on conflict do nothing; end if; end loop; end loop;
  -- ---------- 9. tưới, dịch hại, đất, luân canh, hợp đồng, kế hoạch, công cụ ----------
  for k in 0..(M*30/10) loop d := d0 + k*10; exit when d > current_date; if extract(month from d) not between 6 and 9 then
    insert into irrigation_logs(farm_id, ts, created_by, source, client_ref, plot_id, method, minutes, volume_m3, water_source, energy_kwh) values (F, d + time '06:00', U, 'IMPORT', 'h-tuoi-'||k, plotc[1 + k%6], 'PHUN_MUA', 120, 180 + (k%4)*20, 'ao', 22) on conflict do nothing; end if; end loop;
  for k in 0..(M) loop d := (d0 + (k||' months')::interval)::date + 12; exit when d > current_date;
    insert into pest_scouting(farm_id, ts, created_by, source, client_ref, plot_id, pest, pest_kind, density, unit, threshold, ipm_level, action) values (F, d + time '08:00', U, 'IMPORT', 'h-pest-'||k, case when k%2=0 then (F||'-LO-G1A') else (F||'-LO-G2A') end, case when k%3=0 then 'Sâu keo mùa thu' when k%3=1 then 'Rầy nâu' else 'Đốm lá' end, case when k%3=2 then 'BENH' else 'SAU' end, 3 + (k*7)%12, 'con/m2', 10, case when 3+(k*7)%12 >= 10 then 'SINH_HOC' else 'THEO_DOI' end, case when 3+(k*7)%12 >= 10 then 'Phun Bt + bẫy pheromone' else null end) on conflict do nothing; end loop;
  insert into soil_tests(id, farm_id, plot_id, sampled_at, ph, om_pct, n_total_pct, p_avail_mgkg, k_avail_mgkg, ec_dsm, cec, texture, lab, recommendation, next_due) values
   ((F||'-SOIL-G1A-1'),F,(F||'-LO-G1A'),d0+10,5.6,2.1,0.12,18,85,0.4,12,'Thịt pha cát','Viện Thổ nhưỡng','Bón vôi 1 t/ha, tăng hữu cơ',d0+375),((F||'-SOIL-G1A-2'),F,(F||'-LO-G1A'),d0+375,6.1,2.8,0.15,26,110,0.35,13,'Thịt pha cát','Viện Thổ nhưỡng','Duy trì hữu cơ 8 t/ha/vụ',d0+740),((F||'-SOIL-G1A-3'),F,(F||'-LO-G1A'),d0+740,6.4,3.4,0.17,31,128,0.3,14,'Thịt pha cát','Viện Thổ nhưỡng','Tốt — theo dõi',d0+1105),
   ((F||'-SOIL-L01-1'),F,(F||'-LO-L01'),d0+20,5.2,1.8,0.10,12,60,0.5,10,'Sét','Viện Thổ nhưỡng','Vôi 1.5 t/ha, phân trùn',d0+385),((F||'-SOIL-K01-1'),F,(F||'-LO-K01'),d0+30,5.9,2.5,0.14,20,95,0.3,11,'Thịt','Viện Thổ nhưỡng','OK',d0+395)
  on conflict do nothing;
  insert into crop_rotation_plans(id, farm_id, plot_id, year, season_no, crop_code, crop_family, purpose, status) values
   ((F||'-ROT-G1A-1'),F,(F||'-LO-G1A'),extract(year from current_date)::int,1,'BAP-SK','HOA_THAO','sinh khối ủ','XONG'),((F||'-ROT-G1A-2'),F,(F||'-LO-G1A'),extract(year from current_date)::int,2,'DAU-NANH','DAU','cải tạo đất','KE_HOACH'),((F||'-ROT-G1A-3'),F,(F||'-LO-G1A'),extract(year from current_date)::int,3,'BAP-SK','HOA_THAO','sinh khối ủ','KE_HOACH'),
   ((F||'-ROT-G2A-1'),F,(F||'-LO-G2A'),extract(year from current_date)::int,1,'KHOAI-MI','KHOAI','củ + lá','DANG_LAM'),((F||'-ROT-G2A-2'),F,(F||'-LO-G2A'),extract(year from current_date)::int,2,'KHOAI-MI','KHOAI','củ','KE_HOACH')
  on conflict do nothing;
  insert into plot_contracts(id, farm_id, plot_id, partner_id, kind, start_date, end_date, area_ha, price_terms, share_pct, inputs_by, status, note) values
   ((F||'-PLC-01'),F,(F||'-LO-L02'),'KH-0002','LIEN_KET',d0,d0+1095,2.5,'Trại bao tiêu thóc 7.000 đ/kg + rơm','30','CHIA','HIEU_LUC','Hộ ông Ba — ruộng liền kề')
  on conflict do nothing;
  -- công cụ hỏng/mất vài lần
  insert into inventory_moves(farm_id, ts, created_by, source, client_ref, warehouse_id, sku, direction, qty, unit, reason, from_to) values (F, current_date - 40 + time '09:00', U, 'IMPORT', 'h-tool-hong-1', F||'-KCC-A', 'CC-CUOC', -1, 1, 'cai', 'HONG', 'gãy cán'), (F, current_date - 12 + time '09:00', U, 'IMPORT', 'h-tool-mat-1', F||'-KCC-R', 'CC-DAO-PHAT', -1, 1, 'cai', 'MAT', 'thất lạc ruộng') on conflict do nothing;
  insert into tool_issues(farm_id, warehouse_id, sku, qty, staff_id, dept, purpose, issued_at, due_back) values (F, F||'-KCC-A', 'CC-XE-RUA', 2, U, 'BO', 'dọn chuồng dãy nái', current_date-3, current_date+4), (F, F||'-KCC-R', 'CC-MAY-CAT-CO', 1, U, 'TT', 'cắt viền K03', current_date-9, current_date-2) on conflict do nothing;
  -- cập nhật số đầu nhóm bò
  update animal_groups set head_count=(select count(*) from animals a where a.farm_id=F and a.group_id=(F||'-DAN-NAI-01') and a.status not in ('CHET','XUAT','LOAI')) where id=(F||'-DAN-NAI-01');
  update animal_groups set head_count=(select count(*) from animals a where a.farm_id=F and a.group_id=(F||'-DAN-VO-01') and a.status not in ('CHET','XUAT','LOAI')) where id=(F||'-DAN-VO-01');
  update sales s2 set amount = s2.qty*s2.price where s2.farm_id=F and coalesce(s2.amount,0)=0;
end $$;
-- ---------- 10. tổng hợp lại agg/herd_daily nếu có hàm ----------
do $$ begin
  if to_regprocedure('itran_agg_daily(text,date)') is not null then for i in 0..900 loop perform itran_agg_daily('F01', current_date - i); end loop; end if;
exception when others then raise notice 'agg skip: %', sqlerrm; end $$;
select 'animals' as t, count(*) from animals where farm_id=:'farm' union all select 'animal_events', count(*) from animal_events where farm_id=:'farm' union all select 'inventory_moves', count(*) from inventory_moves where farm_id=:'farm' union all select 'sales', count(*) from sales where farm_id=:'farm' union all select 'crop_seasons', count(*) from crop_seasons where farm_id=:'farm' union all select 'harvests', count(*) from harvests where farm_id=:'farm' union all select 'weather_daily', count(*) from weather_daily where farm_id=:'farm';
