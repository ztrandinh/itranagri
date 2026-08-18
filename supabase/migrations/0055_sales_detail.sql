-- 0055 · BÁN HÀNG CHI TIẾT: giá theo khách/nhóm + bậc chiết khấu số lượng, báo giá → đơn, chỉ tiêu & hoa hồng NVKD, điểm thưởng (loyalty),
--        công nợ theo hạn (aging) + nhắc nợ tự động (dunning), lịch giao theo hợp đồng bao tiêu, hàm giá bán áp dụng
-- 1) Nhóm khách + giá theo khách/nhóm + bậc chiết khấu
alter table partners add column if not exists customer_group text; -- BAN_LE|DAI_LY|SIEU_THI|HORECA|XUAT_KHAU|NOI_BO
alter table partners add column if not exists sales_rep_id text references staff;
alter table partners add column if not exists loyalty_points numeric default 0;
alter table partners add column if not exists loyalty_tier text; -- BAC|VANG|KIM_CUONG
alter table partners add column if not exists payment_terms text; -- COD|NET7|NET15|NET30
create table if not exists customer_prices(
  id text primary key, farm_id text not null references farms, partner_id text references partners, customer_group text, sku text not null references products,
  price numeric, discount_pct numeric, min_qty numeric default 0, valid_from date default current_date, valid_to date, priority int default 100, note text, active bool default true,
  created_at timestamptz default now(), created_by text default app_staff(), attrs jsonb default '{}'::jsonb,
  check (partner_id is not null or customer_group is not null));
create table if not exists discount_tiers(
  id text primary key, farm_id text not null references farms, sku text references products, customer_group text, min_qty numeric not null, discount_pct numeric not null, valid_from date default current_date, valid_to date, active bool default true, note text);
do $$ declare t text; begin
  foreach t in array array['customer_prices','discount_tiers'] loop
    execute format('alter table %I enable row level security', t); execute format('drop policy if exists p_all on %I', t);
    execute format('create policy p_all on %I for all using (can_see_farm(farm_id)) with check (true)', t); execute format('grant select, insert, update on %I to app_user', t);
  end loop; end $$;
-- giá áp dụng cho (khách, sku, số lượng): giá riêng khách → giá nhóm → giá thị trường price_list → bậc chiết khấu; không dưới giá sàn (SAN) trừ khi được duyệt
create or replace function price_for(p_farm text, p_partner text, p_sku text, p_qty numeric default 1) returns table(price numeric, list_price numeric, discount_pct numeric, source text, floor_price numeric, below_floor bool) language plpgsql stable as $$
declare v_grp text; v_list numeric; v_floor numeric; v_price numeric; v_disc numeric := 0; v_src text := 'THI_TRUONG'; r record; begin
  select customer_group into v_grp from partners where id=p_partner;
  select pl.price into v_list from price_list pl where pl.kind='THI_TRUONG' and pl.subject=p_sku and (pl.farm_id=p_farm or pl.farm_id is null) and pl.valid_from<=current_date and (pl.valid_to is null or pl.valid_to>=current_date) order by (pl.farm_id=p_farm) desc, pl.valid_from desc limit 1;
  select pl.price into v_floor from price_list pl where pl.kind='SAN' and pl.subject=p_sku and (pl.farm_id=p_farm or pl.farm_id is null) order by (pl.farm_id=p_farm) desc, pl.valid_from desc limit 1;
  v_price := v_list;
  select * into r from customer_prices cp where cp.farm_id=p_farm and cp.sku=p_sku and cp.active and cp.valid_from<=current_date and (cp.valid_to is null or cp.valid_to>=current_date) and p_qty>=coalesce(cp.min_qty,0)
    and (cp.partner_id=p_partner or (cp.partner_id is null and cp.customer_group is not null and cp.customer_group=v_grp)) order by (cp.partner_id is not null) desc, cp.priority, cp.min_qty desc limit 1;
  if found then
    if r.price is not null then v_price := r.price; v_src := case when r.partner_id is not null then 'GIA_RIENG_KHACH' else 'GIA_NHOM' end;
    elsif r.discount_pct is not null then v_disc := r.discount_pct; v_src := case when r.partner_id is not null then 'CK_RIENG_KHACH' else 'CK_NHOM' end; end if;
  end if;
  if v_src in ('THI_TRUONG','CK_RIENG_KHACH','CK_NHOM') then
    select greatest(v_disc, coalesce(max(dt.discount_pct),0)) into v_disc from discount_tiers dt where dt.farm_id=p_farm and dt.active and (dt.sku=p_sku or dt.sku is null) and (dt.customer_group is null or dt.customer_group=v_grp) and p_qty>=dt.min_qty and dt.valid_from<=current_date and (dt.valid_to is null or dt.valid_to>=current_date);
    if v_disc>0 and v_src='THI_TRUONG' then v_src := 'BAC_SO_LUONG'; end if;
  end if;
  price := round(coalesce(v_price,0) * (1 - coalesce(v_disc,0)/100)); list_price := v_list; discount_pct := v_disc; source := v_src; floor_price := v_floor; below_floor := v_floor is not null and price < v_floor;
  return next; end $$;
