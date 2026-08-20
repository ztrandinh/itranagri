-- 0166 — T4.1 NHÀ KÍNH CEA (môi trường kiểm soát): lô gieo–thu + fertigation digestate + KPI kg/m²
--
-- Dòng $/m² cao nhất, ít người — chạy bằng nhiệt/CO2/digestate biogas (khép vòng §04C). Bản ghi LÔ CEA
-- có VÒNG ĐỜI (gieo → thu) nên MUTABLE (điền harvest/yield sau, như lots/lab_samples), KHÔNG append-only.
-- Chỉ số khí hậu (nhiệt/ẩm/CO2/EC/pH) đi qua sensor_reads (metric CEA_*) — không cần bảng riêng.

create table if not exists cea_batches(
  id             uuid primary key default gen_random_uuid(),
  farm_id        text not null references farms(id),
  created_at     timestamptz not null default now(),
  created_by     text,
  house_id       text,                           -- nhà kính / khu (location)
  crop           text not null,                  -- rau lá / thảo mộc / dâu…
  sow_date       date not null default current_date,
  harvest_date   date,
  area_m2        numeric not null,
  yield_kg       numeric,
  nutrient_source text not null default 'DIGESTATE',  -- DIGESTATE (bã biogas) | HUU_CO | KHAC
  status         text not null default 'GIEO',   -- GIEO | THU | BO
  note           text,
  constraint cea_status_check check (status in ('GIEO','THU','BO')),
  constraint cea_area_pos check (area_m2 > 0)
);
create index if not exists ix_cea_farm on cea_batches(farm_id, sow_date desc);
alter table cea_batches enable row level security;
drop policy if exists p_all on cea_batches;
create policy p_all on cea_batches for all using (can_see_farm(farm_id)) with check (true);
grant select, insert, update on cea_batches to app_user;  -- update: điền harvest_date/yield khi thu

-- KPI năng suất: kg/m² + chu kỳ ngày, theo nhà kính/cây
create or replace view v_cea_yield as
select farm_id, house_id, crop,
       count(*) filter (where status='THU') as lo_thu,
       round(sum(yield_kg),1) as yield_kg,
       round(sum(area_m2),1) as area_m2,
       round(sum(yield_kg) / nullif(sum(area_m2),0), 2) as kg_per_m2,
       round(avg((harvest_date - sow_date)) filter (where harvest_date is not null),0) as chu_ky_ngay
  from cea_batches
 group by farm_id, house_id, crop;
