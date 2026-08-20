-- 0155 · PHÂN TÍCH TĂNG TRƯỞNG CÁ THỂ (read-side, cắm vào chart "mọi trường").
--
-- Thức ăn ghi theo ĐÀN (feed_logs.dest_group_id) → PHÂN BỔ về đầu con (÷ head_count). Feed/đầu con đồng đều,
-- nên thứ phân biệt "con hấp thụ tốt" là TĂNG TRỌNG khác nhau → FCR = feed phân bổ / tăng trọng, ADG = tăng/ngày.
-- Mọi view có farm_id + ts + cột số + animal_id → tự lên chart mọi granularity, drill về bản ghi gốc.

-- Feed phân bổ theo NGÀY / cá thể
create or replace view v_animal_feed_daily as
select a.farm_id, a.id as animal_id, a.group_id,
       date_trunc('day', f.ts) as ts,
       sum(f.qty_kg / nullif(g.head_count, 0)) as feed_kg
from animals a
join animal_groups g on g.id = a.group_id
join feed_logs f on f.dest_group_id = a.group_id and f.status = 'ACTIVE'
where g.head_count > 0
group by a.farm_id, a.id, a.group_id, date_trunc('day', f.ts);

-- Tăng trưởng + FCR + ADG theo THÁNG / cá thể
create or replace view v_animal_growth_month as
with w as ( -- cân CUỐI mỗi tháng/con
  select distinct on (a.id, date_trunc('month', e.ts))
         a.farm_id, a.id as animal_id, date_trunc('month', e.ts) as mth, e.value as w_kg
  from animals a
  join animal_events e on e.animal_id = a.id
  where e.event_type = 'CAN' and e.status = 'ACTIVE' and coalesce(e.value,0) > 0
  order by a.id, date_trunc('month', e.ts), e.ts desc
), wg as ( -- tăng trọng = cân cuối tháng này − cân cuối tháng TRƯỚC ĐÓ của con
  select farm_id, animal_id, mth, w_kg,
         w_kg - lag(w_kg) over (partition by animal_id order by mth) as gain_kg,
         extract(day from (mth + interval '1 month' - interval '1 day'))::int as days
  from w
), fm as ( -- feed phân bổ theo tháng/con
  select farm_id, animal_id, date_trunc('month', ts) as mth, sum(feed_kg) as feed_kg
  from v_animal_feed_daily group by farm_id, animal_id, date_trunc('month', ts)
)
select coalesce(wg.farm_id, fm.farm_id)     as farm_id,
       coalesce(wg.animal_id, fm.animal_id) as animal_id,
       coalesce(wg.mth, fm.mth)             as ts,
       wg.w_kg, wg.gain_kg, fm.feed_kg,
       case when coalesce(wg.gain_kg,0) > 0 and fm.feed_kg is not null
            then round((fm.feed_kg / wg.gain_kg)::numeric, 2) end as fcr,     -- kg thức ăn / kg tăng (thấp = tốt)
       case when wg.gain_kg is not null
            then round((wg.gain_kg * 1000.0 / nullif(wg.days,0))::numeric, 0) end as adg_g   -- g tăng/ngày (cao = tốt)
from wg
full join fm on fm.animal_id = wg.animal_id and fm.mth = wg.mth;

grant select on v_animal_feed_daily, v_animal_growth_month to app_user;
