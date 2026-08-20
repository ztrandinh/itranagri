-- 0151 · Tự ĐÓNG LÔ ĐÃ HẾT TỒN (on_hand<=0) → status HET. Dọn lô "rác" (KHA_DUNG nhưng đã xuất hết).
--
-- An toàn có chủ đích: CHỈ đụng lô status='KHA_DUNG' đã có phát sinh kho (join inventory_moves) mà tồn
-- ròng <=0 → đã dùng hết. KHÔNG đụng: lô còn tồn (>0), lô GIU_QC/THU_HOI/CO_LAP, lô chưa có move nào
-- (mới tạo chờ nhập). Lô HẾT HẠN nhưng CÒN tồn KHÔNG đóng ở đây (cần cách ly/tiêu huỷ — quyết định người,
-- đã có cảnh báo 0149). Chạy trong job (idempotent — lần sau đóng thêm khi có lô mới hết tồn).

create or replace function close_depleted_lots(p_farm text) returns int language plpgsql as $$
declare n int; begin
  with onhand as (
    select lot_id, sum(direction * qty) as ton
    from inventory_moves where status = 'ACTIVE' and lot_id is not null group by lot_id
  )
  update lots l set status = 'HET'
    from onhand o
    where o.lot_id = l.id and l.farm_id = p_farm
      and l.status = 'KHA_DUNG' and coalesce(o.ton, 0) <= 0;
  get diagnostics n = row_count;
  return n;
end $$;
grant execute on function close_depleted_lots(text) to app_user;
