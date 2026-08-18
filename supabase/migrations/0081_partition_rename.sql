-- 0081 · đổi tên phân vùng *_p_YYYYMM → *_YYYYMM để ensure_month_partitions không trùng
do $$ declare r record; begin
  for r in select tablename from pg_tables where schemaname='public' and (tablename like 'event_bus_p_%' or tablename like 'audit_log_p_%' or tablename like 'stock_daily_p_%') loop
    execute format('alter table %I rename to %I', r.tablename, replace(r.tablename, '_p_', '_'));
  end loop; end $$;
