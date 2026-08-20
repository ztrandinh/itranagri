-- 0146 · GIÁM SÁT TỶ LỆ CHẾT (mortality) — cảnh báo SỚM dịch bệnh/quản lý kém. Yêu cầu an toàn sinh học.
--
-- KPI tháng đã có (v_kpi_group_mortality, chỉ báo cáo, pct null khi head=0). Đây là TẦNG CẢNH BÁO:
-- tỷ lệ chết 30 ngày/đàn > norm → sinh việc cho thú y. READ-SIDE (view + task), KHÔNG hard-guard
-- bảng sự kiện → không phá seed/rebuild/phiên khác. Ngưỡng = norm (config=data), theo loài + trại.

insert into norms(id, kind, subject, value, unit, note) values
  ('ITRAN-N-MORT-BO',  'MORTALITY_MAX_30D', 'BO',  2, '%/đàn/30 ngày', 'Trần tỷ lệ chết bò 30 ngày — vượt = nghi dịch/quản lý kém'),
  ('ITRAN-N-MORT-GA',  'MORTALITY_MAX_30D', 'GA',  5, '%/đàn/30 ngày', 'Trần tỷ lệ chết gà 30 ngày'),
  ('ITRAN-N-MORT-ALL', 'MORTALITY_MAX_30D', 'ALL', 5, '%/đàn/30 ngày', 'Trần tỷ lệ chết mặc định (loài chưa đặt riêng)')
  on conflict (id) do nothing;

-- Tỷ lệ chết 30 ngày theo đàn (mẫu số = đầu đàn hiện tại + số đã chết trong kỳ ≈ quần thể phơi nhiễm)
create or replace view v_mortality_watch as
with base as (
  select g.farm_id, g.id as group_id, g.species, g.head_count,
         coalesce((select sum(e.value) from animal_events e
                    where e.group_id = g.id and e.event_type = 'CHET' and e.status = 'ACTIVE'
                      and e.ts >= now() - interval '30 days'), 0) as chet_30d
  from animal_groups g
), rated as (
  select b.*, case when b.head_count + b.chet_30d > 0
                   then round(100.0 * b.chet_30d / (b.head_count + b.chet_30d), 2) else 0 end as ty_le_pct
  from base b
)
select r.*, n.value as nguong,
       case when r.ty_le_pct > n.value then 'VUOT' else 'OK' end as muc
from rated r
join lateral (
  select value from norms
   where kind = 'MORTALITY_MAX_30D' and (subject = r.species or subject = 'ALL') and (farm_id = r.farm_id or farm_id is null)
   order by (subject = r.species) desc, (farm_id = r.farm_id) desc nulls last, version desc
   limit 1
) n on true;

-- Sinh việc khi đàn vượt trần chết (idempotent; tự đóng khi về OK) — pattern gen_amu_alerts
create or replace function gen_mortality_alerts(p_farm text) returns int language plpgsql as $$
declare o record; n int := 0; open_task uuid; begin
  for o in select * from v_mortality_watch where farm_id = p_farm and muc = 'VUOT' loop
    select id into open_task from tasks
      where farm_id = p_farm and ref_table = 'mortality' and ref_id = o.group_id and status <> 'XONG' limit 1;
    if open_task is null then
      insert into tasks(farm_id, kind, title, detail, target_type, target_id, role_hint, due_at, priority, source, ref_table, ref_id)
        values (p_farm, 'MORTALITY_HIGH',
          '⛔ TỶ LỆ CHẾT CAO: đàn '||o.group_id||' — '||o.ty_le_pct||'%/30 ngày (trần '||o.nguong||'%, '||o.chet_30d||' con)',
          jsonb_build_object('group', o.group_id, 'species', o.species, 'ty_le_pct', o.ty_le_pct, 'nguong', o.nguong, 'chet_30d', o.chet_30d,
            'note', 'Khám đàn ngay: nghi dịch/ngộ độc/stress. Cách ly nếu cần, báo thú y & giám đốc. Rà thức ăn/nước/mật độ.'),
          'GROUP', o.group_id, 'tech_head', now() + interval '1 day', 'KHAN', 'MORTALITY', 'mortality', o.group_id);
      n := n + 1;
    end if;
    perform publish_event(p_farm, 'mortality.high', jsonb_build_object('group', o.group_id, 'ty_le_pct', o.ty_le_pct, 'nguong', o.nguong));
  end loop;
  update tasks t set status = 'XONG', done_at = now(), done_by = 'system'
    where t.farm_id = p_farm and t.ref_table = 'mortality' and t.status <> 'XONG'
      and not exists (select 1 from v_mortality_watch d where d.farm_id = p_farm and d.group_id = t.ref_id and d.muc = 'VUOT');
  return n;
end $$;
grant execute on function gen_mortality_alerts(text) to app_user;
grant select on v_mortality_watch to app_user;
