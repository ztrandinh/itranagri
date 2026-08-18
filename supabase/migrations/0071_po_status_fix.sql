-- 0071 · trạng thái PO thật: CHO_DUYET|DUYET|TU_CHOI|DA_NHAN|HUY (+ NHAN_MOT_PHAN) — sửa receive_po, các view AP/scorecard/MRP dùng đúng mã
alter table purchase_orders drop constraint if exists purchase_orders_po_status_check;
alter table purchase_orders add constraint purchase_orders_po_status_check check (po_status in ('CHO_DUYET','DUYET','TU_CHOI','NHAN_MOT_PHAN','DA_NHAN','HUY'));
create or replace function receive_po(p_po text, p_wh text default null, p_lines jsonb default null) returns int language plpgsql as $$
declare po record; l jsonb; v_sku text; v_qty numeric; v_price numeric; v_wh text; v_lot text; n int := 0; v_kind text; v_lotno text; v_exp date; v_partial bool := false; begin
  select * into po from purchase_orders where id=p_po; if not found then raise exception 'ERR_NOT_FOUND'; end if;
  if po.po_status not in ('DUYET','NHAN_MOT_PHAN') then raise exception 'ERR_PO_NOT_APPROVED'; end if;
  for l in select * from jsonb_array_elements(coalesce(p_lines, po.lines)) loop
    v_sku := l->>'sku'; v_qty := coalesce((l->>'received_qty')::numeric, (l->>'qty')::numeric); v_price := (l->>'price')::numeric; if v_qty is null or v_qty<=0 then continue; end if;
    if (l->>'received_qty') is not null and (l->>'received_qty')::numeric < (l->>'qty')::numeric then v_partial := true; end if;
    select kind into v_kind from products where sku=v_sku;
    v_wh := coalesce(l->>'warehouse_id', p_wh, (select id from warehouses w where w.farm_id=po.farm_id and w.code = case when v_kind='CONG_CU' then 'KCC-CB' when v_kind in ('THUOC','VACCINE','GIONG','VAT_TU','PHAN_BON') then 'K1' when v_kind='NHIEN_LIEU' then 'K7' when v_kind='BAO_BI' then 'K9' when v_kind='THANH_PHAM' then 'K5' else 'K2' end limit 1));
    if v_wh is null then select id into v_wh from warehouses where farm_id=po.farm_id and code='K2'; end if;
    v_lotno := coalesce(l->>'lot_no', 'PO-'||right(p_po,5)||'-'||to_char(now(),'YYMMDD')); v_exp := coalesce((l->>'expiry')::date, (current_date + coalesce((select shelf_life_days from products where sku=v_sku), 365))::date);
    v_lot := ensure_lot(po.farm_id, v_sku, v_lotno, po.supplier_id, v_exp);
    if l->>'coa_url' is not null then update lots set coa_url=l->>'coa_url' where id=v_lot; end if;
    insert into inventory_moves(farm_id, ts, created_by, source, client_ref, warehouse_id, sku, lot_id, direction, qty, unit, unit_cost, reason, from_to, weigh_point, ref_type, ref_id)
    values (po.farm_id, now(), app_staff(), 'APP', 'po-'||p_po||'-'||v_sku||'-'||to_char(clock_timestamp(),'YYMMDDHH24MISSMS'), v_wh, v_sku, v_lot, 1, v_qty, coalesce((select unit from products where sku=v_sku),'kg'), v_price, 'NHAP_MUA', po.supplier_id, 'CUA_KHO', 'purchase_orders', p_po);
    n := n+1;
  end loop;
  update purchase_orders set po_status=case when v_partial then 'NHAN_MOT_PHAN' else 'DA_NHAN' end, received_at=coalesce(received_at, now()) where id=p_po;
  perform publish_event(po.farm_id, 'po.received', jsonb_build_object('po_id', p_po, 'supplier_id', po.supplier_id, 'lines', n));
  return n; end $$;
-- các view dùng trạng thái đúng
create or replace view v_ap_aging as
select p.farm_id, p.supplier_id as partner_id, pt.name as partner_name, 'PO' as kind, p.id as ref_id, p.ts::date as doc_date, p.invoice_no, p.total as amount, coalesce(p.paid_amount,0) as paid, p.total - coalesce(p.paid_amount,0) as unpaid,
  coalesce(p.payment_due, (coalesce(p.received_at, p.ts)::date + coalesce(pt.supplier_terms_days, 15))) as due_date,
  greatest(current_date - coalesce(p.payment_due, (coalesce(p.received_at, p.ts)::date + coalesce(pt.supplier_terms_days, 15))), 0) as days_overdue
from purchase_orders p left join partners pt on pt.id=p.supplier_id where p.po_status in ('DUYET','NHAN_MOT_PHAN','DA_NHAN') and p.paid_at is null and p.total - coalesce(p.paid_amount,0) > 0
union all
select e.farm_id, null, e.cost_center, 'CHI', e.id::text, e.ts::date, null, e.amount, 0, e.amount, e.ts::date + 7, greatest(current_date - (e.ts::date + 7), 0)
from expense_requests e where e.status='DUYET' and e.paid_at is null;
create or replace view v_supplier_scorecard as
with po as (select p.farm_id, p.supplier_id, count(*) as n_po, sum(p.total) as spend,
   avg(case when p.received_at is not null and p.expected_at is not null then (p.received_at::date <= p.expected_at)::int end) as on_time_rate,
   avg(case when p.po_status in ('DA_NHAN') then 1 when p.po_status='NHAN_MOT_PHAN' then 0.5 else 0 end) as fulfilled_rate
   from purchase_orders p where p.ts > now()-interval '365 days' and p.po_status<>'HUY' group by p.farm_id, p.supplier_id),
lots as (select l.farm_id, l.supplier_id, count(*) as n_lots, avg((l.coa_url is not null)::int) as coa_rate, avg((l.status not in ('HUY','TU_CHOI','CACH_LY'))::int) as qc_pass_rate from lots l where l.created_at > now()-interval '365 days' group by l.farm_id, l.supplier_id)
select pt.id as supplier_id, pt.name, pt.approved, pt.review_due, coalesce(po.farm_id, lots.farm_id) as farm_id, po.n_po, po.spend, round(po.on_time_rate*100,0) as on_time_pct, round(po.fulfilled_rate*100,0) as fulfilled_pct, lots.n_lots, round(lots.coa_rate*100,0) as coa_pct, round(lots.qc_pass_rate*100,0) as qc_pass_pct,
  round((coalesce(po.on_time_rate,0.5)*30 + coalesce(po.fulfilled_rate,0.5)*20 + coalesce(lots.coa_rate,0.5)*25 + coalesce(lots.qc_pass_rate,0.5)*25),0) as score
from partners pt left join po on po.supplier_id=pt.id left join lots on lots.supplier_id=pt.id and (po.farm_id is null or lots.farm_id=po.farm_id)
where pt.kind = 'NCC' or po.supplier_id is not null or lots.supplier_id is not null;
