-- 0030 · NỀN TẢNG & PHẦN CÒN THIẾU: khóa đăng nhập · deliveries kênh · webhook · attrs (trường tùy biến) · GL kế toán kép · chấm công/nghỉ phép · portal đối tác · GHG · workflow enforce biểu mẫu
-- ===== 1. Auth hardening =====
create table if not exists login_attempts(login text not null, ip text, ts timestamptz default now(), ok bool default false);
create index if not exists login_attempts_ix on login_attempts(login, ts desc);
alter table staff add column if not exists locked_until timestamptz, add column if not exists pin_changed_at timestamptz, add column if not exists must_change_pin bool default false;
-- ===== 2. Kênh thông báo thật: nhật ký gửi từng kênh =====
create table if not exists notification_deliveries(id bigserial primary key, notification_id uuid references notifications on delete cascade, channel text not null, -- app|zalo|sms|email|webhook
  to_addr text, status text default 'QUEUED', -- QUEUED|SENT|FAILED|SKIPPED
  provider text, provider_ref text, error text, attempts int default 0, ts timestamptz default now(), sent_at timestamptz);
create index if not exists nd_queue on notification_deliveries(status, ts) where status='QUEUED';
alter table staff add column if not exists email text, add column if not exists zalo_uid text;
alter table notification_deliveries enable row level security; drop policy if exists p_all on notification_deliveries; create policy p_all on notification_deliveries for all using (app_role() in ('owner','it_engineer','director')) with check (true); grant select, insert, update on notification_deliveries to app_user; grant usage, select on all sequences in schema public to app_user;
-- ===== 3. Trường tùy biến: cột attrs jsonb trên bảng danh mục chính =====
do $$ declare t text; begin foreach t in array array['animals','animal_groups','plots','products','partners','staff','devices','facilities','locations','warehouses','crop_seasons','farms','recipes'] loop
  execute format('alter table %I add column if not exists attrs jsonb default ''{}''::jsonb', t); end loop; end $$;
-- ===== 4. Kế toán kép tối thiểu (GL) — hạch toán tự động từ bán hàng, chi, mua, lương; sổ cái, cân đối phát sinh =====
create table if not exists gl_accounts(code text primary key, name text not null, kind text not null, -- TAI_SAN|NO_PHAI_TRA|VON|DOANH_THU|CHI_PHI
  parent text, active bool default true);
insert into gl_accounts(code,name,kind,parent) values
('111','Tiền mặt','TAI_SAN',null),('112','Tiền gửi ngân hàng','TAI_SAN',null),('131','Phải thu khách hàng','TAI_SAN',null),('152','Nguyên vật liệu','TAI_SAN',null),('153','Công cụ dụng cụ','TAI_SAN',null),('154','Chi phí SXKD dở dang','TAI_SAN',null),('155','Thành phẩm','TAI_SAN',null),('156','Hàng hóa','TAI_SAN',null),('211','Tài sản cố định','TAI_SAN',null),('214','Hao mòn TSCĐ','TAI_SAN',null),('241','XDCB dở dang','TAI_SAN',null),
('331','Phải trả người bán','NO_PHAI_TRA',null),('333','Thuế phải nộp','NO_PHAI_TRA',null),('334','Phải trả người lao động','NO_PHAI_TRA',null),('338','Phải trả khác','NO_PHAI_TRA',null),('341','Vay','NO_PHAI_TRA',null),
('411','Vốn chủ sở hữu','VON',null),('421','Lợi nhuận chưa phân phối','VON',null),
('511','Doanh thu bán hàng','DOANH_THU',null),('515','Doanh thu tài chính','DOANH_THU',null),('711','Thu nhập khác','DOANH_THU',null),
('621','Chi phí NVL trực tiếp','CHI_PHI',null),('622','Chi phí nhân công trực tiếp','CHI_PHI',null),('627','Chi phí sản xuất chung','CHI_PHI',null),('632','Giá vốn hàng bán','CHI_PHI',null),('641','Chi phí bán hàng','CHI_PHI',null),('642','Chi phí quản lý','CHI_PHI',null),('811','Chi phí khác','CHI_PHI',null)
on conflict do nothing;
create table if not exists journal_entries(id uuid primary key default gen_random_uuid(), farm_id text not null, ts timestamptz default now(), period date, ref_table text, ref_id text, memo text, lines jsonb not null, -- [{acct, debit, credit, cc}]
  total numeric, posted_by text, source text default 'AUTO', reversed_of uuid, created_at timestamptz default now());
