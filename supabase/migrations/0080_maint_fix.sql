-- 0080 · itran_maintenance: notifications dùng cột ts; refresh_agg_daily dùng delta stock_daily
create or replace function itran_maintenance() returns jsonb language plpgsql security definer as $$
declare r jsonb := '{}'::jsonb; n int; begin
  n := ensure_month_partitions('event_bus','ts',1,3) + ensure_month_partitions('audit_log','ts',1,3) + ensure_month_partitions('stock_daily','day',1,3); r := r || jsonb_build_object('partitions_created', n);
  if to_regprocedure('ensure_sensor_partitions()') is not null then perform ensure_sensor_partitions(); end if;
  delete from event_bus where processed_at is not null and ts < now() - interval '6 months'; get diagnostics n = row_count; r := r || jsonb_build_object('event_bus_purged', n);
  insert into audit_log_cold select * from audit_log where ts < now() - interval '24 months' on conflict do nothing; delete from audit_log where ts < now() - interval '24 months'; get diagnostics n = row_count; r := r || jsonb_build_object('audit_cold', n);
  delete from notifications where ts < now() - interval '12 months' and read_at is not null; get diagnostics n = row_count; r := r || jsonb_build_object('notifications_purged', n);
  delete from sessions where expires_at < now() - interval '30 days';
  analyze stock_daily; analyze inventory_moves; analyze event_bus; analyze audit_log;
  return r; exception when others then return r || jsonb_build_object('error', sqlerrm); end $$;

create or replace function refresh_agg_daily(p_farm text, p_day date) returns int language plpgsql as $$
declare n int := 0; begin
  delete from agg_daily where farm_id=p_farm and day=p_day;
  insert into agg_daily(farm_id,day,metric,dim,value,n)
  select p_farm, p_day, m.metric, m.dim, m.v, m.n from (
    select 'feed_kg' metric, coalesce(dest_group_id,'') dim, sum(qty_kg) v, count(*) n from feed_logs where farm_id=p_farm and status='ACTIVE' and ts::date=p_day group by 2
    union all select 'feed_err', coalesce(dest_group_id,''), avg(abs(qty_kg-planned_kg)/nullif(planned_kg,0))*100, count(*) from feed_logs where farm_id=p_farm and status='ACTIVE' and planned_kg>0 and ts::date=p_day group by 2
    union all select 'weight_avg', coalesce(group_id,''), avg(value), count(*) from animal_events e where farm_id=p_farm and status='ACTIVE' and event_type='CAN' and ts::date=p_day group by 2
    union all select 'deaths', coalesce(group_id,animal_id,''), sum(coalesce(value,1)), count(*) from animal_events where farm_id=p_farm and status='ACTIVE' and event_type='CHET' and ts::date=p_day group by 2
    union all select 'repro_events', event_type, count(*), count(*) from animal_events where farm_id=p_farm and status='ACTIVE' and event_type in ('DONG_DUC','PHOI','KHAM_THAI','DE','CAI_SUA') and ts::date=p_day group by 2
    union all select 'treatments', event_type, count(*), count(*) from animal_events where farm_id=p_farm and status='ACTIVE' and event_type in ('DIEU_TRI','VACCINE','BENH') and ts::date=p_day group by 2
    union all select 'eggs', coalesce(m.lot_id,''), sum(m.qty*coalesce(p.unit2_factor,1)), count(*) from inventory_moves m join products p on p.sku=m.sku where m.farm_id=p_farm and m.status='ACTIVE' and m.direction=1 and p.sku like 'SKU-TRUNG%' and m.ts::date=p_day group by 2
    union all select 'harvest_kg', coalesce(plot_id,''), sum(qty_kg), count(*) from crop_logs where farm_id=p_farm and status='ACTIVE' and activity in ('THU','CAT') and ts::date=p_day group by 2
    union all select 'machine_hours', coalesce(machine_id,''), sum(machine_hours), count(*) from crop_logs where farm_id=p_farm and status='ACTIVE' and ts::date=p_day group by 2
    union all select 'fuel_l', coalesce(from_to,''), sum(qty), count(*) from inventory_moves where farm_id=p_farm and status='ACTIVE' and direction=-1 and sku='NL-DAU' and ts::date=p_day group by 2
    union all select 'batch_in_kg', line, sum((i->>'kg')::numeric), count(*) from batch_logs b, jsonb_array_elements(b.inputs) i where farm_id=p_farm and status='ACTIVE' and ts::date=p_day group by 2
    union all select 'batch_out_kg', line, sum((o->>'kg')::numeric), count(*) from batch_logs b, jsonb_array_elements(b.outputs) o where farm_id=p_farm and status='ACTIVE' and ts::date=p_day group by 2
    union all select 'stock_in', sku, sum(qty), count(*) from inventory_moves where farm_id=p_farm and status='ACTIVE' and direction=1 and ts::date=p_day group by 2
    union all select 'stock_out', sku, sum(qty), count(*) from inventory_moves where farm_id=p_farm and status='ACTIVE' and direction=-1 and ts::date=p_day group by 2
    union all select 'stock_value_in', sku, sum(qty*coalesce(unit_cost,0)), count(*) from inventory_moves where farm_id=p_farm and status='ACTIVE' and direction=1 and reason='NHAP_MUA' and ts::date=p_day group by 2
    union all select 'sales_amount', channel::text, sum(amount), count(*) from sales where farm_id=p_farm and status='ACTIVE' and ts::date=p_day group by 2
    union all select 'sales_qty', sku, sum(qty), count(*) from sales where farm_id=p_farm and status='ACTIVE' and ts::date=p_day group by 2
    union all select 'records', coalesce(u.created_by,''), count(*), count(*) from (select created_by from animal_events where farm_id=p_farm and ts::date=p_day union all select created_by from feed_logs where farm_id=p_farm and ts::date=p_day union all select created_by from crop_logs where farm_id=p_farm and ts::date=p_day union all select created_by from batch_logs where farm_id=p_farm and ts::date=p_day union all select created_by from inventory_moves where farm_id=p_farm and ts::date=p_day union all select created_by from checklist_runs where farm_id=p_farm and ts::date=p_day union all select created_by from sales where farm_id=p_farm and ts::date=p_day) u group by 2
    union all select 'alerts', level, count(*), count(*) from alerts where farm_id=p_farm and ts::date=p_day group by 2
    union all select 'gate', direction, count(*), count(*) from gate_logs where farm_id=p_farm and status='ACTIVE' and ts::date=p_day group by 2
    union all select 'sensor', metric, avg(value), count(*) from sensor_reads where farm_id=p_farm and ts::date=p_day group by 2
  ) m; get diagnostics n = row_count;
  -- snapshot tồn kho & đàn cuối ngày
  perform itran_stock_daily_delta(p_farm, p_day);
  delete from herd_daily where farm_id=p_farm and day=p_day;
  insert into herd_daily select p_farm, p_day, species, status, count(*), sum(coalesce(last_weight_kg,0)), sum(coalesce(unit_value,0)) from animals where farm_id=p_farm and status not in ('CHET','XUAT') group by species, status;
  return n; end $$;

