-- 0202 · chk_feed_species() (0143) thiếu `security definer`, giống lỗ hổng đã vá ở ensure_sensor_partitions().
--
-- recipes có RLS SELECT theo can_see_farm(farm_id). Hàm chạy dưới quyền app_user (không security
-- definer) nên nếu recipe_id thuộc TRẠI KHÁC farm_id đang set trong ngữ cảnh (app.farm_id), dòng
-- recipe bị RLS ẩn đi → sp_recipe ra NULL → hàm ÂM THẦM bỏ qua kiểm tra (dòng "recipe null thì không
-- chặn") thay vì raise ERR_FEED_WRONG_SPECIES. Tức là chỉ cần gửi recipe_id của trại khác là né được
-- toàn bộ species guard — đúng thứ mà 0143 sinh ra để chặn ("chống nhầm kho"). Phát hiện qua CI thật
-- (build-test PR #66) khi 1 lứa bò F99 vô tình khớp cùng test với recipe GA chỉ seed ở F01.
create or replace function chk_feed_species(p_group text, p_recipe text) returns void language plpgsql security definer as $$
declare sp_group text; sp_recipe text; begin
  if p_group is null or p_recipe is null then return; end if;
  select species into sp_group from animal_groups where id = p_group;
  select split_part(species_phase, '/', 1) into sp_recipe from recipes where id = p_recipe order by version desc limit 1;
  if sp_group is null or sp_recipe is null or sp_recipe = '' then return; end if;  -- thiếu khai loài thì không chặn
  if sp_group <> sp_recipe then
    raise exception 'ERR_FEED_WRONG_SPECIES: khẩu phần loài % không được cho đàn loài % ăn (recipe %)', sp_recipe, sp_group, p_recipe;
  end if;
end $$;
