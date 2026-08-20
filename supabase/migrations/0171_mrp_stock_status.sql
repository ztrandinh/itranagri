-- 0171 · MRP #2 · SỐ NGÀY DÙNG CÒN LẠI + VẠCH 3 MÀU (đỏ/vàng/xanh) cho nguyên liệu có cầu.
-- Tồn kho ÷ cầu/ngày (gộp từ v_material_demand nhiều nguồn) → days_left. So stock_policies.min_days:
--   🔴 DO   = tồn ≤ min_qty HOẶC days ≤ min_days  (phải mua/bổ sung NGAY)
--   🟡 VANG = days ≤ 2× min_days                   (sắp chạm sàn)
--   🟢 XANH = đủ
-- Ngưỡng = config (stock_policies), không hard-code. Mặc định min_days=3 nếu chưa khai chính sách.

create or replace view v_stock_status as
with onhand as (
  select farm_id, sku, sum(direction * qty) as ton
  from inventory_moves where status = 'ACTIVE' and sku is not null group by farm_id, sku
), demand as (
  select farm_id, sku, round(avg(demand_kg)::numeric, 1) as cau_ngay
  from v_material_demand group by farm_id, sku
)
select d.farm_id, d.sku, p.name as ten, coalesce(o.ton, 0) as ton, d.cau_ngay,
       case when d.cau_ngay > 0 then round((coalesce(o.ton,0) / d.cau_ngay)::numeric, 1) end as ngay_con_lai,
       sp.min_days, sp.min_qty,
       case
         when coalesce(o.ton,0) <= coalesce(sp.min_qty, 0)
           or (d.cau_ngay > 0 and coalesce(o.ton,0) / d.cau_ngay <= coalesce(sp.min_days, 3))       then 'DO'
         when d.cau_ngay > 0 and coalesce(o.ton,0) / d.cau_ngay <= coalesce(sp.min_days, 3) * 2      then 'VANG'
         else 'XANH'
       end as den
from demand d
left join onhand o        on o.farm_id = d.farm_id and o.sku = d.sku
left join products p      on p.sku = d.sku
left join stock_policies sp on sp.farm_id = d.farm_id and sp.sku = d.sku;
grant select on v_stock_status to app_user;
