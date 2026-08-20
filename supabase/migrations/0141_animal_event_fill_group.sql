-- 0141 — Điền group_id cho sự kiện con vật cá thể ở TRIGGER (fix gốc đếm đàn)
--
-- Lỗi (soát "còn bỏ sót"): đếm đầu đàn (itran_group_count_after) thoát sớm khi new.group_id null.
-- Sự kiện cá thể (bò/dê) ghi qua FORM công nhân thường chỉ chọn animal_id, KHÔNG kèm group_id
-- (schema events.ts để group_id optional) → CHET/XUAT/LOAI/NHAP con lẻ KHÔNG cập nhật đầu đàn.
-- 0138 mới sửa "cá thể = 1 đầu" nhưng chỉ có tác dụng khi group_id CÓ mặt. Đường form (và mọi
-- caller quên group_id, kể cả sell_livestock trước bản vá) vẫn hở.
--
-- Sửa GỐC, DRY: before-trigger tự điền new.group_id = group_id hiện tại của con vật khi
-- animal_id có mà group_id trống. Áp cho MỌI event_type → mọi đường ghi đếm đàn đúng, không
-- phải vá từng caller. (group_count_after chỉ cộng/trừ với CHET/LOAI/XUAT/NHAP/SO_LUONG nên
-- điền group_id cho các event khác là vô hại; animals_grp_change chỉ chạy khi ĐỔI nhóm nên
-- không nhân đôi.)

create or replace function itran_animal_event_before() returns trigger language plpgsql as $fn$
declare w date; g text;
begin
  -- điền nhóm hiện tại của con vật nếu caller bỏ trống → đếm đàn chạy đúng cho mọi đường ghi
  if new.animal_id is not null and new.group_id is null then
    select group_id into g from animals where id = new.animal_id;
    new.group_id := g;
  end if;

  if new.event_type = 'XUAT' and new.animal_id is not null then
    select withdrawal_until into w from animals where id = new.animal_id;
    if w is not null and w > new.ts::date and coalesce(new.detail->>'override_by','') = '' then
      raise exception 'ERR_WITHDRAWAL_ACTIVE: animal % under withdrawal until %', new.animal_id, w;
    end if;
  end if;

  return new;
end $fn$;
