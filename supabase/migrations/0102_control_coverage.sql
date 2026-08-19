-- 0102 · "Mỗi khâu đều có SOP (thực hành SX·an toàn·vệ sinh) = checklist bắt buộc chạy" + Độ phủ kiểm soát cho quản lý.
-- (1) Khâu ghi chép dạng CHECKLIST có thể trỏ ĐÚNG 1 SOP (source_ref) → quên chạy checklist SOP đó = báo gắt (dùng engine 0101).
-- (2) v_control_coverage: mỗi SOP × {tick checklist cuối · spot-check cuối · đi ca cuối} → vạch "vùng mù" để quản lý chĩa kiểm ngẫu nhiên (Tuyến 3), kể cả việc KHÔNG sinh số.

alter table recording_obligations add column if not exists source_ref text;   -- CHECKLIST → mã SOP (L2) cụ thể; null = mọi checklist

-- recording_last_ts nhận thêm source_ref (CHECKLIST lọc theo SOP; các nguồn khác giữ nguyên)
create or replace function recording_last_ts(p_farm text, p_kind text, p_ref text) returns timestamptz language plpgsql stable as $$
declare t timestamptz; begin
  case p_kind
    when 'METER' then select max(ts) into t from device_readings where farm_id=p_farm;
    when 'FEED' then select max(ts) into t from feed_logs where farm_id=p_farm;
    when 'ANIMAL' then select max(ts) into t from animal_events where farm_id=p_farm;
    when 'CHECKLIST' then
      if p_ref is not null then select max(ts) into t from checklist_runs where farm_id=p_farm and (sop_code=p_ref or sop_code like p_ref||'.%' or sop_code like p_ref||'%');
      else select max(ts) into t from checklist_runs where farm_id=p_farm; end if;
    when 'PAPER' then select max(ts) into t from paper_scans where farm_id=p_farm;
    when 'STOCK' then select max(ts) into t from inventory_moves where farm_id=p_farm;
    when 'HARVEST' then select max(ts) into t from harvests where farm_id=p_farm;
    when 'PEST' then select max(ts) into t from pest_scouting where farm_id=p_farm;
    when 'IRRIGATION' then select max(ts) into t from irrigation_logs where farm_id=p_farm;
    else t := null; end case;
  return t; end $$;
grant execute on function recording_last_ts(text,text,text) to app_user;

-- v_recording_due dùng bản 3 tham số (truyền source_ref) — drop trước vì thêm cột source_ref (không đổi tên cột được qua replace)
drop view if exists v_recording_due;
create view v_recording_due as
 select o.id, o.farm_id, o.code, o.name, o.dept, o.role_hint, o.source_kind, o.source_ref, o.freq, o.severity, o.escalate_hours,
   recording_last_ts(o.farm_id, o.source_kind, o.source_ref) as last_ts,
   (case o.freq when 'CA' then interval '12 hours' when 'NGAY' then interval '1 day' when 'TUAN' then interval '7 days' when 'THANG' then interval '1 month' else null end) as period,
   greatest(0, round(extract(epoch from (now() - (coalesce(recording_last_ts(o.farm_id,o.source_kind,o.source_ref), timestamptz '2000-01-01') + (case o.freq when 'CA' then interval '12 hours' when 'NGAY' then interval '1 day' when 'TUAN' then interval '7 days' when 'THANG' then interval '1 month' else interval '3650 days' end) + make_interval(hours => o.grace_hours))))/3600.0, 1)) as hours_late,
   case
     when o.freq='DOT' then 'OK'
     when now() <= coalesce(recording_last_ts(o.farm_id,o.source_kind,o.source_ref), timestamptz '2000-01-01') + (case o.freq when 'CA' then interval '12 hours' when 'NGAY' then interval '1 day' when 'TUAN' then interval '7 days' when 'THANG' then interval '1 month' else interval '3650 days' end) + make_interval(hours => o.grace_hours) then 'OK'
     when extract(epoch from (now() - (coalesce(recording_last_ts(o.farm_id,o.source_kind,o.source_ref), timestamptz '2000-01-01') + (case o.freq when 'CA' then interval '12 hours' when 'NGAY' then interval '1 day' when 'TUAN' then interval '7 days' when 'THANG' then interval '1 month' else interval '3650 days' end) + make_interval(hours => o.grace_hours))))/3600.0 > o.escalate_hours then 'ESCALATE'
     else 'DUE' end as level
 from recording_obligations o where o.active;
grant select on v_recording_due to app_user;

drop function if exists recording_last_ts(text,text);   -- bỏ bản 2 tham số cũ (0101), chỉ giữ bản 3 tham số

-- ===== ĐỘ PHỦ KIỂM SOÁT: mỗi SOP × lần tick/spot-check/đi-ca cuối → vùng mù (>14 ngày không ai kiểm) =====
create or replace function control_coverage(p_farm text) returns table(sop text, name text, dept text, last_checklist timestamptz, last_spotcheck timestamptz, last_fieldday date, days_since numeric, blind boolean) language sql stable as $$
  with l2 as (select l2_code as sop, (array_agg(dept order by l3_no))[1] as dept, max(l2_group) as name
              from sops where l2_code is not null and l3_no is not null group by l2_code)
  select l2.sop, l2.name, l2.dept, cr.last_checklist, sc.last_spotcheck, fd.last_fieldday,
    round(extract(epoch from now() - greatest(coalesce(cr.last_checklist, timestamptz '2000-01-01'), coalesce(sc.last_spotcheck, timestamptz '2000-01-01'), coalesce(fd.last_fieldday::timestamptz, timestamptz '2000-01-01')))/86400.0, 1) as days_since,
    (greatest(coalesce(cr.last_checklist, timestamptz '2000-01-01'), coalesce(sc.last_spotcheck, timestamptz '2000-01-01'), coalesce(fd.last_fieldday::timestamptz, timestamptz '2000-01-01')) < now()-interval '14 days') as blind
  from l2
    left join lateral (select max(ts) as last_checklist from checklist_runs where farm_id=p_farm and sop_code like l2.sop||'.%') cr on true
    left join lateral (select max(ts) as last_spotcheck from supervision_checks where farm_id=p_farm and (sop_code like l2.sop||'%' or target_dept=l2.dept)) sc on true
    left join lateral (select max(day) as last_fieldday from gs_field_days where farm_id=p_farm and dept=l2.dept) fd on true;
$$;
grant execute on function control_coverage(text) to app_user;
