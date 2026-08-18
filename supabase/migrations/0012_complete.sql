-- 0012 · HOÀN THIỆN RAY A: kế hoạch vụ/cho ăn · đơn hàng & hợp đồng · lịch vaccine · phác đồ · nhận nuôi · job log · quỹ · thiết bị heartbeat
-- ===== KẾ HOẠCH =====
create table if not exists season_plans(
  id uuid primary key default gen_random_uuid(), farm_id text not null references farms, cycle_id text references cycles, plot_id text references plots,
  crop text, variety text, sow_date date, harvest_date date, plan_yield_kg numeric, plan_cost numeric, note text, created_by text, created_at timestamptz default now());
create table if not exists feed_plans(
  farm_id text not null references farms, group_id text not null references animal_groups, day date not null, plan_kg numeric not null, recipe_id text, head int, source text default 'NORM',
  primary key(farm_id, group_id, day));
-- ===== ĐƠN HÀNG & HỢP ĐỒNG =====
create table if not exists contracts(
  id text primary key, farm_id text not null references farms, partner_id text references partners, kind text not null default 'BAO_TIEU' check (kind in ('BAO_TIEU','B2B','LIEN_KET_HO','NHUONG_QUYEN','NHAP_KHAU','XUAT_KHAU')),
  sku text, qty_committed numeric, unit text, price numeric, start_date date, end_date date, status text default 'HIEU_LUC', file_url text, note text, created_by text, created_at timestamptz default now());
create table if not exists orders(
  id text primary key, farm_id text not null references farms, partner_id text references partners, channel int, order_date date default current_date, deliver_date date,
  lines jsonb not null default '[]'::jsonb, total numeric, status text default 'NHAP' check (status in ('NHAP','CHOT','LENH_SX','DONG_GOI','GIAO','HOAN_TAT','HUY')),
  cutoff_ok bool, discount_pct numeric, discount_approved_by text, created_by text, created_at timestamptz default now(), note text);
-- ===== THÚ Y =====
create table if not exists vaccine_schedules(
  id uuid primary key default gen_random_uuid(), org_id text references orgs, region_id text references regions, species text not null, vaccine_sku text, name text not null,
  age_days_min int, repeat_days int, season_months int[], mandatory bool default true, note text);
create table if not exists treatment_protocols(
  id text primary key, org_id text references orgs, name text not null, species text, indication text, drug_sku text, dose_per_kg numeric, route text, days int, withdrawal_days int not null default 0, signed_by text, signed_at timestamptz, active bool default true);
insert into vaccine_schedules(org_id,species,vaccine_sku,name,age_days_min,repeat_days,mandatory) values
 ('ITRAN','BO','VX-LMLM','LMLM (lở mồm long móng)',120,180,true),('ITRAN','BO',null,'Tụ huyết trùng',120,180,true),('ITRAN','BO',null,'Viêm da nổi cục',120,365,true),
 ('ITRAN','GA',null,'Newcastle',7,90,true),('ITRAN','GA',null,'Gumboro',14,null,true),('ITRAN','GA',null,'Cúm gia cầm H5N1',21,180,true) on conflict do nothing;
insert into treatment_protocols(id,org_id,name,species,indication,drug_sku,dose_per_kg,route,days,withdrawal_days,signed_by,signed_at) values
 ('TP-017','ITRAN','Oxytetracycline LA — nhiễm khuẩn hô hấp/viêm','BO','sốt, bỏ ăn, viêm','TH-OXY',0.05,'IM',3,21,'thú y hợp đồng',now()) on conflict do nothing;
-- ===== NHẬN NUÔI / CHĂM SÓC HỘ (M21 tối thiểu) =====
create table if not exists custody_contracts(
  id text primary key, farm_id text not null references farms, partner_id text references partners, kind text not null check (kind in ('NHAN_NUOI','KY_GUI','DAU_TU','TANG')),
  animal_ids text[] default '{}', package text, fee numeric, period_months int, prepaid numeric, reserve_pct numeric default 30, start_date date default current_date, end_date date,
  end_option text, status text default 'HIEU_LUC', consent_at timestamptz, note text, created_by text, created_at timestamptz default now());
