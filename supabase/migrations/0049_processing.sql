-- 0049 · CHẾ BIẾN SÂU: BOM đa cấp + MRP bung nhu cầu/thiếu hụt, thông số bao bì 3 cấp, nhãn (thành phần/dị ứng/dinh dưỡng/HSD/claims), kế hoạch SX tuần, tem QR mẻ
-- 1) BOM đa cấp (thay/ bổ sung recipes: recipes = công thức trộn theo %, BOM = định mức thành phẩm gồm nguyên liệu + bao bì + bán thành phẩm)
create table if not exists bom_headers(
  id text primary key, farm_id text not null references farms, sku text not null references products, version int not null default 1, name text,
  batch_size numeric not null default 1, unit text default 'kg', yield_pct numeric default 100, line text, cycle_min numeric, labor_min numeric,
  status text not null default 'NHAP' check (status in ('NHAP','BAN_HANH','NGUNG')), approved_by text, approved_at timestamptz, note text,
  created_at timestamptz default now(), created_by text default app_staff(), attrs jsonb default '{}'::jsonb, unique(sku, version));
create table if not exists bom_lines(
  id text primary key, bom_id text not null references bom_headers on delete cascade, component_sku text not null references products, qty numeric not null, unit text default 'kg',
  scrap_pct numeric default 0, is_packaging bool default false, stage text, seq int default 1, note text);
alter table bom_headers enable row level security; drop policy if exists p_all on bom_headers; create policy p_all on bom_headers for all using (can_see_farm(farm_id)) with check (true); grant select, insert, update on bom_headers to app_user;
alter table bom_lines enable row level security; drop policy if exists p_all on bom_lines; create policy p_all on bom_lines for all using (exists (select 1 from bom_headers h where h.id=bom_lines.bom_id and can_see_farm(h.farm_id))) with check (true); grant select, insert, update, delete on bom_lines to app_user;
-- bung BOM đệ quy (≤6 cấp): nhu cầu lá theo số lượng thành phẩm cần
create or replace function mrp_explode(p_farm text, p_sku text, p_qty numeric) returns table(level int, component_sku text, component_name text, unit text, req_qty numeric, is_packaging bool, path text) language sql stable as $$
  with recursive x as (
    select 1 as level, l.component_sku, l.unit, (p_qty / nullif(h.batch_size,0)) * l.qty * (1 + coalesce(l.scrap_pct,0)/100) / (coalesce(h.yield_pct,100)/100) as req_qty, l.is_packaging, p_sku||' > '||l.component_sku as path
    from bom_headers h join bom_lines l on l.bom_id=h.id where h.farm_id=p_farm and h.sku=p_sku and h.status='BAN_HANH' and h.version=(select max(version) from bom_headers where farm_id=p_farm and sku=p_sku and status='BAN_HANH')
    union all
    select x.level+1, l.component_sku, l.unit, (x.req_qty / nullif(h.batch_size,0)) * l.qty * (1 + coalesce(l.scrap_pct,0)/100) / (coalesce(h.yield_pct,100)/100), l.is_packaging, x.path||' > '||l.component_sku
    from x join bom_headers h on h.farm_id=p_farm and h.sku=x.component_sku and h.status='BAN_HANH' and h.version=(select max(version) from bom_headers where farm_id=p_farm and sku=h.sku and status='BAN_HANH')
    join bom_lines l on l.bom_id=h.id where x.level < 6)
  select x.level, x.component_sku, p.name, x.unit, round(x.req_qty::numeric, 3), x.is_packaging, x.path from x join products p on p.sku=x.component_sku $$;
grant execute on function mrp_explode(text,text,numeric) to app_user;
-- 2) Kế hoạch sản xuất tuần
create table if not exists production_plans(
  id text primary key, farm_id text not null references farms, week_start date not null, sku text not null references products, qty_plan numeric not null, unit text default 'kg',
  line text, source text default 'DU_BAO' check (source in ('DON_HANG','DU_BAO','TON_KHO_MIN','HOP_DONG')), qty_done numeric default 0, status text default 'KE_HOACH' check (status in ('KE_HOACH','DANG_SX','XONG','HUY')),
  bom_id text references bom_headers, note text, created_at timestamptz default now(), created_by text default app_staff(), attrs jsonb default '{}'::jsonb);
