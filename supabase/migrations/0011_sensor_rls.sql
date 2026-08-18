-- 0011 · RLS cho sensor_reads (partition kế thừa policy từ bảng cha)
alter table sensor_reads enable row level security;
drop policy if exists p_sel on sensor_reads; create policy p_sel on sensor_reads for select using (can_see_farm(farm_id));
drop policy if exists p_ins on sensor_reads; create policy p_ins on sensor_reads for insert with check (farm_id=app_farm() and app_role() not in ('auditor','anon'));
grant select, insert on sensor_reads to app_user;
