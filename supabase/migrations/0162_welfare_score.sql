-- 0162 — T2.2 PHÚC LỢI ĐỊNH LƯỢNG: lameness (què) + giảm đau thủ thuật + view giám sát
--
-- Bối cảnh (audit §T2.2): hệ mới có BCS (monitoring_params BCS30) — thiếu lameness scoring,
-- và không ràng "giảm đau bắt buộc khi khử sừng/thiến".
--
-- NGUYÊN TẮC AN TOÀN (theo phối hợp điều phối): KHÔNG hard-guard chặn ghi trên animal_events
-- (bảng sự kiện traffic cao — seed-history/phiên khác chèn liên tục). Dùng:
--   * Config: thêm monitoring_param LAME (nhịp giám sát + ngưỡng, cấu hình = dữ liệu — luật 7).
--   * AFTER INSERT (skip IMPORT/backfill, KHÔNG raise): thủ thuật khử sừng/thiến thiếu giảm đau
--     → sinh VIỆC phúc lợi (không chặn ghi → không phá rebuild).
--   * View read-side v_welfare_gap: liệt kê lỗ phúc lợi (lameness cao + thủ thuật thiếu giảm đau).
-- Quy ước ghi thủ thuật: animal_events.detail->>'thu_thuat' ∈ ('KHU_SUNG','THIEN'),
--   detail->>'giam_dau' = 'true'/tên thuốc khi CÓ giảm đau.

-- 1) Lameness monitoring param (BO, DE) — điểm 0..3, ≥2 báo động
insert into monitoring_params(species_code, code, name, event_type, every_days, target_min, target_max, unit, level, role_hint, sop_code)
select v.sp, 'LAME30', 'Chấm điểm què (lameness) 0–3', 'LAME', 30, 0, 1, 'điểm', 'MAJOR', 'tech_head', null::text  -- sop_code=null: FK→sops; SOP-CN-10.1 nạp DB sau
from (values ('BO'),('DE')) v(sp)
where not exists (select 1 from monitoring_params m where m.code='LAME30' and m.species_code=v.sp);

-- 2) Trigger: thủ thuật khử sừng/thiến thiếu giảm đau → việc phúc lợi (AFTER, không chặn ghi)
create or replace function itran_welfare_painrelief()
returns trigger language plpgsql as $fn$
declare v_proc text; v_relief text;
begin
  if new.source = 'IMPORT' or new.is_backfill then return new; end if;
  v_proc   := new.detail->>'thu_thuat';
  if v_proc is null or v_proc not in ('KHU_SUNG','THIEN') then return new; end if;
  v_relief := new.detail->>'giam_dau';
  if v_relief is not null and v_relief <> '' and lower(v_relief) <> 'false' then
    return new;  -- có giảm đau → đạt phúc lợi
  end if;

  insert into tasks(farm_id, kind, title, detail, target_type, target_id,
                    role_hint, due_at, priority, source, ref_table, ref_id)
  values (new.farm_id, 'WELFARE_PAINREL',
          'Thủ thuật '||v_proc||' THIẾU giảm đau — con '||coalesce(new.animal_id,'?'),
          jsonb_build_object('animal', new.animal_id, 'thu_thuat', v_proc,
            'note','Phúc lợi WOAH/GlobalGAP: khử sừng/thiến bắt buộc giảm đau. Bổ sung phác đồ + ghi giảm đau.'),
          'ANIMAL', coalesce(new.animal_id, new.id::text),
          'ktt_ty', now()+interval '2 hour', 'CAO', 'welfare', 'animal_events', new.id::text);
  return new;
end $fn$;

drop trigger if exists zz_welfare_painrelief on animal_events;
create trigger zz_welfare_painrelief
  after insert on animal_events
  for each row execute function itran_welfare_painrelief();

-- 3) View read-side: lỗ phúc lợi (lameness ≥2 gần nhất + thủ thuật thiếu giảm đau)
create or replace view v_welfare_gap as
select farm_id, animal_id, 'LAMENESS' as loai,
       'Què điểm '||value::text as mo_ta, ts
  from animal_events
 where event_type='LAME' and value >= 2 and status='ACTIVE'
union all
select farm_id, animal_id, 'THIEU_GIAM_DAU' as loai,
       (detail->>'thu_thuat')||' không ghi giảm đau' as mo_ta, ts
  from animal_events
 where detail->>'thu_thuat' in ('KHU_SUNG','THIEN')
   and coalesce(nullif(lower(detail->>'giam_dau'),'false'),'') = ''
   and status='ACTIVE';
