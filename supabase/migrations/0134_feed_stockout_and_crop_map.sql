-- 0134 — Nối truy xuất 2 chặng vòng đời: đồng ruộng→kho (bắp) và kho→cho ăn
--
-- Bối cảnh (truy trực tiếp CSDL 20-08-2026):
--  (A) crop_to_sku('BAP') = NULL vì sku_crop_map chỉ có 'BAP-SK', không có 'BAP' →
--      thu hoạch bắp (harvest.crop='BAP') KHÔNG vào kho được (trg_harvest_stockin thoát sớm khi sku null).
--  (B) Cho ăn (feed_logs) KHÔNG trừ tồn nguyên liệu ở đường LIVE: feed_logs/batch_logs không có
--      trigger nào; toàn bộ move XUAT_CHO_AN hiện có đều source='IMPORT' (seed sinh tay, ref_type=NULL).
--      → cho ăn thật qua app sẽ không rút kho, tồn nguyên liệu bị thổi phồng, và không truy được
--      lô nguyên liệu nào đã cho đàn nào ăn.
--
-- Sửa:
--  (A) thêm 'BAP','THAN-BAP' vào alt_crops của BAP-SK → crop_to_sku('BAP') = NL-BAP-U.
--  (B) trigger AFTER INSERT feed_logs: nổ công thức (recipes.components [{sku,pct}]) theo qty_kg,
--      xuất kho từng nguyên liệu (FEFO), reason='XUAT_CHO_AN', NỐI ref_type='feed_logs'/ref_id.
--      CHỈ chạy cho bản ghi LIVE (source<>'IMPORT', không backfill) để seed chạy lại không trừ ĐÔI.

-- ── (A) map bắp ─────────────────────────────────────────────────────────────
update sku_crop_map
   set alt_crops = array(select distinct e from unnest(alt_crops || array['BAP','THAN-BAP']) e)
 where crop_code = 'BAP-SK';

-- ── (B) cho ăn → xuất kho nguyên liệu theo công thức, có ref ────────────────
create or replace function itran_feed_stockout() returns trigger language plpgsql as $fn$
declare comp record; v_qty numeric; v_wh text; v_lot text;
begin
  -- chỉ bản ghi cho ăn THẬT (app), có khối lượng, có công thức; bỏ qua seed/import & backfill
  if coalesce(new.qty_kg,0) <= 0 or new.status <> 'ACTIVE'
     or new.recipe_id is null or new.source = 'IMPORT' or coalesce(new.is_backfill,false) then
    return new;
  end if;

  for comp in
    select (c->>'sku') as sku, (c->>'pct')::numeric as pct
    from recipes r, jsonb_array_elements(r.components) c
    where r.id = new.recipe_id and (c->>'pct') is not null and (c->>'sku') is not null
  loop
    v_qty := round(new.qty_kg * comp.pct / 100.0, 2);
    if v_qty <= 0 then continue; end if;

    -- chọn kho+lô còn tồn dương cho nguyên liệu, ưu tiên hết hạn sớm (FEFO)
    select s.warehouse_id, nullif(s.lot_id,'') into v_wh, v_lot
      from stock_at(new.farm_id, new.ts::date) s
      left join lots l on l.id = nullif(s.lot_id,'')
     where s.sku = comp.sku and s.qty > 0
     order by l.expiry_date nulls last, s.qty desc
     limit 1;

    -- không thấy tồn: vẫn ghi xuất để giữ cân vật chất, dùng kho nguyên liệu mặc định K3
    if v_wh is null then
      select id into v_wh from warehouses where farm_id = new.farm_id and code = 'K3' limit 1;
    end if;
    if v_wh is null then continue; end if;

    insert into inventory_moves(farm_id, ts, created_by, source, warehouse_id, sku, lot_id,
                                direction, qty, unit, reason, ref_type, ref_id, client_ref)
    values (new.farm_id, new.ts, new.created_by, 'APP', v_wh, comp.sku, v_lot,
            -1, v_qty, (select unit from products where sku = comp.sku),
            'XUAT_CHO_AN', 'feed_logs', new.id::text,
            'feed-'||new.id::text||'-'||comp.sku)
    on conflict (farm_id, client_ref) where client_ref is not null do nothing;
  end loop;
  return new;
end $fn$;

drop trigger if exists feed_logs_stockout on feed_logs;
create trigger feed_logs_stockout after insert on feed_logs
  for each row execute function itran_feed_stockout();
