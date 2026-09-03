-- 0192 · 2 vá toàn vẹn dữ liệu nhỏ từ audit
-- 1) sales.lot_id không có FK (0002_events.sql:71) — thiếu validate lô hàng tồn tại khi có giá trị.
--    Xác nhận trước khi thêm: 0 bản ghi mồ côi trong DB hiện tại.
alter table sales add constraint sales_lot_id_fkey foreign key (lot_id) references lots(id);

-- 2) tool_move (chuyển kho công cụ, actions/route.ts) vẫn insert inventory_moves không gắn
--    ref_type/ref_id — đứt truy xuất nguồn gốc cho loại di chuyển này (không sửa được bằng
--    migration, xem sửa code kèm theo ở actions/route.ts).
