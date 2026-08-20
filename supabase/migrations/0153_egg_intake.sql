-- 0153 · NHẬP KHO SẢN XUẤT/THU HOẠCH TỔNG QUÁT — quy cách khai báo BIẾN, KHÔNG fix cứng sản phẩm (luật 7).
--
-- Bất kỳ SKU (khai trong `products`) + NGUỒN (đàn/ruộng/mẻ… — biến) → tạo LÔ có hạn dùng (lấy shelf_life
-- từ config products) + move NHAP_SX truy về nguồn. Dùng cho: TRỨNG (nguồn=đàn gà đẻ), phân trùn/bò/dê/gà,
-- tôm/cá… — CÙNG một hàm, không đẻ hàm riêng từng SP. Forward-safe (không đụng lô cũ), idempotent theo client_ref.
--
-- Quy cách khai báo (tối thiểu): sản phẩm (SKU) · số lượng · [nguồn: loại+mã] · [ngày] · [loại/grade] · [đơn vị] · [kho].

create or replace function record_intake(
  p_farm text, p_sku text, p_qty numeric, p_by text,
  p_source_type text default null, p_source_id text default null,
  p_client_ref text default null, p_date date default current_date,
  p_grade text default null, p_unit text default null, p_warehouse text default null
) returns jsonb language plpgsql as $$
declare v_lot text; v_wh text; v_shelf int; v_kind text; v_unit text; v_exp date; v_cref text; v_lotno text; existed uuid;
begin
  if p_sku is null then raise exception 'ERR_SKU: chưa khai sản phẩm'; end if;
  if coalesce(p_qty,0) <= 0 then raise exception 'ERR_QTY: thiếu số lượng nhập'; end if;
  select kind, coalesce(shelf_life_days,0), coalesce(unit,'kg') into v_kind, v_shelf, v_unit
    from products where sku = p_sku;
  if not found then raise exception 'ERR_SKU_UNKNOWN: % chưa khai trong danh mục sản phẩm', p_sku; end if;

  v_exp   := case when v_shelf > 0 then (p_date + v_shelf)::date else null end;   -- hạn dùng từ CONFIG, không hằng số
  v_lotno := to_char(p_date,'YYMMDD')||'-'||coalesce(p_source_id,'X');
  v_cref  := coalesce(p_client_ref, 'in-'||p_farm||'-'||p_sku||'-'||v_lotno||'-'||coalesce(p_grade,''));

  select id into existed from inventory_moves where farm_id = p_farm and client_ref = v_cref;
  if existed is not null then
    return jsonb_build_object('dup', true, 'lot', (select lot_id from inventory_moves where id = existed));
  end if;

  v_lot := ensure_lot(p_farm, p_sku, v_lotno, null, v_exp);      -- lô theo ngày×nguồn (idempotent)
  update lots set mfg_date = coalesce(mfg_date, p_date) where id = v_lot;

  v_wh := coalesce(p_warehouse,
                   (select id from warehouses where farm_id = p_farm
                     and code = (case when v_kind = 'THANH_PHAM' then 'K5' else 'K3' end) limit 1));

  insert into inventory_moves(farm_id, ts, created_by, source, client_ref, warehouse_id, sku, lot_id,
                              direction, qty, unit, reason, from_to, ref_type, ref_id)
  values (p_farm, p_date::timestamptz, p_by, 'APP', v_cref, v_wh, p_sku, v_lot,
          1, p_qty, coalesce(p_unit, v_unit), 'NHAP_SX', p_grade, p_source_type, p_source_id);

  return jsonb_build_object('lot', v_lot, 'qty', p_qty, 'don_vi', coalesce(p_unit,v_unit),
                            'han_dung', v_exp, 'nguon_loai', p_source_type, 'nguon', p_source_id, 'loai', p_grade);
end $$;
grant execute on function record_intake(text,text,numeric,text,text,text,text,date,text,text,text) to app_user;
