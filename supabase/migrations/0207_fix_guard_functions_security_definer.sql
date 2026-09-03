-- 0207 · 4 hàm guard khác cùng lỗ hổng đã vá ở 0202 (chk_feed_species) — CHƯA có `security definer`.
--
-- Cùng cơ chế: hàm chạy dưới quyền app_user (không phải chủ bảng) tra cứu bảng THAM CHIẾU (animals/
-- animal_groups) theo ID được truyền vào. RLS trên bảng đó lọc theo can_see_farm(farm_id) — nếu ID
-- thuộc TRẠI KHÁC với app.farm_id đang set trong session, dòng bị RLS ẩn đi, SELECT trả NULL, và
-- guard có nhánh "không thấy dữ liệu thì không chặn" (chủ ý, để không cản luồng ghi tối thiểu khi
-- thiếu tham chiếu hợp lệ) → ÂM THẦM BỎ QUA thay vì raise. Vì FK (0127) đã đảm bảo ID luôn TỒN TẠI,
-- "không thấy" ở đây chỉ có thể do RLS — không phải do ID rác — nên an toàn để coi là false negative
-- cần vá bằng security definer (đọc được xuyên trại để KIỂM TRA, KHÔNG trả dữ liệu ra ngoài).
--
-- 4 hàm, mức nghiêm trọng giảm dần:
-- 1. chk_group_active() — CÙNG TRIGGER với chk_feed_species (0186: feed_guard/animal_evt_guard) —
--    0202 mới vá được nửa; nửa "đàn đã đóng sổ" vẫn hở, né được bằng group_id trại khác.
-- 2. itran_animal_event_before() (0141) — né được ERR_WITHDRAWAL_ACTIVE lúc XUAT cá thể — control
--    C-WITHDRAWAL (ngưng thuốc → ATTP/pháp lý), gửi animal_id trại khác là né được hoàn toàn.
-- 3. trg_sales_withdrawal() (0073) — cùng control C-WITHDRAWAL, phía bán hàng (sales).
-- 4. itran_dead_check() (0009) — ghi được sự kiện lên con đã CHẾT/XUẤT nếu animal_id trại khác.
--
-- set search_path = public, pg_temp: chặn search_path hijacking (chuẩn khi thêm security definer).

alter function chk_group_active(text) security definer set search_path = public, pg_temp;
alter function itran_animal_event_before() security definer set search_path = public, pg_temp;
alter function trg_sales_withdrawal() security definer set search_path = public, pg_temp;
alter function itran_dead_check() security definer set search_path = public, pg_temp;