alter table production_plans enable row level security; drop policy if exists p_all on production_plans; create policy p_all on production_plans for all using (can_see_farm(farm_id)) with check (true); grant select, insert, update on production_plans to app_user;
-- MRP: nhu cầu = kế hoạch SX tuần (chưa xong) + đơn hàng đã xác nhận chưa giao → bung BOM → so tồn khả dụng → thiếu hụt gợi ý mua
create or replace function mrp_run(p_farm text, p_days int default 14) returns table(component_sku text, component_name text, unit text, req_qty numeric, available numeric, shortage numeric, is_packaging bool, sources text) language sql stable as $$
  with demand as (
    select sku, sum(qty_plan - coalesce(qty_done,0)) as qty, 'KHSX' as src from production_plans where farm_id=p_farm and status in ('KE_HOACH','DANG_SX') and week_start <= current_date + p_days group by sku
    union all
    select (l->>'sku'), sum((l->>'qty')::numeric), 'DON' from orders o, jsonb_array_elements(o.lines) l where o.farm_id=p_farm and o.status in ('XAC_NHAN','DANG_SOAN','CHO_GIAO') and coalesce(o.deliver_date, current_date) <= current_date + p_days group by 1
    union all
    select sku, sum(qty), 'LSX' from production_orders where farm_id=p_farm and status in ('MO','DANG_SX') group by sku),
  req as (select e.component_sku, e.unit, sum(e.req_qty) as req_qty, bool_or(e.is_packaging) as is_packaging, string_agg(distinct d.src, ',') as sources from demand d, lateral mrp_explode(p_farm, d.sku, d.qty) e group by e.component_sku, e.unit),
  st as (select sku, sum(available) as available from v_stock_available where farm_id=p_farm group by sku)
  select r.component_sku, p.name, r.unit, round(r.req_qty,2), round(coalesce(st.available,0),2), round(greatest(r.req_qty - coalesce(st.available,0), 0),2), r.is_packaging, r.sources
  from req r join products p on p.sku=r.component_sku left join st on st.sku=r.component_sku order by greatest(r.req_qty - coalesce(st.available,0), 0) desc $$;
grant execute on function mrp_run(text,int) to app_user;
-- 3) Bao bì 3 cấp
create table if not exists packaging_specs(
  id text primary key, org_id text default 'ITRAN', sku text not null references products, level text not null check (level in ('SO_CAP','THU_CAP','VAN_CHUYEN')), -- bao bì tiếp xúc | thùng | pallet
  material text, packaging_sku text references products, dims_mm text, net_weight_g numeric, gross_weight_g numeric, units_per_pack int, packs_per_case int, cases_per_pallet int, pallet_pattern text,
  gtin text, sscc_prefix text, food_contact_cert text, recyclable bool, recycle_code text, supplier_id text references partners, moq int, unit_cost numeric, shelf_life_days int, storage_temp text, note text,
  status text default 'ACTIVE', created_at timestamptz default now(), created_by text default app_staff(), attrs jsonb default '{}'::jsonb);
grant select, insert, update on packaging_specs to app_user;
-- 4) Danh mục chất gây dị ứng (EU 1169/2011 Phụ lục II — 14 nhóm; Codex STAN 1-1985 §4.2.1.4; VN Nghị định 43/2017 ghi nhãn — không bịa, có nguồn)
create table if not exists allergens(code text primary key, name_vi text, name_en text, source text default 'EU 1169/2011 Annex II');
insert into allergens(code, name_vi, name_en) values
 ('GLUTEN','Ngũ cốc chứa gluten (lúa mì, lúa mạch đen, đại mạch, yến mạch)','Cereals containing gluten'),('CRUSTACEAN','Giáp xác (tôm, cua)','Crustaceans'),('EGG','Trứng','Eggs'),('FISH','Cá','Fish'),
 ('PEANUT','Lạc/đậu phộng','Peanuts'),('SOY','Đậu nành','Soybeans'),('MILK','Sữa (kể cả lactose)','Milk'),('NUTS','Hạt cây (hạnh nhân, điều, óc chó…)','Tree nuts'),('CELERY','Cần tây','Celery'),
 ('MUSTARD','Mù tạt','Mustard'),('SESAME','Vừng/mè','Sesame'),('SULPHITE','Sulphit/SO2 >10 mg/kg','Sulphur dioxide & sulphites'),('LUPIN','Lupin','Lupin'),('MOLLUSC','Nhuyễn thể (ốc, sò, mực)','Molluscs')
