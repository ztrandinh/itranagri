-- 0124 — Gán việc theo CHỖ NGỒI + dọn việc quá hạn theo CHU KỲ
--
-- Vấn đề người dùng nặng nhất của cả hệ, đo được trước khi sửa:
--   12.751 việc đang mở  ·  34 việc có người nhận (0,27%)  ·  10.083 việc quá hạn
-- Hệ quả trên máy: A1 TMR, A2 Sinh sản, A3 Gà, A4 RAS, A5 Lái máy mở app ra THẤY Y HỆT NHAU
-- — cùng "300 việc · 296 quá hạn", việc đứng đầu đều là "Cân định kỳ bò" dù A3 nuôi gà,
-- A4 nuôi cá. Công nhân nhìn một lần rồi bỏ qua toàn bộ, kể cả việc thật của mình.
--
-- Nguyên tắc: gán vào CHỖ NGỒI, không gán vào người. Người nghỉ thì đóng nhiệm kỳ, người mới
-- nhận tiếp, việc không mồ côi. `assignee_id` giữ người ĐANG giữ ghế để hộp thư hiển thị được
-- ngay; `role_hint` giữ mã nghề làm dự phòng khi ghế trống hoặc đang bàn giao.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Hai hàm dùng chung — đã thống nhất với phiên "Tiếp tục ITRAN OS" để hai bên bám một chuẩn
-- ─────────────────────────────────────────────────────────────────────────────

/** Ai đang giữ chỗ ngồi này (ưu tiên đúng ca, rồi tới người chịu trách nhiệm chính).
 *  Ghế trống -> null, việc rơi về role_hint thay vì mồ côi. */
create or replace function staff_of_account(p_account text, p_shift text default 'HC')
returns text language sql stable as $$
  select h.staff_id from account_holders h
   where h.account_code = p_account and h.to_date is null
   order by (h.shift = p_shift) desc, h.is_primary desc, h.from_date
   limit 1 $$;

/** Chỗ ngồi + nghề của một người. */
create or replace function account_of_staff(p_staff text)
returns table(account_code text, position_code text) language sql stable as $$
  select a.code, a.position_code from job_accounts a
    join account_holders h on h.account_code = a.code and h.to_date is null
   where h.staff_id = p_staff
   limit 1 $$;

grant execute on function staff_of_account(text,text), account_of_staff(text) to app_user;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Gán việc đang mở cho người đang giữ ghế đúng nghề
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function assign_open_tasks(p_farm text default null)
returns text language plpgsql security definer as $$
declare n_nghe int := 0; n_vai int := 0;
begin
  -- 2a. role_hint dạng 'worker:A3' -> chia đều cho những người đang giữ ghế nghề A3.
  with ghe as (
    select a.position_code, h.staff_id,
           row_number() over (partition by a.position_code order by h.is_primary desc, a.seq) as thu_tu,
           count(*)      over (partition by a.position_code) as tong
    from job_accounts a
    join account_holders h on h.account_code = a.code and h.to_date is null
    where a.active and a.position_code is not null
  ),
  viec as (
    select t.id, substring(t.role_hint from 'worker:(.+)') as nghe,
           row_number() over (partition by t.role_hint order by t.due_at, t.id) as stt
    from tasks t
    where t.status in ('MO','DANG_LAM','TREO') and t.assignee_id is null
      and t.role_hint like 'worker:%'
      and (p_farm is null or t.farm_id = p_farm)
  )
  update tasks t set assignee_id = g.staff_id
  from viec v join ghe g on g.position_code = v.nghe and g.thu_tu = 1 + (v.stt - 1) % g.tong
  where t.id = v.id;
  get diagnostics n_nghe = row_count;

  -- 2b. role_hint là VAI THÔ ('worker', 'team_lead', 'tech_head'…): chia đều cho người
  --     đang giữ ghế có vai đó. Đây là 11.400 việc đang khiến mọi công nhân thấy giống hệt nhau.
  with ghe as (
    select a.role_code, h.staff_id,
           row_number() over (partition by a.role_code order by a.dept_code, a.seq) as thu_tu,
           count(*)      over (partition by a.role_code) as tong
    from job_accounts a
    join account_holders h on h.account_code = a.code and h.to_date is null
    where a.active
  ),
  viec as (
    select t.id, t.role_hint as vai,
           row_number() over (partition by t.role_hint order by t.due_at, t.id) as stt
    from tasks t
    where t.status in ('MO','DANG_LAM','TREO') and t.assignee_id is null
      and t.role_hint is not null and t.role_hint not like 'worker:%'
      and (p_farm is null or t.farm_id = p_farm)
  )
  update tasks t set assignee_id = g.staff_id
  from viec v join ghe g on g.role_code = v.vai and g.thu_tu = 1 + (v.stt - 1) % g.tong
  where t.id = v.id;
  get diagnostics n_vai = row_count;

  return format('Gán %s việc theo nghề + %s việc theo vai. Còn %s việc mở chưa có người.',
                n_nghe, n_vai,
                (select count(*) from tasks where status in ('MO','DANG_LAM','TREO') and assignee_id is null));
end $$;
grant execute on function assign_open_tasks(text) to app_user;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Dọn việc quá hạn theo CHU KỲ — KHÔNG xoá, chỉ dời hạn
--    Xoá là mất dấu vết; dời hạn theo đúng nhịp của từng luật thì việc quay lại đúng lúc,
--    và trải đều thay vì dồn cục vào một ngày.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function reschedule_overdue_tasks(p_farm text default null)
returns text language plpgsql security definer as $$
declare n int := 0;
begin
  with chu_ky(rule_code, so_ngay) as (values
    ('T-ALERT', 1), ('T-SO-HOA', 1), ('T-CHECKLIST', 1),
    ('T-BAO-DUONG', 30), ('T-KIEM-KE', 30),
    ('T-VAC-2f8577', 90), ('T-VAC-b832dd', 90), ('T-VAC-72a356', 90)
  ),
  qua_han as (
    select t.id, coalesce(c.so_ngay, 7) as so_ngay,
           row_number() over (partition by coalesce(t.rule_code,'?') order by t.due_at, t.id) as stt
    from tasks t left join chu_ky c on c.rule_code = t.rule_code
    where t.status in ('MO','DANG_LAM','TREO') and t.due_at < now()
      and (p_farm is null or t.farm_id = p_farm)
  )
  update tasks t
     set due_at = date_trunc('day', now())
                + ((q.stt - 1) % q.so_ngay) * interval '1 day'   -- trải đều trong đúng chu kỳ
                + interval '8 hours'                              -- đầu ca sáng
  from qua_han q where t.id = q.id;
  get diagnostics n = row_count;

  return format('Dời hạn %s việc quá hạn theo chu kỳ. Còn %s việc quá hạn.',
                n, (select count(*) from tasks where status in ('MO','DANG_LAM','TREO') and due_at < now()));
end $$;
grant execute on function reschedule_overdue_tasks(text) to app_user;

select assign_open_tasks();
select reschedule_overdue_tasks();
