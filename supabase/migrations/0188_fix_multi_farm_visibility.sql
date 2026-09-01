-- 0188 · Vá lỗi can_see_farm() bỏ qua farm_ids của mọi role trừ owner/auditor
-- Bug: staff.farm_ids ("các trại được xem — owner/auditor/HQ", 0001_master.sql:34) được set cho
-- cả director đa trại (CEO/HQ dùng chung role 'director' theo seed), nhưng can_see_farm() chỉ đọc
-- app_farms() khi app_role() in ('owner','auditor') — mọi role khác (director/tech_head/accountant/
-- it_engineer...) bị ép về đúng 1 app_farm() dù farm_ids của họ có nhiều trại. Hệ quả: dashboard /hq
-- và cảnh báo dịch liên vùng (v_epi_region*, chạy bằng it_engineer) âm thầm thiếu số cho đúng vai trò
-- cần xem đa trại nhất — không có lỗi hiển thị.
--
-- Fix: quyền xem chéo trại đi theo đúng farm_ids đã gán cho NHÂN SỰ đó (không gate thêm theo tên role).
-- Giữ nguyên hành vi "farm_ids rỗng = xem hết" chỉ cho owner/auditor (siêu quản trị mặc định), tránh
-- vô tình mở toang cho role khác nếu ai đó quên set farm_ids.
create or replace function can_see_farm(p_farm text) returns bool language sql stable as $$
  select p_farm = app_farm()
      or p_farm = any(app_farms())
      or (app_role() in ('owner','auditor') and cardinality(app_farms()) = 0)
$$;
