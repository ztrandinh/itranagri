-- 0035 · ĐƠN → GIỮ HÀNG (reservation FEFO) → PHIẾU SOẠN (picking) → XUẤT KHO → GIAO; TRẢ HÀNG / CREDIT NOTE; LỆNH SẢN XUẤT tự sinh khi thiếu tồn; GIÁ THÀNH TỪNG MẺ
-- ===== 1. Giữ hàng theo lô (FEFO) =====
create table if not exists stock_reservations(id uuid primary key default gen_random_uuid(), farm_id text not null, order_id text not null, sku text not null, lot_id text, warehouse_id text, qty numeric not null, status text default 'GIU', -- GIU|DA_XUAT|HUY
  created_at timestamptz default now(), created_by text, released_at timestamptz);
create index if not exists resv_order on stock_reservations(order_id); create index if not exists resv_lot on stock_reservations(farm_id, sku, lot_id) where status='GIU';
alter table stock_reservations enable row level security; drop policy if exists p_all on stock_reservations; create policy p_all on stock_reservations for all using (can_see_farm(farm_id)) with check (true); grant select, insert, update on stock_reservations to app_user;
-- tồn khả dụng = tồn − đã giữ
create or replace view v_stock_available as
select b.*, coalesce((select sum(qty) from stock_reservations r where r.farm_id=b.farm_id and r.sku=b.sku and r.lot_id=b.lot_id and r.status='GIU'),0) as reserved, b.qty - coalesce((select sum(qty) from stock_reservations r where r.farm_id=b.farm_id and r.sku=b.sku and r.lot_id=b.lot_id and r.status='GIU'),0) as available
from v_stock_balance b;
grant select on v_stock_available to app_user;
-- Giữ hàng FEFO cho 1 đơn: trả về thiếu bao nhiêu mỗi SKU
create or replace function reserve_order(p_order text, p_by text) returns jsonb language plpgsql as $$
declare o record; l jsonb; need numeric; r record; short jsonb := '[]'::jsonb; taken numeric; begin
  select * into o from orders where id=p_order; if o is null then raise exception 'ERR_NOT_FOUND'; end if;
  update stock_reservations set status='HUY', released_at=now() where order_id=p_order and status='GIU';
  for l in select * from jsonb_array_elements(o.lines) loop
    need := (l->>'qty')::numeric;
    for r in select * from v_stock_available where farm_id=o.farm_id and sku=l->>'sku' and available>0 and coalesce(lot_status,'KHA_DUNG')='KHA_DUNG' and (expiry_date is null or expiry_date>current_date) order by expiry_date nulls last, last_move_at loop
      exit when need <= 0; taken := least(need, r.available);
      insert into stock_reservations(farm_id,order_id,sku,lot_id,warehouse_id,qty,created_by) values (o.farm_id,p_order,l->>'sku',r.lot_id,r.warehouse_id,taken,p_by); need := need - taken;
    end loop;
    if need > 0 then short := short || jsonb_build_object('sku', l->>'sku', 'short', need); end if;
  end loop;
  return jsonb_build_object('order', p_order, 'short', short); end $$;
-- Phiếu soạn hàng (picking list) = reservation đang GIU của đơn, sắp theo kho/vị trí
create or replace view v_picking as
select r.farm_id, r.order_id, o.partner_id, pt.name as partner_name, o.deliver_date, r.sku, p.name as product_name, r.lot_id, r.warehouse_id, w.code as warehouse_code, r.qty, l.expiry_date, r.status
from stock_reservations r join orders o on o.id=r.order_id left join partners pt on pt.id=o.partner_id left join products p on p.sku=r.sku left join warehouses w on w.id=r.warehouse_id left join lots l on l.id=r.lot_id where r.status='GIU' order by r.order_id, w.code, l.expiry_date;
grant select on v_picking to app_user;
-- Xuất kho theo phiếu soạn: tạo inventory_moves XUAT_BAN từng lô + đánh dấu reservation DA_XUAT + đơn → GIAO
create or replace function ship_order(p_order text, p_by text) returns int language plpgsql as $$
declare r record; n int := 0; begin
  for r in select * from stock_reservations where order_id=p_order and status='GIU' loop
    insert into inventory_moves(farm_id,created_by,source,warehouse_id,sku,lot_id,direction,qty,reason,ref_type,ref_id,client_ref) values (r.farm_id,p_by,'APP',r.warehouse_id,r.sku,r.lot_id,-1,r.qty,'XUAT_BAN','orders',p_order,'ship-'||r.id::text);
    update stock_reservations set status='DA_XUAT', released_at=now() where id=r.id; n := n + 1;
  end loop;
  update orders set status='GIAO' where id=p_order; return n; end $$;
