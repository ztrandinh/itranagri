-- 0148 · T0.3 · ĐỘ PHỦ TRUY XUẤT — dashboard read-side cho audit/compliance/xuất khẩu.
--
-- Đo mức độ nối chuỗi truy xuất theo từng chiều: dịch chuyển kho có nguồn (ref_id — nối bởi OS-3),
-- bán hàng có lô, mẻ sản xuất có nguyên liệu vào. KHÔNG alert (độ phủ <100% có lý do hệ thống, không
-- phải lỗi từng dòng) — chỉ cấp SỐ để audit thấy chỗ hở & theo dõi cải thiện. Read-side thuần.
-- Dùng so-sánh jsonb an toàn cho inputs (batch_logs.inputs có thể KHÔNG phải mảng — xem fix 0109).

create or replace view v_trace_coverage as
select x.farm_id, x.chieu, x.tong, x.truy_duoc,
       case when x.tong > 0 then round(100.0 * x.truy_duoc / x.tong, 1) else null end as pct
from (
  select farm_id, 'MOVE:'||reason as chieu, count(*)::bigint as tong,
         count(*) filter (where ref_id is not null)::bigint as truy_duoc
  from inventory_moves where status = 'ACTIVE' group by farm_id, reason
  union all
  select farm_id, 'SALE→LOT', count(*)::bigint, count(*) filter (where lot_id is not null)::bigint
  from sales where status = 'ACTIVE' group by farm_id
  union all
  select farm_id, 'BATCH→INPUTS', count(*)::bigint,
         count(*) filter (where inputs is not null and inputs <> '[]'::jsonb and inputs <> '{}'::jsonb)::bigint
  from batch_logs where status = 'ACTIVE' group by farm_id
) x;

grant select on v_trace_coverage to app_user;