create index if not exists je_farm_period on journal_entries(farm_id, period);
alter table journal_entries enable row level security; drop policy if exists p_all on journal_entries; create policy p_all on journal_entries for all using (can_see_farm(farm_id)) with check (true); grant select, insert on journal_entries to app_user; grant select on gl_accounts to app_user;
create or replace function gl_post(p_farm text, p_ref_table text, p_ref_id text, p_memo text, p_lines jsonb, p_ts timestamptz default now(), p_by text default null) returns uuid language plpgsql security definer as $$
declare d numeric; c numeric; i uuid; begin
  select coalesce(sum((l->>'debit')::numeric),0), coalesce(sum((l->>'credit')::numeric),0) into d, c from jsonb_array_elements(p_lines) l;
  if round(d,0) <> round(c,0) then raise exception 'ERR_GL_UNBALANCED: no % <> co %', d, c; end if;
  if exists (select 1 from journal_entries where ref_table=p_ref_table and ref_id=p_ref_id and reversed_of is null) then return null; end if;
  insert into journal_entries(farm_id,ts,period,ref_table,ref_id,memo,lines,total,posted_by) values (p_farm,p_ts,date_trunc('month',p_ts)::date,p_ref_table,p_ref_id,p_memo,p_lines,d,p_by) returning id into i; return i; end $$;
-- Trigger tự hạch toán: bán hàng (131/111 ↔ 511), chi đã duyệt & thanh toán (6xx ↔ 111/112), nhập mua (152/156 ↔ 331)
create or replace function itran_gl_sales() returns trigger language plpgsql as $$
begin if new.amount is not null and new.amount > 0 then perform gl_post(new.farm_id,'sales',new.id::text,'Bán '||coalesce(new.sku,'')||' '||coalesce(new.qty::text,''), jsonb_build_array(jsonb_build_object('acct', case when new.paid then (case when new.payment in ('CK','QR','THE') then '112' else '111' end) else '131' end,'debit',new.amount,'credit',0,'cc',null), jsonb_build_object('acct','511','debit',0,'credit',new.amount,'cc',null)), new.ts, new.created_by); end if; return new; end $$;
drop trigger if exists gl_sales on sales; create trigger gl_sales after insert on sales for each row execute function itran_gl_sales();
create or replace function itran_gl_expense() returns trigger language plpgsql as $$
begin if new.paid_at is not null and (old.paid_at is null) then perform gl_post(new.farm_id,'expense_requests',new.id::text,coalesce(new.purpose,'Chi'), jsonb_build_array(jsonb_build_object('acct', case when new.cost_center like '%CC-HC%' or new.cost_center like '%CC-CN%' then '642' when new.cost_center like '%CC-KD%' then '641' else '627' end,'debit',new.amount,'credit',0,'cc',new.cost_center), jsonb_build_object('acct','111','debit',0,'credit',new.amount,'cc',null)), new.paid_at, new.approver1); end if; return new; end $$;
drop trigger if exists gl_expense on expense_requests; create trigger gl_expense after update on expense_requests for each row execute function itran_gl_expense();
create or replace function itran_gl_purchase() returns trigger language plpgsql as $$
begin if new.reason='NHAP_MUA' and new.direction=1 and coalesce(new.unit_cost,0)>0 then perform gl_post(new.farm_id,'inventory_moves',new.id::text,'Nhập mua '||coalesce(new.sku,''), jsonb_build_array(jsonb_build_object('acct','152','debit',new.qty*new.unit_cost,'credit',0,'cc',null), jsonb_build_object('acct','331','debit',0,'credit',new.qty*new.unit_cost,'cc',null)), new.ts, new.created_by); end if; return new; end $$;
drop trigger if exists gl_purchase on inventory_moves; create trigger gl_purchase after insert on inventory_moves for each row execute function itran_gl_purchase();
create or replace view v_gl_trial_balance as
select j.farm_id, j.period, l->>'acct' as acct, a.name, a.kind, sum((l->>'debit')::numeric) as debit, sum((l->>'credit')::numeric) as credit from journal_entries j, jsonb_array_elements(j.lines) l left join gl_accounts a on a.code=l->>'acct' where j.reversed_of is null group by 1,2,3,4,5;
create or replace view v_gl_ledger as select j.farm_id, j.ts, j.period, j.ref_table, j.ref_id, j.memo, l->>'acct' as acct, (l->>'debit')::numeric as debit, (l->>'credit')::numeric as credit, l->>'cc' as cc, j.posted_by from journal_entries j, jsonb_array_elements(j.lines) l where j.reversed_of is null;
grant select on v_gl_trial_balance, v_gl_ledger to app_user;
-- backfill sổ cái từ dữ liệu đã có
do $$ declare r record; begin
  for r in select * from sales where status='ACTIVE' and amount>0 loop perform gl_post(r.farm_id,'sales',r.id::text,'Bán '||coalesce(r.sku,''), jsonb_build_array(jsonb_build_object('acct', case when r.paid then '111' else '131' end,'debit',r.amount,'credit',0), jsonb_build_object('acct','511','debit',0,'credit',r.amount)), r.ts, r.created_by); end loop;
  for r in select * from inventory_moves where status='ACTIVE' and reason='NHAP_MUA' and direction=1 and coalesce(unit_cost,0)>0 loop perform gl_post(r.farm_id,'inventory_moves',r.id::text,'Nhập mua '||coalesce(r.sku,''), jsonb_build_array(jsonb_build_object('acct','152','debit',r.qty*r.unit_cost,'credit',0), jsonb_build_object('acct','331','debit',0,'credit',r.qty*r.unit_cost)), r.ts, r.created_by); end loop;