-- ===== QUỸ & JOB LOG =====
create table if not exists funds(farm_id text not null references farms, kind text not null check (kind in ('THIEN_TAI','BAO_DUONG','DAO_TAO','MARKETING')), pct numeric, base text, balance numeric default 0, updated_at timestamptz default now(), primary key(farm_id, kind));
insert into funds(farm_id,kind,pct,base) select f.id, k.kind, k.pct, k.base from farms f cross join (values ('THIEN_TAI',3,'DOANH_THU'),('BAO_DUONG',5,'GIA_TRI_MAY'),('DAO_TAO',1,'QUY_LUONG'),('MARKETING',4,'DOANH_THU')) as k(kind,pct,base) on conflict do nothing;
create table if not exists job_runs(id uuid primary key default gen_random_uuid(), farm_id text, job text not null, started_at timestamptz default now(), finished_at timestamptz, ok bool, detail jsonb);
-- RLS cho bảng mới
do $$ declare t text; begin
  for t in select unnest(array['season_plans','feed_plans','contracts','orders','custody_contracts','funds','job_runs']) loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists p_sel on %I', t); execute format('create policy p_sel on %I for select using (can_see_farm(farm_id) or farm_id is null)', t);
    execute format('drop policy if exists p_w on %I', t); execute format('create policy p_w on %I for all using (farm_id=app_farm() and app_role() not in (''auditor'',''anon'')) with check (farm_id=app_farm())', t);
    execute format('grant select, insert, update on %I to app_user', t);
  end loop;
  for t in select unnest(array['vaccine_schedules','treatment_protocols']) loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists p_all on %I', t); execute format('create policy p_all on %I for select using (true)', t);
    execute format('drop policy if exists p_w on %I', t); execute format('create policy p_w on %I for all using (app_role() in (''tech_head'',''director'',''owner'')) with check (true)', t);
    execute format('grant select, insert, update on %I to app_user', t);
  end loop; end $$;

-- ===== KẾ HOẠCH CHO ĂN TỰ SINH từ định mức × số con (7 ngày tới) =====
create or replace function gen_feed_plans(p_farm text) returns int language plpgsql as $$
declare n int := 0; r record; nrm numeric; begin
  select value into nrm from norms where kind='TA_KG_CON_NGAY' and subject='BO' and (farm_id=p_farm or farm_id is null) order by farm_id nulls last limit 1;
  for r in select id, head_count, kind from animal_groups where farm_id=p_farm and status='ACTIVE' and head_count>0 loop
    for i in 0..6 loop
      insert into feed_plans(farm_id,group_id,day,plan_kg,head,recipe_id) values (p_farm, r.id, current_date+i,
        case r.kind when 'BO_NHOM' then coalesce(nrm,32)*r.head_count when 'GA_DE' then 0.115*r.head_count when 'GA_THIT' then 0.09*r.head_count when 'RAS' then 0.012*r.head_count else 0.5*r.head_count end, r.head_count,
        case r.kind when 'BO_NHOM' then 'RC-TMR-VO' when 'GA_DE' then 'RC-GA-DE' else null end)
      on conflict (farm_id,group_id,day) do update set plan_kg=excluded.plan_kg, head=excluded.head; n:=n+1;
    end loop; end loop; return n; end $$;
grant execute on function gen_feed_plans(text) to app_user;

