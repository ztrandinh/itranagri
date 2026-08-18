-- 0090 · GIÁM SÁT HẰNG NGÀY theo QUY TRÌNH của từng phòng · kiểm cả thợ lẫn trưởng phòng · GS bỏ sót lỗi hệ thống đã thấy = lỗi của GS → mất thưởng
-- 1) Mỗi phòng có quy trình rõ (processes 146 + process_steps.control) → sinh BỘ TIÊU CHÍ KIỂM của phòng (MANUAL) để GS chấm hằng ngày/tuần
alter table supervision_criteria add column if not exists process_code text, add column if not exists role_scope text; -- role_scope: 'TRUONG_PHONG' = chỉ chấm trưởng phòng
create or replace function sync_process_criteria() returns int language plpgsql as $$
declare n int := 0; r record; ctl text; freq text;
begin
  for r in select p.code, p.name, p.dept_code, p.trigger_text, p.kpi, p.sop_code from processes p where p.active is distinct from false and p.dept_code is not null and p.dept_code not in ('HDQT','GDT','MR','RD','XNK') loop
    select string_agg(coalesce(nullif(control,''), name), ' · ' order by step_no) into ctl from (select control, name, step_no from process_steps where process_code=r.code and (control is not null or checklist is not null) order by step_no limit 4) x;
    freq := case when r.trigger_text ilike '%ngày%' or r.trigger_text ilike '%ca%' then 'NGAY' when r.trigger_text ilike '%tuần%' then 'TUAN' when r.trigger_text ilike '%tháng%' then 'THANG' else 'TUAN' end;
    insert into supervision_criteria(id, org_id, dept_code, name, what, method, unit, target, direction, weight, severity, frequency, sop_code, active, process_code)
      values ('SC-P-'||r.code, 'ITRAN', r.dept_code, r.name, coalesce(ctl, 'Làm đúng các bước; có bằng chứng ghi trong hệ thống')||coalesce(' · KPI: '||r.kpi,''), 'MANUAL', null, null, null, 1, 'TRUNG', freq, coalesce(r.sop_code, r.code), true, r.code)
      on conflict (id) do update set name=excluded.name, what=excluded.what, dept_code=excluded.dept_code, frequency=excluded.frequency, process_code=excluded.process_code, active=true;
    n := n+1;
  end loop;
  -- Tiêu chí riêng cho TRƯỞNG PHÒNG (tuyến 1): tự kiểm, giao việc, dạy, CAPA, việc phòng không quá hạn
  insert into supervision_criteria(id, org_id, dept_code, name, what, method, sql, unit, target, direction, weight, severity, frequency, active, role_scope) values
   ('SC-TP-01','ITRAN',null,'Trưởng phòng đi tự kiểm & giao việc rõ đầu ca','Có mặt đầu ca, phân việc trên app (tasks assignee) hoặc bảng, đi 1 vòng khu vực','MANUAL',null,null,null,null,2,'TRUNG','NGAY',true,'TRUONG_PHONG'),
   ('SC-TP-02','ITRAN',null,'Trưởng phòng dạy đủ giờ tuần','Buổi dạy XONG trong tuần','AUTO','select s.id, coalesce(sum(t.actual_hours),0) as value, setting_num(''training.hours_per_week'',$1,2.5) as target from staff s left join training_sessions t on t.trainer_id=s.id and t.status=''XONG'' and t.held_at>=$2 and t.held_at<$3 where s.farm_id=$1 and s.active and s.role in (''tech_head'',''team_lead'') group by s.id','giờ',2.5,'>=',2,'TRUNG','TUAN',true,'TRUONG_PHONG'),
   ('SC-TP-03','ITRAN',null,'CAPA đúng hạn (lỗi giám sát có biện pháp ≤ T2)','Lỗi tuần trước còn thiếu biện pháp','AUTO','select h.id, count(c.id) as value, 0 as target from staff h left join supervision_checks c on c.farm_id=h.farm_id and coalesce(c.target_dept,(select dept from staff x where x.id=c.target_staff_id))=h.dept and c.result=''LOI'' and c.week_start=$2::date-7 and c.corrective is null where h.farm_id=$1 and h.active and h.role in (''tech_head'',''team_lead'') group by h.id','lỗi',0,'<=',2,'NANG','TUAN',true,'TRUONG_PHONG'),
   ('SC-TP-04','ITRAN',null,'Việc của phòng không quá hạn','Việc mở quá hạn của nhân sự trong phòng','AUTO','select h.id, count(t.id) as value, 2 as target from staff h left join staff w on w.farm_id=h.farm_id and w.dept=h.dept and w.active left join tasks t on t.farm_id=h.farm_id and t.assignee_id=w.id and t.status in (''MO'',''DANG_LAM'') and t.due_at<$3 where h.farm_id=$1 and h.active and h.role in (''tech_head'',''team_lead'') group by h.id','việc',2,'<=',2,'TRUNG','TUAN',true,'TRUONG_PHONG'),
   ('SC-TP-05','ITRAN',null,'Lỗi lặp trong phòng (≥3 tuần cùng lỗi)','Số lỗi lặp','AUTO','select h.id, count(*) as value, 0 as target from staff h left join v_repeat_faults r on r.farm_id=h.farm_id and r.dept=h.dept where h.farm_id=$1 and h.active and h.role in (''tech_head'',''team_lead'') group by h.id','lỗi',0,'<=',3,'NANG','TUAN',true,'TRUONG_PHONG')
  on conflict (id) do update set name=excluded.name, what=excluded.what, sql=excluded.sql, target=excluded.target, direction=excluded.direction, role_scope=excluded.role_scope, active=true;
  return n;
