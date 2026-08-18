-- 0019 · RLS cho bảng sự kiện mới (crop_inputs, harvests, pos_receipts, hosp_folio) — cùng mẫu 0003 + append-only + supersede
do $$ declare t text; begin
  foreach t in array array['crop_inputs','harvests','pos_receipts','hosp_folio'] loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists p_sel on %I', t); execute format('create policy p_sel on %I for select using (can_see_farm(farm_id))', t);
    execute format('drop policy if exists p_ins on %I', t); execute format('create policy p_ins on %I for insert with check (farm_id = app_farm() and app_role() not in (''auditor'',''anon''))', t);
    execute format('drop policy if exists p_upd on %I', t); execute format('create policy p_upd on %I for update using (farm_id = app_farm() and app_role() not in (''auditor'',''anon'',''worker''))', t);
    execute format('drop policy if exists p_del on %I', t); execute format('create policy p_del on %I for delete using (false)', t);
    execute format('grant select, insert, update on %I to app_user', t);
  end loop; end $$;
