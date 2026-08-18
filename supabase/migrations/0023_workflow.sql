-- 0023 · KHAI BÁO & CHẠY QUY TRÌNH (workflow engine): quy trình = N bước; mỗi bước thuộc phòng ban, cần công cụ/vật tư, có đầu vào/đầu ra;
--        xuất bản → thông báo phòng ban/nhân sự liên quan; chạy quy trình → sinh việc theo bước → hoàn thành → bước kế → kết thúc. Thêm/xóa bước tự do khi ở trạng thái NHAP.
alter table processes add column if not exists status text default 'BAN_HANH', -- NHAP|BAN_HANH|NGUNG
  add column if not exists version int default 1, add column if not exists farm_id text, add column if not exists created_by text, add column if not exists published_at timestamptz, add column if not exists published_by text, add column if not exists description text, add column if not exists auto_start jsonb default '{}'::jsonb; -- {topic:'harvest.done'} tự chạy khi có sự kiện
alter table process_steps add column if not exists tools text[] default '{}',           -- thiết bị/công cụ (mã devices hoặc tên)
  add column if not exists materials jsonb default '[]'::jsonb,                          -- [{sku, qty, unit}] vật tư/tư liệu sản xuất
  add column if not exists inputs text, add column if not exists outputs text,           -- đầu vào/đầu ra của bước (mô tả + bảng/biểu mẫu)
  add column if not exists duration_min int, add column if not exists sla_hours numeric, add column if not exists form_table text, -- bảng sự kiện phải ghi để hoàn thành bước
  add column if not exists notify_roles text[] default '{}', add column if not exists required bool default true, add column if not exists parallel_group int, add column if not exists checklist jsonb default '[]'::jsonb;
create table if not exists process_runs(id uuid primary key default gen_random_uuid(), farm_id text not null, process_code text references processes, process_version int, ref_table text, ref_id text, title text, status text default 'DANG_CHAY', -- DANG_CHAY|XONG|HUY|TAM_DUNG
  current_step int default 1, started_at timestamptz default now(), started_by text, finished_at timestamptz, note text, context jsonb default '{}'::jsonb);
create table if not exists process_run_steps(id uuid primary key default gen_random_uuid(), run_id uuid references process_runs on delete cascade, step_no int not null, name text, dept_code text, actor_role text, assignee_id text, task_id uuid, status text default 'CHO', -- CHO|DANG_LAM|XONG|BO_QUA
  started_at timestamptz, done_at timestamptz, done_by text, output_ref text, note text, unique(run_id, step_no));
create index if not exists process_runs_farm on process_runs(farm_id, status, started_at desc);
do $$ declare t text; begin foreach t in array array['process_runs','process_run_steps'] loop
  execute format('alter table %I enable row level security', t); execute format('drop policy if exists p_all on %I', t); end loop; end $$;
create policy p_all on process_runs for all using (can_see_farm(farm_id)) with check (true);
create policy p_all on process_run_steps for all using (exists (select 1 from process_runs r where r.id=run_id and can_see_farm(r.farm_id))) with check (true);
grant select, insert, update on process_runs, process_run_steps to app_user; grant delete on process_steps to app_user;
-- Xuất bản quy trình → sự kiện cho các phòng ban trong bước
create or replace function publish_process(p_code text, p_by text) returns void language plpgsql as $$
declare depts text[]; roles text[]; begin
  select array_agg(distinct dept_code) filter (where dept_code is not null), array_agg(distinct actor_role) filter (where actor_role is not null) into depts, roles from process_steps where process_code=p_code;
  update processes set status='BAN_HANH', published_at=now(), published_by=p_by, version=coalesce(version,0)+case when status='BAN_HANH' then 1 else 0 end where code=p_code;
  perform publish_event((select farm_id from processes where code=p_code), 'process.published', jsonb_build_object('code',p_code,'name',(select name from processes where code=p_code),'depts',to_jsonb(coalesce(depts,'{}')),'roles',to_jsonb(coalesce(roles,'{}')),'by',p_by,'steps',(select count(*) from process_steps where process_code=p_code)));
end $$;
-- Chạy quy trình: tạo run + tất cả run_steps + việc cho bước 1 (hoặc nhóm song song đầu tiên)
create or replace function start_process_run(p_farm text, p_code text, p_by text, p_ref_table text default null, p_ref_id text default null, p_title text default null, p_ctx jsonb default '{}'::jsonb) returns uuid language plpgsql as $$
declare rid uuid; s record; first_group int; begin
  if not exists (select 1 from processes where code=p_code and status='BAN_HANH') then raise exception 'ERR_PROCESS_NOT_PUBLISHED'; end if;
  insert into process_runs(farm_id,process_code,process_version,ref_table,ref_id,title,started_by,context) values (p_farm,p_code,(select version from processes where code=p_code),p_ref_table,p_ref_id,coalesce(p_title,(select name from processes where code=p_code)),p_by,p_ctx) returning id into rid;
  insert into process_run_steps(run_id,step_no,name,dept_code,actor_role) select rid, step_no, name, dept_code, actor_role from process_steps where process_code=p_code order by step_no;
  perform activate_run_step(rid, (select min(step_no) from process_steps where process_code=p_code));
  return rid; end $$;