end $$;
-- ===== 5. Chấm công & nghỉ phép =====
create table if not exists attendance(id uuid primary key default gen_random_uuid(), farm_id text not null, staff_id text not null, day date not null default current_date, check_in timestamptz, check_out timestamptz, shift text, lat numeric, lng numeric, method text default 'APP', -- APP|QR|TAY
  hours numeric, note text, approved_by text, unique(farm_id, staff_id, day, shift));
create table if not exists leave_requests(id uuid primary key default gen_random_uuid(), farm_id text not null, staff_id text not null, kind text not null, -- PHEP|OM|VIEC_RIENG|KHONG_LUONG|THAI_SAN
  from_date date not null, to_date date not null, days numeric, reason text, status text default 'CHO', -- CHO|DUYET|TU_CHOI
  approved_by text, approved_at timestamptz, created_at timestamptz default now());
do $$ declare t text; begin foreach t in array array['attendance','leave_requests'] loop execute format('alter table %I enable row level security', t); execute format('drop policy if exists p_all on %I', t); execute format('create policy p_all on %I for all using (can_see_farm(farm_id) and (staff_id=app_staff() or app_role() in (''owner'',''director'',''accountant'',''tech_head'',''team_lead'',''it_engineer''))) with check (true)', t); execute format('grant select, insert, update on %I to app_user', t); end loop; end $$;
create or replace view v_attendance_month as select farm_id, staff_id, date_trunc('month', day)::date as month, count(distinct day) as days, round(coalesce(sum(hours),0),1) as hours from attendance where check_in is not null group by 1,2,3;
grant select on v_attendance_month to app_user;
-- ===== 6. Portal đối tác (token) =====
alter table partners add column if not exists portal_token text unique, add column if not exists email text, add column if not exists bank_account text;
update partners set portal_token = encode(gen_random_bytes(12),'hex') where portal_token is null;
alter table farms add column if not exists bank_bin text, add column if not exists bank_name text;
-- ===== 7. GHG ước tính (IPCC 2006/2019 Tier 1, hệ số mặc định — chỉnh trong norms) =====
insert into norms(id,org_id,farm_id,kind,subject,value,unit,version) values ('NORM-GHG-1','ITRAN',null,'GHG_CH4_ENTERIC','BO',56,'kg CH4/con/năm',1),('NORM-GHG-2','ITRAN',null,'GHG_CH4_ENTERIC','DE',5,'kg CH4/con/năm',1),('NORM-GHG-3','ITRAN',null,'GHG_CH4_ENTERIC','HEO',1,'kg CH4/con/năm',1),('NORM-GHG-4','ITRAN',null,'GHG_CH4_MANURE','BO',2,'kg CH4/con/năm',1),('NORM-GHG-5','ITRAN',null,'GHG_CH4_MANURE','GA',0.02,'kg CH4/con/năm',1),('NORM-GHG-6','ITRAN',null,'GHG_GWP_CH4','*',28,'CO2e/CH4',1) on conflict do nothing;
create or replace view v_ghg_month as
select h.farm_id, date_trunc('month', h.day)::date as month, h.species, round(avg(h.head)) as avg_head,
  round(avg(h.head) * (coalesce((select value from norms where kind='GHG_CH4_ENTERIC' and subject=h.species order by farm_id nulls last limit 1),0) + coalesce((select value from norms where kind='GHG_CH4_MANURE' and subject=h.species order by farm_id nulls last limit 1),0)) / 12, 1) as ch4_kg,
  round(avg(h.head) * (coalesce((select value from norms where kind='GHG_CH4_ENTERIC' and subject=h.species order by farm_id nulls last limit 1),0) + coalesce((select value from norms where kind='GHG_CH4_MANURE' and subject=h.species order by farm_id nulls last limit 1),0)) / 12 * coalesce((select value from norms where kind='GHG_GWP_CH4' limit 1),28), 1) as co2e_kg
