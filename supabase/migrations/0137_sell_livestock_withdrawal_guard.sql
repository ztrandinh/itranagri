-- 0137 — Chốt AN TOÀN THỰC PHẨM + trạng thái ở khâu bán vật hơi
--
-- sell_livestock (0135) mới chặn status='XUAT'. Hai lỗ hổng:
--  1. Không kiểm animals.withdrawal_until → bán được con còn tồn dư kháng sinh/thuốc
--     (vi phạm ngưng thuốc, luật thú y). Không hàm nào chặn ngưng thuốc ở khâu bán.
--  2. Không chặn con CHẾT/LOẠI THẢI → có thể "bán hơi" một con đã chết hoặc bị loại.
-- Sửa: guard ERR_WITHDRAWAL + chỉ cho bán con đang ở trạng thái sống trên trại
-- (chặn XUAT/CHET/LOAI/DA_BAN). Giữ nguyên phần còn lại.

create or replace function sell_livestock(
  p_farm text, p_by text, p_animal_ids text[], p_buyer text,
  p_price_per_kg numeric, p_sku text default 'SKU-BO-HOI'
) returns uuid language plpgsql as $fn$
declare v_sale uuid := gen_random_uuid(); v_total_kg numeric := 0; a record;
begin
  if array_length(p_animal_ids,1) is null then raise exception 'ERR_NO_ANIMAL: chưa chọn con nào'; end if;
  if coalesce(p_price_per_kg,0) <= 0 then raise exception 'ERR_PRICE: thiếu đơn giá/kg'; end if;

  -- kiểm & tính tổng khối lượng theo lần cân gần nhất
  for a in select id, coalesce(last_weight_kg,0) as kg, status, withdrawal_until
             from animals where id = any(p_animal_ids) and farm_id = p_farm loop
    if a.status in ('XUAT','CHET','LOAI','DA_BAN') then
      raise exception 'ERR_NOT_SELLABLE: % không bán được (trạng thái %)', a.id, a.status;
    end if;
    if a.withdrawal_until is not null and a.withdrawal_until > current_date then
      raise exception 'ERR_WITHDRAWAL: % còn ngưng thuốc tới %, không được bán', a.id, a.withdrawal_until;
    end if;
    v_total_kg := v_total_kg + a.kg;
  end loop;
  if v_total_kg <= 0 then raise exception 'ERR_NO_WEIGHT: chưa có cân, không tính được tiền'; end if;

  -- 1 đơn bán cho cả lô (trigger itran_gl_sales tự đăng Nợ 131 · Có 511)
  insert into sales(id, farm_id, ts, created_by, source, status, sku, qty, unit, price, amount,
                    channel_code, payment, paid, partner_id, client_ref)
  values (v_sale, p_farm, now(), p_by, 'APP', 'ACTIVE', p_sku, v_total_kg, 'kg',
          p_price_per_kg, round(v_total_kg * p_price_per_kg), 'HOI', 'CK', false, p_buyer,
          'livestock-'||v_sale::text);

  -- từng con: sự kiện XUAT (trigger đổi animals.status='XUAT') + nối sale_animals
  -- Phải mang group_id để itran_group_count_after GIẢM đầu đàn (nếu null sẽ thoát sớm → đàn không giảm)
  for a in select id, coalesce(last_weight_kg,0) as kg, group_id
             from animals where id = any(p_animal_ids) and farm_id = p_farm loop
    insert into animal_events(farm_id, ts, created_by, source, status, animal_id, group_id, event_type,
                              value, unit, detail, client_ref)
    values (p_farm, now(), p_by, 'APP', 'ACTIVE', a.id, a.group_id, 'XUAT', a.kg, 'kg',
            jsonb_build_object('note','xuất bán hơi','buyer',p_buyer,'sale_id',v_sale::text),
            'xuat-'||v_sale::text||'-'||a.id);
    insert into sale_animals(sale_id, animal_id, weight_kg) values (v_sale, a.id, a.kg);
  end loop;

  return v_sale;
end $fn$;
