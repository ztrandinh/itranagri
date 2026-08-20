-- 0135 — Nối XUAT (xuất chuồng) ⇄ bán vật hơi: truy được đơn bán về TỪNG CON
--
-- Bối cảnh: bán bò/dê hơi hiện ghi RỜI với sự kiện xuất chuồng — sales.lot_id=NULL, không lô nào
-- cho SKU vật hơi, người mua ở event ≠ partner ở đơn bán. Không truy được đơn về con nào
-- (vi phạm luật 4 định danh 3 cấp + luật 8 mọi số drill về gốc). Vật hơi RỜI ĐÀN nên không có
-- tồn kho — bản ghi truy xuất đúng là sự kiện XUAT + đơn bán, cần một mối nối tường minh.
--
-- Sửa: bảng nối sale_animals + hàm sell_livestock() tạo 1 đơn bán cho cả lô, sinh sự kiện XUAT
-- cho từng con (đổi status), và nối sale⇄animal. Đơn bán kích hoạt trigger GL 511 sẵn có.

create table if not exists sale_animals(
  sale_id   uuid not null references sales(id),
  animal_id text not null references animals(id),
  weight_kg numeric,
  primary key (sale_id, animal_id)
);
create index if not exists ix_sale_animals_animal on sale_animals(animal_id);

-- RLS (luật 1): bảng nối không có farm_id → policy theo trại của đơn bán cha.
alter table sale_animals enable row level security; drop policy if exists p_all on sale_animals;
create policy p_all on sale_animals for all
  using (exists (select 1 from sales s where s.id = sale_id and can_see_farm(s.farm_id))) with check (true);
grant select, insert on sale_animals to app_user;

comment on table sale_animals is 'Nối đơn bán vật hơi ⇄ từng con vật (truy xuất 2 chiều: đơn→con, con→đơn)';

create or replace function sell_livestock(
  p_farm text, p_by text, p_animal_ids text[], p_buyer text,
  p_price_per_kg numeric, p_sku text default 'SKU-BO-HOI'
) returns uuid language plpgsql as $fn$
declare v_sale uuid := gen_random_uuid(); v_total_kg numeric := 0; a record;
begin
  if array_length(p_animal_ids,1) is null then raise exception 'ERR_NO_ANIMAL: chưa chọn con nào'; end if;
  if coalesce(p_price_per_kg,0) <= 0 then raise exception 'ERR_PRICE: thiếu đơn giá/kg'; end if;

  -- kiểm & tính tổng khối lượng theo lần cân gần nhất
  for a in select id, coalesce(last_weight_kg,0) as kg, status
             from animals where id = any(p_animal_ids) and farm_id = p_farm loop
    if a.status = 'XUAT' then raise exception 'ERR_ALREADY_OUT: % đã xuất chuồng', a.id; end if;
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
  for a in select id, coalesce(last_weight_kg,0) as kg
             from animals where id = any(p_animal_ids) and farm_id = p_farm loop
    insert into animal_events(farm_id, ts, created_by, source, status, animal_id, event_type,
                              value, unit, detail, client_ref)
    values (p_farm, now(), p_by, 'APP', 'ACTIVE', a.id, 'XUAT', a.kg, 'kg',
            jsonb_build_object('note','xuất bán hơi','buyer',p_buyer,'sale_id',v_sale::text),
            'xuat-'||v_sale::text||'-'||a.id);
    insert into sale_animals(sale_id, animal_id, weight_kg) values (v_sale, a.id, a.kg);
  end loop;

  return v_sale;
end $fn$;

-- Truy xuất 2 chiều tiện tra
create or replace view v_livestock_sale_trace as
select sa.sale_id, sa.animal_id, sa.weight_kg, s.ts as sold_at, s.partner_id as buyer,
       s.sku, s.price, an.species, an.class_code
  from sale_animals sa
  join sales s   on s.id = sa.sale_id
  join animals an on an.id = sa.animal_id;