grant execute on function price_for(text,text,text,numeric) to app_user;

-- 2) Báo giá → đơn hàng
create table if not exists quotes(
  id text primary key, farm_id text not null references farms, partner_id text references partners, quote_date date default current_date, valid_until date, lines jsonb not null default '[]'::jsonb, -- [{sku,name,qty,unit,price,discount_pct,amount}]
  subtotal numeric default 0, discount numeric default 0, vat_pct numeric default 0, total numeric default 0, terms text, delivery_terms text, payment_terms text, note text,
  status text default 'NHAP' check (status in ('NHAP','GUI','CHAP_NHAN','TU_CHOI','HET_HAN','THANH_DON')), order_id text, sent_at timestamptz, accepted_at timestamptz, sales_rep_id text references staff,
  created_at timestamptz default now(), created_by text default app_staff(), attrs jsonb default '{}'::jsonb);
alter table quotes enable row level security; drop policy if exists p_all on quotes; create policy p_all on quotes for all using (can_see_farm(farm_id)) with check (true); grant select, insert, update on quotes to app_user;
create or replace function quote_to_order(p_quote text) returns text language plpgsql as $$
declare q record; v_id text; begin
  select * into q from quotes where id=p_quote; if not found then raise exception 'ERR_NOT_FOUND'; end if;
  if q.status not in ('GUI','CHAP_NHAN','NHAP') then raise exception 'ERR_QUOTE_STATUS'; end if;
  v_id := next_code_free(q.farm_id, 'DH', 'orders');
  insert into orders(id, farm_id, partner_id, channel, order_date, deliver_date, lines, total, status, created_by, note, attrs)
  values (v_id, q.farm_id, q.partner_id, 'B2B', current_date, coalesce(q.valid_until, current_date+3), q.lines, q.total, 'NHAP', app_staff(), 'Từ báo giá '||q.id, jsonb_build_object('quote_id', q.id));
  update quotes set status='THANH_DON', order_id=v_id, accepted_at=coalesce(accepted_at, now()) where id=p_quote;
  return v_id; end $$;
grant execute on function quote_to_order(text) to app_user;

-- 3) Chỉ tiêu & hoa hồng NVKD
create table if not exists sales_targets(
  id text primary key, farm_id text not null references farms, staff_id text references staff, channel_code text, period text not null, -- YYYY-MM
  target_amount numeric, target_qty numeric, target_new_customers int, commission_pct numeric default 0, bonus_rule jsonb default '{}'::jsonb, note text, unique(farm_id, staff_id, channel_code, period));
alter table sales_targets enable row level security; drop policy if exists p_all on sales_targets; create policy p_all on sales_targets for all using (can_see_farm(farm_id)) with check (true); grant select, insert, update on sales_targets to app_user;
alter table sales add column if not exists sales_rep_id text;
create or replace view v_sales_performance as
select t.farm_id, t.staff_id, s.full_name, t.period, t.channel_code, t.target_amount, t.target_qty, t.commission_pct,
  coalesce(a.amount,0) as actual_amount, coalesce(a.qty,0) as actual_qty, coalesce(a.n_customers,0) as customers,
  case when coalesce(t.target_amount,0)>0 then round(coalesce(a.amount,0)*100/t.target_amount,1) end as pct,
  round(coalesce(a.amount,0)*coalesce(t.commission_pct,0)/100) as commission
from sales_targets t left join staff s on s.id=t.staff_id
left join lateral (select sum(x.amount) as amount, sum(x.qty) as qty, count(distinct x.partner_id) as n_customers from sales x where x.farm_id=t.farm_id and x.status='ACTIVE' and to_char(x.ts,'YYYY-MM')=t.period and (t.staff_id is null or x.sales_rep_id=t.staff_id or (x.sales_rep_id is null and x.created_by=t.staff_id)) and (t.channel_code is null or x.channel_code=t.channel_code)) a on true;
grant select on v_sales_performance to app_user;

-- 4) Điểm thưởng (loyalty): 1 điểm / 10.000đ mặc định (settings loyalty.rate), hạng theo điểm 12 tháng
create table if not exists loyalty_ledger(
  id bigserial primary key, farm_id text not null references farms, partner_id text not null references partners, ts timestamptz default now(), points numeric not null, reason text, ref_type text, ref_id text, created_by text default app_staff());
