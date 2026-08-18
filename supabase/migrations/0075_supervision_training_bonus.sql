-- 0075 · GIÁM SÁT – ĐÀO TẠO – THƯỞNG GẮN LƯƠNG
-- (1) Bộ phận giám sát: phân công người giám sát ↔ bộ phận/người bị giám sát; nhật ký kiểm tra (đạt/lỗi, mức độ, điểm) → giám sát đủ chỉ tiêu tuần = ĐỦ ĐIỀU KIỆN THƯỞNG; bộ phận bị lỗi = TRỪ THƯỞNG (không trừ lương cơ bản — BLLĐ 2019 cấm phạt tiền/cắt lương)
-- (2) Đào tạo bắt buộc: mỗi người 2–3 giờ/tuần do CẤP TRÊN trực tiếp dạy (nội dung = toàn bộ SOP/quy trình vị trí → thuần thục → lên cấp học SOP cấp trên); bài kiểm tra do người KHÁC người dạy chấm; ma trận năng lực
-- (3) Thưởng tháng = điều kiện (dạy đủ + học đủ + kiểm tra đạt + giám sát đủ) × mức thưởng − điểm trừ lỗi → ghi vào payslips.kpi_bonus khi tính lương, có sổ giải trình (bonus_ledger)
-- 0) Tham số (settings, sửa được)
insert into settings(farm_id, key, value) select 'GLOBAL', k, v::jsonb from (values
 ('training.hours_per_week','2.5'),('training.pass_score','80'),('training.session_min_minutes','60'),
 ('bonus.base_worker','1500000'),('bonus.base_team_lead','2500000'),('bonus.base_tech_head','4000000'),('bonus.base_director','6000000'),
 ('bonus.deduct_per_point','50000'),('bonus.max_deduct_pct','100'),('supervision.checks_per_week','5'),('supervision.miss_penalty_points','3')
) v(k,v) where not exists (select 1 from settings s where s.key=v.k and s.farm_id='GLOBAL');
drop function if exists setting_num(text,text,numeric);
create function setting_num(p_key text, p_farm text, p_default numeric) returns numeric language sql stable as $$
  select coalesce((select (value#>>'{}')::numeric from settings where key=p_key and farm_id in (p_farm,'GLOBAL') order by (farm_id=p_farm) desc, version desc limit 1), p_default) $$;
grant execute on function setting_num(text,text,numeric) to app_user;
-- 1) Cấp trên trực tiếp (người dạy) + người giám sát
alter table staff add column if not exists manager_id text references staff;
alter table staff add column if not exists supervisor_id text references staff;
create table if not exists supervision_assignments(
  id text primary key, farm_id text not null references farms, supervisor_id text not null references staff, target_dept text, target_staff_id text references staff, scope text, -- SOP/quy trình/khu vực
  checks_per_week int, from_date date default current_date, to_date date, active bool default true, note text, created_at timestamptz default now(), created_by text default app_staff());
alter table supervision_assignments enable row level security; drop policy if exists p_all on supervision_assignments; create policy p_all on supervision_assignments for all using (can_see_farm(farm_id)) with check (true); grant select, insert, update on supervision_assignments to app_user;
-- nhật ký kiểm tra giám sát (sự kiện append-only)
select itran_make_event_table('supervision_checks', $$
  supervisor_id text references staff, target_dept text, target_staff_id text references staff, sop_code text, task_id uuid, item text not null, result text not null check (result in ('DAT','LOI','TU_BAO_LOI')),
  severity text check (severity in ('NHE','TRUNG','NANG','NGHIEM_TRONG')), points numeric default 0, note text, evidence_url text, corrective text, corrective_due date, verified_by text, verified_at timestamptz
$$);
alter table supervision_checks enable row level security; drop policy if exists p_sel on supervision_checks; create policy p_sel on supervision_checks for select using (can_see_farm(farm_id));
drop policy if exists p_ins on supervision_checks; create policy p_ins on supervision_checks for insert with check (farm_id = app_farm() and app_role() not in ('anon'));
drop policy if exists p_upd on supervision_checks; create policy p_upd on supervision_checks for update using (farm_id = app_farm() and app_role() not in ('anon','worker'));
grant select, insert, update on supervision_checks to app_user;
create or replace function trg_supervision_points() returns trigger language plpgsql as $$
begin
  if new.result='LOI' and coalesce(new.points,0)=0 then new.points := case new.severity when 'NHE' then 1 when 'TRUNG' then 3 when 'NANG' then 6 when 'NGHIEM_TRONG' then 12 else 2 end; end if;
  if new.result='TU_BAO_LOI' then new.points := 0; end if; -- tự báo lỗi: không trừ (khuyến khích minh bạch)
  return new; end $$;
drop trigger if exists supervision_points on supervision_checks; create trigger supervision_points before insert on supervision_checks for each row execute function trg_supervision_points();
create or replace function trg_supervision_publish() returns trigger language plpgsql as $$
begin if new.result='LOI' then perform publish_event(new.farm_id, 'supervision.fault', jsonb_build_object('id', new.id, 'target_dept', new.target_dept, 'target_staff_id', new.target_staff_id, 'sop_code', new.sop_code, 'severity', new.severity, 'points', new.points, 'item', new.item)); end if; return new; end $$;
drop trigger if exists supervision_publish on supervision_checks; create trigger supervision_publish after insert on supervision_checks for each row execute function trg_supervision_publish();
insert into event_topics(topic, description, producer_dept, consumer_depts, source_table, wired) values ('supervision.fault','Giám sát phát hiện lỗi → bộ phận bị giám sát khắc phục, trừ điểm thưởng','QA','{*}','supervision_checks',true),('training.done','Buổi đào tạo hoàn thành','HCNS','{*}','training_sessions',true),('training.test','Bài kiểm tra chấm xong','HCNS','{*}','training_tests',true) on conflict (topic) do nothing;

-- 2) ĐÀO TẠO: buổi học (người dạy = cấp trên trực tiếp), bài kiểm tra (người chấm ≠ người dạy), ma trận năng lực theo SOP
create table if not exists training_sessions(
  id text primary key, farm_id text not null references farms, week_start date not null, trainer_id text not null references staff, trainee_id text not null references staff,
  topic_kind text default 'SOP', topic_code text, topic_title text, planned_hours numeric default 2.5, held_at timestamptz, actual_hours numeric, method text, -- KEM_CAP|LOP|VIDEO|THUC_HANH
  status text default 'KE_HOACH' check (status in ('KE_HOACH','XONG','BO_LO','HUY')), trainee_ack bool default false, notes text, created_at timestamptz default now(), created_by text default app_staff());
create table if not exists training_tests(
  id text primary key, farm_id text not null references farms, session_id text references training_sessions, trainee_id text not null references staff, examiner_id text references staff, sop_code text, taken_at timestamptz default now(),
  kind text default 'LY_THUYET', -- LY_THUYET|THUC_HANH
  score numeric, max_score numeric default 100, passed bool, questions jsonb default '[]'::jsonb, checklist jsonb default '[]'::jsonb, note text, created_by text default app_staff());
create table if not exists staff_competencies(
  farm_id text not null references farms, staff_id text not null references staff, sop_code text not null, level text not null default 'HOC' check (level in ('HOC','THUC_HANH','THUAN_THUC','DAY_DUOC')),
  certified_at timestamptz, certified_by text, last_test_id text, expires_on date, primary key(staff_id, sop_code));
do $$ declare t text; begin
  foreach t in array array['training_sessions','training_tests','staff_competencies'] loop
    execute format('alter table %I enable row level security', t); execute format('drop policy if exists p_all on %I', t);
    execute format('create policy p_all on %I for all using (can_see_farm(farm_id)) with check (true)', t); execute format('grant select, insert, update on %I to app_user', t);
    execute format('drop trigger if exists %s_audit on %I', t, t); execute format('create trigger %s_audit after insert or update or delete on %I for each row execute function itran_audit()', t, t);
  end loop; end $$;
-- Chương trình học của 1 vị trí = các SOP L3 thuộc quy trình phòng ban đó (processes.dept_code / visible_depts) → hàng đợi học: chưa THUAN_THUC
create or replace view v_training_curriculum as
select s.farm_id, s.id as staff_id, s.full_name, s.dept, s.role, s.manager_id, sp.code as sop_code, sp.title as sop_title, sp.l2_code, coalesce(c.level,'CHUA_HOC') as level, c.certified_at
from staff s join processes p on (p.dept_code=s.dept or s.dept = any(p.visible_depts)) and p.code like 'SOP-%' join sops sp on sp.l2_code=p.code and sp.status<>'THAY_THE'
left join staff_competencies c on c.staff_id=s.id and c.sop_code=sp.code where s.active;
grant select on v_training_curriculum to app_user;
-- lên cấp: người thuần thục 100% SOP vị trí → học SOP cấp trên (quy trình của người quản lý) — thể hiện qua "next_topic"
create or replace function next_training_topic(p_staff text) returns table(sop_code text, sop_title text, reason text) language sql stable as $$
  with own as (select sop_code, sop_title, level from v_training_curriculum where staff_id=p_staff),
  todo as (select sop_code, sop_title, 'SOP vị trí chưa thuần thục' as reason from own where level not in ('THUAN_THUC','DAY_DUOC') order by sop_code limit 1),
  up as (select sp.code, sp.title, 'Đã thuần thục vị trí → học SOP cấp trên' from staff s join staff m on m.id=s.manager_id join v_training_curriculum vc on vc.staff_id=m.id left join staff_competencies c on c.staff_id=p_staff and c.sop_code=vc.sop_code join sops sp on sp.code=vc.sop_code where s.id=p_staff and coalesce(c.level,'CHUA_HOC') not in ('THUAN_THUC','DAY_DUOC') order by sp.code limit 1)
  select * from todo union all select * from up where not exists (select 1 from todo) limit 1 $$;
grant execute on function next_training_topic(text) to app_user;
-- sinh lịch đào tạo tuần: mỗi nhân sự có manager → 1 buổi (giờ theo settings) chủ đề = next_training_topic; tạo việc cho người dạy + người học
create or replace function gen_training_week(p_farm text, p_week date default date_trunc('week', current_date)::date) returns int language plpgsql as $$
declare r record; n int := 0; t record; v_id text; hrs numeric := setting_num('training.hours_per_week',p_farm,2.5); begin
  for r in select s.id, s.full_name, s.manager_id from staff s where s.farm_id=p_farm and s.active and s.manager_id is not null loop
    if exists (select 1 from training_sessions x where x.trainee_id=r.id and x.week_start=p_week) then continue; end if;
    select * into t from next_training_topic(r.id);
    v_id := p_farm||'-DT-'||to_char(p_week,'YYMMDD')||'-'||r.id;
    insert into training_sessions(id, farm_id, week_start, trainer_id, trainee_id, topic_kind, topic_code, topic_title, planned_hours, method) values (v_id, p_farm, p_week, r.manager_id, r.id, 'SOP', t.sop_code, coalesce(t.sop_title, 'Ôn tập quy trình vị trí'), hrs, 'KEM_CAP') on conflict do nothing;
    insert into tasks(id, farm_id, kind, title, detail, due_at, role_hint, assignee_id, target_type, target_id, status, source, priority)
    values (gen_random_uuid(), p_farm, 'DAO_TAO_DAY', 'Dạy '||r.full_name||': '||coalesce(t.sop_title,'ôn quy trình')||' ('||hrs||'h)', jsonb_build_object('session_id', v_id, 'trainee_id', r.id, 'sop_code', t.sop_code, 'text', coalesce(t.reason,'')), (p_week + 6)::timestamptz + interval '17 hours', null, r.manager_id, 'training_session', v_id, 'MO', 'TRAINING', 'BINH_THUONG'),
           (gen_random_uuid(), p_farm, 'DAO_TAO_HOC', 'Học: '||coalesce(t.sop_title,'ôn quy trình')||' với cấp trên ('||hrs||'h) + kiểm tra', jsonb_build_object('session_id', v_id, 'trainer_id', r.manager_id, 'sop_code', t.sop_code), (p_week + 6)::timestamptz + interval '17 hours', null, r.id, 'training_session', v_id, 'MO', 'TRAINING', 'BINH_THUONG');
    n := n+1;
  end loop; return n; end $$;
grant execute on function gen_training_week(text,date) to app_user;
-- ghi kết quả buổi học + bài kiểm tra → cập nhật năng lực; người chấm ≠ người dạy (nếu không có người khác thì hệ thống chấm trắc nghiệm = examiner null)
create or replace function complete_training(p_session text, p_hours numeric, p_score numeric, p_examiner text default null, p_notes text default null) returns jsonb language plpgsql as $$
declare s record; pass_score numeric; v_pass bool; v_test text; lvl text; begin
  select * into s from training_sessions where id=p_session; if not found then raise exception 'ERR_NOT_FOUND'; end if;
  if p_examiner is not null and p_examiner = s.trainer_id then raise exception 'ERR_EXAMINER_IS_TRAINER: người chấm phải khác người dạy'; end if;
  pass_score := setting_num(s.farm_id,'training.pass_score',80); v_pass := p_score >= pass_score;
  update training_sessions set status='XONG', held_at=now(), actual_hours=p_hours, notes=coalesce(p_notes,notes), trainee_ack=true where id=p_session;
  v_test := p_session||'-T'; insert into training_tests(id, farm_id, session_id, trainee_id, examiner_id, sop_code, score, passed, note) values (v_test, s.farm_id, p_session, s.trainee_id, p_examiner, s.topic_code, p_score, v_pass, p_notes) on conflict (id) do update set score=excluded.score, passed=excluded.passed, taken_at=now();
  if s.topic_code is not null then
    select level into lvl from staff_competencies where staff_id=s.trainee_id and sop_code=s.topic_code;
    lvl := case when not v_pass then coalesce(lvl,'HOC') when lvl is null or lvl='HOC' then 'THUC_HANH' when lvl='THUC_HANH' then 'THUAN_THUC' else lvl end;
    insert into staff_competencies(farm_id, staff_id, sop_code, level, certified_at, certified_by, last_test_id, expires_on) values (s.farm_id, s.trainee_id, s.topic_code, lvl, case when v_pass then now() end, p_examiner, v_test, (current_date + 365))
    on conflict (staff_id, sop_code) do update set level=excluded.level, certified_at=coalesce(excluded.certified_at, staff_competencies.certified_at), certified_by=coalesce(excluded.certified_by, staff_competencies.certified_by), last_test_id=excluded.last_test_id, expires_on=excluded.expires_on;
  end if;
  update tasks set status='XONG', done_by=app_staff(), done_at=now() where target_type='training_session' and target_id=p_session and status='MO';
  perform publish_event(s.farm_id, 'training.done', jsonb_build_object('session_id', p_session, 'trainee_id', s.trainee_id, 'trainer_id', s.trainer_id, 'score', p_score, 'passed', v_pass));
  return jsonb_build_object('passed', v_pass, 'level', lvl); end $$;
grant execute on function complete_training(text,numeric,numeric,text,text) to app_user;
-- 3) THƯỞNG THÁNG: điều kiện + số tiền, ghi sổ
create table if not exists bonus_ledger(id bigserial primary key, farm_id text not null references farms, staff_id text not null references staff, period text not null, kind text not null, points numeric default 0, amount numeric default 0, ref_type text, ref_id text, note text, created_at timestamptz default now());
alter table bonus_ledger enable row level security; drop policy if exists p_all on bonus_ledger; create policy p_all on bonus_ledger for all using (can_see_farm(farm_id)) with check (true); grant select, insert, update, delete on bonus_ledger to app_user; grant usage on sequence bonus_ledger_id_seq to app_user;
create or replace function bonus_eval(p_farm text, p_period text) returns table(staff_id text, full_name text, role text, dept text, base_bonus numeric, weeks int,
  learn_hours numeric, learn_required numeric, learn_ok bool, teach_sessions int, teach_required int, teach_ok bool, tests int, tests_passed int, test_ok bool,
  supervise_checks int, supervise_required int, supervise_ok bool, fault_points numeric, deduction numeric, eligible bool, bonus numeric, mastered_all bool) language plpgsql stable as $$
