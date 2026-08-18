-- 0054 · gen_cycle_counts: id tasks là uuid
create or replace function gen_cycle_counts(p_farm text) returns int language plpgsql as $$
declare n int := 0; r record; begin
  for r in select sp.sku, p.name, sp.warehouse_id, coalesce(sp.count_cycle_days, case sp.abc_class when 'A' then 30 when 'B' then 90 else 180 end) as cyc
           from stock_policies sp join products p on p.sku=sp.sku where sp.farm_id=p_farm and sp.active loop
    if not exists (select 1 from stocktakes s where s.farm_id=p_farm and s.status='ACTIVE' and s.ts > current_date - r.cyc and (r.warehouse_id is null or s.warehouse_id=r.warehouse_id) and s.lines::text like '%'||r.sku||'%')
       and not exists (select 1 from tasks t where t.farm_id=p_farm and t.kind='KIEM_KE_CHU_KY' and t.status='MO' and t.target_id=r.sku) then
      insert into tasks(id, farm_id, kind, title, due_at, role_hint, target_type, target_id, status, source)
      values (gen_random_uuid(), p_farm, 'KIEM_KE_CHU_KY', 'Kiểm kê chu kỳ '||r.name||' ('||r.sku||') — chu kỳ '||r.cyc||' ngày', now()+interval '3 days', 'team_lead', 'sku', r.sku, 'MO', 'AUTO');
      n := n+1;
    end if;
  end loop; return n; end $$;
