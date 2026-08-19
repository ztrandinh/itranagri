-- 0123 — Nới mẫu kiểm tra cho mã SEMANTIC
--
-- 0122 khai mẫu quá hẹp so với dữ liệu thật, nên bộ soát báo lệch oan:
--   processes    83/149 "lệch"  -> thật ra 'P-D5-01' có CHỮ SỐ ở đoạn giữa,
--                                   và một số quy trình mang thẳng mã 'SOP-AT-01'
--   sops          72/506 "lệch"  -> 'SOP-KHO-01.1', 'SOP-NAM-03.1', 'SOP-RAS-01.1'
--                                   có đoạn giữa 3 chữ, không phải 2
--   job_accounts   8/67  "lệch"  -> 'D5-A-01' — mã phòng D5 có chữ số
--   departments    2/18  "lệch"  -> 'D5' có chữ số, và '*' là phòng dùng chung mọi bộ phận
--
-- Đây là lỗi của mẫu, KHÔNG phải lỗi dữ liệu. Nếu cứ để nguyên thì bộ soát kêu oan 165 dòng,
-- và kêu oan lâu ngày thì không ai còn tin bộ soát nữa — đúng cái bệnh chuông 99+.

update code_registry set pattern = '^SOP-[A-Z]{2,4}-[0-9]{2}(\.[0-9]+)?$' where object_type = 'sop';
update code_registry set pattern = '^(P|SOP)-[A-Z0-9]{2,4}-[0-9]{2}$'      where object_type = 'quy_trinh';
update code_registry set pattern = '^[A-Z0-9]{2,6}-[A-Z]-[0-9]{2}$'        where object_type = 'tai_khoan';
update code_registry set pattern = '^([A-Z0-9]{2,5}|\*)$'                  where object_type = 'phong_ban';