grant execute on function reserve_order(text,text), ship_order(text,text) to app_user;
-- ===== 2. Trả hàng / credit note =====
create table if not exists sales_returns(id text primary key, farm_id text not null, sale_id uuid, order_id text, partner_id text, ts timestamptz default now(), sku text, lot_id text, qty numeric, unit_price numeric, amount numeric, reason text, -- HU_HONG|SAI_HANG|HET_HAN|KHACH_DOI_Y|KHAC
  disposition text default 'NHAP_LAI', -- NHAP_LAI|HUY|CHE_BIEN_LAI
  restocked bool default false, credit_note_no text, refund_method text, refunded_at timestamptz, status text default 'MOI', -- MOI|DUYET|HOAN_TAT|TU_CHOI
  approved_by text, created_by text, note text);
alter table sales_returns enable row level security; drop policy if exists p_all on sales_returns; create policy p_all on sales_returns for all using (can_see_farm(farm_id)) with check (true); grant select, insert, update on sales_returns to app_user;
drop trigger if exists audit_sales_returns on sales_returns; create trigger audit_sales_returns after insert or update or delete on sales_returns for each row execute function itran_audit();
-- Duyệt trả hàng: nhập lại kho (nếu NHAP_LAI) + GL đảo doanh thu (Nợ 511 / Có 131|111) + credit note
create or replace function approve_return(p_id text, p_by text) returns void language plpgsql as $$
declare r record; wh text; begin
  select * into r from sales_returns where id=p_id; if r is null then raise exception 'ERR_NOT_FOUND'; end if; if r.created_by = p_by then raise exception 'ERR_SELF_APPROVE'; end if;
  if r.disposition='NHAP_LAI' and not r.restocked and r.sku is not null then select id into wh from warehouses where farm_id=r.farm_id and code in ('K5','K6') order by code limit 1;
    insert into inventory_moves(farm_id,created_by,source,warehouse_id,sku,lot_id,direction,qty,reason,ref_type,ref_id,client_ref) values (r.farm_id,p_by,'APP',wh,r.sku,r.lot_id,1,r.qty,'TRA_HANG','sales_returns',p_id,'ret-'||p_id); update sales_returns set restocked=true where id=p_id; end if;
  perform gl_post(r.farm_id,'sales_returns',p_id,'Trả hàng '||coalesce(r.sku,''), jsonb_build_array(jsonb_build_object('acct','511','debit',r.amount,'credit',0), jsonb_build_object('acct','131','debit',0,'credit',r.amount)), now(), p_by);
  update sales_returns set status='DUYET', approved_by=p_by, credit_note_no=coalesce(credit_note_no,'CN-'||to_char(now(),'YYMMDD')||'-'||substr(p_id, length(p_id)-3)) where id=p_id;
  perform publish_event(r.farm_id,'return.approved',jsonb_build_object('id',p_id,'sku',r.sku,'amount',r.amount,'partner',r.partner_id));
end $$;
grant execute on function approve_return(text,text) to app_user;
-- ===== 3. Lệnh sản xuất tự sinh khi đơn thiếu tồn =====
create table if not exists production_orders(id text primary key, farm_id text not null, order_id text, sku text not null, qty numeric not null, unit text, due_date date, recipe_id text, line text, status text default 'MOI', -- MOI|DANG_LAM|XONG|HUY
  batch_ids uuid[] default '{}', created_at timestamptz default now(), created_by text, note text);
