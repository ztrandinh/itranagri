-- 0110 · device_readings: bắt bất thường bằng TRIGGER khi INSERT (chạy cho MỌI đường: form offline qua /api/events, online, IoT sau này)
--        + APPEND-ONLY (chặn UPDATE/DELETE, luật 2) + cột created_by (để đi qua endpoint events chuẩn).
-- Trước đây logic nằm trong hàm record_reading → chỉ chạy khi gọi hàm. Đưa vào trigger để offline-first (luật 5) dùng chung 1 nguồn sự thật.

alter table device_readings add column if not exists created_by text;

-- BEFORE INSERT: điền facility/unit/reader + tính prev/delta/bất thường từ cấu hình chỉ số
create or replace function trg_device_reading_calc() returns trigger language plpgsql as $$
declare m record; prev numeric; d numeric; anom boolean := false; reason text; begin
  select * into m from reading_metrics where id=new.metric_id and farm_id=new.farm_id;
  if m is null then raise exception 'ERR_NO_METRIC: %', new.metric_id; end if;
  new.facility_id := coalesce(new.facility_id, m.facility_id);
  new.unit := coalesce(new.unit, m.unit);
  new.reader_id := coalesce(new.reader_id, new.created_by);
  new.ts := coalesce(new.ts, now());
  select value into prev from device_readings where metric_id=new.metric_id and ts <= new.ts order by ts desc limit 1;
  if m.kind='METER' then
    d := new.value - coalesce(prev, new.value);
    if d < 0 then anom := true; reason := 'Số công-tơ LÙI ('||prev||'→'||new.value||') — sai đọc hoặc gian lận';
    elsif m.hi is not null and d > m.hi then anom := true; reason := 'Tiêu thụ kỳ '||round(d,1)||' '||m.unit||' > định mức '||m.hi||' — nghi rò/quá tải'; end if;
  else
    d := new.value;
    if m.lo is not null and new.value < m.lo then anom := true; reason := new.value||' < ngưỡng dưới '||m.lo||' '||m.unit;
    elsif m.hi is not null and new.value > m.hi then anom := true; reason := new.value||' > ngưỡng trên '||m.hi||' '||m.unit; end if;
  end if;
  new.prev_value := prev; new.delta := d; new.is_anomaly := anom; new.anomaly_reason := reason;
  return new;
end $$;
drop trigger if exists device_reading_calc on device_readings;
create trigger device_reading_calc before insert on device_readings for each row execute function trg_device_reading_calc();

-- AFTER INSERT: bất thường → sinh việc (đã gán người bởi assign_open_tasks trong job) + phát sự kiện
create or replace function trg_device_reading_task() returns trigger language plpgsql as $$
declare m record; begin
  if new.is_anomaly then
    select * into m from reading_metrics where id=new.metric_id;
    insert into tasks(farm_id, kind, title, detail, target_type, target_id, role_hint, due_at, priority, source, ref_table, ref_id)
      values (new.farm_id, 'DEVICE_ANOMALY', 'Bất thường số đọc: '||m.name||' — '||left(new.anomaly_reason,60),
        jsonb_build_object('metric', m.code, 'facility', m.facility_id, 'value', new.value, 'delta', new.delta, 'reason', new.anomaly_reason, 'note','Kiểm máy/công-tơ; đối chiếu SERI GIẤY; nếu đúng → xử lý sự cố'),
        'FACILITY', m.facility_id, coalesce(m.role_hint,'it_engineer'), now()+interval '1 day', 'CAO', 'READING', 'device_readings', new.id::text);
    perform publish_event(new.farm_id, 'device.reading.anomaly', jsonb_build_object('id',new.id,'metric',m.code,'facility',m.facility_id,'reason',new.anomaly_reason));
  end if;
  return new;
end $$;
drop trigger if exists device_reading_task on device_readings;
create trigger device_reading_task after insert on device_readings for each row execute function trg_device_reading_task();

-- APPEND-ONLY: chặn UPDATE/DELETE (sửa = ghi bản mới)
drop trigger if exists device_readings_noupd on device_readings;
create trigger device_readings_noupd before update or delete on device_readings for each row execute function itran_no_update_delete();

-- record_reading: thu gọn thành insert mỏng (trigger lo tính) — giữ idempotent theo client_ref
create or replace function record_reading(p_farm text, p_metric text, p_value numeric, p_ts timestamptz, p_paper_serial text, p_note text, p_by text, p_client_ref text, p_source text default 'APP') returns jsonb language plpgsql as $$
declare i uuid; existed uuid; r record; begin
  if p_client_ref is not null then select id into existed from device_readings where client_ref=p_client_ref; if existed is not null then return jsonb_build_object('id',existed,'dup',true); end if; end if;
  insert into device_readings(farm_id, metric_id, value, ts, paper_serial, note, reader_id, created_by, source, client_ref)
    values (p_farm, p_metric, p_value, coalesce(p_ts,now()), p_paper_serial, p_note, p_by, p_by, coalesce(p_source,'APP'), p_client_ref) returning id into i;
  select delta, is_anomaly, anomaly_reason into r from device_readings where id=i;
  return jsonb_build_object('id', i, 'delta', r.delta, 'anomaly', r.is_anomaly, 'reason', r.anomaly_reason);
end $$;
grant execute on function record_reading(text,text,numeric,timestamptz,text,text,text,text,text) to app_user;