from herd_daily h where h.status not in ('CHET','XUAT','LOAI') group by 1,2,3;
grant select on v_ghg_month to app_user;
update variable_catalog set status='DA_CO', source_table='v_ghg_month', source_col='co2e_kg' where code='CN-OUT-10';
-- ===== 8. Workflow: bắt buộc biểu mẫu trước khi xong bước =====
create or replace function complete_run_step(p_run uuid, p_step int, p_by text, p_output text default null, p_note text default null) returns text language plpgsql as $$
declare r record; nxt int; pending int; ft text; started timestamptz; n int; begin
  select * into r from process_runs where id=p_run; if r is null then raise exception 'ERR_NOT_FOUND'; end if;
  select ps.form_table, rs.started_at into ft, started from process_steps ps join process_run_steps rs on rs.run_id=p_run and rs.step_no=ps.step_no where ps.process_code=r.process_code and ps.step_no=p_step;
  if ft is not null and ft <> '' and to_regclass(ft) is not null and coalesce(p_output,'') <> 'OVERRIDE' then
    execute format('select count(*) from %I where farm_id=$1 and created_by=$2 and created_at >= $3', ft) into n using r.farm_id, p_by, coalesce(started, r.started_at);
    if n = 0 then raise exception 'ERR_FORM_REQUIRED: bước này cần ghi biểu mẫu % trước khi hoàn thành', ft; end if;
  end if;
  update process_run_steps set status='XONG', done_at=now(), done_by=p_by, output_ref=p_output, note=p_note where run_id=p_run and step_no=p_step;
  update tasks set status='XONG', done_by=p_by, done_at=now() where id=(select task_id from process_run_steps where run_id=p_run and step_no=p_step) and status<>'XONG';
  select count(*) into pending from process_run_steps rs where rs.run_id=p_run and rs.status='DANG_LAM';
  if pending > 0 then return 'WAIT_PARALLEL'; end if;
  select min(step_no) into nxt from process_run_steps where run_id=p_run and status='CHO';
  if nxt is null then update process_runs set status='XONG', finished_at=now() where id=p_run; perform publish_event(r.farm_id,'process.finished',jsonb_build_object('run_id',p_run,'code',r.process_code,'title',r.title,'by',p_by)); return 'DONE'; end if;
  perform activate_run_step(p_run, nxt); return 'NEXT:'||nxt;
end $$;
