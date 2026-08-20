-- 0163 — T3.3: thay metric_sql PLACEHOLDER 'select 1' (luôn pass = coverage giả) bằng metric THẬT
--
-- Bối cảnh (audit §T3.3): icfs_score chạy metric_sql từng điều khoản → pass/fail. Điều ITRAN-STD 7.3
-- (id 73: hộ liên kết/franchise dùng CÙNG hệ dữ liệu + audit chéo) có metric_sql='select 1' + threshold '—'
-- → LUÔN đạt, không đo gì thật. Thay bằng: % hộ franchise đã lên hệ thống (có farm_id là 1 trại thật),
-- 100 khi chưa có hộ nào (không có gì để fail), threshold ≥80.
-- Config = dữ liệu (luật 7) → cập nhật bằng migration, không sửa code.

update standard_requirements
   set metric_sql = 'select case when count(*)=0 then 100 '
                 || 'else round(100.0*count(*) filter (where farm_id is not null and farm_id in (select id from farms))/count(*)) '
                 || 'end from franchise_sites',
       threshold  = '≥80'
 where standard_code = 'ITRAN-STD' and clause = '7.3' and metric_sql = 'select 1';