alter table loyalty_ledger enable row level security; drop policy if exists p_all on loyalty_ledger; create policy p_all on loyalty_ledger for all using (can_see_farm(farm_id)) with check (true); grant select, insert on loyalty_ledger to app_user; grant usage on sequence loyalty_ledger_id_seq to app_user;
create or replace function trg_loyalty_on_sale() returns trigger language plpgsql as $$
declare rate numeric; begin
  if new.partner_id is null or coalesce(new.amount,0)<=0 then return new; end if;
  select coalesce((select value::numeric from settings where key='loyalty.points_per_10k' and (farm_id=new.farm_id or farm_id is null) order by (farm_id=new.farm_id) desc limit 1), 1) into rate;
  insert into loyalty_ledger(farm_id, partner_id, points, reason, ref_type, ref_id) values (new.farm_id, new.partner_id, floor(new.amount/10000)*rate, 'MUA_HANG', 'sales', new.id::text);
  update partners set loyalty_points = coalesce(loyalty_points,0) + floor(new.amount/10000)*rate,
    loyalty_tier = case when coalesce(loyalty_points,0) + floor(new.amount/10000)*rate >= 5000 then 'KIM_CUONG' when coalesce(loyalty_points,0) + floor(new.amount/10000)*rate >= 1000 then 'VANG' else 'BAC' end where id=new.partner_id;
  return new; end $$;
drop trigger if exists loyalty_on_sale on sales; create trigger loyalty_on_sale after insert on sales for each row execute function trg_loyalty_on_sale();
create or replace function redeem_points(p_partner text, p_points numeric, p_ref text default null) returns numeric language plpgsql as $$
declare v_farm text; v_bal numeric; begin
  select farm_id, coalesce(loyalty_points,0) into v_farm, v_bal from partners where id=p_partner; if v_bal < p_points then raise exception 'ERR_INSUFFICIENT_POINTS'; end if;
  insert into loyalty_ledger(farm_id, partner_id, points, reason, ref_type, ref_id) values (coalesce(v_farm, app_farm()), p_partner, -p_points, 'DOI_DIEM', 'sales', p_ref);
  update partners set loyalty_points = loyalty_points - p_points where id=p_partner; return v_bal - p_points; end $$;
grant execute on function redeem_points(text,numeric,text) to app_user;

-- 5) Công nợ theo hạn (dựa payment_terms) + nhắc nợ
create or replace view v_ar_aging as
select s.farm_id, s.partner_id, p.name as partner_name, p.payment_terms, p.credit_limit, p.credit_days, s.id as sale_id, s.ts, s.amount, s.invoice_no,
  (s.ts::date + coalesce(p.credit_days, case p.payment_terms when 'NET7' then 7 when 'NET15' then 15 when 'NET30' then 30 else 0 end)) as due_date,
  greatest(current_date - (s.ts::date + coalesce(p.credit_days, case p.payment_terms when 'NET7' then 7 when 'NET15' then 15 when 'NET30' then 30 else 0 end)), 0) as days_overdue
from sales s join partners p on p.id=s.partner_id where s.status='ACTIVE' and not s.paid and s.amount>0;
grant select on v_ar_aging to app_user;
create or replace view v_ar_summary as
select farm_id, partner_id, partner_name, credit_limit, sum(amount) as unpaid,
  sum(amount) filter (where days_overdue=0) as not_due, sum(amount) filter (where days_overdue between 1 and 30) as d1_30, sum(amount) filter (where days_overdue between 31 and 60) as d31_60, sum(amount) filter (where days_overdue>60) as d60p,
  max(days_overdue) as max_overdue, count(*) as n_inv, case when credit_limit is not null and sum(amount) > credit_limit then true else false end as over_limit
from v_ar_aging group by farm_id, partner_id, partner_name, credit_limit;
grant select on v_ar_summary to app_user;
create table if not exists dunning_log(id bigserial primary key, farm_id text not null, partner_id text not null, level int not null, amount numeric, sent_at timestamptz default now(), channel text, note text);
grant select, insert on dunning_log to app_user; grant usage on sequence dunning_log_id_seq to app_user;
-- nhắc nợ: mức 1 quá hạn 1–7 ngày (nhắc nhẹ), mức 2 8–30 (nhắc + KTT), mức 3 >30 (khóa bán chịu, báo GĐ); mỗi mức tối đa 1 lần / 7 ngày
create or replace function run_dunning(p_farm text) returns int language plpgsql as $$
declare n int := 0; r record; lvl int; begin
  for r in select * from v_ar_summary where farm_id=p_farm and max_overdue>0 loop
    lvl := case when r.max_overdue>30 then 3 when r.max_overdue>7 then 2 else 1 end;
    if not exists (select 1 from dunning_log d where d.farm_id=p_farm and d.partner_id=r.partner_id and d.level=lvl and d.sent_at>now()-interval '7 days') then
      insert into dunning_log(farm_id, partner_id, level, amount, channel, note) values (p_farm, r.partner_id, lvl, r.unpaid, 'app', 'quá hạn '||r.max_overdue||' ngày');
      perform publish_event(p_farm, 'ar.overdue', jsonb_build_object('partner_id', r.partner_id, 'partner_name', r.partner_name, 'unpaid', r.unpaid, 'max_overdue', r.max_overdue, 'level', lvl));
      if lvl=3 then update partners set credit_limit=0 where id=r.partner_id and coalesce(credit_limit,0)>0; end if;
      n := n+1;
    end if;
  end loop; return n; end $$;
