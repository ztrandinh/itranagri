-- 0003 · RLS 2 tầng (org + farm) · quyền ghi theo vai · append-only cho app_user
-- Ứng dụng đặt: set local app.org_id, app.farm_id, app.role, app.staff_id, app.farm_ids (csv)
create or replace function app_org() returns text language sql stable as $$ select nullif(current_setting('app.org_id', true),'') $$;
create or replace function app_farm() returns text language sql stable as $$ select nullif(current_setting('app.farm_id', true),'') $$;
create or replace function app_role() returns text language sql stable as $$ select coalesce(nullif(current_setting('app.role', true),''),'anon') $$;
create or replace function app_staff() returns text language sql stable as $$ select nullif(current_setting('app.staff_id', true),'') $$;
create or replace function app_farms() returns text[] language sql stable as $$ select string_to_array(coalesce(nullif(current_setting('app.farm_ids', true),''),''),',') $$;
-- được xem trại p_farm?
create or replace function can_see_farm(p_farm text) returns bool language sql stable as $$
  select app_role() in ('owner','auditor') and (p_farm = any(app_farms()) or app_farm() = p_farm or cardinality(app_farms())=0)
      or p_farm = app_farm()
$$;

do $$
declare t text;
begin
  -- bảng có farm_id: policy đọc theo can_see_farm, ghi theo farm hiện tại
  for t in select it.table_name::text from information_schema.tables it where it.table_schema='public' and it.table_type='BASE TABLE'
           and it.table_name not in ('schema_migrations','orgs','regions','products','sops','sop_versions','norms','kpi_defs','rc_rules','alert_rules','paper_form_templates','sessions','staff','farms','sensor_reads','id_sequences')
           and exists (select 1 from information_schema.columns c where c.table_name=it.table_name and c.column_name='farm_id' and c.table_schema='public')
  loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists p_sel on %I', t);
    execute format('create policy p_sel on %I for select using (can_see_farm(farm_id))', t);
    execute format('drop policy if exists p_ins on %I', t);
    execute format('create policy p_ins on %I for insert with check (farm_id = app_farm() and app_role() not in (''auditor'',''anon''))', t);
    execute format('drop policy if exists p_upd on %I', t);
    execute format('create policy p_upd on %I for update using (farm_id = app_farm() and app_role() not in (''auditor'',''anon'',''worker''))', t);
    execute format('drop policy if exists p_del on %I', t);
    execute format('create policy p_del on %I for delete using (false)', t);
    execute format('grant select, insert, update on %I to app_user', t);
  end loop;
end $$;

-- bảng toàn hệ (org scope): đọc theo org, ghi tech_head trở lên
do $$ declare t text; begin
  for t in select unnest(array['orgs','regions','products','sops','sop_versions','norms','kpi_defs','rc_rules','alert_rules','paper_form_templates']) loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists p_all on %I', t);
    execute format('create policy p_all on %I for select using (true)', t);
    execute format('drop policy if exists p_w on %I', t);
    execute format('create policy p_w on %I for all using (app_role() in (''tech_head'',''director'',''owner'',''it_engineer'')) with check (app_role() in (''tech_head'',''director'',''owner'',''it_engineer''))', t);
    execute format('grant select, insert, update on %I to app_user', t);
  end loop;
end $$;
-- farms: xem trại được phép; sửa director/owner
alter table farms enable row level security;
drop policy if exists p_farm_sel on farms; create policy p_farm_sel on farms for select using (can_see_farm(id) or org_id = app_org());
drop policy if exists p_farm_w on farms; create policy p_farm_w on farms for all using (app_role() in ('owner','director','it_engineer')) with check (true);
grant select, insert, update on farms to app_user;
-- staff: thấy cùng org; sửa director/owner; ai cũng thấy chính mình
alter table staff enable row level security;
drop policy if exists p_staff_sel on staff; create policy p_staff_sel on staff for select using (org_id = app_org() or id = app_staff());
drop policy if exists p_staff_w on staff; create policy p_staff_w on staff for all using (app_role() in ('owner','director','it_engineer')) with check (true);
grant select, insert, update on staff to app_user;
-- sessions/id_sequences/sensor_reads: không RLS (được truy cập qua hàm/service), grant
grant select, insert, update on sessions, id_sequences to app_user;
grant select, insert on sensor_reads to app_user;
grant usage on schema public to app_user;
grant execute on all functions in schema public to app_user;
alter default privileges in schema public grant select, insert, update on tables to app_user;

-- Chặn UPDATE trên bảng sự kiện đối với app_user trừ cột status (supersede) → revoke update, cho phép qua hàm
do $$ declare t text; begin
  for t in select unnest(array['animal_events','feed_logs','crop_logs','batch_logs','inventory_moves','weigh_tickets','gate_logs','sales','checklist_runs','incidents','stocktakes','calibrations']) loop
    execute format('revoke update on %I from app_user', t);
    execute format('grant update (status) on %I to app_user', t);
  end loop;
end $$;
-- adjustments: cho phép cập nhật cột duyệt; paper_scans: cột digitized; checklist_runs: duyệt
grant update (adj_status, approved_by, approved_at, status) on adjustments to app_user;
grant update (digitized, digitized_by, digitized_ts, linked_ids, anomaly, status) on paper_scans to app_user;
grant update (approved_by, approved_at, status) on checklist_runs to app_user;
grant update (acked_by, acked_at, resolved_at, incident_id) on alerts to app_user;
grant update (acked_by, incident_id) on recon_results to app_user;
