-- 0145 · AMU — GIÁM SÁT CƯỜNG ĐỘ ĐIỀU TRỊ (kháng sinh). Yêu cầu VietGAP/GlobalGAP/EU: ghi + giám sát AMU.
--
-- READ-SIDE thuần: view + sinh VIỆC cảnh báo (KHÔNG hard-guard bảng sự kiện → không phá seed/rebuild/phiên khác).
-- Tín hiệu "có dùng thuốc": DIEU_TRI có withdrawal_until (thuốc có tồn dư/ngưng thuốc). Ngưỡng = norm (config=data).
-- Theo đúng pattern gen_recording_alerts: idempotent (1 việc mở/con), tự đóng khi con về dưới ngưỡng.

-- Ngưỡng mặc định org-wide: tối đa N lượt điều trị-có-ngưng-thuốc / con / 90 ngày (có thể đặt riêng theo trại)
insert into norms(id, kind, subject, value, unit, note)
  values ('ITRAN-N-AMU90', 'AMU_MAX_90D', 'ALL', 5, 'lượt/con/90 ngày',
          'Trần cường độ điều trị (thuốc có ngưng thuốc) — vượt = nghi lạm dụng kháng sinh, rà bệnh án')
  on conflict (id) do nothing;

-- Cường độ điều trị 90 ngày gần nhất theo cá thể
create or replace view v_amu_usage as
select a.farm_id, ae.animal_id, a.visual_tag,
       count(*) filter (where ae.withdrawal_until is not null) as lan_dieu_tri_90d,
       max(ae.ts)                                              as lan_gan_nhat,
       max(a.withdrawal_until)                                 as ngung_thuoc_toi
from animal_events ae
join animals a on a.id = ae.animal_id
where ae.event_type = 'DIEU_TRI' and ae.status = 'ACTIVE' and ae.ts >= now() - interval '90 days'
group by a.farm_id, ae.animal_id, a.visual_tag;

-- So ngưỡng (norm theo trại ưu tiên, rồi org-wide)
create or replace view v_amu_over as
select u.*, n.value as nguong,
       case when u.lan_dieu_tri_90d > n.value then 'VUOT' else 'OK' end as muc
from v_amu_usage u
join lateral (
  select value from norms
   where kind = 'AMU_MAX_90D' and (farm_id = u.farm_id or farm_id is null)
   order by (farm_id = u.farm_id) desc nulls last, version desc
   limit 1
) n on true;

-- Sinh việc cho con vượt ngưỡng (idempotent; tự đóng khi về OK) — pattern gen_recording_alerts
create or replace function gen_amu_alerts(p_farm text) returns int language plpgsql as $$
declare o record; n int := 0; open_task uuid; begin
  for o in select * from v_amu_over where farm_id = p_farm and muc = 'VUOT' loop
    select id into open_task from tasks
      where farm_id = p_farm and ref_table = 'amu' and ref_id = o.animal_id and status <> 'XONG' limit 1;
    if open_task is null then
      insert into tasks(farm_id, kind, title, detail, target_type, target_id, role_hint, due_at, priority, source, ref_table, ref_id)
        values (p_farm, 'AMU_OVER',
          '⚠ Nghi LẠM DỤNG KHÁNG SINH: '||coalesce(o.visual_tag, o.animal_id)||' — '||o.lan_dieu_tri_90d||' lượt/90 ngày (trần '||o.nguong||')',
          jsonb_build_object('animal', o.animal_id, 'lan_90d', o.lan_dieu_tri_90d, 'nguong', o.nguong,
            'note', 'Rà bệnh án con này; nếu đúng phác đồ, xem lại đề kháng/điều kiện nuôi. Bảo đảm tuân thủ ngưng thuốc.'),
          'ANIMAL', o.animal_id, 'tech_head', now() + interval '2 days', 'CAO', 'AMU', 'amu', o.animal_id);
      n := n + 1;
    end if;
    perform publish_event(p_farm, 'amu.over', jsonb_build_object('animal', o.animal_id, 'lan_90d', o.lan_dieu_tri_90d, 'nguong', o.nguong));
  end loop;
  -- tự đóng việc khi con đã về dưới ngưỡng
  update tasks t set status = 'XONG', done_at = now(), done_by = 'system'
    where t.farm_id = p_farm and t.ref_table = 'amu' and t.status <> 'XONG'
      and not exists (select 1 from v_amu_over d where d.farm_id = p_farm and d.animal_id = t.ref_id and d.muc = 'VUOT');
  return n;
end $$;
grant execute on function gen_amu_alerts(text) to app_user;
grant select on v_amu_usage, v_amu_over to app_user;
