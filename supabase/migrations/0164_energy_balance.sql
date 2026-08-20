-- 0164 — T4.4 ENERGY_BALANCE (keystone Nhóm 4) + UNLOCK carbon Tier 2 (v_ghg_net)
--
-- Bối cảnh: GhgPanel báo thiếu dữ liệu năng lượng thu hồi ("ghi biogas_m3, solar_kwh để tính"),
-- v_ghg_month mới là GROSS (đầu con × hệ số). Migration này thêm bản ghi NĂNG LƯỢNG THU HỒI
-- (điện biogas / nhiệt thải / CO2 thu hồi / solar) → tính CO2e TRÁNH được → v_ghg_net = gross − offset.
-- Đây chính là mảnh mở khoá T3.1-Tier2 (carbon theo thu hồi năng lượng thật).

-- 1) Bảng sự kiện năng lượng thu hồi (append-only + RLS — luật 1,2)
create table if not exists energy_logs(
  id          uuid primary key default gen_random_uuid(),
  farm_id     text not null references farms(id),
  ts          timestamptz not null default now(),
  created_at  timestamptz not null default now(),
  created_by  text,
  source      text not null default 'APP',
  is_backfill boolean not null default false,
  stream      text not null,          -- DIEN_BIOGAS | NHIET_THAI | CO2_THU_HOI | SOLAR
  value       numeric not null,       -- kWh (điện/nhiệt/solar) hoặc kg (CO2)
  unit        text not null default 'kWh',
  note        text,
  constraint energy_logs_stream_check check (stream in ('DIEN_BIOGAS','NHIET_THAI','CO2_THU_HOI','SOLAR')),
  constraint energy_logs_source_check check (source in ('APP','DEVICE','IMPORT','BACKFILL','PAPER','API'))
);
create index if not exists ix_energy_logs on energy_logs(farm_id, ts desc);
alter table energy_logs enable row level security;
drop policy if exists p_all on energy_logs;
create policy p_all on energy_logs for all using (can_see_farm(farm_id)) with check (true);
drop trigger if exists energy_logs_bud on energy_logs;
create trigger energy_logs_bud before update or delete on energy_logs
  for each row execute function itran_no_update_delete();
grant select, insert on energy_logs to app_user;

-- 2) Hệ số CO2e TRÁNH được (config = dữ liệu, luật 7; org-wide farm_id null)
insert into norms(id, kind, subject, value, unit, note)
select v.id, v.kind, v.subject, v.value::numeric, v.unit, v.note
from (values
  ('GHG_OFFSET_DIEN_BIOGAS','GHG_OFFSET','DIEN_BIOGAS','0.68','kgCO2e/kWh','Điện biogas thay điện lưới VN'),
  ('GHG_OFFSET_NHIET_THAI', 'GHG_OFFSET','NHIET_THAI', '0.25','kgCO2e/kWh','Nhiệt thải thay đốt dầu'),
  ('GHG_OFFSET_CO2_THU_HOI','GHG_OFFSET','CO2_THU_HOI','1.0', 'kgCO2e/kg', 'CO2 thu hồi tái dùng (nhà kính/tảo)'),
  ('GHG_OFFSET_SOLAR',      'GHG_OFFSET','SOLAR',      '0.68','kgCO2e/kWh','Điện mặt trời thay điện lưới')
) v(id,kind,subject,value,unit,note)
where not exists (select 1 from norms n where n.id = v.id);

-- 3) Views: thu hồi năng lượng · offset CO2e · GHG NET
create or replace view v_energy_recovery as
select farm_id, date_trunc('month', ts)::date as month, stream,
       round(sum(value),1) as qty, max(unit) as unit
  from energy_logs
 group by farm_id, date_trunc('month', ts)::date, stream;

create or replace view v_ghg_offset as
select e.farm_id, date_trunc('month', e.ts)::date as month,
       round(sum(e.value * coalesce((select value from norms
              where kind='GHG_OFFSET' and subject = e.stream limit 1), 0)), 1) as co2e_offset_kg
  from energy_logs e
 group by e.farm_id, date_trunc('month', e.ts)::date;

-- carbon Tier 2: NET = gross (enteric+manure) − CO2e tránh được nhờ thu hồi năng lượng
create or replace view v_ghg_net as
select g.farm_id, g.month,
       round(sum(g.co2e_kg), 1)                         as co2e_gross_kg,
       coalesce(max(o.co2e_offset_kg), 0)               as co2e_offset_kg,
       round(sum(g.co2e_kg) - coalesce(max(o.co2e_offset_kg), 0), 1) as co2e_net_kg
  from v_ghg_month g
  left join v_ghg_offset o on o.farm_id = g.farm_id and o.month = g.month
 group by g.farm_id, g.month;
