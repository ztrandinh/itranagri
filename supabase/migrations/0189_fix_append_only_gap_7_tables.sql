-- 0189 · Vá hở UPDATE (luật 2 — append-only) trên 7 bảng sự kiện bị bỏ sót khi tạo sau 0003_rls.sql
-- Bảng: crop_inputs, harvests, pos_receipts, hosp_folio (0018), irrigation_logs, pest_scouting (0046),
-- supervision_checks (0075). Cả 7 đều tạo qua itran_make_event_table() nên có itran_paper_check()
-- (BEFORE INSERT) tự UPDATE cột status='SUPERSEDED' của bản ghi cũ khi insert kèm supersedes_id.
--
-- KHÔNG dùng trigger chặn "before update or delete" kiểu 0110/0120/0164 ở đây — trigger đó chặn
-- MỌI update kể cả update nội bộ của itran_paper_check, sẽ làm hỏng luôn tính năng supersede hợp lệ
-- của 7 bảng này. Dùng đúng pattern gốc (0003_rls.sql cuối file) cho 12 bảng đầu: revoke full UPDATE,
-- chỉ grant lại UPDATE(status) — vừa chặn sửa dữ liệu nghiệp vụ, vừa giữ được supersede qua status.
do $$ declare t text; begin
  for t in select unnest(array[
    'crop_inputs','harvests','pos_receipts','hosp_folio',
    'irrigation_logs','pest_scouting','supervision_checks'
  ]) loop
    execute format('revoke update on %I from app_user', t);
    execute format('grant update (status) on %I to app_user', t);
  end loop;
end $$;
