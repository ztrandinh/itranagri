-- 0051 · v_lot_label: tên dị ứng tiếng Việt, NSX/HSD suy ra từ lô (created_at) + shelf_life nếu thiếu
drop view if exists v_lot_label;
create view v_lot_label as
select l.id as lot_id, l.farm_id, l.sku, p.name as sku_name, l.lot_no,
  coalesce(l.mfg_date, l.created_at::date) as mfg_date,
  coalesce(l.expiry_date, (coalesce(l.mfg_date, l.created_at::date) + coalesce(ls.shelf_life_days, p.shelf_life_days))::date) as expiry_date,
  ls.product_name, ls.ingredients, ls.allergens,
  (select array_agg(coalesce(a.name_vi, x) order by x) from unnest(coalesce(ls.allergens,'{}')) x left join allergens a on a.code=x) as allergen_names,
  ls.may_contain, ls.net_content, ls.nutrition, ls.storage, ls.usage_instr, ls.origin,
  coalesce(ls.producer, f.legal_entity, 'ITRAN FARM') as producer, coalesce(ls.address, f.address) as address, coalesce(ls.hotline, f.phone) as hotline, ls.claims, ls.std_marks, ls.halal, ls.organic, coalesce(ls.gtin, p.gtin) as gtin, ls.template, ls.warnings, ls.market, ls.lang
from lots l join products p on p.sku=l.sku join farms f on f.id=l.farm_id
left join lateral (select * from label_specs x where x.sku=l.sku and x.status='DUYET' order by (x.market='VN') desc, x.version desc limit 1) ls on true;
grant select on v_lot_label to app_user;
