-- 0076 · setting_num giữ chữ ký gốc (p_key, p_farm, p_default) như 0036 (payroll); 0075 gọi theo thứ tự này
drop function if exists setting_num(text,text,numeric);
create function setting_num(p_key text, p_farm text, p_default numeric) returns numeric language sql stable as $$
  select coalesce((select (value#>>'{}')::numeric from settings where key=p_key and farm_id in (p_farm,'GLOBAL') order by (farm_id=p_farm) desc, version desc limit 1), p_default) $$;
grant execute on function setting_num(text,text,numeric) to app_user;

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

