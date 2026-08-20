-- 0174 · PHỦ BIỂU ĐỒ HIỆU QUẢ cho các đối tượng còn thiếu (read-side thuần, cắm vào chart "mọi trường").
--
-- Nguyên tắc: chỉ VIEW đo lường (farm_id + ts + cột SỐ + cột lọc); KHÔNG hard-guard bảng sự kiện; KHÔNG
-- fix cứng SKU/loài — mọi ngưỡng/loại đọc từ dữ liệu (detail jsonb, products, class). Loài nuôi ĐÀN (gà/lươn)
-- phân tích theo ĐÀN; bò/dê cá thể có view riêng (0155) → gộp lên đàn ở đây để so lứa.

-- ============================================================================
-- A. GÀ ĐẺ (đàn) — sản lượng trứng, tỷ lệ đẻ, thức ăn/quả trứng.
-- Trứng ghi bằng animal_events SO_LUONG với detail.metric='eggs_counted' (value=số quả/ngày, detail.lay_pct,
-- detail.hens). Đây là NHÃN NGỮ NGHĨA trong dữ liệu (không hard-code loài) → mọi đàn ghi eggs_counted đều lên chart.
-- ============================================================================
create or replace view v_group_egg_daily as
select e.farm_id, e.group_id,
       date_trunc('day', e.ts)                     as ts,
       e.value                                     as eggs,          -- số trứng/ngày (quả)
       (e.detail->>'lay_pct')::numeric             as lay_pct,       -- tỷ lệ đẻ (%) — cao = tốt
       (e.detail->>'hens')::numeric                as hens           -- mái đang đẻ
from animal_events e
where e.event_type = 'SO_LUONG'
  and e.detail->>'metric' = 'eggs_counted'
  and e.status = 'ACTIVE'
  and coalesce(e.value, 0) > 0;
grant select on v_group_egg_daily to app_user;

-- Hiệu quả thức ăn theo THÁNG (khớp tổng trứng ↔ tổng cám cùng tháng để tránh nhiễu ngày ghi cám thưa).
create or replace view v_group_egg_month as
with eg as (
  select farm_id, group_id, date_trunc('month', ts) as mth,
         sum(eggs) as eggs, round(avg(lay_pct), 1) as lay_pct
  from v_group_egg_daily group by farm_id, group_id, date_trunc('month', ts)
), fd as (
  select farm_id, dest_group_id as group_id, date_trunc('month', ts) as mth, sum(qty_kg) as feed_kg
  from feed_logs where status = 'ACTIVE' group by farm_id, dest_group_id, date_trunc('month', ts)
)
select eg.farm_id, eg.group_id, eg.mth as ts,
       eg.eggs, eg.lay_pct, fd.feed_kg,
       case when eg.eggs > 0 and fd.feed_kg is not null
            then round((fd.feed_kg / eg.eggs)::numeric, 3) end as feed_per_egg   -- kg cám / quả (THẤP = tốt)
from eg left join fd on fd.group_id = eg.group_id and fd.mth = eg.mth;
grant select on v_group_egg_month to app_user;

-- ============================================================================
-- B. SO SÁNH LỨA/ĐÀN bò/dê — gộp v_animal_growth_month (0155) theo animals.group_id → FCR/ADG trung bình đàn.
-- (Chỉ loài có cá thể + group_id: bò. Dê seed chưa gắn group_id nên chưa lên — sẽ tự có khi gắn đàn.)
-- ============================================================================
create or replace view v_group_growth_month as
select a.farm_id, a.group_id, g.ts,
       round(avg(g.w_kg), 1)            as w_kg,        -- cân TB con trong đàn
       round(avg(g.gain_kg), 2)         as gain_kg,     -- tăng trọng TB/con/tháng
       round(avg(g.fcr), 2)             as fcr,         -- FCR TB đàn (THẤP = tốt)
       round(avg(g.adg_g), 0)           as adg_g,       -- ADG TB đàn (g/ngày, CAO = tốt)
       count(*)                         as n_animals    -- số con có số liệu tháng đó
from v_animal_growth_month g
join animals a on a.id = g.animal_id
where a.group_id is not null
group by a.farm_id, a.group_id, g.ts;
grant select on v_group_growth_month to app_user;

-- ============================================================================
-- D. NĂNG SUẤT NHÂN SỰ — việc hoàn thành/ngày + tỷ lệ đúng hạn (on-time).
-- ============================================================================
create or replace view v_staff_task_daily as
select farm_id, done_by as staff_id,
       date_trunc('day', done_at)                                             as ts,
       count(*)                                                               as done,          -- việc xong/ngày
       count(*) filter (where done_at <= due_at)                              as on_time,        -- xong đúng hạn
       round(100.0 * count(*) filter (where done_at <= due_at) / count(*), 0) as on_time_pct     -- % đúng hạn (CAO = tốt)
from tasks
where done_by is not null and done_at is not null
group by farm_id, done_by, date_trunc('day', done_at);
grant select on v_staff_task_daily to app_user;

-- ============================================================================
-- E. HIỆU SUẤT THIẾT BỊ — giờ máy + nhiên liệu ước tính (giờ × định mức L/giờ từ devices.fuel_l_per_h, config).
-- ============================================================================
create or replace view v_device_fuel_daily as
select cl.farm_id, cl.machine_id as device_id,
       date_trunc('day', cl.ts)                          as ts,
       sum(cl.machine_hours)                             as hours,     -- giờ máy/ngày
       sum(cl.machine_hours * coalesce(d.fuel_l_per_h,0)) as fuel_l     -- nhiên liệu ước tính (L)
from crop_logs cl
join devices d on d.id = cl.machine_id
where coalesce(cl.machine_hours, 0) > 0 and cl.status = 'ACTIVE'
group by cl.farm_id, cl.machine_id, date_trunc('day', cl.ts);
grant select on v_device_fuel_daily to app_user;
