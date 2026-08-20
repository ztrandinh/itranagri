-- 0170 · MRP #1 · NỐI CHUỖI: sửa gen_feed_plans (bug + hard-code) + GỘP CẦU nguyên liệu nhiều nguồn.
--
-- BUG: gen_feed_plans ghi cứng recipe_id='RC-GA-DE'/'RC-TMR-VO' — KHÔNG khớp recipes.id (ITRAN-RC-####) →
-- nổ công thức fail → v_days_of_stock.use_per_day=0 → toàn MRP đứng. Vi phạm luật 7 (hard-code).
-- SỬA: resolve recipe từ bảng recipes theo LOÀI của đàn (config-driven), + regenerate feed_plans.
-- v_material_demand: 1 nguyên liệu ← NHIỀU khẩu phần/đối tượng → GỘP TỔNG cầu/ngày (ngô cho nhiều đàn,
-- cỏ ủ cho bò+dê, ấu trùng cho gà+cá…).

create or replace function gen_feed_plans(p_farm text) returns integer language plpgsql as $$
declare n int := 0; r record; nrm numeric; v_recipe text; begin
  select value into nrm from norms where kind='TA_KG_CON_NGAY' and subject='BO' and (farm_id=p_farm or farm_id is null) order by farm_id nulls last limit 1;
  for r in select id, head_count, kind, species from animal_groups where farm_id=p_farm and status='ACTIVE' and head_count>0 loop
    -- recipe THẬT theo loài (config, không hard-code mã)
    select id into v_recipe from recipes where active and split_part(species_phase,'/',1) = r.species order by version desc limit 1;
    for i in 0..6 loop
      insert into feed_plans(farm_id,group_id,day,plan_kg,head,recipe_id) values (p_farm, r.id, current_date+i,
        case r.kind when 'BO_NHOM' then coalesce(nrm,32)*r.head_count when 'GA_DE' then 0.115*r.head_count when 'GA_THIT' then 0.09*r.head_count when 'RAS' then 0.012*r.head_count else 0.5*r.head_count end,
        r.head_count, v_recipe)
      on conflict (farm_id,group_id,day) do update set plan_kg=excluded.plan_kg, head=excluded.head, recipe_id=excluded.recipe_id; n:=n+1;
    end loop; end loop; return n; end $$;
grant execute on function gen_feed_plans(text) to app_user;

-- GỘP CẦU nguyên liệu/ngày từ MỌI khẩu phần × MỌI đàn (net requirement gross)
create or replace view v_material_demand as
with comp as (
  select r.id as recipe_id, (c->>'sku') as sku, nullif(c->>'pct','')::numeric as pct
  from recipes r, jsonb_array_elements(r.components) c
)
select fp.farm_id, comp.sku, fp.day as ts,
       round(sum(fp.plan_kg * comp.pct / 100.0)::numeric, 1) as demand_kg,
       count(distinct fp.recipe_id) as so_khau_phan,
       count(distinct fp.group_id)  as so_doi_tuong
from feed_plans fp
join comp on comp.recipe_id = fp.recipe_id
where comp.sku is not null and comp.pct is not null
group by fp.farm_id, comp.sku, fp.day;
grant select on v_material_demand to app_user;
