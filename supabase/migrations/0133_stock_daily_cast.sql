-- 0133 — Vá tổng hợp tồn kho: null::numeric cho avg_cost trong UNION
--
-- Chặng thứ hai của dòng chảy đứt (truy khi chạy /api/jobs/all):
--   refresh_agg_daily -> itran_stock_daily_delta -> lỗi
--   'column "avg_cost" is of type numeric but expression is of type text'
-- Nguyên nhân: trong UNION, `null` KHÔNG có kiểu nên Postgres mặc định thành TEXT; chèn vào
-- cột avg_cost numeric là hỏng. Bug tiềm ẩn — chỉ nổ khi đi nhánh prev (cuối tháng, hoặc lô
-- về 0), nên bình thường không thấy, tới kỳ tổng hợp cuối tháng mới đứng CẢ job đêm.
-- Sửa: ép null::numeric. Không đổi logic.

create or replace function itran_stock_daily_delta(p_farm text, p_day date) returns integer language plpgsql as $function$
declare n int; is_eom bool := p_day = (date_trunc('month', p_day) + interval '1 month - 1 day')::date; begin
  delete from stock_daily where farm_id=p_farm and day=p_day;
  with cur as (select warehouse_id, sku, coalesce(lot_id,'') as lot_id, sum(direction*qty) as qty from inventory_moves where farm_id=p_farm and status='ACTIVE' and ts::date<=p_day group by 1,2,3),
  prev as (select * from stock_at(p_farm, p_day-1))
  insert into stock_daily(farm_id, day, warehouse_id, sku, lot_id, qty, avg_cost)
  select p_farm, p_day, c.warehouse_id, c.sku, c.lot_id, c.qty, null::numeric from cur c left join prev p on p.warehouse_id=c.warehouse_id and p.sku=c.sku and p.lot_id=c.lot_id
  where is_eom or p_day >= current_date-90 or p.qty is distinct from c.qty
  union all
  select p_farm, p_day, p.warehouse_id, p.sku, p.lot_id, 0, null::numeric from prev p left join cur c on p.warehouse_id=c.warehouse_id and p.sku=c.sku and p.lot_id=c.lot_id where c.sku is null and p.qty<>0;
  get diagnostics n = row_count; return n; end $function$;