end $$;
select sync_process_criteria();
grant execute on function sync_process_criteria() to app_user;
-- 2) LỖI CỦA GS (bỏ sót / không kiểm / không kiểm trưởng phòng) — máy ghi, GS không sửa được
create table if not exists gs_omissions(
  id uuid primary key default gen_random_uuid(), farm_id text not null, supervisor_id text not null, day date not null, kind text not null check (kind in ('BO_SOT_LOI','KHONG_KIEM','KHONG_KIEM_TRUONG_PHONG','KHONG_XU_LY_LOI')),
  target_dept text, target_staff_id text, criteria_id text, detail text, points numeric not null default 2, created_at timestamptz default now()
);
create unique index if not exists ux_gs_omissions on gs_omissions(supervisor_id, day, kind, coalesce(target_staff_id,''), coalesce(criteria_id,''), coalesce(target_dept,''));
alter table gs_omissions enable row level security; drop policy if exists p_all on gs_omissions; create policy p_all on gs_omissions for all using (can_see_farm(farm_id)) with check (true); grant select, insert on gs_omissions to app_user;
-- Việc GS phải làm hằng ngày với mỗi phòng được phân công: (a) có ít nhất N lượt kiểm/ngày làm việc; (b) mọi lỗi dữ liệu tự động phát hiện phải được GS ghi (LOI) hoặc xem-xác nhận trong 24h; (c) mỗi tuần kiểm trưởng phòng ≥1 lần
create or replace function gen_gs_omissions(p_farm text, p_day date default current_date - 1) returns int language plpgsql as $$
declare n int := 0; a record; f record; wk date := date_trunc('week', p_day)::date; minchk int := setting_num('gs.daily_checks_min', p_farm, 2)::int; pts_day numeric := setting_num('gs.omission_points_day', p_farm, 3); pts_fault numeric := setting_num('gs.omission_points_fault', p_farm, 2); dow int := extract(isodow from p_day);
begin
  for a in select distinct supervisor_id, target_dept from supervision_assignments where farm_id=p_farm and active and target_dept is not null and from_date <= p_day and (to_date is null or to_date >= p_day) and current_grade(supervisor_id,'GS') is not null loop
    -- (a) ngày làm việc T2–T7 không có lượt kiểm nào cho phòng đó (không tính khi GS nghỉ phép được duyệt / đang có người thay)
    if dow between 1 and 6 and not exists (select 1 from leave_requests l where l.staff_id=a.supervisor_id and l.status='DUYET' and p_day between l.from_date and l.to_date)
       and (select count(*) from supervision_checks c where c.supervisor_id=a.supervisor_id and c.ts::date=p_day and coalesce(c.target_dept,(select dept from staff where id=c.target_staff_id))=a.target_dept) < minchk then
      insert into gs_omissions(farm_id,supervisor_id,day,kind,target_dept,detail,points) values (p_farm,a.supervisor_id,p_day,'KHONG_KIEM',a.target_dept,'Không đủ '||minchk||' lượt kiểm phòng '||a.target_dept||' trong ngày',pts_day) on conflict (supervisor_id, day, kind, coalesce(target_staff_id,''), coalesce(criteria_id,''), coalesce(target_dept,'')) do nothing; n:=n+1;
    end if;
    -- (b) lỗi hệ thống tự phát hiện (điểm AUTO tuần này/tuần trước không đạt, việc quá hạn >1 ngày) mà GS chưa ghi/xác nhận
    for f in select ss.staff_id, ss.criteria_id, cr.name from supervision_scores ss join staff s on s.id=ss.staff_id join supervision_criteria cr on cr.id=ss.criteria_id
             where ss.farm_id=p_farm and ss.method='AUTO' and coalesce(ss.achieved,0) < 1 and ss.week_start in (wk, wk-7) and s.dept=a.target_dept and s.active
               and not exists (select 1 from supervision_checks c where c.supervisor_id=a.supervisor_id and c.target_staff_id=ss.staff_id and (c.criteria_id=ss.criteria_id or c.note like '[đã xem auto]%') and c.ts >= ss.week_start and c.ts < p_day + 1)
               and p_day >= ss.week_start + 1 loop
      insert into gs_omissions(farm_id,supervisor_id,day,kind,target_dept,target_staff_id,criteria_id,detail,points) values (p_farm,a.supervisor_id,p_day,'BO_SOT_LOI',a.target_dept,f.staff_id,f.criteria_id,'Hệ thống đã phát hiện "'||f.name||'" không đạt nhưng GS chưa ghi/xác nhận',pts_fault) on conflict (supervisor_id, day, kind, coalesce(target_staff_id,''), coalesce(criteria_id,''), coalesce(target_dept,'')) do nothing; n:=n+1;
    end loop;
    -- (c) thứ Hai: tuần trước không kiểm trưởng phòng lần nào
    if dow = 1 and not exists (select 1 from supervision_checks c join staff h on h.id=c.target_staff_id where c.supervisor_id=a.supervisor_id and h.dept=a.target_dept and h.role in ('tech_head','team_lead') and c.week_start=wk-7) then
      insert into gs_omissions(farm_id,supervisor_id,day,kind,target_dept,detail,points) values (p_farm,a.supervisor_id,p_day,'KHONG_KIEM_TRUONG_PHONG',a.target_dept,'Tuần '||to_char(wk-7,'DD/MM')||' không kiểm trưởng phòng '||a.target_dept,pts_day) on conflict (supervisor_id, day, kind, coalesce(target_staff_id,''), coalesce(criteria_id,''), coalesce(target_dept,'')) do nothing; n:=n+1;
    end if;
    -- (d) lỗi GS ghi nhưng >7 ngày chưa theo dõi (không xác nhận khắc phục, không quá hạn) — GS bỏ lửng
    if dow = 1 then
      insert into gs_omissions(farm_id,supervisor_id,day,kind,target_dept,target_staff_id,criteria_id,detail,points)
        select p_farm, a.supervisor_id, p_day, 'KHONG_XU_LY_LOI', a.target_dept, c.target_staff_id, c.criteria_id, 'Lỗi ghi '||to_char(c.ts,'DD/MM')||' có biện pháp nhưng GS không chấm lại sau 7 ngày', pts_fault
        from supervision_checks c where c.supervisor_id=a.supervisor_id and c.result='LOI' and c.corrective is not null and c.verified_at is null and c.corrective_due < p_day - 7 and coalesce(c.target_dept,(select dept from staff where id=c.target_staff_id))=a.target_dept on conflict (supervisor_id, day, kind, coalesce(target_staff_id,''), coalesce(criteria_id,''), coalesce(target_dept,'')) do nothing;
    end if;
  end loop;
  -- báo GS
  insert into notifications(farm_id,staff_id,level,title,body,link,source) select p_farm, supervisor_id, 'CAM', 'Bạn có '||count(*)||' lỗi giám sát ngày '||to_char(p_day,'DD/MM')||' (máy ghi)', string_agg(left(detail,80), ' · '), '/giam-sat', 'gs_omission' from gs_omissions where farm_id=p_farm and day=p_day group by supervisor_id;
  return n;
