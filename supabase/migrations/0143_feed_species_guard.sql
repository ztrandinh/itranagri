-- 0143 · FEED SPECIES GUARD (Nhóm 0/1) — cấm CHO ĂN SAI LOÀI tại lúc ghi.
--
-- Loài đàn đích (feed_logs.dest_group_id → animal_groups.species, vd BO/GA/LUON) PHẢI khớp
-- loài của khẩu phần (recipes.species_phase dạng 'LOÀI/GIAI_ĐOẠN', vd BO/VO2, GA/DE). Lệch =
-- chặn ngay (vd khẩu phần gà đổ cho đàn bò, hay ngược lại) → an toàn thú y + chống nhầm kho.
--
-- MỞ RỘNG trg_feed_guard sẵn có (0131/0134) — KHÔNG tạo trigger trùng. Chỉ kiểm khi CÓ cả
-- dest_group_id và recipe_id; cho ăn theo vị trí (không rõ đàn) hoặc chưa gắn recipe thì bỏ qua
-- (không cản luồng ghi tối thiểu 3 chạm). Dữ liệu hiện có: 1422 bản ghi khớp, 0 lệch → không chặn nhầm.

create or replace function chk_feed_species(p_group text, p_recipe text) returns void language plpgsql as $$
declare sp_group text; sp_recipe text; begin
  if p_group is null or p_recipe is null then return; end if;
  select species into sp_group from animal_groups where id = p_group;
  select split_part(species_phase, '/', 1) into sp_recipe from recipes where id = p_recipe order by version desc limit 1;
  if sp_group is null or sp_recipe is null or sp_recipe = '' then return; end if;  -- thiếu khai loài thì không chặn
  if sp_group <> sp_recipe then
    raise exception 'ERR_FEED_WRONG_SPECIES: khẩu phần loài % không được cho đàn loài % ăn (recipe %)', sp_recipe, sp_group, p_recipe;
  end if;
end $$;

-- Nối vào trg_feed_guard (giữ nguyên các kiểm cũ: ngày tương lai + đàn còn hoạt động)
create or replace function trg_feed_guard() returns trigger language plpgsql as $$
begin
  perform chk_no_future_ts(new.ts, new.is_backfill, new.source);
  perform chk_group_active(new.dest_group_id);
  perform chk_feed_species(new.dest_group_id, new.recipe_id);
  return new;
end $$;