alter table production_orders enable row level security; drop policy if exists p_all on production_orders; create policy p_all on production_orders for all using (can_see_farm(farm_id)) with check (true); grant select, insert, update on production_orders to app_user;
drop trigger if exists audit_production_orders on production_orders; create trigger audit_production_orders after insert or update or delete on production_orders for each row execute function itran_audit();
create or replace function gen_production_from_shortage(p_order text, p_by text) returns int language plpgsql as $$
declare sh jsonb; l jsonb; n int := 0; o record; pid text; begin
  select * into o from orders where id=p_order; sh := (reserve_order(p_order, p_by))->'short';
  for l in select * from jsonb_array_elements(sh) loop
    if exists (select 1 from production_orders where order_id=p_order and sku=l->>'sku' and status in ('MOI','DANG_LAM')) then continue; end if;
    pid := next_code_free(o.farm_id,'LSX','production_orders',5);
    insert into production_orders(id,farm_id,order_id,sku,qty,due_date,recipe_id,created_by,note) values (pid,o.farm_id,p_order,l->>'sku',(l->>'short')::numeric,coalesce(o.deliver_date, current_date+1),(select id from recipes where farm_id=o.farm_id and active and (attrs->>'output_sku'=l->>'sku') limit 1),p_by,'Tự sinh do thiếu tồn cho đơn '||p_order);
    insert into tasks(farm_id,kind,title,target_type,target_id,role_hint,priority,due_at,ref_table,ref_id,source) values (o.farm_id,'LENH_SX','Lệnh SX '||pid||': '||(l->>'sku')||' × '||(l->>'short')||' cho đơn '||p_order,'production_order',pid,'team_lead','CAO',coalesce(o.deliver_date, current_date+1)::timestamptz,'production_orders',pid,'AUTO');
    perform publish_event(o.farm_id,'production.ordered',jsonb_build_object('id',pid,'order',p_order,'sku',l->>'sku','qty',l->>'short')); n := n + 1;
  end loop; return n; end $$;
grant execute on function gen_production_from_shortage(text,text) to app_user;
-- ===== 4. Giá thành từng mẻ (batch costing): Σ đầu vào × giá bình quân lô + chi phí chung phân bổ theo kg =====
create or replace view v_batch_cost as
with b as (select id, farm_id, ts, batch_code, line, recipe_id, inputs, outputs, status from batch_logs where status='ACTIVE'),
inp as (select b.id, sum(coalesce((i->>'kg')::numeric,0)) as in_kg, sum(coalesce((i->>'kg')::numeric,0) * coalesce((select avg(avg_cost) from v_stock_balance sb where sb.farm_id=b.farm_id and sb.sku=i->>'sku'), (select avg(unit_cost) from inventory_moves m where m.farm_id=b.farm_id and m.sku=i->>'sku' and m.unit_cost>0), 0)) as mat_cost from b, jsonb_array_elements(coalesce(b.inputs,'[]'::jsonb)) i group by b.id),
outp as (select b.id, sum(coalesce((o->>'kg')::numeric,0)) as out_kg from b, jsonb_array_elements(coalesce(b.outputs,'[]'::jsonb)) o group by b.id),
oh as (select farm_id, date_trunc('month', month)::date as month, sum(amount) as fixed_amt from cc_fixed_costs where cost_center like '%CC-D5%' or cost_center like '%CC-CB%' group by 1,2),
vol as (select b.farm_id, date_trunc('month', b.ts)::date as month, sum(coalesce(o.out_kg,0)) as month_kg from b left join outp o on o.id=b.id group by 1,2)
select b.farm_id, b.ts, b.batch_code, b.line, b.recipe_id, coalesce(i.in_kg,0) as in_kg, coalesce(o.out_kg,0) as out_kg, round(coalesce(i.mat_cost,0),0) as mat_cost,
  round(coalesce(oh.fixed_amt,0) * coalesce(o.out_kg,0) / nullif(v.month_kg,0),0) as overhead_alloc,
  round((coalesce(i.mat_cost,0) + coalesce(oh.fixed_amt,0) * coalesce(o.out_kg,0) / nullif(v.month_kg,0)) / nullif(coalesce(o.out_kg,0),0),0) as cost_per_kg,
  round(100 - 100.0*coalesce(o.out_kg,0)/nullif(coalesce(i.in_kg,0),0),1) as loss_pct
from b left join inp i on i.id=b.id left join outp o on o.id=b.id left join vol v on v.farm_id=b.farm_id and v.month=date_trunc('month', b.ts)::date left join oh on oh.farm_id=b.farm_id and oh.month=v.month;
grant select on v_batch_cost to app_user;
insert into event_topics(topic,producer_dept,consumer_depts,description,source_table,wired) values ('return.approved','KDM','{CCU,TCKT,QA}','Trả hàng duyệt → nhập lại kho/hủy, đảo doanh thu, credit note, QA truy nguyên nhân','sales_returns',true),('production.ordered','KDM','{D5,CCU,GDT}','Lệnh SX tự sinh do đơn thiếu tồn → D5 làm, Kho chuẩn bị nguyên liệu','production_orders',true) on conflict (topic) do update set description=excluded.description, wired=true;