declare p_from date := to_date(p_period||'-01','YYYY-MM-DD'); p_to date := (to_date(p_period||'-01','YYYY-MM-DD') + interval '1 month')::date; wk int; hpw numeric := setting_num('training.hours_per_week',p_farm,2.5); cpw numeric := setting_num('supervision.checks_per_week',p_farm,5); dpp numeric := setting_num('bonus.deduct_per_point',p_farm,50000); maxd numeric := setting_num('bonus.max_deduct_pct',p_farm,100);
begin
  wk := greatest(1, round((p_to - p_from)/7.0));
  return query
  with s as (select st.* from staff st where st.farm_id=p_farm and st.active),
  learn as (select trainee_id, coalesce(sum(actual_hours),0) as h from training_sessions where farm_id=p_farm and status='XONG' and held_at >= p_from and held_at < p_to group by 1),
  teach as (select trainer_id, count(*) as n from training_sessions where farm_id=p_farm and status='XONG' and held_at >= p_from and held_at < p_to group by 1),
  subs as (select manager_id, count(*) as n from staff where farm_id=p_farm and active and manager_id is not null group by 1),
  tst as (select trainee_id, count(*) as n, count(*) filter (where passed) as np from training_tests where farm_id=p_farm and taken_at >= p_from and taken_at < p_to group by 1),
  sup as (select supervisor_id, count(*) as n from supervision_checks where farm_id=p_farm and status='ACTIVE' and ts >= p_from and ts < p_to group by 1),
  supreq as (select supervisor_id, sum(coalesce(checks_per_week, cpw)) as per_week from supervision_assignments where farm_id=p_farm and active group by 1),
  faults as (select coalesce(target_staff_id, '') as sid, target_dept as dept, sum(points) as pts from supervision_checks where farm_id=p_farm and status='ACTIVE' and result='LOI' and ts >= p_from and ts < p_to group by 1,2),
  mast as (select vc.staff_id, bool_and(vc.level in ('THUAN_THUC','DAY_DUOC')) as all_ok from v_training_curriculum vc where vc.farm_id=p_farm group by 1)
  select s.id, s.full_name, s.role, s.dept,
    setting_num('bonus.base_'||s.role, p_farm, case s.role when 'worker' then 1500000 when 'team_lead' then 2500000 when 'tech_head' then 4000000 when 'director' then 6000000 else 0 end) as base_bonus, wk,
    coalesce(l.h,0), case when s.manager_id is null then 0 else hpw*wk end, (s.manager_id is null or coalesce(l.h,0) >= hpw*wk*0.8 or coalesce(m.all_ok,false)) as learn_ok,
    coalesce(t.n,0)::int, case when coalesce(sb.n,0)>0 then wk else 0 end, (coalesce(sb.n,0)=0 or coalesce(t.n,0) >= wk*0.8) as teach_ok,
    coalesce(ts.n,0)::int, coalesce(ts.np,0)::int, (s.manager_id is null or coalesce(m.all_ok,false) or coalesce(ts.np,0) >= 1) as test_ok,
    coalesce(su.n,0)::int, coalesce(round(sr.per_week*wk),0)::int, (sr.supervisor_id is null or coalesce(su.n,0) >= sr.per_week*wk*0.8) as supervise_ok,
    coalesce(f1.pts,0) + coalesce(f2.pts,0)/greatest((select count(*) from staff x where x.farm_id=p_farm and x.active and x.dept=s.dept),1) as fault_points,
    least((coalesce(f1.pts,0) + coalesce(f2.pts,0)/greatest((select count(*) from staff x where x.farm_id=p_farm and x.active and x.dept=s.dept),1)) * dpp, setting_num('bonus.base_'||s.role, p_farm, 1500000) * maxd/100) as deduction,
    ((s.manager_id is null or coalesce(l.h,0) >= hpw*wk*0.8 or coalesce(m.all_ok,false)) and (coalesce(sb.n,0)=0 or coalesce(t.n,0) >= wk*0.8) and (s.manager_id is null or coalesce(m.all_ok,false) or coalesce(ts.np,0) >= 1) and (sr.supervisor_id is null or coalesce(su.n,0) >= sr.per_week*wk*0.8)) as eligible,
    greatest(0, case when ((s.manager_id is null or coalesce(l.h,0) >= hpw*wk*0.8 or coalesce(m.all_ok,false)) and (coalesce(sb.n,0)=0 or coalesce(t.n,0) >= wk*0.8) and (s.manager_id is null or coalesce(m.all_ok,false) or coalesce(ts.np,0) >= 1) and (sr.supervisor_id is null or coalesce(su.n,0) >= sr.per_week*wk*0.8)) then setting_num('bonus.base_'||s.role, p_farm, 1500000) else 0 end
      - least((coalesce(f1.pts,0) + coalesce(f2.pts,0)/greatest((select count(*) from staff x where x.farm_id=p_farm and x.active and x.dept=s.dept),1)) * dpp, setting_num('bonus.base_'||s.role, p_farm, 1500000) * maxd/100)) as bonus,
    coalesce(m.all_ok,false)
  from s left join learn l on l.trainee_id=s.id left join teach t on t.trainer_id=s.id left join subs sb on sb.manager_id=s.id left join tst ts on ts.trainee_id=s.id left join sup su on su.supervisor_id=s.id left join supreq sr on sr.supervisor_id=s.id
  left join faults f1 on f1.sid=s.id left join faults f2 on f2.sid='' and f2.dept=s.dept left join mast m on m.staff_id=s.id
  order by s.dept, s.id; end $$;
