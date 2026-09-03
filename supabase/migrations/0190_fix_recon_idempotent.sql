-- 0190 · Job đối soát đêm (runRecon) chạy lại an toàn (idempotent)
-- Trước đây INSERT thẳng vào recon_results mỗi lần chạy → chạy lại 1 ngày đã xử lý (vd sau khi job
-- chết giữa chừng, hoặc admin bấm chạy tay lại) sẽ NHÂN ĐÔI kết quả đối soát + bắn lặp alert.
-- Bằng chứng: DB hiện có sẵn 13 nhóm (farm_id,rule_code,period) trùng do đúng bug này — dọn trước khi
-- tạo unique index. Đây là TÍNH LẠI kết quả của đúng ngày đang xử lý (không phải sửa lịch sử ngày đã
-- qua), nên cho phép ghi đè qua ON CONFLICT thay vì insert vô tội vạ.
--
-- recon_results có trigger chặn DELETE tuyệt đối (kể cả superuser) — tắt tạm trong đúng transaction
-- này để dọn bản trùng (giữ bản mới nhất theo ts), bật lại ngay sau, không đổi hành vi cho ai khác.
alter table recon_results disable trigger recon_results_bud;
delete from recon_results a using recon_results b
  where a.farm_id = b.farm_id and a.rule_code = b.rule_code and a.period = b.period
    and (a.ts, a.id) < (b.ts, b.id);
alter table recon_results enable trigger recon_results_bud;

create unique index if not exists recon_results_farm_rule_period_ux on recon_results(farm_id, rule_code, period);
grant update (expected, actual, diff_pct, status, detail, ts) on recon_results to app_user;
