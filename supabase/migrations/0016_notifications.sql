-- 0016 · EVENT BUS + NOTIFICATIONS: luật cấu hình → sự kiện → hộp thư từng người/nhóm · kênh (app/zalo/sms/email)
create table if not exists event_bus(
  id bigserial primary key, farm_id text, topic text not null, payload jsonb not null default '{}'::jsonb, ts timestamptz default now(), processed_at timestamptz);
create index if not exists event_bus_unprocessed on event_bus(ts) where processed_at is null;
create table if not exists notifications(
  id uuid primary key default gen_random_uuid(), farm_id text, staff_id text not null, level text default 'INFO', title text not null, body text, link text, source text, source_id text,
  channels text[] default '{app}', sent jsonb default '{}'::jsonb, ts timestamptz default now(), read_at timestamptz);
create index if not exists notifications_inbox on notifications(staff_id, read_at, ts desc);
create table if not exists notification_prefs(
  staff_id text not null, rule_code text not null default '*', level_min text default 'XANH', channels text[] default '{app}', quiet_from time, quiet_to time, muted bool default false, primary key(staff_id, rule_code));
-- alert_rules: chuẩn hóa expr JSON tự cấu hình
alter table alert_rules add column if not exists description text, add column if not exists created_by text, add column if not exists last_fired_at timestamptz, add column if not exists fire_count int default 0;
alter table notifications enable row level security; alter table notification_prefs enable row level security; alter table event_bus enable row level security;
drop policy if exists p_sel on notifications; create policy p_sel on notifications for select using (staff_id=app_staff() or app_role() in ('owner','director','it_engineer'));
drop policy if exists p_w on notifications; create policy p_w on notifications for all using (staff_id=app_staff() or app_role() in ('owner','director','it_engineer')) with check (true);
drop policy if exists p_sel on notification_prefs; create policy p_sel on notification_prefs for select using (staff_id=app_staff() or app_role() in ('owner','director','it_engineer'));
drop policy if exists p_w on notification_prefs; create policy p_w on notification_prefs for all using (staff_id=app_staff() or app_role() in ('owner','director','it_engineer')) with check (true);
drop policy if exists p_sel on event_bus; create policy p_sel on event_bus for select using (can_see_farm(farm_id) or farm_id is null);
drop policy if exists p_w on event_bus; create policy p_w on event_bus for all using (true) with check (true);
grant select, insert, update on notifications, notification_prefs, event_bus to app_user;
grant usage on sequence event_bus_id_seq to app_user;
-- Publish helper (event bus = bảng outbox + NOTIFY)
create or replace function publish_event(p_farm text, p_topic text, p_payload jsonb) returns bigint language plpgsql as $$
declare i bigint; begin insert into event_bus(farm_id,topic,payload) values (p_farm,p_topic,p_payload) returning id into i; perform pg_notify('itran_events', json_build_object('id',i,'topic',p_topic,'farm',p_farm)::text); return i; end $$;
grant execute on function publish_event(text,text,jsonb) to app_user;
-- Trigger: mọi alert mới → sự kiện; mọi task khẩn/cao mới → sự kiện; sự cố mới → sự kiện
create or replace function itran_alert_publish() returns trigger language plpgsql as $$
begin perform publish_event(new.farm_id, 'alert.raised', jsonb_build_object('alert_id',new.id,'rule',new.rule_code,'level',new.level,'subject',new.subject,'sent_to',to_jsonb(new.sent_to))); return new; end $$;
drop trigger if exists alerts_publish on alerts; create trigger alerts_publish after insert on alerts for each row execute function itran_alert_publish();
create or replace function itran_task_publish() returns trigger language plpgsql as $$
begin if new.priority in ('KHAN','CAO') then perform publish_event(new.farm_id, 'task.created', jsonb_build_object('task_id',new.id,'title',new.title,'role_hint',new.role_hint,'assignee',new.assignee_id,'priority',new.priority,'due',new.due_at)); end if; return new; end $$;
drop trigger if exists tasks_publish on tasks; create trigger tasks_publish after insert on tasks for each row execute function itran_task_publish();
create or replace function itran_incident_publish() returns trigger language plpgsql as $$
begin perform publish_event(new.farm_id, 'incident.created', jsonb_build_object('incident_id',new.id,'code',new.code,'kind',new.kind,'severity',new.severity,'description',new.description)); return new; end $$;
drop trigger if exists incidents_publish on incidents; create trigger incidents_publish after insert on incidents for each row execute function itran_incident_publish();
create or replace function itran_expense_publish() returns trigger language plpgsql as $$
begin if new.amount > 5e7 and (old.status is distinct from new.status) and new.status='DUYET' then perform publish_event(new.farm_id, 'expense.approved.big', jsonb_build_object('id',new.id,'amount',new.amount,'purpose',new.purpose)); end if; return new; end $$;
drop trigger if exists expense_publish on expense_requests; create trigger expense_publish after update on expense_requests for each row execute function itran_expense_publish();
-- Luật cảnh báo cấu hình mẫu (kiểu tự cấu hình): stock_days · metric_threshold · overdue_tasks · kpi_below · missing_event · due
insert into alert_rules(code,version,farm_id,name,source,expr,level,recipients,channels,description) values
 ('AL-STOCK-DAYS',1,'GLOBAL','Ngày-tồn mặt hàng dưới ngưỡng','custom','{"type":"stock_days","sku":"*","op":"<","value":30}','VANG','{worker:A8,tech_head,director}','{app}','Mọi mặt hàng K1–K4/K7 còn < 30 ngày dùng (dựa 14 ngày tiêu thụ)'),
 ('AL-STOCK-DAYS-RED',1,'GLOBAL','Ngày-tồn mặt hàng < 15 ngày','custom','{"type":"stock_days","sku":"*","op":"<","value":15}','DO','{tech_head,director,owner}','{app,zalo}','Cần đặt mua/mở rộng nguồn ngay'),
 ('AL-TASK-OVERDUE',1,'GLOBAL','Việc quá hạn > 5','custom','{"type":"overdue_tasks","op":">","value":5}','VANG','{tech_head,director}','{app}',null),
 ('AL-KPI-LAY',1,'GLOBAL','Tỷ lệ đẻ 7 ngày < 75%','custom','{"type":"metric_threshold","metric":"lay_pct","op":"<","value":75}','VANG','{worker:A3,tech_head}','{app}','Từ v_kpi_lay_rate'),
 ('AL-KPI-FEEDERR',1,'GLOBAL','Sai số mẻ TMR 7 ngày > 3%','custom','{"type":"metric_threshold","metric":"feed_err","op":">","value":3}','VANG','{worker:A1,tech_head}','{app}',null),
 ('AL-DEATHS-WEEK',1,'GLOBAL','Chết > 3 con/tuần (bò)','custom','{"type":"metric_threshold","metric":"deaths_week","op":">","value":3}','DO','{tech_head,director,owner}','{app,zalo}',null),
 ('AL-EXPAND-CROP',1,'GLOBAL','Cần mở rộng vùng trồng: ngày-tồn ủ chua < 60 và đàn tăng','custom','{"type":"expand_biomass","value":60}','VANG','{tech_head,director}','{app}','Gợi ý mở rộng đất sinh khối / liên kết hộ')
