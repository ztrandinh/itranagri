-- 0173 · Vạch 3 MÀU cho TOÀN BỘ vật tư/nguyên liệu trong kho (không chỉ NL có cầu thức ăn).
-- Chủ: "số liệu vật tư/nguyên liệu trong kho phải LUÔN có mức vàng/đỏ/xanh".
-- cau_ngay = cầu thức ăn (v_material_demand) NẾU có, else TIÊU THỤ TB/ngày từ xuất kho 90 ngày (thuốc/vật tư/
-- nhiên liệu/bao bì…). Màu theo stock_policies (min_qty/min_days), mặc định min_days=3. Mọi SKU có tồn → có màu.

create or replace view v_stock_status as
with onhand as (
  select farm_id, sku, sum(direction * qty) as ton
  from inventory_moves where status = 'ACTIVE' and sku is not null group by farm_id, sku
), feeddem as (
  select farm_id, sku, round(avg(demand_kg)::numeric, 2) as cau_ngay from v_material_demand group by farm_id, sku
), outflow as (
  select farm_id, sku, round((sum(qty) / 90.0)::numeric, 2) as out_ngay
  from inventory_moves
  where status = 'ACTIVE' and direction = -1 and sku is not null and ts >= now() - interval '90 days'
  group by farm_id, sku
)
select o.farm_id, o.sku, p.name as ten, coalesce(o.ton, 0) as ton,
       coalesce(fd.cau_ngay, of.out_ngay) as cau_ngay,
       case when coalesce(fd.cau_ngay, of.out_ngay, 0) > 0
            then round((coalesce(o.ton,0) / coalesce(fd.cau_ngay, of.out_ngay))::numeric, 1) end as ngay_con_lai,
       sp.min_days, sp.min_qty,
       case
         when coalesce(o.ton,0) <= coalesce(sp.min_qty, 0) and coalesce(sp.min_qty,0) > 0                                          then 'DO'
         when coalesce(fd.cau_ngay, of.out_ngay, 0) > 0 and coalesce(o.ton,0) / coalesce(fd.cau_ngay, of.out_ngay) <= coalesce(sp.min_days, 3)     then 'DO'
         when coalesce(fd.cau_ngay, of.out_ngay, 0) > 0 and coalesce(o.ton,0) / coalesce(fd.cau_ngay, of.out_ngay) <= coalesce(sp.min_days, 3) * 2 then 'VANG'
         else 'XANH'
       end as den
from onhand o
left join feeddem fd        on fd.farm_id = o.farm_id and fd.sku = o.sku
left join outflow of        on of.farm_id = o.farm_id and of.sku = o.sku
left join products p        on p.sku = o.sku
left join stock_policies sp on sp.farm_id = o.farm_id and sp.sku = o.sku;
grant select on v_stock_status to app_user;