-- ===== TASK: vaccine đến hạn (theo lịch + lần tiêm gần nhất) & theo dõi động dục lại =====
create or replace function itran_generate_tasks_v2(p_farm text) returns int language plpgsql as $$
declare n int := 0; r record; begin
  n := itran_generate_tasks(p_farm);
  for r in select a.id, v.name, v.repeat_days, v.age_days_min,
      (select max(ts) from animal_events e where e.animal_id=a.id and e.event_type='VACCINE' and e.status='ACTIVE' and coalesce(e.detail->>'vaccine','')=v.name) as last_v
      from animals a join vaccine_schedules v on v.species=a.species where a.farm_id=p_farm and a.status not in ('CHET','XUAT') and a.birth_date <= current_date - (v.age_days_min||' days')::interval loop
    if r.last_v is null or (r.repeat_days is not null and r.last_v < now() - (r.repeat_days||' days')::interval) then
      insert into tasks(farm_id,kind,title,target_type,target_id,role_hint,due_at,priority,rule_code) values (p_farm,'VACCINE','Tiêm '||r.name||' — '||r.id,'animal',r.id,'worker:A2',date_trunc('week',now())+interval '4 days','BINH_THUONG','T-VAC-'||left(md5(r.name),6)) on conflict do nothing; n:=n+1;
    end if; end loop;
  for r in select e.animal_id, e.ts from animal_events e where e.farm_id=p_farm and e.status='ACTIVE' and e.event_type='PHOI' and e.ts between now()-interval '24 days' and now()-interval '18 days'
      and not exists (select 1 from animal_events k where k.animal_id=e.animal_id and k.status='ACTIVE' and k.event_type in ('KHAM_THAI','PHOI','DONG_DUC') and k.ts>e.ts) loop
    insert into tasks(farm_id,kind,title,target_type,target_id,role_hint,due_at,priority,rule_code) values (p_farm,'DONG_DUC','Theo dõi động dục lại '||r.animal_id||' (18–24 ngày sau phối)','animal',r.animal_id,'worker:A2',r.ts+interval '21 days','CAO','T-DD-LAI') on conflict do nothing; n:=n+1;
  end loop;
  return n; end $$;
grant execute on function itran_generate_tasks_v2(text) to app_user;
-- ===== VIEW hỗ trợ =====
create or replace view v_feed_plan_vs_actual as
select p.farm_id, p.day, p.group_id, g.name as group_name, p.plan_kg, coalesce((select sum(qty_kg) from feed_logs f where f.farm_id=p.farm_id and f.dest_group_id=p.group_id and f.status='ACTIVE' and f.ts::date=p.day),0) as actual_kg
from feed_plans p join animal_groups g on g.id=p.group_id;
create or replace view v_vet_board as
select a.farm_id, a.id, a.visual_tag, a.status, a.location_id, a.withdrawal_until,
  (select max(ts) from animal_events e where e.animal_id=a.id and e.event_type='DIEU_TRI' and e.status='ACTIVE') as last_treatment,
  (select max(ts) from animal_events e where e.animal_id=a.id and e.event_type='VACCINE' and e.status='ACTIVE') as last_vaccine,
  (select count(*) from animal_events e where e.animal_id=a.id and e.event_type='BENH' and e.status='ACTIVE' and e.ts>now()-interval '90 days') as sick_90d
from animals a where a.status not in ('CHET','XUAT') and (a.status='BENH' or a.withdrawal_until>current_date or exists (select 1 from animal_events e where e.animal_id=a.id and e.event_type in ('BENH','DIEU_TRI') and e.status='ACTIVE' and e.ts>now()-interval '14 days'));
create or replace view v_staff_activity as
select s.id, s.full_name, s.role, s.position, s.farm_id, s.sop_certs, s.health_check_due, s.food_safety_training_due,
  (select count(*) from checklist_runs c where c.created_by=s.id and c.ts>now()-interval '30 days') as checklists_30d,
  (select count(*) from checklist_runs c where c.created_by=s.id and c.ts>now()-interval '30 days' and c.all_green) as checklists_green_30d,
  (select count(*) from (select created_by from animal_events where created_by=s.id and ts>now()-interval '30 days' union all select created_by from feed_logs where created_by=s.id and ts>now()-interval '30 days' union all select created_by from crop_logs where created_by=s.id and ts>now()-interval '30 days' union all select created_by from batch_logs where created_by=s.id and ts>now()-interval '30 days' union all select created_by from inventory_moves where created_by=s.id and ts>now()-interval '30 days') u) as records_30d,
  (select count(*) from tasks t where t.done_by=s.id and t.done_at>now()-interval '30 days') as tasks_done_30d,
  (select max(ts) from shift_notes n where n.created_by=s.id) as last_note
from staff s where s.active;
create or replace view v_device_board as
select d.*, (select max(ts) from sensor_reads r where r.device_id=d.id) as last_seen,
  (select count(*) from tasks t where t.target_type='device' and t.target_id=d.id and t.status='MO') as open_tasks,
  (select max(next_due) from calibrations c where c.target_device_id=d.id and c.status='ACTIVE') as calib_next
from devices d;
grant select on all tables in schema public to app_user;
