-- 0108 — Bộ form đi theo NGHỀ, khai trong danh mục thay vì dò chữ trong code
--
-- Trước đây `formsForPosition()` trong src/lib/forms.ts phải dò chữ bằng regex trên chức danh
-- tự do ("CN gà đẻ ca 2 – phân loại trứng"), vì cột position_code sai hàng loạt nên không tra được.
-- Nay mã nghề đã đúng (0103/0107) nên bộ form khai thẳng vào positions_catalog.
--
-- LƯU Ý QUAN TRỌNG: bảng ROLE_FORMS trong code đang dùng NGHĨA CŨ của mã, lệch hẳn với danh mục:
--     code cũ A4  = RAS thuỷ sản     ·  danh mục A4  = Khu D sinh học   (RAS thật là A15)
--     code cũ A5  = ruộng/máy        ·  danh mục A5  = Nhập đàn/cách ly (ruộng thật là A6)
--     code cũ A6  = khu D sinh học   ·  danh mục A6  = Ruộng / máy nông nghiệp
--     code cũ A11 = cổng/bảo vệ      ·  danh mục A11 = Bảo trì/điện/IoT (cổng thật là A10)
-- Nếu cứ để code tra theo mã mới mà giữ bảng cũ thì công nhân sẽ nhận NHẦM form. Dưới đây là
-- bản khai theo ĐÚNG danh mục.
--
-- Cột `forms` trước chứa TÊN BẢNG (feed_logs…) — thứ UI không dùng được. Đổi sang KHOÁ FORM
-- (feed_tmr, animal_event…) đúng thứ ThreeTap cần.

update positions_catalog set forms = v.f from (values
  -- ── Công nhân ──
  ('A1',  '{feed_tmr,d5_batch,stock_in,stock_out,checklist,incident,paper_submit}'::text[]),
  ('A2',  '{animal_event,feed_tmr,stock_in,stock_out,checklist,incident,paper_submit}'),
  ('A3',  '{poultry_daily,egg_in,feed_tmr,stock_in,stock_out,checklist,incident,paper_submit}'),
  ('A4',  '{bio_batch,stock_in,stock_out,checklist,incident,paper_submit}'),
  ('A5',  '{animal_event,stock_in,stock_out,checklist,incident,paper_submit}'),
  ('A6',  '{crop_log,irrigation,pest_scout,fuel_out,stock_in,stock_out,checklist,incident,paper_submit}'),
  ('A7',  '{d5_batch,stock_in,stock_out,checklist,incident,paper_submit}'),
  ('A8',  '{stock_in,stock_out,stocktake,sale,checklist,incident,paper_submit}'),
  ('A9',  '{sale,stock_in,stock_out,incident,paper_submit}'),
  ('A10', '{gate,stock_in,stock_out,incident,paper_submit}'),
  ('A11', '{checklist,stock_in,stock_out,incident,paper_submit}'),
  ('A12', '{sale,incident,paper_submit}'),
  ('A13', '{incident,paper_submit}'),
  ('A14', '{sale,stock_in,stock_out,incident,paper_submit}'),
  ('A15', '{ras_daily,ras_feed,stock_in,stock_out,checklist,incident,paper_submit}'),
  ('A16', '{gate,stock_out,fuel_out,incident,paper_submit}'),
  ('A17', '{stock_in,incident,paper_submit}'),
  ('A18', '{incident,paper_submit}'),
  -- ── Trưởng nhóm: thấy trọn bộ form của nhóm mình phụ trách ──
  ('T01', '{animal_event,feed_tmr,stock_in,stock_out,checklist,incident,paper_submit}'),
  ('T02', '{d5_batch,stock_in,stock_out,stocktake,checklist,incident,paper_submit}'),
  ('T03', '{bio_batch,ras_daily,ras_feed,stock_in,stock_out,checklist,incident,paper_submit}'),
  ('T04', '{crop_log,irrigation,pest_scout,fuel_out,stock_in,stock_out,checklist,incident,paper_submit}'),
  ('T05', '{stock_in,stock_out,stocktake,sale,checklist,incident,paper_submit}'),
  ('T06', '{animal_event,stock_in,stock_out,checklist,incident,paper_submit}'),
  ('T07', '{checklist,incident,paper_submit}'),
  -- ── Kỹ thuật trưởng / trưởng phòng: xem được form chuyên môn để kiểm tra và ghi bù ──
  ('K01', '{animal_event,feed_tmr,d5_batch,checklist,incident,paper_submit}'),
  ('K02', '{bio_batch,ras_daily,ras_feed,checklist,incident,paper_submit}'),
  ('K03', '{animal_event,poultry_daily,egg_in,checklist,incident,paper_submit}'),
  ('K04', '{crop_log,irrigation,pest_scout,checklist,incident,paper_submit}'),
  ('K05', '{stock_in,stock_out,stocktake,incident,paper_submit}'),
  ('K06', '{incident,paper_submit}'),
  ('K07', '{incident,paper_submit}'),
  ('K08', '{incident,paper_submit}'),
  -- ── Ban điều hành / kế toán / chất lượng: chủ yếu duyệt và xem, ghi rất ít ──
  ('G01', '{incident}'), ('G02', '{incident}'), ('G03', '{incident}'), ('G04', '{incident,paper_submit}'),
  ('G05', '{sale,incident}'), ('G06', '{incident,paper_submit}'), ('G07', '{incident}'), ('G08', '{incident}'),
  ('C01', '{incident,paper_submit}'), ('C02', '{incident,paper_submit}'),
  ('C03', '{incident,paper_submit}'), ('C04', '{incident,paper_submit}'),
  ('Q01', '{checklist,incident,paper_submit}'),
  ('Q02', '{checklist,incident,paper_submit}'),
  ('Q03', '{checklist,incident,paper_submit}')
) as v(code, f) where positions_catalog.code = v.code;

-- Nghề nào chưa khai bộ form — phải luôn rỗng, nếu không công nhân mở app ra thấy màn trắng.
create or replace view v_positions_no_forms as
select code as ma_nghe, name as ten_nghe, dept_code as phong, role_code as vai
from positions_catalog
where active is not false and (forms is null or cardinality(forms) = 0);
grant select on v_positions_no_forms to app_user;

-- Truy vấn cho giao diện: mã nghề -> danh sách khoá form.
create or replace view v_position_forms as
select code as position_code, name, dept_code, role_code, forms
from positions_catalog where active is not false;
grant select on v_position_forms to app_user;
