-- 0092 · LIÊN THÔNG PHÒNG BAN qua quy trình (bật notify_roles vốn khai báo ở 0023 nhưng chưa dùng)
-- Ý tưởng: khi 1 bước của phòng A XONG mà bước kế thuộc phòng B → tự nhắc phòng B ("đến phần của bạn").
-- Additive: chỉ ĐIỀN dữ liệu + THÊM trigger; không sửa hàm workflow của bản gốc (tránh xung đột).

-- 1) Tự điền notify_roles cho các bước có BÀN GIAO CHÉO PHÒNG (bước kế khác dept), nếu chưa điền.
with nx as (
  select id, dept_code,
         lead(actor_role) over (partition by process_code order by step_no) as next_role,
         lead(dept_code)  over (partition by process_code order by step_no) as next_dept
  from process_steps
)
update process_steps s
set notify_roles = array[nx.next_role]
from nx
where nx.id = s.id
  and nx.next_role is not null
  and nx.next_dept is distinct from s.dept_code            -- chỉ khi đổi phòng
  and s.dept_code is not null
  and (s.notify_roles is null or array_length(s.notify_roles, 1) is null);

-- 2) Trigger: bước chạy XONG → sinh "tin phối hợp" (INFO) cho các vai trong notify_roles của bước đó.
create or replace function notify_step_handoff() returns trigger language plpgsql as $$
declare nr text[]; fh text;
begin
  if new.status = 'XONG' and (old.status is distinct from 'XONG') then
    select ps.notify_roles into nr
    from process_steps ps join process_runs r on r.id = new.run_id
    where ps.process_code = r.process_code and ps.step_no = new.step_no;
    if nr is not null and array_length(nr, 1) > 0 then
      insert into notifications(farm_id, staff_id, level, title, body, link, source, source_id)
      select r.farm_id, s.id, 'INFO',
             'Phối hợp: đã xong "' || coalesce(new.name, 'bước ' || new.step_no) || '"',
             'Phòng ' || coalesce(new.dept_code, '?') || ' hoàn tất — đến phần của bạn (quy trình ' || r.process_code || ')',
             '/to-chuc?tab=chay', 'handoff', new.run_id::text || ':' || new.step_no
      from process_runs r
      join staff s on s.active and s.role = any(nr)
        and (s.farm_id = r.farm_id or s.farm_id is null or r.farm_id = any(s.farm_ids))
      where r.id = new.run_id
        and s.id <> coalesce(new.done_by, '')            -- không tự báo cho người vừa làm
      on conflict do nothing;
    end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_notify_step_handoff on process_run_steps;
create trigger trg_notify_step_handoff after update on process_run_steps
  for each row execute function notify_step_handoff();
