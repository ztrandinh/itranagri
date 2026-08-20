-- 0156 · Thức ăn nạp/cá thể THEO LOẠI KHẨU PHẦN (thức ăn hỗn hợp). Thêm chiều `recipe` để chart tách theo mix.
-- feed_logs.recipe_id = khẩu phần/công thức trộn (TMR…). Thêm cột recipe (CUỐI view → create-or-replace an toàn
-- với view phụ thuộc v_animal_growth_month, nó chỉ dùng feed_kg). Tổng feed vẫn đúng (sum cộng mọi recipe).

create or replace view v_animal_feed_daily as
select a.farm_id, a.id as animal_id, a.group_id,
       date_trunc('day', f.ts)                    as ts,
       sum(f.qty_kg / nullif(g.head_count, 0))    as feed_kg,
       coalesce(r.name, f.recipe_id, 'Chưa gắn khẩu phần') as recipe
from animals a
join animal_groups g on g.id = a.group_id
join feed_logs f     on f.dest_group_id = a.group_id and f.status = 'ACTIVE'
left join recipes r  on r.id = f.recipe_id
where g.head_count > 0
group by a.farm_id, a.id, a.group_id, date_trunc('day', f.ts), coalesce(r.name, f.recipe_id, 'Chưa gắn khẩu phần');
