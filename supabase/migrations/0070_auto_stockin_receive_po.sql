-- 0070 · ĐẦU VÀO TỰ CHẢY VÀO KHO: (1) công nhân ghi Nhật ký lô CẮT/THU (crop_logs) hoặc Thu hoạch (harvests) → tự nhập kho K3/K5 đúng SKU (qua sku_crop_map / crops.products);
--        (2) người mua hàng: nhận hàng theo PO (receive_po) → nhập kho từng dòng, sinh lô (NCC, HSD), PO=NHAN, received_at (scorecard NCC, AP aging); (3) mua giống/thiết bị/công cụ đều là PO với products bất kỳ
-- 1) map cây → SKU nhập kho
create or replace function crop_to_sku(p_crop text) returns text language sql stable as $$
  select coalesce((select m.sku from sku_crop_map m where m.crop_code=p_crop or p_crop=any(m.alt_crops) order by (m.crop_code=p_crop) desc limit 1), (select c.products[1] from crops c where c.code=p_crop)) $$;
create or replace function trg_croplog_stockin() returns trigger language plpgsql as $$
declare v_sku text; v_wh text; v_lot text; v_crop text; begin
  if new.activity not in ('CAT','THU') or coalesce(new.qty_kg,0)<=0 or new.status<>'ACTIVE' then return new; end if;
  select coalesce(p.crop_code, (select cs.crop_code from crop_seasons cs where cs.plot_id=p.id and cs.status in ('DANG_TRONG','THU_HOACH') order by sow_date desc limit 1)) into v_crop from plots p where p.id=new.plot_id;
  v_sku := crop_to_sku(v_crop); if v_sku is null then return new; end if;
  select id into v_wh from warehouses where farm_id=new.farm_id and code=case when (select kind from products where sku=v_sku) in ('THANH_PHAM') then 'K5' else 'K3' end limit 1; if v_wh is null then return new; end if;
  v_lot := ensure_lot(new.farm_id, v_sku, to_char(new.ts,'YYMM')||'-'||coalesce(new.plot_id,'X'), null, (new.ts::date + coalesce((select shelf_life_days from products where sku=v_sku), 30))::date);
  insert into inventory_moves(farm_id, ts, created_by, source, client_ref, warehouse_id, sku, lot_id, direction, qty, unit, reason, from_to, weigh_point, ref_type, ref_id)
  values (new.farm_id, new.ts, new.created_by, 'APP', 'croplog-'||new.id, v_wh, v_sku, v_lot, 1, new.qty_kg, 'kg', 'NHAP_SX', new.plot_id, coalesce(new.water_source, 'CAN_CAU_D'), 'crop_logs', new.id::text) on conflict do nothing;
  return new; end $$;
drop trigger if exists croplog_stockin on crop_logs; create trigger croplog_stockin after insert on crop_logs for each row execute function trg_croplog_stockin();
create or replace function trg_harvest_stockin() returns trigger language plpgsql as $$
declare v_sku text; v_wh text; v_lot text; begin
  if coalesce(new.qty_kg,0)<=0 or new.status<>'ACTIVE' then return new; end if;
  v_sku := coalesce(crop_to_sku((select cs.crop_code from crop_seasons cs where cs.id=new.season_id)), crop_to_sku(new.crop)); if v_sku is null then return new; end if;
  v_wh := coalesce(new.dest_warehouse_id, (select id from warehouses where farm_id=new.farm_id and code=case when (select kind from products where sku=v_sku)='THANH_PHAM' then 'K5' else 'K3' end limit 1)); if v_wh is null then return new; end if;
  v_lot := ensure_lot(new.farm_id, v_sku, coalesce(new.harvest_lot, to_char(new.ts,'YYMMDD')||'-'||coalesce(new.plot_id,'X')), null, (new.ts::date + coalesce((select shelf_life_days from products where sku=v_sku), 30))::date);
  insert into inventory_moves(farm_id, ts, created_by, source, client_ref, warehouse_id, sku, lot_id, direction, qty, unit, reason, from_to, weigh_point, ref_type, ref_id)
  values (new.farm_id, new.ts, new.created_by, 'APP', 'harvest-'||new.id, v_wh, v_sku, v_lot, 1, new.qty_kg, coalesce(new.unit,'kg'), 'NHAP_SX', new.plot_id, 'CAN_CAU_D', 'harvests', new.id::text) on conflict do nothing;
  return new; end $$;