-- Kích hoạt bước: tạo việc (tasks) → trigger tasks_publish → thông báo người/vai; ghi lại task_id
create or replace function activate_run_step(p_run uuid, p_step int) returns void language plpgsql as $$
declare r record; st record; tid uuid; grp int; begin
  select * into r from process_runs where id=p_run; if r is null then return; end if;
  select parallel_group into grp from process_steps where process_code=r.process_code and step_no=p_step;
  for st in select ps.* from process_steps ps where ps.process_code=r.process_code and (ps.step_no=p_step or (grp is not null and ps.parallel_group=grp)) order by ps.step_no loop
    insert into tasks(farm_id,kind,title,detail,role_hint,priority,due_at,ref_table,ref_id,source) values (r.farm_id,'QUY_TRINH', '['||r.process_code||' b'||st.step_no||'] '||st.name||coalesce(' — '||r.title,''), jsonb_build_object('run_id',p_run,'step_no',st.step_no,'dept',st.dept_code,'tools',st.tools,'materials',st.materials,'inputs',st.inputs,'outputs',st.outputs,'form_table',st.form_table,'checklist',st.checklist,'action',st.action,'system_where',st.system_where), coalesce(st.actor_role,'team_lead'), 'CAO', now() + (coalesce(st.sla_hours, 24) || ' hours')::interval, 'process_runs', p_run::text, 'PROCESS') returning id into tid;
    update process_run_steps set status='DANG_LAM', started_at=now(), task_id=tid where run_id=p_run and step_no=st.step_no;
  end loop;
  update process_runs set current_step=p_step where id=p_run;
end $$;
-- Hoàn thành bước → bước kế (bỏ qua bước không bắt buộc nếu yêu cầu) → xong run
create or replace function complete_run_step(p_run uuid, p_step int, p_by text, p_output text default null, p_note text default null) returns text language plpgsql as $$
declare r record; nxt int; pending int; begin
  select * into r from process_runs where id=p_run; if r is null then raise exception 'ERR_NOT_FOUND'; end if;
  update process_run_steps set status='XONG', done_at=now(), done_by=p_by, output_ref=p_output, note=p_note where run_id=p_run and step_no=p_step;
  update tasks set status='XONG', done_by=p_by, done_at=now() where id=(select task_id from process_run_steps where run_id=p_run and step_no=p_step) and status<>'XONG';
  -- còn bước song song chưa xong?
  select count(*) into pending from process_run_steps rs join process_steps ps on ps.process_code=r.process_code and ps.step_no=rs.step_no where rs.run_id=p_run and rs.status='DANG_LAM';
  if pending > 0 then return 'WAIT_PARALLEL'; end if;
  select min(step_no) into nxt from process_run_steps where run_id=p_run and status='CHO';
  if nxt is null then update process_runs set status='XONG', finished_at=now() where id=p_run; perform publish_event(r.farm_id,'process.finished',jsonb_build_object('run_id',p_run,'code',r.process_code,'title',r.title,'by',p_by)); return 'DONE'; end if;
  perform activate_run_step(p_run, nxt); return 'NEXT:'||nxt;
end $$;
grant execute on function publish_process(text,text), start_process_run(text,text,text,text,text,text,jsonb), activate_run_step(uuid,int), complete_run_step(uuid,int,text,text,text) to app_user;
-- Tự chạy quy trình theo sự kiện (auto_start.topic) — xử lý trong dispatch (lib/notify.ts)
create or replace view v_process_runs as
select r.*, p.name as process_name, (select count(*) from process_run_steps s where s.run_id=r.id) as steps_total, (select count(*) from process_run_steps s where s.run_id=r.id and s.status='XONG') as steps_done,
  (select string_agg(s.name, ' → ' order by s.step_no) from process_run_steps s where s.run_id=r.id and s.status='DANG_LAM') as current_names
from process_runs r join processes p on p.code=r.process_code;
grant select on v_process_runs to app_user;
-- Bổ sung công cụ/vật tư/đầu vào-ra cho các bước mẫu đã có
update process_steps set tools='{Máy cày,Máy gieo}', materials='[{"sku":"GIONG-BAP","qty":25,"unit":"kg/ha"}]', inputs='Ô đã quy hoạch, giống đã kiểm', outputs='crop_logs GIEO, xuất kho giống', duration_min=480, sla_hours=48, form_table='crop_logs' where process_code='P-TT-02' and step_no=2;
update process_steps set tools='{Bình phun,PPE}', materials='[{"sku":"PHAN-HUU-CO","qty":2000,"unit":"kg/ha"}]', inputs='Lịch bón, kết quả đất', outputs='crop_inputs (PHI tự tính)', duration_min=240, sla_hours=24, form_table='crop_inputs' where process_code='P-TT-02' and step_no=3;
update process_steps set tools='{Máy cắt/băm,Xe kéo,Cân 40T}', inputs='Ô đã hết PHI', outputs='harvests + phiếu cân', duration_min=480, sla_hours=24, form_table='harvests' where process_code='P-TT-02' and step_no=5;
update process_steps set sla_hours=24 where sla_hours is null;
