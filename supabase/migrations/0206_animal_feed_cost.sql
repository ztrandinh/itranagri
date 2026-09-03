-- 0170 · CHI PHÍ THỨC ĂN + LÃI/con CÁ THỂ (read-side) — để chủ quyết GIỮ hay BÁN.
--
-- Nối tiếp 0155/0156 (tăng trưởng + feed phân bổ/con) và 0158 (feed đàn). Ở đây quy feed đã phân bổ về
-- ĐẦU CON (÷ head_count) × ĐƠN GIÁ KHẨU PHẦN → chi phí thức ăn/con/tháng, luỹ kế, đ/kg tăng, và ước LÃI
-- nếu bán bây giờ. CHỈ CÁ THỂ (bò/dê — bảng animals; gà/lươn = đàn, đã có view riêng).
--
-- KHÔNG hard-code giá (luật 7):
--  · Đơn giá khẩu phần = Σ (pct thành phần × giá NL). Giá NL lấy products.ref_price → nếu trống thì
--    bình quân inventory_moves.unit_cost (mọi lần nhập có giá >0). Cỏ tự trồng không có giá NL = 0đ.
--  · Giá bán hơi = price_list (kind THI_TRUONG, subject '<LOÀI>_HOI': BO_HOI/DE_HOI) — cấu hình, có phiên bản.

-- Cấu hình giá dê hơi (bò hơi đã seed ở 0007). Chỉ thêm khi chưa có → chạy lại migrate không nhân đôi.
insert into price_list(org_id, kind, subject, price, unit, source)
select 'ITRAN', 'THI_TRUONG', 'DE_HOI', 120000, 'đ/kg', 'chợ đầu mối (cấu hình, GĐ duyệt quý)'
where not exists (select 1 from price_list where subject = 'DE_HOI' and kind = 'THI_TRUONG');

-- ĐƠN GIÁ mỗi kg khẩu phần (đ/kg) = Σ pct/100 × giá thành phần. Helper, không cắm chart.
create or replace view v_recipe_cost as
select r.id as recipe_id, r.farm_id,
       round(sum(
         (c->>'pct')::numeric / 100.0 * coalesce(
           p.ref_price,
           (select round(avg(m.unit_cost)) from inventory_moves m where m.sku = c->>'sku' and m.unit_cost > 0),
           0)
       )) as cost_per_kg
from recipes r,
     jsonb_array_elements(r.components) c
left join products p on p.sku = c->>'sku'
where (c->>'sku') is not null and (c->>'pct') is not null
group by r.id, r.farm_id;

-- CHI PHÍ THỨC ĂN + LÃI theo THÁNG / cá thể. farm_id + ts + animal_id + cột số → tự lên chart, drill được.
create or replace view v_animal_cost_month as
with feed as ( -- feed phân bổ/con × đơn giá khẩu phần → chi phí thức ăn/tháng/con
  select a.farm_id, a.id as animal_id, a.species,
         date_trunc('month', f.ts) as ts,
         sum(f.qty_kg / nullif(g.head_count, 0))                              as feed_kg,
         sum(f.qty_kg / nullif(g.head_count, 0) * coalesce(rc.cost_per_kg, 0)) as feed_cost
  from animals a
  join animal_groups g on g.id = a.group_id
  join feed_logs f     on f.dest_group_id = a.group_id and f.status = 'ACTIVE'
  left join v_recipe_cost rc on rc.recipe_id = f.recipe_id
  where g.head_count > 0
  group by a.farm_id, a.id, a.species, date_trunc('month', f.ts)
), fc as ( -- luỹ kế chi phí thức ăn tới từng tháng của con
  select farm_id, animal_id, species, ts, feed_kg, feed_cost,
         sum(feed_cost) over (partition by animal_id order by ts) as cum_feed_cost
  from feed
)
select fc.farm_id, fc.animal_id, fc.species, fc.ts,
       round(fc.feed_kg)                as feed_kg,        -- kg ăn (phân bổ) trong tháng
       round(fc.feed_cost)              as feed_cost,      -- đ thức ăn trong tháng
       round(fc.cum_feed_cost)          as cum_feed_cost,  -- đ thức ăn luỹ kế
       gm.w_kg, gm.gain_kg,
       case when coalesce(gm.gain_kg, 0) > 0
            then round(fc.feed_cost / gm.gain_kg) end                          as cost_per_gain, -- đ/kg tăng (thấp = tốt)
       case when coalesce(gm.w_kg, 0) > 0
            then round(gm.w_kg * pr.price - fc.cum_feed_cost) end              as est_profit     -- ước lãi nếu bán (giá hơi×cân − TA luỹ kế; chưa gồm giống/công)
from fc
left join v_animal_growth_month gm on gm.animal_id = fc.animal_id and gm.ts = fc.ts
left join lateral (
  select pl.price from price_list pl
  where pl.kind = 'THI_TRUONG' and pl.subject = fc.species || '_HOI'
    and (pl.valid_to is null or pl.valid_to >= current_date)
  order by pl.valid_from desc nulls last limit 1
) pr on true;

grant select on v_recipe_cost, v_animal_cost_month to app_user;