end $$;
grant execute on function gen_gs_omissions(text,date) to app_user;
-- 3) THƯỞNG GS & TRƯỞNG PHÒNG gắn với lỗi giám sát: viết lại bonus_eval (giữ nguyên chữ ký) — lỗi GS (gs_omissions) trừ điểm & quá ngưỡng thì mất thưởng; trưởng phòng bị trừ theo lỗi lặp/CAPA quá hạn của phòng
create or replace function bonus_eval(p_farm text, p_period text) returns table(staff_id text, full_name text, role text, dept text, base_bonus numeric, weeks int,
  learn_hours numeric, learn_required numeric, learn_ok bool, teach_sessions int, teach_required int, teach_ok bool, tests int, tests_passed int, test_ok bool,
  supervise_checks int, supervise_required int, supervise_ok bool, fault_points numeric, deduction numeric, eligible bool, bonus numeric, mastered_all bool) language plpgsql stable as $$
declare p_from date := to_date(p_period||'-01','YYYY-MM-DD'); p_to date := (to_date(p_period||'-01','YYYY-MM-DD') + interval '1 month')::date; wk int; hpw numeric := setting_num('training.hours_per_week',p_farm,2.5); cpw numeric := setting_num('supervision.checks_per_week',p_farm,5); dpp numeric := setting_num('bonus.deduct_per_point',p_farm,50000); maxd numeric := setting_num('bonus.max_deduct_pct',p_farm,100); om_max int := setting_num('gs.omissions_max_month',p_farm,3)::int;
begin
  wk := greatest(1, round((p_to - p_from)/7.0));
  return query
  with s as (select st.* from staff st where st.active and (st.farm_id=p_farm or (st.farm_id is null and current_grade(st.id,'GS') is not null))),
  learn as (select trainee_id, coalesce(sum(actual_hours),0) as h from training_sessions where farm_id=p_farm and status='XONG' and held_at >= p_from and held_at < p_to group by 1),
  teach as (select trainer_id, count(*) as n from training_sessions where farm_id=p_farm and status='XONG' and held_at >= p_from and held_at < p_to group by 1),
  subs as (select manager_id, count(*) as n from staff where farm_id=p_farm and active and manager_id is not null group by 1),
  tst as (select trainee_id, count(*) as n, count(*) filter (where passed) as np from training_tests where farm_id=p_farm and taken_at >= p_from and taken_at < p_to group by 1),
  sup as (select supervisor_id, count(*) as n from supervision_checks where farm_id=p_farm and status='ACTIVE' and ts >= p_from and ts < p_to group by 1),
  supreq as (select supervisor_id, sum(coalesce(checks_per_week, cpw)) as per_week from supervision_assignments where farm_id=p_farm and active group by 1),
  faults as (select coalesce(target_staff_id, '') as sid, target_dept as dept, sum(points) as pts from supervision_checks where farm_id=p_farm and status='ACTIVE' and result='LOI' and ts >= p_from and ts < p_to group by 1,2),
  gsom as (select supervisor_id, count(*) as n, sum(points) as pts from gs_omissions where farm_id=p_farm and day >= p_from and day < p_to group by 1),
  headpen as (select h.id, coalesce((select count(*) from v_repeat_faults r where r.farm_id=p_farm and r.dept=h.dept),0)*setting_num('bonus.head_repeat_points',p_farm,3)
                 + coalesce((select count(*) from supervision_checks c where c.farm_id=p_farm and coalesce(c.target_dept,(select x.dept from staff x where x.id=c.target_staff_id))=h.dept and c.result='LOI' and c.ts>=p_from and c.ts<p_to and c.corrective_due < p_to and c.verified_at is null),0)*setting_num('bonus.head_capa_points',p_farm,1) as pts
              from staff h where h.farm_id=p_farm and h.active and h.role in ('tech_head','team_lead')),
  mast as (select vc.staff_id, bool_and(vc.level in ('THUAN_THUC','DAY_DUOC')) as all_ok from v_training_curriculum vc where vc.farm_id=p_farm group by 1),
  calc as (
   select s.id, s.full_name, s.role, s.dept,
    setting_num('bonus.base_'||coalesce(case when current_grade(s.id,'GS') is not null then 'gs' end, s.role), p_farm, case s.role when 'worker' then 1500000 when 'team_lead' then 2500000 when 'tech_head' then 4000000 when 'director' then 6000000 when 'auditor' then 3000000 else 0 end) as base_bonus,
    coalesce(l.h,0) as lh, case when s.manager_id is null then 0 else hpw*wk end as lreq, (s.manager_id is null or coalesce(l.h,0) >= hpw*wk*0.8 or coalesce(m.all_ok,false)) as learn_ok,
    coalesce(t.n,0)::int as tn, case when coalesce(sb.n,0)>0 then wk else 0 end as treq, (coalesce(sb.n,0)=0 or coalesce(t.n,0) >= wk*0.8) as teach_ok,
    coalesce(ts.n,0)::int as tsn, coalesce(ts.np,0)::int as tsp, (s.manager_id is null or coalesce(m.all_ok,false) or coalesce(ts.np,0) >= 1) as test_ok,
    coalesce(su.n,0)::int as sun, coalesce(round(sr.per_week*wk),0)::int as sureq,
    (sr.supervisor_id is null or coalesce(su.n,0) >= sr.per_week*wk*0.8) and coalesce(g.n,0) <= om_max as supervise_ok, -- GS: đủ lượt VÀ không quá ngưỡng lỗi GS
    coalesce(f1.pts,0) + coalesce(f2.pts,0)/greatest((select count(*) from staff x where x.farm_id=p_farm and x.active and x.dept=s.dept),1) + coalesce(g.pts,0) + coalesce(hp.pts,0) as fpts,
    coalesce(m.all_ok,false) as mall
   from s left join learn l on l.trainee_id=s.id left join teach t on t.trainer_id=s.id left join subs sb on sb.manager_id=s.id left join tst ts on ts.trainee_id=s.id left join sup su on su.supervisor_id=s.id left join supreq sr on sr.supervisor_id=s.id
   left join faults f1 on f1.sid=s.id left join faults f2 on f2.sid='' and f2.dept=s.dept left join mast m on m.staff_id=s.id left join gsom g on g.supervisor_id=s.id left join headpen hp on hp.id=s.id)
  select c.id, c.full_name, c.role, c.dept, c.base_bonus, wk, c.lh, c.lreq, c.learn_ok, c.tn, c.treq, c.teach_ok, c.tsn, c.tsp, c.test_ok, c.sun, c.sureq, c.supervise_ok, c.fpts,
    least(c.fpts*dpp, c.base_bonus*maxd/100) as deduction,
    (c.learn_ok and c.teach_ok and c.test_ok and c.supervise_ok) as eligible,
    greatest(0, case when (c.learn_ok and c.teach_ok and c.test_ok and c.supervise_ok) then c.base_bonus else 0 end - least(c.fpts*dpp, c.base_bonus*maxd/100)) as bonus,
    c.mall
  from calc c order by c.dept, c.id; end $$;
