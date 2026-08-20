-- 0158 · Phân tích THỨC ĂN THEO ĐÀN (cho loài nuôi theo ĐÀN: gà/lươn/tôm/cá — KHÔNG quy về cá thể được).
--
-- PHÂN BIỆT (chủ nhấn mạnh): bò/dê = cá thể (có bảng animals → v_animal_* per-con). Gà/lươn = ĐÀN (chỉ
-- animal_groups, không có con, chỉ SO_LUONG/feed) → phân tích theo ĐÀN. View này KHÔNG join animals → đúng
-- cho mọi đàn. Feed tổng đàn + /đầu con + theo khẩu phần. (FCR đàn cần cân/biomass — gà seed chưa cân;
-- gà đẻ thì hiệu quả = feed/quả trứng, để chip riêng.)
create or replace view v_group_feed_daily as
select f.farm_id, f.dest_group_id as group_id,
       date_trunc('day', f.ts)                     as ts,
       sum(f.qty_kg)                               as feed_kg,          -- tổng cả đàn
       sum(f.qty_kg / nullif(g.head_count, 0))     as feed_per_head,    -- /đầu con
       coalesce(r.name, f.recipe_id, 'Chưa gắn khẩu phần') as recipe
from feed_logs f
join animal_groups g on g.id = f.dest_group_id
left join recipes r  on r.id = f.recipe_id
where f.status = 'ACTIVE'
group by f.farm_id, f.dest_group_id, date_trunc('day', f.ts), coalesce(r.name, f.recipe_id, 'Chưa gắn khẩu phần');
grant select on v_group_feed_daily to app_user;
