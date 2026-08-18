-- 0082 · trg_cache_dirty là trigger theo câu lệnh → không có NEW; lấy trại từ ngữ cảnh app.farm_id (bỏ qua nếu không có)
create or replace function trg_cache_dirty() returns trigger language plpgsql security definer as $$
declare f text := nullif(current_setting('app.farm_id', true), ''); begin
  if f is not null and f <> 'GLOBAL' then insert into cache_dirty(farm_id, dirty_at) values (f, now()) on conflict (farm_id) do update set dirty_at=now(); end if; return null; end $$;
alter table audit_log_cold enable row level security; drop policy if exists p_sel on audit_log_cold; create policy p_sel on audit_log_cold for select using (app_role() in ('owner','director','it_engineer','auditor','accountant')); grant select on audit_log_cold to app_user;
alter table cache_dirty enable row level security; drop policy if exists p_all on cache_dirty; create policy p_all on cache_dirty for all using (true) with check (true);
