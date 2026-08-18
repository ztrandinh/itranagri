-- 0014 · P&L phân hệ · cổng khách · sao kê ngân hàng (RC10) · KPI→lương lớp 2 · sơ đồ khu · export log
-- ===== P&L PHÂN HỆ =====
alter table products add column if not exists cost_center text; -- CC hưởng doanh thu/chi phí (không tiền tố trại)
update products set cost_center = case
  when sku like 'SKU-TRUNG%' then 'CC-GA' when sku like 'SKU-PTR%' then 'CC-TRUN' when sku in ('SKU-TMR-25','TA-TMR-VO','TA-VIEN-GA') then 'CC-D5' when sku='SKU-NAM-1' then 'CC-CB'
  when sku='SKU-BO-HOI' then 'CC-BO' when sku in ('NL-BAP-U','NL-CO-TUOI') then 'CC-TT' when sku='NL-DAU' then 'CC-TT' when kind in ('THUOC','VACCINE','GIONG') then 'CC-BO' else null end where cost_center is null;
alter table animal_groups add column if not exists cost_center text;
update animal_groups set cost_center = case kind when 'BO_NHOM' then 'CC-BO' when 'GA_DE' then 'CC-GA' when 'GA_THIT' then 'CC-GA' when 'RAS' then 'CC-RAS' when 'AO' then 'CC-RAS' when 'DE' then 'CC-BO' else 'CC-BO' end where cost_center is null;
create table if not exists cc_fixed_costs(
  id uuid primary key default gen_random_uuid(), farm_id text not null references farms, month date not null, cost_center text not null, kind text not null check (kind in ('LUONG','KHAU_HAO','DIEN_NUOC','THUE_NGOAI','KHAC')),
  amount numeric not null, note text, created_by text, created_at timestamptz default now(), unique(farm_id, month, cost_center, kind));
alter table cc_fixed_costs enable row level security;
drop policy if exists p_sel on cc_fixed_costs; create policy p_sel on cc_fixed_costs for select using (can_see_farm(farm_id));
drop policy if exists p_w on cc_fixed_costs; create policy p_w on cc_fixed_costs for all using (farm_id=app_farm() and app_role() in ('accountant','director','owner')) with check (farm_id=app_farm());
grant select, insert, update on cc_fixed_costs to app_user;
-- CC nhận chi phí của 1 move xuất: theo đàn nhận (from_to = group) → CC đàn; theo lý do
create or replace function cc_of_move(p_farm text, p_reason text, p_from_to text, p_sku text) returns text language sql stable as $$
  select coalesce(
    (select cost_center from animal_groups g where g.farm_id=p_farm and g.id=p_from_to),
    case when p_reason='XUAT_SX' and p_from_to in ('D5','KHU-D') then 'CC-D5' when p_reason='XUAT_SX' and p_from_to like 'F01-TB-%' then 'CC-TT' end,
    (select cost_center from products p where p.sku=p_sku), 'CC-HC') $$;
create or replace view v_pl_cc_month as
with rev as (
  select s.farm_id, date_trunc('month', s.ts)::date as month, coalesce(p.cost_center,'CC-KD') as cc, sum(s.amount) as revenue
  from sales s join products p on p.sku=s.sku where s.status='ACTIVE' group by 1,2,3),
mat as (
  select m.farm_id, date_trunc('month', m.ts)::date as month, cc_of_move(m.farm_id, m.reason, m.from_to, m.sku) as cc,
    sum(m.qty*coalesce(m.unit_cost, (select avg_cost from lots l where l.id=m.lot_id), (select avg(unit_cost) from inventory_moves x where x.sku=m.sku and x.direction=1 and x.unit_cost is not null), 0)) as material_cost
  from inventory_moves m where m.status='ACTIVE' and m.direction=-1 and m.reason in ('XUAT_CHO_AN','XUAT_SX','HUY') group by 1,2,3),
internal as ( -- giá chuyển nội bộ 70%: sản phẩm D5/TT tiêu thụ nội bộ ghi doanh thu cho CC sản xuất, chi phí cho CC nhận
  select m.farm_id, date_trunc('month', m.ts)::date as month, p.cost_center as producer_cc, cc_of_move(m.farm_id, m.reason, m.from_to, m.sku) as consumer_cc,
    sum(m.qty*0.7*coalesce((select price from price_list pl where pl.kind='SAN' and pl.subject=m.sku limit 1), m.unit_cost, 0)) as amt
  from inventory_moves m join products p on p.sku=m.sku where m.status='ACTIVE' and m.direction=-1 and m.reason='XUAT_CHO_AN' and p.cost_center in ('CC-D5','CC-TT') group by 1,2,3,4),
