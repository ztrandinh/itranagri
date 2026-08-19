-- 0125 — Gán việc theo ĐÚNG PHÒNG/NGHỀ, không chỉ theo vai thô
--
-- 0124 mới chia đều theo vai ('worker', 'team_lead'…) nên hết cảnh mọi người thấy giống nhau,
-- NHƯNG gán sai nghề. Đo được ngay trên giao diện sau 0124:
--   a2 (A2 Chăm sóc bò)  nhận "Checklist ca sáng SOP-TOM-04 — Kéo bè trú lũ"
--   a3 (A3 Chăm sóc gà)  nhận "Checklist ca sáng SOP-HC-01 — Kế toán P&L phân hệ"
--   a2 ôm 224 việc trong khi các vai khác chỉ 2-3 việc
-- Giao đúng người mà sai nghề thì công nhân vẫn bỏ qua — chỉ đổi kiểu vô dụng.
--
-- Việc CHECKLIST có `sop_code`; SOP có `dept`. Ghép hai thứ đó lại là ra đúng phòng phải làm.

create or replace function reassign_tasks_by_dept(p_farm text default null)
returns text language plpgsql security definer as $$
declare n int := 0;
begin
  with ghe as (
    select a.dept_code, a.role_code, h.staff_id,
           row_number() over (partition by a.dept_code, a.role_code order by a.seq) as thu_tu,
           count(*)      over (partition by a.dept_code, a.role_code) as tong
    from job_accounts a
    join account_holders h on h.account_code = a.code and h.to_date is null
    where a.active and a.dept_code is not null
  ),
  viec as (
    -- phòng của việc = phòng của SOP nó chạy
    select t.id, s.dept as phong, coalesce(t.role_hint, 'worker') as vai,
           row_number() over (partition by s.dept, coalesce(t.role_hint,'worker') order by t.due_at, t.id) as stt
    from tasks t
    join sops s on s.code = t.sop_code
    where t.status in ('MO','DANG_LAM','TREO') and s.dept is not null
      and (p_farm is null or t.farm_id = p_farm)
  )
  update tasks t set assignee_id = g.staff_id
  from viec v
  join ghe g on g.dept_code = v.phong
            and g.role_code = case when v.vai like 'worker%' then 'worker' else v.vai end
            and g.thu_tu = 1 + (v.stt - 1) % g.tong
  where t.id = v.id and t.assignee_id is distinct from g.staff_id;
  get diagnostics n = row_count;

  return format('Gán lại %s việc theo đúng phòng của SOP. Việc mở chưa có người: %s.',
                n, (select count(*) from tasks where status in ('MO','DANG_LAM','TREO') and assignee_id is null));
end $$;
grant execute on function reassign_tasks_by_dept(text) to app_user;

select reassign_tasks_by_dept();
-- Người nào không thuộc phòng của SOP thì 0124 đã gán, nay trả về đúng phòng; phần còn sót
-- (SOP không khai phòng) vẫn giữ kết quả 0124 để không có việc nào mồ côi.
select assign_open_tasks();