grant execute on function bonus_eval(text,text) to app_user;
-- chốt thưởng tháng vào sổ (kế toán/GĐ) → payslips.kpi_bonus khi tính lương
create or replace function close_bonus(p_farm text, p_period text) returns int language plpgsql as $$
declare r record; n int := 0; begin
  delete from bonus_ledger where farm_id=p_farm and period=p_period and kind='THUONG_THANG';
  for r in select * from bonus_eval(p_farm, p_period) loop
    insert into bonus_ledger(farm_id, staff_id, period, kind, points, amount, note) values (p_farm, r.staff_id, p_period, 'THUONG_THANG', r.fault_points, r.bonus,
      format('học %s/%sh · dạy %s/%s buổi · KT đạt %s/%s · giám sát %s/%s · điểm lỗi %s → trừ %s', r.learn_hours, r.learn_required, r.teach_sessions, r.teach_required, r.tests_passed, r.tests, r.supervise_checks, r.supervise_required, r.fault_points, r.deduction)); n := n+1;
  end loop; return n; end $$;
grant execute on function close_bonus(text,text) to app_user;
-- compute_payroll: cộng thưởng đã chốt vào kpi_bonus (nếu compute_payroll hiện có, bọc lại: sau khi tính, cập nhật payslips)
create or replace function apply_bonus_to_payroll(p_farm text, p_month date) returns int language plpgsql as $$
declare n int; begin
  update payslips p set kpi_bonus = coalesce(b.amount,0), gross = p.gross - coalesce(p.kpi_bonus,0) + coalesce(b.amount,0), net = p.net - coalesce(p.kpi_bonus,0) + coalesce(b.amount,0),
    detail = coalesce(p.detail,'{}'::jsonb) || jsonb_build_object('bonus_note', b.note)
  from bonus_ledger b where b.farm_id=p_farm and b.staff_id=p.staff_id and b.period=to_char(p_month,'YYYY-MM') and b.kind='THUONG_THANG' and p.farm_id=p_farm and p.month=p_month;
  get diagnostics n = row_count; return n; end $$;
