-- 0097 · Sổ đọc số vận hành máy/công-tơ (điện·nước·biogas·giờ máy·sản lượng) — công nhân vận hành máy ghi số,
-- đối chiếu SERI GIẤY (giấy bắt buộc = file cứng soát file mềm), tự bắt bất thường → việc/cảnh báo.
-- Đây là "cái bàn" mà IoT/MQTT (red-list) sẽ ghi vào sau — giờ nhập tay, sau tự động, cùng schema (source APP/PAPER/IOT).

-- ===== Cấu hình chỉ số đọc theo máy (config = data, có phiên bản qua active) =====
create table if not exists reading_metrics(
  id text primary key, farm_id text not null, facility_id text not null, code text not null, name text not null, unit text not null,
  kind text not null default 'METER' check (kind in ('METER','SPOT')),   -- METER: công-tơ tích lũy (điện/nước/giờ máy) · SPOT: đo tức thời (nhiệt/mực)
  freq text not null default 'NGAY' check (freq in ('CA','NGAY','TUAN')),
  lo numeric, hi numeric,   -- METER: hi = chênh tối đa mỗi kỳ (vượt = bất thường) · SPOT: [lo,hi] khoảng cho phép
  role_hint text default 'it_engineer', active boolean default true, note text,
  unique (farm_id, facility_id, code)
);
alter table reading_metrics enable row level security; drop policy if exists p_all on reading_metrics;
create policy p_all on reading_metrics for all using (can_see_farm(farm_id)) with check (true);
grant select, insert, update on reading_metrics to app_user;

-- ===== Số đọc (append-only: sửa = ghi bản mới, KHÔNG update/delete) =====
create table if not exists device_readings(
  id uuid primary key default gen_random_uuid(), farm_id text not null, facility_id text not null, metric_id text not null references reading_metrics(id),
  ts timestamptz not null default now(), value numeric not null, unit text, prev_value numeric, delta numeric,
  is_anomaly boolean default false, anomaly_reason text, paper_serial text, note text,
  reader_id text, source text not null default 'APP' check (source in ('APP','PAPER','IOT')), client_ref text unique, created_at timestamptz default now()
);
create index if not exists idx_device_readings_metric_ts on device_readings(metric_id, ts desc);
alter table device_readings enable row level security; drop policy if exists p_all on device_readings;
create policy p_all on device_readings for all using (can_see_farm(farm_id)) with check (true);
grant select, insert on device_readings to app_user;   -- append-only: không cấp update/delete

-- ===== Ghi 1 số đọc: tính chênh so kỳ trước, bắt bất thường, sinh việc nếu bất thường =====
create or replace function record_reading(p_farm text, p_metric text, p_value numeric, p_ts timestamptz, p_paper_serial text, p_note text, p_by text, p_client_ref text, p_source text default 'APP') returns jsonb language plpgsql as $$
declare m record; prev numeric; d numeric; anom boolean := false; reason text; i uuid; existed uuid;
begin
  if p_client_ref is not null then select id into existed from device_readings where client_ref=p_client_ref; if existed is not null then return jsonb_build_object('id',existed,'dup',true); end if; end if;
  select * into m from reading_metrics where id=p_metric and farm_id=p_farm; if m is null then raise exception 'ERR_NO_METRIC'; end if;
  select value into prev from device_readings where metric_id=p_metric and ts <= coalesce(p_ts, now()) order by ts desc limit 1;
  if m.kind='METER' then
    d := p_value - coalesce(prev, p_value);
    if d < 0 then anom := true; reason := 'Số công-tơ LÙI ('||prev||'→'||p_value||') — sai đọc hoặc gian lận';
    elsif m.hi is not null and d > m.hi then anom := true; reason := 'Tiêu thụ kỳ '||round(d,1)||' '||m.unit||' > định mức '||m.hi||' — nghi rò/quá tải'; end if;
  else
    d := p_value;
    if m.lo is not null and p_value < m.lo then anom := true; reason := p_value||' < ngưỡng dưới '||m.lo||' '||m.unit;
    elsif m.hi is not null and p_value > m.hi then anom := true; reason := p_value||' > ngưỡng trên '||m.hi||' '||m.unit; end if;
  end if;
  insert into device_readings(farm_id, facility_id, metric_id, ts, value, unit, prev_value, delta, is_anomaly, anomaly_reason, paper_serial, note, reader_id, source, client_ref)
    values (p_farm, m.facility_id, p_metric, coalesce(p_ts, now()), p_value, m.unit, prev, d, anom, reason, p_paper_serial, p_note, p_by, coalesce(p_source,'APP'), p_client_ref) returning id into i;
  if anom then
    insert into tasks(farm_id, kind, title, detail, target_type, target_id, role_hint, due_at, priority, source, ref_table, ref_id)
      values (p_farm, 'DEVICE_ANOMALY', 'Bất thường số đọc: '||m.name||' — '||left(reason,60),
        jsonb_build_object('metric', m.code, 'facility', m.facility_id, 'value', p_value, 'delta', d, 'reason', reason, 'note','Kiểm máy/công-tơ; đối chiếu SERI GIẤY; nếu đúng → xử lý sự cố'),
        'FACILITY', m.facility_id, coalesce(m.role_hint,'it_engineer'), now()+interval '1 day', 'CAO', 'READING', 'device_readings', i::text);
    perform publish_event(p_farm, 'device.reading.anomaly', jsonb_build_object('id',i,'metric',m.code,'facility',m.facility_id,'reason',reason));
  end if;
  return jsonb_build_object('id', i, 'delta', d, 'anomaly', anom, 'reason', reason);
end $$;
grant execute on function record_reading(text,text,numeric,timestamptz,text,text,text,text,text) to app_user;

-- ===== Số đọc mới nhất mỗi chỉ số (kèm tên máy, chênh kỳ, cờ bất thường) =====
create or replace view v_reading_latest as
 select distinct on (r.metric_id) r.metric_id, m.farm_id, m.facility_id, f.name as facility_name, m.code, m.name as metric_name, m.unit, m.kind,
   r.ts, r.value, r.delta, r.is_anomaly, r.anomaly_reason, r.paper_serial, r.reader_id, r.source
 from device_readings r join reading_metrics m on m.id=r.metric_id left join facilities f on f.id=m.facility_id
 order by r.metric_id, r.ts desc;
grant select on v_reading_latest to app_user;

-- ===== Chỉ số CẦN ĐỌC (quá hạn theo tần suất) — dẫn việc cho người vận hành =====
create or replace view v_reading_due as
 select m.id as metric_id, m.farm_id, m.facility_id, f.name as facility_name, m.code, m.name as metric_name, m.unit, m.freq, m.role_hint,
   l.ts as last_ts,
   (now() - coalesce(l.ts, now() - interval '99 days')) > (case m.freq when 'CA' then interval '12 hours' when 'NGAY' then interval '1 day' else interval '7 days' end) as due
 from reading_metrics m left join facilities f on f.id=m.facility_id
   left join lateral (select ts from device_readings d where d.metric_id=m.id order by d.ts desc limit 1) l on true
 where m.active;
grant select on v_reading_due to app_user;