on conflict do nothing; grant select on allergens to app_user;
-- 5) Nhãn sản phẩm (nội dung bắt buộc theo NĐ 43/2017 + TT 29/2023 dinh dưỡng; xuất khẩu theo thị trường)
create table if not exists label_specs(
  id text primary key, org_id text default 'ITRAN', sku text not null references products, version int default 1, market text default 'VN', lang text default 'vi',
  product_name text, ingredients text, allergens text[] default '{}', may_contain text[] default '{}', net_content text, nutrition jsonb default '{}'::jsonb, -- {energy_kcal, protein_g, fat_g, sat_fat_g, carb_g, sugar_g, fiber_g, sodium_mg, per:"100g"}
  storage text, usage_instr text, origin text default 'Việt Nam', producer text, address text, hotline text, claims text[] default '{}', std_marks text[] default '{}', -- VIETGAP|HACCP|HALAL|ORGANIC|ISO22000|ICFS
  halal bool default false, organic bool default false, gtin text, qr_base text, template text default 'A6', warnings text, date_format text default 'NSX dd/mm/yyyy · HSD dd/mm/yyyy', shelf_life_days int,
  status text default 'NHAP' check (status in ('NHAP','DUYET','NGUNG')), approved_by text, approved_at timestamptz, created_at timestamptz default now(), created_by text default app_staff(), attrs jsonb default '{}'::jsonb, unique(sku, market, version));
grant select, insert, update on label_specs to app_user;
-- audit
do $$ declare t text; begin
  foreach t in array array['bom_headers','bom_lines','production_plans','packaging_specs','label_specs'] loop
    execute format('drop trigger if exists %s_audit on %I', t, t);
    execute format('create trigger %s_audit after insert or update or delete on %I for each row execute function itran_audit()', t, t);
  end loop; end $$;
-- 6) view nhãn hoàn chỉnh cho 1 lô: gộp label_spec + lots + farm
create or replace view v_lot_label as
select l.id as lot_id, l.farm_id, l.sku, p.name as sku_name, l.lot_no, l.mfg_date, l.expiry_date, ls.product_name, ls.ingredients, ls.allergens, ls.may_contain, ls.net_content, ls.nutrition, ls.storage, ls.usage_instr, ls.origin,
  coalesce(ls.producer, f.legal_entity, 'ITRAN FARM') as producer, coalesce(ls.address, f.address) as address, ls.hotline, ls.claims, ls.std_marks, ls.halal, ls.organic, coalesce(ls.gtin, p.gtin) as gtin, ls.template, ls.warnings, ls.market, ls.lang
from lots l join products p on p.sku=l.sku join farms f on f.id=l.farm_id
left join lateral (select * from label_specs x where x.sku=l.sku and x.status='DUYET' order by (x.market='VN') desc, x.version desc limit 1) ls on true;
grant select on v_lot_label to app_user;
-- 7) Sự kiện: kế hoạch SX ban hành → thông báo D5/CB/CCU
insert into event_topics(topic, description, producer_dept, consumer_depts, source_table, wired) values
 ('production.planned','Kế hoạch sản xuất tuần ban hành','KDM','{D5,CCU,SH,QA}','production_plans',true),
 ('label.approved','Nhãn sản phẩm phê duyệt','QA','{KDM,D5}','label_specs',true)
on conflict (topic) do nothing;
create or replace function itran_pub_plan() returns trigger language plpgsql as $$
begin if new.status='DANG_SX' and (tg_op='INSERT' or old.status is distinct from new.status) then perform publish_event(new.farm_id, 'production.planned', jsonb_build_object('id', new.id, 'sku', new.sku, 'qty', new.qty_plan, 'week_start', new.week_start, 'line', new.line)); end if; return new; end $$;
drop trigger if exists pub_plan on production_plans; create trigger pub_plan after insert or update on production_plans for each row execute function itran_pub_plan();
-- 8) sự kiện đóng gói: batch_logs line DONG_GOI đã có; thêm cột lot_id vào batch_logs? (dùng outputs jsonb [{sku, qty, lot_id}]) — giữ nguyên, view gom mẻ đóng gói theo lô
create or replace view v_pack_batches as
select b.farm_id, b.ts, b.batch_code, b.line, o->>'sku' as sku, (o->>'qty')::numeric as qty, o->>'lot_id' as lot_id, b.qc, b.ccp_readings, b.created_by
from batch_logs b, jsonb_array_elements(case when jsonb_typeof(b.outputs)='array' then b.outputs else '[]'::jsonb end) o where b.status='ACTIVE' and b.line in ('DONG_GOI','SO_CHE','SAY');
grant select on v_pack_batches to app_user;
