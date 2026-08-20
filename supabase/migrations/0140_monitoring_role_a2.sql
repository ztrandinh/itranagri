-- 0140 — Việc chăm sóc bò/dê phải gắn nghề A2, không rơi vào thợ trộn TMR (A1)
--
-- Lỗi (phiên phối hợp báo + truy lại live): việc THEO_DOI chăm sóc (tẩy ký sinh, BCS, cai sữa,
-- cân định kỳ, động dục, đẻ dự kiến) sinh từ gen_monitoring_tasks lấy role_hint từ
-- monitoring_params — đang để 'worker' (chung, không nghề). assign_open_tasks không định tuyến
-- được theo nghề → 31 việc chăm bò/dê rơi vào a1 (ITRAN-NS-00070, nghề A1 = trộn TMR/vận hành D5).
-- Công nhân TMR mở app thấy toàn việc thú y.
--
-- Sửa: role_hint 'worker' của param chăm sóc bò/dê → 'worker:A2' (A2 = Chăm sóc bò/sinh sản/
-- điều trị; không có nghề dê riêng nên dê cũng thuộc A2). Các param 'tech_head' (ADG, khám thai,
-- vaccine) giữ nguyên — đúng là việc kỹ thuật/thú y. Đổi luôn việc đang mở + gán lại.

-- 1) Nguồn (cho các lần sinh việc sau)
update monitoring_params
   set role_hint = 'worker:A2'
 where role_hint = 'worker' and species_code in ('BO','DE');

-- 2) Việc THEO_DOI đang mở sinh từ MONITOR còn 'worker' → gắn nghề + gỡ người gán sai để gán lại
update tasks
   set role_hint = 'worker:A2', assignee_id = null
 where kind = 'THEO_DOI' and source = 'MONITOR' and role_hint = 'worker'
   and status in ('MO','DANG_LAM','TREO');

-- 3) Gán lại theo nghề cho từng trại có việc chờ gán
do $$
declare f text;
begin
  for f in select distinct farm_id from tasks
            where kind='THEO_DOI' and source='MONITOR' and role_hint='worker:A2'
              and assignee_id is null and status in ('MO','DANG_LAM','TREO') loop
    perform assign_open_tasks(f);
  end loop;
end $$;
