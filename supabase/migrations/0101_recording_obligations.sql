-- 0098 · Cảnh báo NGHIÊM NGẶT khi khâu ghi chép bị QUÊN cập nhật.
-- Công nhân điền bảng mẫu theo quy trình (ngày/tuần/tháng/đợt). Quên nhập = mất dữ liệu đầu vào cho phân tích/dự báo.
-- Engine: khai báo "khâu bắt buộc" + tần suất → phát hiện quá hạn → tạo việc KHẨN cho người phụ trách, quá mức → LEO THANG lên GĐ, ghi nhật ký bỏ sót để đo tỷ lệ đúng hạn.

-- ===== Khai báo khâu ghi chép bắt buộc (config = data) =====
create table if not exists recording_obligations(
  id text primary key, farm_id text not null, code text not null, name text not null, dept text, role_hint text default 'team_lead',
  source_kind text not null,   -- METER/FEED/ANIMAL/CHECKLIST/PAPER/STOCK/HARVEST/PEST/IRRIGATION (map tới bảng ghi thật)
  freq text not null check (freq in ('CA','NGAY','TUAN','THANG','DOT')),
  grace_hours int default 6, escalate_hours int default 24, severity text default 'TRUNG', active boolean default true, note text,
  unique (farm_id, code)
);
alter table recording_obligations enable row level security; drop policy if exists p_all on recording_obligations;
create policy p_all on recording_obligations for all using (can_see_farm(farm_id)) with check (true);
grant select, insert, update on recording_obligations to app_user;

-- ===== Nhật ký bỏ sót (append log, 1 dòng / khâu / kỳ) — nguồn đo tỷ lệ đúng hạn =====
create table if not exists recording_misses(
  id uuid primary key default gen_random_uuid(), farm_id text not null, obligation_code text not null, period_key text not null,
  detected_at timestamptz default now(), hours_late numeric, severity text, escalated boolean default false, resolved_at timestamptz, resolved_by text,
  unique (farm_id, obligation_code, period_key)
);
alter table recording_misses enable row level security; drop policy if exists p_all on recording_misses;
create policy p_all on recording_misses for all using (can_see_farm(farm_id)) with check (true);
grant select, insert, update on recording_misses to app_user;

-- ===== Lần ghi gần nhất của mỗi loại khâu (map source_kind → bảng ghi thật) =====
create or replace function recording_last_ts(p_farm text, p_kind text) returns timestamptz language plpgsql stable as $$
declare t timestamptz; begin
  case p_kind
    when 'METER' then select max(ts) into t from device_readings where farm_id=p_farm;
    when 'FEED' then select max(ts) into t from feed_logs where farm_id=p_farm;
    when 'ANIMAL' then select max(ts) into t from animal_events where farm_id=p_farm;
    when 'CHECKLIST' then select max(ts) into t from checklist_runs where farm_id=p_farm;
    when 'PAPER' then select max(ts) into t from paper_scans where farm_id=p_farm;
    when 'STOCK' then select max(ts) into t from inventory_moves where farm_id=p_farm;
    when 'HARVEST' then select max(ts) into t from harvests where farm_id=p_farm;
    when 'PEST' then select max(ts) into t from pest_scouting where farm_id=p_farm;
    when 'IRRIGATION' then select max(ts) into t from irrigation_logs where farm_id=p_farm;
    else t := null; end case;
  return t; end $$;
grant execute on function recording_last_ts(text,text) to app_user;

-- ===== Trạng thái từng khâu: OK / DUE (quá hạn) / ESCALATE (quá hạn quá mức) =====
create or replace view v_recording_due as
 select o.id, o.farm_id, o.code, o.name, o.dept, o.role_hint, o.source_kind, o.freq, o.severity, o.escalate_hours,
   recording_last_ts(o.farm_id, o.source_kind) as last_ts,
   (case o.freq when 'CA' then interval '12 hours' when 'NGAY' then interval '1 day' when 'TUAN' then interval '7 days' when 'THANG' then interval '1 month' else null end) as period,
   greatest(0, round(extract(epoch from (now() - (coalesce(recording_last_ts(o.farm_id,o.source_kind), timestamptz '2000-01-01') + (case o.freq when 'CA' then interval '12 hours' when 'NGAY' then interval '1 day' when 'TUAN' then interval '7 days' when 'THANG' then interval '1 month' else interval '3650 days' end) + make_interval(hours => o.grace_hours))))/3600.0, 1)) as hours_late,
   case
     when o.freq='DOT' then 'OK'
     when now() <= coalesce(recording_last_ts(o.farm_id,o.source_kind), timestamptz '2000-01-01') + (case o.freq when 'CA' then interval '12 hours' when 'NGAY' then interval '1 day' when 'TUAN' then interval '7 days' when 'THANG' then interval '1 month' else interval '3650 days' end) + make_interval(hours => o.grace_hours) then 'OK'
     when extract(epoch from (now() - (coalesce(recording_last_ts(o.farm_id,o.source_kind), timestamptz '2000-01-01') + (case o.freq when 'CA' then interval '12 hours' when 'NGAY' then interval '1 day' when 'TUAN' then interval '7 days' when 'THANG' then interval '1 month' else interval '3650 days' end) + make_interval(hours => o.grace_hours))))/3600.0 > o.escalate_hours then 'ESCALATE'
     else 'DUE' end as level
 from recording_obligations o where o.active;
