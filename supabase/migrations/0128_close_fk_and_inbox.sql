-- 0128 — Đóng nốt 2 cột tham chiếu + vá my_inbox() cho hai con số thôi đá nhau
--
-- ══ PHẦN 1: 63 "dòng mồ côi" — soi kỹ thì KHÔNG phải mồ côi, mà là cột ĐA HÌNH ══
--
-- supervision_criteria.sop_code (59 dòng) chứa MÃ QUY TRÌNH, không phải mã SOP:
--     P-CCU-01, P-CCU-02, P-CN-01, P-CT-01…
-- Đây là do `sync_process_criteria` sinh tiêu chí giám sát từ QUY TRÌNH phòng ban (SC-P-*).
-- Cột tên là `sop_code` nhưng thực tế giữ mã của HAI danh mục khác nhau.
-- Ép khoá ngoại vào `sops` là SAI THIẾT KẾ — sẽ chặn mất luồng tiêu chí theo quy trình.
-- Cách đúng: ràng buộc mã phải tồn tại ở MỘT TRONG HAI danh mục, bằng trigger kiểm tra.
--
-- training_tests.sop_code (4 dòng): SOP-KH-01, SOP-TY-01 — mã SOP hợp lệ nhưng THIẾU DÒNG
-- trong `sops` (giống hệt chuyện 81 dòng L2 thiếu ở 0121). Dựng bù rồi khai khoá ngoại.

-- 1a. Dựng bù dòng SOP còn thiếu mà nơi khác đang trỏ tới
insert into sops (code, org_id, title, dept, status, version)
select distinct t.sop_code, 'ITRAN', t.sop_code, null, 'BAN_HANH', 1
from training_tests t
where t.sop_code is not null
  and t.sop_code ~ '^SOP-'
  and not exists (select 1 from sops s where s.code = t.sop_code)
on conflict (code) do nothing;

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'fk_training_tests_sop_code') then
    alter table training_tests add constraint fk_training_tests_sop_code
      foreign key (sop_code) references sops(code) not valid;
  end if;
exception when others then raise notice 'training_tests.sop_code: %', sqlerrm; end $$;

-- 1b. supervision_criteria.sop_code — cột đa hình, dùng trigger thay cho khoá ngoại
create or replace function trg_criteria_code_exists() returns trigger language plpgsql as $$
begin
  if new.sop_code is null then return new; end if;
  if exists (select 1 from sops s where s.code = new.sop_code)
     or exists (select 1 from processes p where p.code = new.sop_code) then
    return new;
  end if;
  raise exception 'ERR_NO_SOP_OR_PROCESS: % không có trong danh mục SOP lẫn danh mục quy trình', new.sop_code;
end $$;
drop trigger if exists criteria_code_exists on supervision_criteria;
create trigger criteria_code_exists before insert or update on supervision_criteria
  for each row execute function trg_criteria_code_exists();

comment on column supervision_criteria.sop_code is
  'ĐA HÌNH: giữ mã SOP (SOP-XX-NN) HOẶC mã quy trình (P-XX-NN). Không khai khoá ngoại được; trigger criteria_code_exists kiểm tra mã có ở một trong hai danh mục.';

-- ══ PHẦN 2: my_inbox() — hai con số trên cùng màn hình đang đá nhau ══
--
-- Công nhân thấy "Hôm nay của tôi (13)" ngay cạnh "Việc hôm nay (2)" và không biết tin con nào.
-- CaPanel đã sửa (chỉ đếm việc ĐÍCH DANH), còn my_inbox() vẫn đếm mọi việc đến hạn trong 2 ngày.
-- Vá đúng nhánh VIEC, KHÔNG đụng nhánh giám sát (my_inbox_gs) dùng chung với mảng phiên kia.
-- Bám CHỖ NGỒI chứ không bám người: người nghỉ thì việc vẫn nằm đúng ghế.
do $$
declare src text; moi text;
  neo  text := 'from tasks t where t.farm_id=p_farm and t.status in (''MO'',''DANG_LAM'',''TREO'') and t.due_at <= now() + interval ''2 days''';
  them text := ' and (t.assignee_id = p_staff or t.role_hint = ''worker:'' || coalesce((select a.position_code from job_accounts a join account_holders h on h.account_code = a.code and h.to_date is null where h.staff_id = p_staff limit 1), ''~''))';
begin
  select pg_get_functiondef(p.oid) into src
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'my_inbox' limit 1;
  if src is null then raise notice 'Không thấy my_inbox()'; return; end if;
  if position(neo in src) = 0 then
    raise notice 'my_inbox(): không khớp mệnh đề neo — BỎ QUA, không sửa mù. Cần vá tay.';
    return;
  end if;
  if position(them in src) > 0 then raise notice 'my_inbox(): đã vá rồi'; return; end if;
  moi := replace(src, neo, neo || them);
  execute moi;
  raise notice 'my_inbox(): đã vá nhánh VIEC — chỉ còn đếm việc đích danh.';
end $$;
