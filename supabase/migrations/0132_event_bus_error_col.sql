-- 0132 — Cột `error` cho event_bus + dọn mã nhân sự cũ trong payload phân mảnh
--
-- Truy dòng chảy dữ liệu: dispatch (event_bus -> notifications) KẸT VĨNH VIỄN vì một sự kiện
-- có payload.assignee = 'NS-110' (mã cũ). Chuẩn hoá mã 0106 đổi staff.id sang ITRAN-NS-* nhưng
-- BỎ SÓT jsonb trong bảng PHÂN MẢNH event_bus_* (loại relispartition). 8.132 payload còn mã cũ.
-- Chèn notification cho staff không tồn tại -> vướng khoá ngoại -> văng CẢ LƯỢT -> hàng đợi đứng.
--
-- notify.ts đã vá hai lớp: (1) lọc người nhận về chỉ ai còn tồn tại; (2) try/catch từng sự kiện.
-- Migration này thêm cột `error` để ghi sự kiện hỏng, và ĐỔI mã cũ trong payload sang chuẩn.

alter table event_bus add column if not exists error text;

-- Đổi mã nhân sự cũ (NS-xxx) trong payload sang mã chuẩn, DÙNG bảng ánh xạ đã có (code_rename).
-- Chỉ chạm bảng cha; Postgres áp xuống mọi phân mảnh. Áp qua apply_code_map (đã dựng ở 0106).
do $$
declare cnt int;
begin
  if to_regprocedure('public.apply_code_map(text)') is null then
    raise notice 'apply_code_map chưa có — bỏ qua đổi payload';
    return;
  end if;
  update event_bus set payload = apply_code_map(payload::text)::jsonb
   where payload::text ~ '"(F[0-9]+|ITRAN|NS)-[^"]+"';
  get diagnostics cnt = row_count;
  raise notice 'Đã đổi mã trong % payload event_bus', cnt;
end $$;