on conflict do nothing;
-- ===== KHAI BÁO TRẠI MỚI: hàm sinh khung dữ liệu chuẩn cho trại (9 kho · 12 CC · khu mặc định · settings · quỹ · chu kỳ) =====
create or replace function create_farm(p_id text, p_org text, p_region text, p_name text, p_province text, p_legal text, p_kind text, p_s numeric, p_k numeric, p_modules jsonb) returns text language plpgsql as $$
begin
  insert into farms(id,org_id,region_id,legal_entity,kind,name,province,s_ha,k_factor,scale_band,modules) values (p_id,p_org,p_region,p_legal,coalesce(p_kind,'CAMPUS'),p_name,p_province,p_s,p_k,
    case when p_s<3 then '<3ha' when p_s<10 then '3-10ha' when p_s<30 then '10-30ha' when p_s<60 then '30-60ha' else '>60ha' end, coalesce(p_modules,'{}'::jsonb));
  insert into cost_centers(id,farm_id,name) select p_id||'-'||c, p_id, n from (values ('CC-BO','Bò'),('CC-GA','Gà'),('CC-RAS','RAS'),('CC-TRUN','Trùn–BSF'),('CC-D5','Xưởng thức ăn D5'),('CC-TT','Trồng trọt'),('CC-CB','Chế biến'),('CC-KD','Kinh doanh'),('CC-DL','Du lịch'),('CC-HC','HC-TC-NS'),('CC-CN','Công nghệ'),('CC-VIEN','Kinh tế viền')) t(c,n) on conflict do nothing;
  insert into warehouses(id,farm_id,code,name,unit_kind,count_cycle,temp_monitored) select p_id||'-'||k.code, p_id, k.code, k.name, k.u, k.c, k.t from (values ('K1','Vật tư – thuốc – vaccine','SKU','THANG',false),('K2','Nguyên liệu thô mua','KG','THANG',false),('K3','Bán thành phẩm TA','KG','THANG',false),('K4','Thức ăn thành phẩm','KG','TUAN',false),('K5','Thành phẩm SKU','SKU','TUAN',false),('K6','Kho lạnh','KG','TUAN',true),('K7','Nhiên liệu','L','TUAN',false),('K8','Sổ đàn','CON','TUAN',false),('K9','Bao bì – tem','CAI','THANG',false)) k(code,name,u,c,t) on conflict do nothing;
  insert into locations(id,farm_id,code,name,kind,elevation_tier,grid_x,grid_y) values (p_id||'-KHU-C',p_id,'KHU-C','Khu chuồng','KHU','T1',0,0),(p_id||'-KHU-D',p_id,'KHU-D','Khu D sinh học','KHU','T1',1,0),(p_id||'-D5',p_id,'D5','Xưởng thức ăn','NHA','T1',2,0),(p_id||'-CONG',p_id,'CONG','Cổng lõi + cân','TRAM','T1',3,0),(p_id||'-TRAM-DAU',p_id,'TRAM-DAU','Trạm dầu','TRAM','T1',4,0) on conflict do nothing;
  insert into funds(farm_id,kind,pct,base) values (p_id,'THIEN_TAI',3,'DOANH_THU'),(p_id,'BAO_DUONG',5,'GIA_TRI_MAY'),(p_id,'DAO_TAO',1,'QUY_LUONG'),(p_id,'MARKETING',4,'DOANH_THU') on conflict do nothing;
  insert into cycles(id,farm_id,kind,name,start_date) values (p_id||'-NAM-'||to_char(now(),'YYYY'),p_id,'NAM_TC','Năm tài chính '||to_char(now(),'YYYY'),date_trunc('year',now())::date) on conflict do nothing;
  perform publish_event(p_id,'farm.created',jsonb_build_object('farm',p_id,'name',p_name));
  return p_id;
end $$;
grant execute on function create_farm(text,text,text,text,text,text,text,numeric,numeric,jsonb) to app_user;
create table if not exists farm_archives(farm_id text primary key references farms, archived_at timestamptz default now(), by_staff text, note text, export_file text);
alter table farm_archives enable row level security; drop policy if exists p_all on farm_archives; create policy p_all on farm_archives for all using (app_role() in ('owner')) with check (true); grant select, insert on farm_archives to app_user;
