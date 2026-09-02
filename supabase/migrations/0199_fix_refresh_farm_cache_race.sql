-- 0199 · Phát hiện khi truy vết bug thật do phiên khác báo cáo (React "duplicate key" cho nhiều SKU
-- trên /du-tru): refresh_farm_cache() DELETE-rồi-INSERT không khoá. `ensureFarmCache()` (route
-- /api/data/[view]) gọi fire-and-forget, không đồng bộ — 2 request đồng thời cho CÙNG 1 trại (dễ xảy
-- ra khi nhiều tab/nhiều phiên cùng mở dashboard trong cửa sổ TTL 15') có thể xen kẽ: cả 2 cùng DELETE
-- xong 0 dòng còn lại rồi cùng INSERT trọn bộ kết quả → toàn bộ cache_stock_dashboard bị NHÂN ĐÔI cho
-- trại đó (không phải lỗi 1 SKU cụ thể — đúng khớp triệu chứng "nhiều SKU khác nhau cùng trùng key").
-- Vá bằng pg_advisory_xact_lock theo farm_id, đúng pattern rate-limit login (0003_rls.sql liên quan)
-- đã dùng trong codebase — khoá tự giải phóng khi statement/transaction gọi hàm kết thúc.
create or replace function refresh_farm_cache(p_farm text) returns jsonb language plpgsql security definer as $$
declare n1 int; t0 timestamptz := clock_timestamp(); begin
  perform pg_advisory_xact_lock(hashtext('cache_stock_dashboard:'||p_farm));
  delete from cache_stock_dashboard where farm_id=p_farm;
  insert into cache_stock_dashboard select v.*, now() from v_stock_dashboard v where v.farm_id=p_farm; get diagnostics n1 = row_count;
  insert into cache_kv(farm_id, key, payload, refreshed_at) values
   (p_farm, 'herd_forecast_series', coalesce((select jsonb_agg(row_to_json(x)) from (select h.horizon, f.* from (values (0),(30),(60),(90)) h(horizon), lateral herd_forecast(p_farm, h.horizon) f order by f.class_code, h.horizon) x), '[]'::jsonb), now()),
   (p_farm, 'feed_forecast_series', coalesce((select jsonb_agg(row_to_json(x)) from (select h.horizon, sum(f.kg_day_forecast) as kg_day, sum(f.head_forecast) as head from (values (0),(30),(60),(90)) h(horizon), lateral feed_forecast(p_farm, h.horizon) f group by h.horizon order by h.horizon) x), '[]'::jsonb), now()),
   (p_farm, 'plan_supply_live', coalesce((select jsonb_agg(row_to_json(x)) from plan_supply(p_farm, null) x), '[]'::jsonb), now()),
   (p_farm, 'warehouse_fill', coalesce((select jsonb_agg(row_to_json(x)) from v_warehouse_fill x where x.farm_id=p_farm), '[]'::jsonb), now())
  on conflict (farm_id, key) do update set payload=excluded.payload, refreshed_at=now();
  return jsonb_build_object('rows', n1, 'ms', round(extract(epoch from clock_timestamp()-t0)*1000)); end $$;

-- Dọn dữ liệu nhân đôi hiện có (nếu race đã từng xảy ra trước khi vá) — giữ đúng 1 dòng mới nhất
-- theo (farm_id, block, sku), xoá phần trùng.
delete from cache_stock_dashboard a using cache_stock_dashboard b
where a.farm_id=b.farm_id and a.block=b.block and a.sku=b.sku
  and (a.refreshed_at, a.ctid) < (b.refreshed_at, b.ctid);
