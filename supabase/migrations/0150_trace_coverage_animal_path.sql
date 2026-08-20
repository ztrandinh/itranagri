-- 0150 · v_trace_coverage: đơn bán "truy xuất được" phải kể CẢ ĐƯỜNG QUA CON (sale_animals), không chỉ lô.
--
-- 0148 chỉ tính lot_id → phạt oan đơn bán CON SỐNG (bò/dê/gà hơi) vốn truy xuất về CÁ THỂ qua sale_animals
-- (0135), không qua lô. Sửa: sale truy được = có lot_id HOẶC nối sale_animals. (Hiện sale_animals seed
-- còn rỗng nên số chưa đổi — xem docs/backlog.md: cần populate sale_animals; công thức nay ĐÚNG & tự lên
-- khi có dữ liệu.) Chỉ sửa 1 chiều SALE, giữ nguyên MOVE/BATCH.

create or replace view v_trace_coverage as
select x.farm_id, x.chieu, x.tong, x.truy_duoc,
       case when x.tong > 0 then round(100.0 * x.truy_duoc / x.tong, 1) else null end as pct
from (
  select farm_id, 'MOVE:'||reason as chieu, count(*)::bigint as tong,
         count(*) filter (where ref_id is not null)::bigint as truy_duoc
  from inventory_moves where status = 'ACTIVE' group by farm_id, reason
  union all
  select s.farm_id, 'SALE→LÔ/CON', count(*)::bigint,
         count(*) filter (where s.lot_id is not null
                             or exists (select 1 from sale_animals sa where sa.sale_id = s.id))::bigint
  from sales s where s.status = 'ACTIVE' group by s.farm_id
  union all
  select farm_id, 'BATCH→INPUTS', count(*)::bigint,
         count(*) filter (where inputs is not null and inputs <> '[]'::jsonb and inputs <> '{}'::jsonb)::bigint
  from batch_logs where status = 'ACTIVE' group by farm_id
) x;

grant select on v_trace_coverage to app_user;