drop trigger if exists harvest_stockin on harvests; create trigger harvest_stockin after insert on harvests for each row execute function trg_harvest_stockin();
-- 2) nhận hàng theo PO → nhập kho từng dòng
create or replace function receive_po(p_po text, p_wh text default null, p_lines jsonb default null) returns int language plpgsql as $$
declare po record; l jsonb; v_sku text; v_qty numeric; v_price numeric; v_wh text; v_lot text; n int := 0; v_kind text; v_lotno text; v_exp date; begin
  select * into po from purchase_orders where id=p_po; if not found then raise exception 'ERR_NOT_FOUND'; end if;
  if po.po_status not in ('DUYET','NHAN') then raise exception 'ERR_PO_NOT_APPROVED'; end if;
  for l in select * from jsonb_array_elements(coalesce(p_lines, po.lines)) loop
    v_sku := l->>'sku'; v_qty := coalesce((l->>'received_qty')::numeric, (l->>'qty')::numeric); v_price := (l->>'price')::numeric; if v_qty is null or v_qty<=0 then continue; end if;
    select kind into v_kind from products where sku=v_sku;
    v_wh := coalesce(l->>'warehouse_id', p_wh, (select id from warehouses w where w.farm_id=po.farm_id and w.code = case when v_kind='CONG_CU' then 'KCC-CB' when v_kind in ('THUOC','VACCINE','GIONG','VAT_TU','PHAN_BON') then 'K1' when v_kind='NHIEN_LIEU' then 'K7' when v_kind='BAO_BI' then 'K9' when v_kind='THANH_PHAM' then 'K5' else 'K2' end limit 1));
    if v_wh is null then select id into v_wh from warehouses where farm_id=po.farm_id and code='K2'; end if;
    v_lotno := coalesce(l->>'lot_no', 'PO-'||right(p_po,5)||'-'||to_char(now(),'YYMMDD')); v_exp := coalesce((l->>'expiry')::date, (current_date + coalesce((select shelf_life_days from products where sku=v_sku), 365))::date);
    v_lot := ensure_lot(po.farm_id, v_sku, v_lotno, po.supplier_id, v_exp);
    if l->>'coa_url' is not null then update lots set coa_url=l->>'coa_url' where id=v_lot; end if;
    insert into inventory_moves(farm_id, ts, created_by, source, client_ref, warehouse_id, sku, lot_id, direction, qty, unit, unit_cost, reason, from_to, weigh_point, ref_type, ref_id)
    values (po.farm_id, now(), app_staff(), 'APP', 'po-'||p_po||'-'||v_sku||'-'||to_char(now(),'YYMMDDHH24MISS'), v_wh, v_sku, v_lot, 1, v_qty, coalesce((select unit from products where sku=v_sku),'kg'), v_price, 'NHAP_MUA', po.supplier_id, 'CUA_KHO', 'purchase_orders', p_po);
    n := n+1;
  end loop;
  update purchase_orders set po_status='NHAN', received_at=now() where id=p_po;
  perform publish_event(po.farm_id, 'po.received', jsonb_build_object('po_id', p_po, 'supplier_id', po.supplier_id, 'lines', n));
  return n; end $$;
grant execute on function receive_po(text,text,jsonb) to app_user;
insert into event_topics(topic, description, producer_dept, consumer_depts, source_table, wired) values ('po.received','Nhận hàng PO → nhập kho, COA, công nợ NCC','CCU','{TCKT,QA,D5}','purchase_orders',true) on conflict (topic) do nothing;
alter table purchase_orders add column if not exists kind text default 'VAT_TU'; -- VAT_TU|GIONG|THIET_BI|CONG_CU|DICH_VU|TAI_SAN
alter table purchase_orders add column if not exists requested_by_dept text;