grant execute on function apply_bonus_to_payroll(text,date) to app_user;
-- cảnh báo: tuần này chưa học/chưa dạy, giám sát thiếu lượt
insert into alert_rules(code, version, farm_id, name, source, expr, level, recipients, channels, cooldown_min, active)
select v.code, 1, 'GLOBAL', v.name, 'custom', v.expr::jsonb, v.level, v.rec::text[], '{app}'::text[], v.cd, true from (values
 ('AL-TRAIN-WEEK','Buổi đào tạo tuần chưa hoàn thành (T6)','{"type":"sql_rows","sql":"select s.full_name as ref, t.topic_title as value from training_sessions t join staff s on s.id=t.trainee_id where t.farm_id=$1 and t.week_start=date_trunc(''week'',current_date)::date and t.status=''KE_HOACH'' and extract(dow from current_date)>=5","message":"{ref} chưa hoàn thành đào tạo tuần ({value}) — ảnh hưởng thưởng tháng cả người học và người dạy"}','VANG','{team_lead,tech_head,director}',1440),
 ('AL-SUP-WEEK','Giám sát chưa đủ lượt kiểm tra tuần','{"type":"sql_rows","sql":"select s.full_name as ref, count(c.id) as value, coalesce(max(a.checks_per_week),5) as req from supervision_assignments a join staff s on s.id=a.supervisor_id left join supervision_checks c on c.supervisor_id=a.supervisor_id and c.ts>=date_trunc(''week'',current_date) and c.status=''ACTIVE'' where a.farm_id=$1 and a.active group by s.full_name having count(c.id) < coalesce(max(a.checks_per_week),5)*0.6 and extract(dow from current_date)>=4","message":"Giám sát {ref}: {value}/{req} lượt kiểm tra tuần"}','VANG','{tech_head,director}',1440)
) as v(code, name, expr, level, rec, cd) where not exists (select 1 from alert_rules a where a.code=v.code);
