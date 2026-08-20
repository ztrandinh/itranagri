-- 0136 — Nối truy xuất chặng SẢN XUẤT D5 (batch_logs) ⇄ kho
--
-- Bối cảnh: y hệt mắt cho ăn — sản xuất D5/khu D (batch_logs) KHÔNG trừ/nhập kho ở đường LIVE.
-- Toàn bộ move XUAT_SX (nguyên liệu vào mẻ) và NHAP_SX (thành phẩm ra mẻ) hiện có đều
-- source='IMPORT' (seed sinh tay, ref_type=NULL). batch_logs ghi rõ inputs [{sku,kg}] và
-- outputs [{sku,kg}] nên đọc thẳng, không cần nổ công thức.
--
-- Sửa: trigger AFTER INSERT batch_logs:
--   inputs  → xuất kho (direction -1, reason XUAT_SX), FEFO, ref_type='batch_logs'
--   outputs → nhập kho (direction +1, reason NHAP_SX), tạo lô ensure_lot, ref_type='batch_logs'
-- Chỉ chạy bản ghi LIVE (source<>'IMPORT', không backfill) để seed chạy lại không nhân đôi.
-- Chỉ với SKU có thật trong products (tránh FK ma / lô rác).

create or replace function itran_batch_stockmove() returns trigger language plpgsql as $fn$
declare it record; v_wh text; v_lot text; v_kind text;
begin
  if new.status <> 'ACTIVE' or new.source = 'IMPORT' or coalesce(new.is_backfill,false) then
    return new;
  end if;

  -- ── INPUTS → xuất kho nguyên liệu (XUAT_SX) ────────────────────────────────
  if new.inputs is not null and jsonb_typeof(new.inputs) = 'array' then
    for it in
      select (e->>'sku') as sku, (e->>'kg')::numeric as kg
        from jsonb_array_elements(new.inputs) e
       where (e->>'sku') is not null and (e->>'kg') is not null
    loop
      if coalesce(it.kg,0) <= 0 or not exists(select 1 from products where sku = it.sku) then continue; end if;
      select s.warehouse_id, nullif(s.lot_id,'') into v_wh, v_lot
        from stock_at(new.farm_id, new.ts::date) s
        left join lots l on l.id = nullif(s.lot_id,'')
       where s.sku = it.sku and s.qty > 0
       order by l.expiry_date nulls last, s.qty desc limit 1;
      if v_wh is null then select id into v_wh from warehouses where farm_id = new.farm_id and code = 'K3' limit 1; end if;
      if v_wh is null then continue; end if;
      insert into inventory_moves(farm_id, ts, created_by, source, warehouse_id, sku, lot_id,
                                  direction, qty, unit, reason, ref_type, ref_id, client_ref)
      values (new.farm_id, new.ts, new.created_by, 'APP', v_wh, it.sku, v_lot,
              -1, it.kg, (select unit from products where sku = it.sku),
              'XUAT_SX', 'batch_logs', new.id::text, 'batchin-'||new.id::text||'-'||it.sku)
      on conflict (farm_id, client_ref) where client_ref is not null do nothing;
    end loop;
  end if;

  -- ── OUTPUTS → nhập kho thành phẩm (NHAP_SX) ────────────────────────────────
  if new.outputs is not null and jsonb_typeof(new.outputs) = 'array' then
    for it in
      select (e->>'sku') as sku, (e->>'kg')::numeric as kg
        from jsonb_array_elements(new.outputs) e
       where (e->>'sku') is not null and (e->>'kg') is not null
    loop
      if coalesce(it.kg,0) <= 0 or not exists(select 1 from products where sku = it.sku) then continue; end if;
      select kind into v_kind from products where sku = it.sku;
      select id into v_wh from warehouses
       where farm_id = new.farm_id and code = case when v_kind in ('THANH_PHAM','BAN_TP') then 'K5' else 'K3' end limit 1;
      if v_wh is null then select id into v_wh from warehouses where farm_id = new.farm_id and code = 'K3' limit 1; end if;
      if v_wh is null then continue; end if;
      v_lot := ensure_lot(new.farm_id, it.sku, coalesce(new.batch_code, new.id::text), null,
                          (new.ts::date + coalesce((select shelf_life_days from products where sku = it.sku), 30))::date);
      insert into inventory_moves(farm_id, ts, created_by, source, warehouse_id, sku, lot_id,
                                  direction, qty, unit, reason, ref_type, ref_id, client_ref)
      values (new.farm_id, new.ts, new.created_by, 'APP', v_wh, it.sku, v_lot,
              1, it.kg, (select unit from products where sku = it.sku),
              'NHAP_SX', 'batch_logs', new.id::text, 'batchout-'||new.id::text||'-'||it.sku)
      on conflict (farm_id, client_ref) where client_ref is not null do nothing;
    end loop;
  end if;

  return new;
end $fn$;

drop trigger if exists batch_logs_stockmove on batch_logs;
create trigger batch_logs_stockmove after insert on batch_logs
  for each row execute function itran_batch_stockmove();
