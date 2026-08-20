-- 0172 · MRP #3 · SUY NGƯỢC nhu cầu SẢN XUẤT: cầu nguyên liệu → HA cần TRỒNG (cây) hoặc SL cần NUÔI (sinh học).
--
-- Nguyên liệu TỰ SẢN XUẤT (sku_crop_map.source): TRONG (ngô/cỏ) → ha = cầu × fresh_per_sku ÷ năng suất kg/ha
-- (v_plot_yield). MUA → không trồng (đã có cảnh báo tồn 3 màu #2 lo mua). Phụ phẩm (CA_HAI) → theo cây chính.
-- Kèm lead_days (thời gian trồng/mua) để biết phải đặt/gieo TRƯỚC bao lâu. Cầu gộp từ nhiều đối tượng (#1).

create or replace view v_production_need as
with d as (
  select farm_id, sku, avg(demand_kg) as cau_ngay from v_material_demand group by farm_id, sku
), y as (  -- năng suất kg/ha theo cây (khớp linh hoạt: crop_code có thể là BAP-SK còn harvest ghi BAP)
  select farm_id, crop, avg(kg_per_ha) as ns_kg_ha from v_plot_yield group by farm_id, crop
)
select d.farm_id, d.sku, p.name as ten_nl, m.crop_code, m.source, m.fresh_per_sku, m.lead_days,
       round(d.cau_ngay::numeric, 1)        as cau_ngay,
       round((d.cau_ngay * 30)::numeric, 0) as cau_thang,
       round(yl.ns_kg_ha::numeric, 0)       as nang_suat_kg_ha,
       case when m.source = 'TRONG' and yl.ns_kg_ha > 0
            then round((d.cau_ngay * 30 * coalesce(m.fresh_per_sku, 1) / yl.ns_kg_ha)::numeric, 2)
       end as ha_can_trong_thang,
       case when m.source = 'MUA' then 'Mua ngoài (xem cảnh báo tồn 3 màu)'
            when m.source = 'TRONG' and coalesce(yl.ns_kg_ha,0) = 0 then 'Tự trồng — CHƯA có năng suất mẫu, cần khớp mã cây'
            when m.source = 'TRONG' then 'Tự trồng'
            else m.source end as ghi_chu
from d
join sku_crop_map m on m.sku = d.sku
left join products p on p.sku = d.sku
left join y yl on yl.farm_id = d.farm_id and (yl.crop = m.crop_code or m.crop_code like yl.crop || '%' or yl.crop like split_part(m.crop_code,'-',1) || '%');
grant select on v_production_need to app_user;