grant execute on function run_dunning(text) to app_user;
insert into event_topics(topic, description, producer_dept, consumer_depts, source_table, wired) values
 ('ar.overdue','Công nợ khách quá hạn (nhắc nợ 3 mức)','TCKT','{KDM,BGD}','dunning_log',true),
 ('quote.sent','Báo giá gửi khách','KDM','{TCKT}','quotes',true)
on conflict (topic) do nothing;

-- 6) Lịch giao theo hợp đồng bao tiêu
create table if not exists contract_deliveries(
  id text primary key, contract_id text not null references contracts, farm_id text not null references farms, planned_date date not null, planned_qty numeric not null, unit text, delivered_qty numeric default 0, order_id text, status text default 'KE_HOACH' check (status in ('KE_HOACH','DA_GIAO','TRE','HUY')), note text);
alter table contract_deliveries enable row level security; drop policy if exists p_all on contract_deliveries; create policy p_all on contract_deliveries for all using (can_see_farm(farm_id)) with check (true); grant select, insert, update on contract_deliveries to app_user;
create or replace function gen_contract_deliveries(p_contract text, p_every_days int default 7) returns int language plpgsql as $$
declare c record; d date; n int := 0; total_slots int; per numeric; begin
  select * into c from contracts where id=p_contract; if not found then raise exception 'ERR_NOT_FOUND'; end if;
  total_slots := greatest(1, ceil((coalesce(c.end_date, c.start_date + 90) - c.start_date)::numeric / p_every_days)); per := round(coalesce(c.qty_committed,0)/total_slots, 1);
  d := c.start_date;
  while d <= coalesce(c.end_date, c.start_date + 90) loop
    if not exists (select 1 from contract_deliveries x where x.contract_id=p_contract and x.planned_date=d) then
      insert into contract_deliveries(id, contract_id, farm_id, planned_date, planned_qty, unit) values (p_contract||'-'||to_char(d,'YYMMDD'), p_contract, c.farm_id, d, per, c.unit); n := n+1; end if;
    d := d + p_every_days;
  end loop; return n; end $$;
grant execute on function gen_contract_deliveries(text,int) to app_user;
create or replace view v_contract_schedule as
select cd.*, c.partner_id, p.name as partner_name, c.sku, pr.name as product_name, c.price,
  case when cd.status='KE_HOACH' and cd.planned_date < current_date then true else false end as late
from contract_deliveries cd join contracts c on c.id=cd.contract_id left join partners p on p.id=c.partner_id left join products pr on pr.sku=c.sku;
grant select on v_contract_schedule to app_user;
-- audit
do $$ declare t text; begin
  foreach t in array array['customer_prices','discount_tiers','quotes','sales_targets','contract_deliveries'] loop
    execute format('drop trigger if exists %s_audit on %I', t, t);
    execute format('create trigger %s_audit after insert or update or delete on %I for each row execute function itran_audit()', t, t);
  end loop; end $$;
-- cảnh báo: vượt hạn mức tín dụng, lịch giao HĐ trễ
insert into alert_rules(code, version, farm_id, name, source, expr, level, recipients, channels, cooldown_min, active)
select v.code, 1, 'GLOBAL', v.name, 'custom', v.expr::jsonb, v.level, v.rec::text[], '{app}'::text[], v.cd, true from (values
 ('AL-CREDIT','Khách vượt hạn mức tín dụng / nợ >60 ngày','{"type":"sql_rows","sql":"select partner_name as ref, unpaid as value, d60p, credit_limit from v_ar_summary where farm_id=$1 and (over_limit or coalesce(d60p,0)>0)","message":"{ref}: nợ {value} đ (quá 60 ngày {d60p}, hạn mức {credit_limit}) — dừng bán chịu, thu hồi"}','VANG','{accountant,director}',1440),
 ('AL-CONTRACT-LATE','Lịch giao hợp đồng bao tiêu trễ','{"type":"sql_rows","sql":"select id as ref, partner_name, product_name, planned_qty as value, planned_date::text as d from v_contract_schedule where farm_id=$1 and late","message":"Giao HĐ {ref} cho {partner_name} ({product_name} {value}) trễ từ {d}"}','VANG','{director,tech_head}',1440)
) as v(code, name, expr, level, rec, cd) where not exists (select 1 from alert_rules a where a.code=v.code);