grant select on v_recording_due to app_user;

-- ===== Sinh cảnh báo nghiêm ngặt: việc KHẨN cho người phụ trách; quá mức → LEO THANG lên GĐ; ghi nhật ký bỏ sót =====
create or replace function gen_recording_alerts(p_farm text) returns int language plpgsql as $$
declare o record; n int := 0; pk text; esc boolean; sev text; open_task uuid; begin
  for o in select * from v_recording_due where farm_id=p_farm and level in ('DUE','ESCALATE') loop
    pk := case o.freq when 'TUAN' then to_char(now(),'IYYY-"W"IW') when 'THANG' then to_char(now(),'YYYY-MM') when 'CA' then to_char(now(),'YYYY-MM-DD')||case when extract(hour from now())<12 then '-S' else '-C' end else to_char(now(),'YYYY-MM-DD') end;
    esc := (o.level='ESCALATE'); sev := case when esc then 'NANG' else o.severity end;
    insert into recording_misses(farm_id, obligation_code, period_key, hours_late, severity, escalated)
      values (p_farm, o.code, pk, o.hours_late, sev, esc)
      on conflict (farm_id, obligation_code, period_key) do update set hours_late=excluded.hours_late, severity=excluded.severity, escalated=recording_misses.escalated or excluded.escalated;
    select id into open_task from tasks where farm_id=p_farm and ref_table='recording_obligations' and ref_id=o.code and status<>'XONG' limit 1;
    if open_task is null then
      insert into tasks(farm_id, kind, title, detail, target_type, target_id, role_hint, due_at, priority, source, ref_table, ref_id)
        values (p_farm, 'RECORD_MISS', (case when esc then '⛔ LEO THANG — ' else '⚠ ' end)||'QUÊN CẬP NHẬT: '||o.name||' (quá hạn '||o.hours_late||'h)',
          jsonb_build_object('obligation',o.code,'freq',o.freq,'source',o.source_kind,'note','Bảng mẫu khâu này CHƯA nhập kỳ này. Nhập ngay; số phải khớp giấy. Bỏ sót làm hỏng dữ liệu phân tích/dự báo.'),
          'OBLIGATION', o.code, case when esc then 'director' else o.role_hint end, now(), case when esc then 'KHAN' else 'CAO' end, 'RECORDING', 'recording_obligations', o.code);
      n := n + 1;
    elsif esc then
      update tasks set priority='KHAN', role_hint='director', title='⛔ LEO THANG — QUÊN CẬP NHẬT: '||o.name||' (quá hạn '||o.hours_late||'h)' where id=open_task;
    end if;
    perform publish_event(p_farm, 'recording.missed', jsonb_build_object('obligation',o.code,'level',o.level,'hours_late',o.hours_late));
  end loop;
  -- tự đóng khi khâu đã được cập nhật trở lại (level OK)
  update tasks t set status='XONG', done_at=now(), done_by='system'
    where t.farm_id=p_farm and t.ref_table='recording_obligations' and t.status<>'XONG'
      and exists (select 1 from v_recording_due d where d.farm_id=p_farm and d.code=t.ref_id and d.level='OK');
  update recording_misses m set resolved_at=now() where m.farm_id=p_farm and m.resolved_at is null
      and exists (select 1 from v_recording_due d where d.farm_id=p_farm and d.code=m.obligation_code and d.level='OK');
  return n; end $$;
grant execute on function gen_recording_alerts(text) to app_user;

-- ===== Tỷ lệ đúng hạn theo khâu (bỏ sót 30 ngày) — dữ liệu để đánh giá =====
create or replace view v_recording_compliance as
 select o.farm_id, o.dept, o.code, o.name, o.freq, o.source_kind,
   (select count(*) from recording_misses m where m.farm_id=o.farm_id and m.obligation_code=o.code and m.detected_at > now()-interval '30 days') as misses_30d,
   (select count(*) filter (where m.escalated) from recording_misses m where m.farm_id=o.farm_id and m.obligation_code=o.code and m.detected_at > now()-interval '30 days') as escalated_30d,
   (select max(m.detected_at) from recording_misses m where m.farm_id=o.farm_id and m.obligation_code=o.code) as last_miss
 from recording_obligations o where o.active;
grant select on v_recording_compliance to app_user;
