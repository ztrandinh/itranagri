-- 0165 — T4.3 BIOCHAR + TÍN CHỈ CARBON (CDR)
--
-- Biochar = carbon removal đo đếm được, lưu trữ lâu (dòng tiền ESG). Ghi mẻ biochar → tính CO2e lưu giữ
-- (CDR) → sổ tín chỉ carbon (ISSUE từ mẻ đã thẩm định, SELL cho người mua). CHẶN BÁN VƯỢT lượng khả dụng
-- (đã ISSUE − đã SELL) — guard trên bảng ledger LOW-traffic (an toàn, skip IMPORT/backfill).

-- 1) Mẻ biochar (append-only + RLS)
create table if not exists biochar_batches(
  id            uuid primary key default gen_random_uuid(),
  farm_id       text not null references farms(id),
  ts            timestamptz not null default now(),
  created_at    timestamptz not null default now(),
  created_by    text,
  source        text not null default 'APP',
  is_backfill   boolean not null default false,
  feedstock     text,                          -- nguyên liệu (vỏ trấu, gỗ, mo cau…)
  input_kg      numeric,
  biochar_kg    numeric not null,
  carbon_pct    numeric not null default 80,   -- % C trong biochar
  permanence_pct numeric not null default 80,  -- % bền vững (100+ năm)
  method        text default 'NHIET_PHAN',
  note          text,
  constraint biochar_source_check check (source in ('APP','DEVICE','IMPORT','BACKFILL','PAPER','API'))
);
create index if not exists ix_biochar_farm on biochar_batches(farm_id, ts desc);
alter table biochar_batches enable row level security;
drop policy if exists p_all on biochar_batches;
create policy p_all on biochar_batches for all using (can_see_farm(farm_id)) with check (true);
drop trigger if exists biochar_batches_bud on biochar_batches;
create trigger biochar_batches_bud before update or delete on biochar_batches
  for each row execute function itran_no_update_delete();
grant select, insert on biochar_batches to app_user;

-- CO2e lưu giữ mỗi mẻ (tấn): biochar_kg × %C × 44/12 × %bền / 1000
create or replace view v_biochar_cdr as
select id, farm_id, ts, feedstock, biochar_kg,
       round(biochar_kg * (carbon_pct/100.0) * (44.0/12.0) * (permanence_pct/100.0) / 1000.0, 3) as co2e_tonnes
  from biochar_batches;

-- 2) Sổ tín chỉ carbon (append-only + RLS)
create table if not exists carbon_credits(
  id            uuid primary key default gen_random_uuid(),
  farm_id       text not null references farms(id),
  ts            timestamptz not null default now(),
  created_at    timestamptz not null default now(),
  created_by    text,
  source        text not null default 'APP',
  is_backfill   boolean not null default false,
  entry_type    text not null,                 -- ISSUE | SELL
  co2e_tonnes   numeric not null,
  batch_id      uuid references biochar_batches(id),   -- với ISSUE
  buyer         text,                          -- với SELL
  mrv_standard  text,                          -- PURO | VERRA…
  mrv_ref       text,
  note          text,
  constraint cc_entry_check check (entry_type in ('ISSUE','SELL')),
  constraint cc_source_check check (source in ('APP','DEVICE','IMPORT','BACKFILL','PAPER','API')),
  constraint cc_pos check (co2e_tonnes > 0)
);
create index if not exists ix_cc_farm on carbon_credits(farm_id, ts desc);
alter table carbon_credits enable row level security;
drop policy if exists p_all on carbon_credits;
create policy p_all on carbon_credits for all using (can_see_farm(farm_id)) with check (true);
drop trigger if exists carbon_credits_bud on carbon_credits;
create trigger carbon_credits_bud before update or delete on carbon_credits
  for each row execute function itran_no_update_delete();
grant select, insert on carbon_credits to app_user;

-- 3) Guard: CẤM bán tín chỉ vượt lượng khả dụng (ISSUE − SELL). Skip IMPORT/backfill.
create or replace function itran_carbon_no_oversell()
returns trigger language plpgsql as $fn$
declare v_avail numeric;
begin
  if new.entry_type <> 'SELL' or new.source='IMPORT' or new.is_backfill then return new; end if;
  select coalesce(sum(case when entry_type='ISSUE' then co2e_tonnes else -co2e_tonnes end),0)
    into v_avail from carbon_credits where farm_id = new.farm_id;
  if v_avail < new.co2e_tonnes then
    raise exception 'ERR_CARBON_OVERSELL: bán % tấn > khả dụng % tấn (đã thẩm định − đã bán)', new.co2e_tonnes, v_avail;
  end if;
  return new;
end $fn$;
drop trigger if exists carbon_credits_bi_oversell on carbon_credits;
create trigger carbon_credits_bi_oversell before insert on carbon_credits
  for each row execute function itran_carbon_no_oversell();

-- 4) Cân đối tín chỉ
create or replace view v_carbon_balance as
select farm_id,
       round(sum(co2e_tonnes) filter (where entry_type='ISSUE'),3) as issued_t,
       round(sum(co2e_tonnes) filter (where entry_type='SELL'),3)  as sold_t,
       round(coalesce(sum(co2e_tonnes) filter (where entry_type='ISSUE'),0)
            - coalesce(sum(co2e_tonnes) filter (where entry_type='SELL'),0),3) as available_t
  from carbon_credits group by farm_id;