-- 4) "HÔM NAY CỦA GS": việc phải làm hôm nay, tự suy từ phân công + quy trình phòng + dữ liệu tự động
create or replace function gs_today(p_farm text, p_staff text) returns jsonb language plpgsql stable as $$
declare j jsonb; wk date := date_trunc('week', current_date)::date; mon text := to_char(current_date,'YYYY-MM');
begin
  select jsonb_build_object(
   'is_gs', current_grade(p_staff,'GS') is not null,
   'depts', coalesce((select jsonb_agg(jsonb_build_object('dept', d.target_dept, 'name', (select name from departments where code=d.target_dept), 'checks_today', (select count(*) from supervision_checks c where c.supervisor_id=p_staff and c.ts::date=current_date and coalesce(c.target_dept,(select dept from staff where id=c.target_staff_id))=d.target_dept), 'min_per_day', setting_num('gs.daily_checks_min',p_farm,2),
      'head', (select jsonb_build_object('id',h.id,'name',h.full_name,'checked_this_week', exists(select 1 from supervision_checks c where c.supervisor_id=p_staff and c.target_staff_id=h.id and c.week_start=wk)) from staff h where h.farm_id=p_farm and h.dept=d.target_dept and h.active and h.role in ('tech_head','team_lead') order by h.role='tech_head' desc limit 1),
      'staff', (select jsonb_agg(jsonb_build_object('id',w.id,'name',w.full_name,'position',w.position,'position_code',w.position_code,'role',w.role,'last_check',(select max(c.ts)::date from supervision_checks c where c.supervisor_id=p_staff and c.target_staff_id=w.id),'auto_fails',(select count(*) from supervision_scores ss where ss.staff_id=w.id and ss.method='AUTO' and coalesce(ss.achieved,0)<1 and ss.week_start in (wk,wk-7))) order by w.role='tech_head' desc, w.role='team_lead' desc, w.full_name) from staff w where w.farm_id=p_farm and w.dept=d.target_dept and w.active),
      'processes', (select jsonb_agg(jsonb_build_object('id',cr.id,'name',cr.name,'what',cr.what,'freq',cr.frequency,'last_check',(select max(c.ts)::date from supervision_checks c where c.supervisor_id=p_staff and c.criteria_id=cr.id),'due', case when cr.frequency='NGAY' then not exists(select 1 from supervision_checks c where c.supervisor_id=p_staff and c.criteria_id=cr.id and c.ts::date=current_date) when cr.frequency='TUAN' then not exists(select 1 from supervision_checks c where c.supervisor_id=p_staff and c.criteria_id=cr.id and c.week_start=wk) else not exists(select 1 from supervision_checks c where c.supervisor_id=p_staff and c.criteria_id=cr.id and c.ts > current_date-30) end) order by cr.frequency, cr.name) from supervision_criteria cr where cr.active and cr.method='MANUAL' and cr.dept_code=d.target_dept and cr.process_code is not null)
     )) from (select distinct target_dept from supervision_assignments a where a.farm_id=p_farm and a.supervisor_id=p_staff and a.active and a.target_dept is not null) d), '[]'::jsonb),
   'pending_auto', coalesce((select jsonb_agg(jsonb_build_object('staff_id',ss.staff_id,'name',s.full_name,'dept',s.dept,'criteria_id',ss.criteria_id,'criteria',cr.name,'value',ss.value,'target',ss.target,'week',ss.week_start) order by ss.week_start desc, s.dept) from supervision_scores ss join staff s on s.id=ss.staff_id join supervision_criteria cr on cr.id=ss.criteria_id
      where ss.farm_id=p_farm and ss.method='AUTO' and coalesce(ss.achieved,0)<1 and ss.week_start in (wk,wk-7) and s.dept in (select target_dept from supervision_assignments a where a.farm_id=p_farm and a.supervisor_id=p_staff and a.active)
        and not exists (select 1 from supervision_checks c where c.supervisor_id=p_staff and c.target_staff_id=ss.staff_id and (c.criteria_id=ss.criteria_id or c.note like '[đã xem auto]%') and c.ts >= ss.week_start)), '[]'::jsonb),
   'overdue_tasks', (select count(*) from tasks t join staff w on w.id=t.assignee_id where t.farm_id=p_farm and t.status in ('MO','DANG_LAM') and t.due_at < now() - interval '1 day' and w.dept in (select target_dept from supervision_assignments a where a.farm_id=p_farm and a.supervisor_id=p_staff and a.active)),
   'omissions_month', (select count(*) from gs_omissions o where o.supervisor_id=p_staff and to_char(o.day,'YYYY-MM')=mon),
   'omissions_max', setting_num('gs.omissions_max_month',p_farm,3),
   'omissions_list', coalesce((select jsonb_agg(jsonb_build_object('day',o.day,'kind',o.kind,'detail',o.detail,'points',o.points) order by o.day desc) from (select * from gs_omissions o where o.supervisor_id=p_staff order by day desc limit 20) o), '[]'::jsonb),
   'checks_month', (select count(*) from supervision_checks c where c.supervisor_id=p_staff and to_char(c.ts,'YYYY-MM')=mon),
   'field_days_month', (select count(*) from gs_field_days f where f.supervisor_id=p_staff and to_char(f.day,'YYYY-MM')=mon)
  ) into j;
  return j;
