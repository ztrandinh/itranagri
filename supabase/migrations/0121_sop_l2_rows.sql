-- 0121 — Tạo dòng SOP cấp L2 còn thiếu
--
-- Bộ SOP có 81 quy trình L2 và 422 bước L3 (Quyển 3 §15). Nhưng trong CSDL chỉ có các dòng
-- L3; L2 chỉ tồn tại dưới dạng GIÁ TRỊ trong cột `l2_code` của con, KHÔNG có dòng riêng.
--
-- Hậu quả đo được: form "Checklist ca theo SOP" ghi `sop_code = 'SOP-AT-01'` thì bị
-- `checklist_runs_sop_code_fkey` chặn, bản ghi KHÔNG xuống CSDL — dù giao diện vẫn báo
-- "Đã ghi" (lỗi riêng, xem NO-5). Công nhân tưởng đã chấm checklist xong, thực tế mất trắng.
--
-- Tạo dòng L2 từ chính dữ liệu con: mã, tên nhóm, phòng, chuỗi L1.

insert into sops (code, org_id, title, dept, l1_chain, l2_group, status, version, l2_code, l3_no)
select c.l2_code,
       min(c.org_id),
       coalesce(min(c.l2_group), c.l2_code)          as title,
       min(c.dept),
       min(c.l1_chain),
       min(c.l2_group),
       'BAN_HANH',                                    -- L2 là quy trình đang chạy ngoài trại
       1,
       null, null
from sops c
where c.l2_code is not null and c.l3_no is not null
  and not exists (select 1 from sops p where p.code = c.l2_code)
group by c.l2_code;

-- Bước L3 phải trỏ về đúng dòng cha vừa tạo (trước đây l2_code là chuỗi tự do, không ràng buộc).
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'sops_l2_code_fkey') then
    alter table sops add constraint sops_l2_code_fkey foreign key (l2_code) references sops(code);
  end if;
exception when others then
  raise notice 'Chưa gắn được khoá ngoại l2_code: %', sqlerrm;
end $$;