fixed as (select farm_id, month, cost_center as cc, sum(amount) as fixed_cost from cc_fixed_costs group by 1,2,3),
ccs as (select distinct farm_id, month, cc from (select farm_id, month, cc from rev union select farm_id, month, cc from mat union select farm_id, month, producer_cc from internal union select farm_id, month, consumer_cc from internal union select farm_id, month, cc from fixed) u where cc is not null)
select c.farm_id, c.month, c.cc,
  coalesce(r.revenue,0) as revenue_external,
  coalesce((select sum(amt) from internal i where i.farm_id=c.farm_id and i.month=c.month and i.producer_cc=c.cc),0) as revenue_internal,
  coalesce(m.material_cost,0) as material_cost,
  coalesce((select sum(amt) from internal i where i.farm_id=c.farm_id and i.month=c.month and i.consumer_cc=c.cc),0) as internal_cost,
  coalesce(f.fixed_cost,0) as fixed_cost,
  coalesce(r.revenue,0) + coalesce((select sum(amt) from internal i where i.farm_id=c.farm_id and i.month=c.month and i.producer_cc=c.cc),0)
   - coalesce(m.material_cost,0) - coalesce((select sum(amt) from internal i where i.farm_id=c.farm_id and i.month=c.month and i.consumer_cc=c.cc),0) - coalesce(f.fixed_cost,0) as ebitda
from ccs c left join rev r on r.farm_id=c.farm_id and r.month=c.month and r.cc=c.cc left join mat m on m.farm_id=c.farm_id and m.month=c.month and m.cc=c.cc left join fixed f on f.farm_id=c.farm_id and f.month=c.month and f.cc=c.cc;
-- ===== SAO KÊ NGÂN HÀNG (RC10) =====
create table if not exists bank_statement_lines(
  id uuid primary key default gen_random_uuid(), farm_id text not null references farms, bank text, account text, txn_date date not null, amount numeric not null, direction text check (direction in ('IN','OUT')), ref text, memo text, matched_sale_id uuid, imported_by text, imported_at timestamptz default now(), import_batch text);
create index if not exists bank_lines_ix on bank_statement_lines(farm_id, txn_date);
alter table bank_statement_lines enable row level security;
drop policy if exists p_sel on bank_statement_lines; create policy p_sel on bank_statement_lines for select using (can_see_farm(farm_id));
drop policy if exists p_w on bank_statement_lines; create policy p_w on bank_statement_lines for all using (farm_id=app_farm() and app_role() in ('accountant','director','owner','it_engineer')) with check (farm_id=app_farm());
grant select, insert, update on bank_statement_lines to app_user;
update rc_rules set name='Tiền vs hàng: SALE đã thu (CK/QR/POS) vs sao kê ngân hàng + két', side_b_sql=$b$select coalesce(sum(amount),0) from bank_statement_lines where farm_id=$1 and direction='IN' and txn_date=$2$b$,
  side_a_sql=$a$select coalesce(sum(amount),0) from sales where farm_id=$1 and status='ACTIVE' and paid and payment in ('CK','VIETQR','POS') and ts::date=$2$a$ where code='RC10';
-- ===== KPI → LƯƠNG LỚP 2 (theo nhân sự, tháng) =====
create table if not exists kpi_results(
  id uuid primary key default gen_random_uuid(), farm_id text not null references farms, staff_id text not null, month date not null, kpi_code text not null, value numeric, target numeric, score numeric, computed_at timestamptz default now(), unique(farm_id, staff_id, month, kpi_code));
