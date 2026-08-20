-- 0138 — Sửa đếm đầu đàn khi vật nuôi CÁ THỂ chết/loại/xuất
--
-- Lỗi (truy live): con bò/dê CHẾT lẻ → status='CHET' nhưng animal_groups.head_count KHÔNG giảm.
-- itran_group_count_after trừ theo new.value — đúng cho sự kiện ĐÀN (gà/tôm: SO_LUONG value=N),
-- nhưng sự kiện CÁ THỂ (bò/dê: 1 con/ sự kiện) có value=NULL → trừ 0. head_count drift dần
-- (chỉ khớp lúc gieo vì seed set cứng cuối mẻ; recompute animals_grp_change chỉ chạy khi ĐỔI NHÓM,
-- không chạy khi chết). → đầu đàn báo cáo cao hơn thực tế sau mỗi con chết/xuất lẻ.
--
-- Sửa: sự kiện cá thể (animal_id không null) tính 1 đầu; sự kiện đàn (animal_id null) giữ theo value.

create or replace function itran_group_count_after() returns trigger language plpgsql as $fn$
declare v_delta int;
begin
  if new.group_id is null then return new; end if;
  -- cá thể: 1 đầu/sự kiện; đàn: theo value
  v_delta := case when new.animal_id is not null then 1 else coalesce(new.value,0)::int end;

  if new.event_type in ('CHET','LOAI','XUAT') then
    update animal_groups set head_count = greatest(0, head_count - v_delta) where id = new.group_id;
  elsif new.event_type in ('NHAP') then
    update animal_groups set head_count = head_count + v_delta where id = new.group_id;
  elsif new.event_type = 'SO_LUONG' and coalesce(new.detail->>'metric','') = 'head_count' then
    update animal_groups set head_count = coalesce(new.value,0)::int where id = new.group_id;
  end if;
  return new;
end $fn$;

-- Đồng bộ lại head_count cho các nhóm cá thể về đúng số con đang sống (vá drift đã có, nếu có).
update animal_groups g
   set head_count = (select count(*) from animals a where a.group_id = g.id and a.status not in ('CHET','XUAT','LOAI'))
 where g.kind = 'BO_NHOM';
