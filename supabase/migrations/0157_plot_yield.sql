-- 0157 · NĂNG SUẤT CÂY TRỒNG trên diện tích (kg/ha) — biết ô nào/cây nào/mùa nào năng suất, để giữ/đổi/mở rộng.
-- harvests.qty_kg ÷ plots.area_ha → kg/ha. Có chiều crop (cây) + plot (ô) + thời gian (bucket quý/năm = mùa vụ).
create or replace view v_plot_yield as
select h.farm_id, h.plot_id, h.crop, h.season_id, h.ts,
       h.qty_kg,
       case when p.area_ha > 0 then round((h.qty_kg / p.area_ha)::numeric, 1) else null end as kg_per_ha
from harvests h
join plots p on p.id = h.plot_id
where h.status = 'ACTIVE' and coalesce(h.qty_kg, 0) > 0;
grant select on v_plot_yield to app_user;
