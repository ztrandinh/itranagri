-- 0167 — T4.5 BÈO TẤM/DUCKWEED: thu hồi N-P từ nước thải → đạm feed. Ghi thu hoạch + đạm thu hồi.
--
-- Bèo tấm ăn nước thải giàu N-P (RAS/rửa chuồng/digestate loãng) → sinh khối ~35-40% đạm → feed.
-- Bản ghi lô có vòng đời (gieo→thu) → MUTABLE như cea_batches. Liên kết N-P chi tiết sẽ nối
-- effluent_logs (T1.3 của điều phối) khi có.

create table if not exists duckweed_batches(
  id            uuid primary key default gen_random_uuid(),
  farm_id       text not null references farms(id),
  created_at    timestamptz not null default now(),
  created_by    text,
  pond_id       text,
  area_m2       numeric not null,
  sow_date      date not null default current_date,
  harvest_date  date,
  harvest_kg    numeric,
  protein_pct   numeric not null default 35,   -- % đạm sinh khối bèo
  nutrient_src  text not null default 'NUOC_THAI',  -- NUOC_THAI (RAS/rửa chuồng/digestate)
  status        text not null default 'GIEO',
  note          text,
  constraint dw_status_check check (status in ('GIEO','THU','BO')),
  constraint dw_area_pos check (area_m2 > 0)
);
create index if not exists ix_dw_farm on duckweed_batches(farm_id, sow_date desc);
alter table duckweed_batches enable row level security;
drop policy if exists p_all on duckweed_batches;
create policy p_all on duckweed_batches for all using (can_see_farm(farm_id)) with check (true);
grant select, insert, update on duckweed_batches to app_user;

-- KPI: tấn tươi/ha + đạm thu hồi (kg) theo ao
create or replace view v_duckweed_output as
select farm_id, pond_id,
       round(sum(harvest_kg),1) as harvest_kg,
       round(sum(harvest_kg)/1000.0 / nullif(sum(area_m2)/10000.0,0), 1) as tan_per_ha,
       round(sum(harvest_kg * protein_pct/100.0),1) as dam_thu_hoi_kg
  from duckweed_batches
 where status = 'THU'
 group by farm_id, pond_id;
