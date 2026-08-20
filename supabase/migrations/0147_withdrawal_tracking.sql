-- 0147 · NGƯNG THUỐC — theo dõi & NHẮC TỰ ĐỘNG (T0.2). Read-side: view + việc nhắc, KHÔNG hard-guard.
--
-- Trước đây withdrawal_until chỉ là 1 cột ngày "câm": guard chặn XUAT nhưng KHÔNG ai được nhắc, và
-- sữa/trứng/thịt vẫn có thể bị thu hoạch trong thời gian ngưng thuốc (guard chỉ chặn bán con sống).
-- T0.2 làm nó SỐNG: view cá thể đang ngưng thuốc + tự sinh việc nhắc "cấm xuất/thu hoạch tới ngày Y",
-- tự đóng khi hết. Pattern gen_amu_alerts (idempotent). Không đụng bảng sự kiện.

create or replace view v_withdrawal_active as
select a.farm_id, a.id as animal_id, a.visual_tag, a.group_id, a.location_id, a.withdrawal_until,
       (a.withdrawal_until - current_date) as con_lai_ngay,
       (select max(e.ts) from animal_events e
         where e.animal_id = a.id and e.event_type in ('DIEU_TRI','VACCINE') and e.status = 'ACTIVE') as dieu_tri_gan_nhat
from animals a
where a.withdrawal_until is not null and a.withdrawal_until >= current_date
  and coalesce(a.status,'') not in ('CHET','XUAT');

create or replace function gen_withdrawal_reminders(p_farm text) returns int language plpgsql as $$
declare o record; n int := 0; open_task uuid; begin
  for o in select * from v_withdrawal_active where farm_id = p_farm loop
    select id into open_task from tasks
      where farm_id = p_farm and ref_table = 'withdrawal' and ref_id = o.animal_id and status <> 'XONG' limit 1;
    if open_task is null then
      insert into tasks(farm_id, kind, title, detail, target_type, target_id, role_hint, due_at, priority, source, ref_table, ref_id)
        values (p_farm, 'WITHDRAWAL_ACTIVE',
          '⏳ NGƯNG THUỐC: '||coalesce(o.visual_tag, o.animal_id)||' — cấm xuất/thu hoạch tới '||o.withdrawal_until||' (còn '||o.con_lai_ngay||' ngày)',
          jsonb_build_object('animal', o.animal_id, 'withdrawal_until', o.withdrawal_until, 'con_lai', o.con_lai_ngay,
            'note', 'Không bán/giết mổ/lấy sữa-trứng-thịt con này tới hết ngày ngưng thuốc. Hệ đã chặn bán con sống; đây là nhắc cho SẢN PHẨM (sữa/trứng/thịt).'),
          'ANIMAL', o.animal_id, 'tech_head', o.withdrawal_until::timestamptz, 'CAO', 'WITHDRAWAL', 'withdrawal', o.animal_id);
      n := n + 1;
    end if;
  end loop;
  -- tự đóng khi con đã hết ngưng thuốc (không còn trong view)
  update tasks t set status = 'XONG', done_at = now(), done_by = 'system'
    where t.farm_id = p_farm and t.ref_table = 'withdrawal' and t.status <> 'XONG'
      and not exists (select 1 from v_withdrawal_active d where d.farm_id = p_farm and d.animal_id = t.ref_id);
  return n;
end $$;
grant execute on function gen_withdrawal_reminders(text) to app_user;
grant select on v_withdrawal_active to app_user;
