-- 0193 · Vá hở UPDATE (luật 2 — append-only) trên adjustments/paper_scans, bỏ sót khi 0189 chỉ vá 7 bảng khác
-- Live-verified: 0003_rls.sql dòng 31 grant UPDATE toàn cột cho MỌI bảng có farm_id (kể cả 2 bảng này) qua vòng
-- lặp chung; dòng 71-72 sau đó chỉ THÊM grant cột hẹp (adj_status/digitized...), KHÔNG revoke trước — nên
-- team_lead vẫn UPDATE được delta/reason/target_id của adjustments (bảng điều chỉnh có phê duyệt) không vết.
-- Theo đúng pattern 0189: revoke full UPDATE, chỉ grant lại đúng cột trạng thái/duyệt.
revoke update on adjustments from app_user;
grant update (adj_status, approved_by, approved_at, status) on adjustments to app_user;
revoke update on paper_scans from app_user;
grant update (digitized, digitized_by, digitized_ts, linked_ids, anomaly, status) on paper_scans to app_user;