end $$;
grant execute on function gs_today(text,text) to app_user;
-- 5) Hộp việc: GS thấy ngay việc hằng ngày của mình
create or replace function my_inbox_gs(p_farm text, p_staff text) returns table(kind text, title text, detail text, due_at timestamptz, priority text, link text, ref_table text, ref_id text, on_behalf text) language sql stable as $$
  with j as (select gs_today(p_farm, p_staff) t)
  select 'GS_NGAY', 'Kiểm hằng ngày phòng '||(d->>'dept')||': '||(d->>'checks_today')||'/'||(d->>'min_per_day')||' lượt', 'Kiểm thợ + trưởng phòng theo quy trình; ghi lỗi ngay', current_date::timestamptz + interval '17 hours', 'CAO', '/giam-sat', 'supervision_assignments', d->>'dept', null
   from j, jsonb_array_elements(j.t->'depts') d where (d->>'checks_today')::int < (d->>'min_per_day')::numeric and (j.t->>'is_gs')='true'
  union all
  select 'GS_NGAY', 'Hệ thống phát hiện '||jsonb_array_length(j.t->'pending_auto')||' lỗi chưa được GS ghi/xác nhận', 'Không ghi trong 24h = lỗi của GS (mất thưởng)', now() + interval '12 hours', 'KHAN', '/giam-sat', 'supervision_scores', 'auto', null
   from j where jsonb_array_length(j.t->'pending_auto') > 0 and (j.t->>'is_gs')='true'
  union all
  select 'GS_NGAY', 'Tuần này chưa kiểm trưởng phòng '||(d->>'dept'), 'Tuyến 2 kiểm cả tuyến 1', (date_trunc('week', current_date) + interval '5 days')::timestamptz, 'BINH_THUONG', '/giam-sat', 'staff', d->'head'->>'id', null
   from j, jsonb_array_elements(j.t->'depts') d where (d->'head'->>'checked_this_week')='false' and (j.t->>'is_gs')='true'
$$;
grant execute on function my_inbox_gs(text,text) to app_user;