alter table kpi_results enable row level security;
drop policy if exists p_sel on kpi_results; create policy p_sel on kpi_results for select using (can_see_farm(farm_id) and (app_role() not in ('worker') or staff_id=app_staff()));
drop policy if exists p_w on kpi_results; create policy p_w on kpi_results for all using (farm_id=app_farm() and app_role() in ('it_engineer','director','owner')) with check (farm_id=app_farm());
grant select, insert, update, delete on kpi_results to app_user;
create or replace function compute_staff_kpi(p_farm text, p_month date) returns int language plpgsql as $$
declare n int := 0; r record; begin
  delete from kpi_results where farm_id=p_farm and month=p_month;
  for r in select id from staff where (farm_id=p_farm) and active and role in ('worker','team_lead') loop
    -- KPI-GHI: số bản ghi/ngày làm việc (mục tiêu ≥ 8)
    insert into kpi_results(farm_id,staff_id,month,kpi_code,value,target,score)
    select p_farm, r.id, p_month, 'KPI-GHI', round(cnt::numeric/greatest(days,1),1), 8, least(100, round(100*cnt::numeric/greatest(days,1)/8)) from (
      select count(*) cnt, count(distinct ts::date) days from (select ts from animal_events where created_by=r.id and farm_id=p_farm and date_trunc('month',ts)=p_month union all select ts from feed_logs where created_by=r.id and farm_id=p_farm and date_trunc('month',ts)=p_month union all select ts from crop_logs where created_by=r.id and farm_id=p_farm and date_trunc('month',ts)=p_month union all select ts from batch_logs where created_by=r.id and farm_id=p_farm and date_trunc('month',ts)=p_month union all select ts from inventory_moves where created_by=r.id and farm_id=p_farm and date_trunc('month',ts)=p_month) u) x; n:=n+1;
    -- KPI-CHECKLIST: % checklist xanh (mục tiêu ≥ 90)
    insert into kpi_results(farm_id,staff_id,month,kpi_code,value,target,score)
    select p_farm, r.id, p_month, 'KPI-CHECKLIST', round(100.0*count(*) filter (where all_green)/nullif(count(*),0),1), 90, least(100, round(100.0*count(*) filter (where all_green)/nullif(count(*),0)/0.9)) from checklist_runs where created_by=r.id and farm_id=p_farm and date_trunc('month',ts)=p_month having count(*)>0;
    -- KPI-SAI-SO-ME (A1): sai số mẻ TB (mục tiêu ≤ 2)
    insert into kpi_results(farm_id,staff_id,month,kpi_code,value,target,score)
    select p_farm, r.id, p_month, 'KPI-SAI-SO-ME', round(avg(abs(qty_kg-planned_kg)/nullif(planned_kg,0))*100,2), 2, least(100, greatest(0, round(100 - (avg(abs(qty_kg-planned_kg)/nullif(planned_kg,0))*100 - 2)*20))) from feed_logs where created_by=r.id and farm_id=p_farm and planned_kg>0 and date_trunc('month',ts)=p_month having count(*)>0;
    -- KPI-VIEC: việc hoàn thành đúng hạn %
    insert into kpi_results(farm_id,staff_id,month,kpi_code,value,target,score)
    select p_farm, r.id, p_month, 'KPI-VIEC', round(100.0*count(*) filter (where done_at<=due_at)/nullif(count(*),0),1), 90, least(100, round(100.0*count(*) filter (where done_at<=due_at)/nullif(count(*),0)/0.9)) from tasks where done_by=r.id and farm_id=p_farm and date_trunc('month',done_at)=p_month having count(*)>0;
    -- KPI-BU: % nhập bù (mục tiêu ≤ 5)
    insert into kpi_results(farm_id,staff_id,month,kpi_code,value,target,score)
    select p_farm, r.id, p_month, 'KPI-BU', round(100.0*count(*) filter (where is_backfill)/nullif(count(*),0),1), 5, least(100, greatest(0, round(100 - (100.0*count(*) filter (where is_backfill)/nullif(count(*),0) - 5)*5))) from (select is_backfill from animal_events where created_by=r.id and farm_id=p_farm and date_trunc('month',ts)=p_month union all select is_backfill from feed_logs where created_by=r.id and farm_id=p_farm and date_trunc('month',ts)=p_month) u having count(*)>0;
  end loop; return n; end $$;
grant execute on function compute_staff_kpi(text,date) to app_user;
create or replace view v_staff_kpi_month as
select k.farm_id, k.month, k.staff_id, s.full_name, s.position, round(avg(k.score)) as score, jsonb_object_agg(k.kpi_code, jsonb_build_object('v',k.value,'t',k.target,'s',k.score)) as detail,
  case when avg(k.score)>=95 then 25 when avg(k.score)>=85 then 20 when avg(k.score)>=75 then 15 when avg(k.score)>=60 then 10 else 0 end as bonus_pct
from kpi_results k join staff s on s.id=k.staff_id group by 1,2,3,4,5;
-- ===== SƠ ĐỒ KHU: tọa độ lưới cho locations =====
alter table locations add column if not exists grid_x int, add column if not exists grid_y int, add column if not exists color text;
update locations set grid_x=x.gx, grid_y=x.gy from (select id, ((row_number() over (order by kind, id))-1) % 6 as gx, ((row_number() over (order by kind, id))-1) / 6 as gy from locations) x where locations.id=x.id and locations.grid_x is null;
-- ===== Cổng khách: token hợp đồng =====
alter table custody_contracts add column if not exists portal_token text unique default encode(gen_random_bytes(12),'hex');
create table if not exists customer_messages(id uuid primary key default gen_random_uuid(), farm_id text not null, contract_id text, animal_id text, from_customer bool default true, body text not null, ts timestamptz default now(), replied_by text, replied_at timestamptz);
alter table customer_messages enable row level security;
drop policy if exists p_sel on customer_messages; create policy p_sel on customer_messages for select using (can_see_farm(farm_id));
drop policy if exists p_w on customer_messages; create policy p_w on customer_messages for all using (farm_id=app_farm()) with check (farm_id=app_farm());
grant select, insert, update on customer_messages to app_user;
insert into settings(farm_id,key,value,updated_by) values ('GLOBAL','portal.live_hours','["08:00-09:00","16:00-17:00"]','NS-005'),('GLOBAL','portal.live_stream_url','""','NS-005') on conflict do nothing;
grant select on all tables in schema public to app_user;
