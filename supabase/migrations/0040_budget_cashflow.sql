-- 0040 · NGÂN SÁCH theo CC/tháng vs THỰC TẾ (từ GL + chi + doanh thu) · DÒNG TIỀN DỰ BÁO 13 tuần (thu: công nợ đến hạn + doanh thu TB; chi: PO chưa trả, lương, cố định, khấu hao không tính) · báo cáo tuần tự gửi
create table if not exists budgets(id uuid primary key default gen_random_uuid(), farm_id text not null, year int not null, month int, cost_center text, kind text not null, -- DOANH_THU|CHI_PHI|DAU_TU
  category text, amount numeric not null, note text, created_by text, created_at timestamptz default now(), unique(farm_id, year, month, cost_center, kind, category));
alter table budgets enable row level security; drop policy if exists p_all on budgets; create policy p_all on budgets for all using (can_see_farm(farm_id)) with check (app_role() in ('owner','director','accountant')); grant select, insert, update on budgets to app_user;
drop trigger if exists audit_budgets on budgets; create trigger audit_budgets after insert or update or delete on budgets for each row execute function itran_audit();
create or replace view v_budget_vs_actual as
with b as (select farm_id, year, month, coalesce(cost_center,'*') as cc, kind, sum(amount) as budget from budgets group by 1,2,3,4,5),
act as (
  select farm_id, extract(year from ts)::int as year, extract(month from ts)::int as month, coalesce(l->>'cc','*') as cc, case when a.kind='DOANH_THU' then 'DOANH_THU' when a.kind='CHI_PHI' then 'CHI_PHI' end as kind, sum(case when a.kind='DOANH_THU' then (l->>'credit')::numeric-(l->>'debit')::numeric else (l->>'debit')::numeric-(l->>'credit')::numeric end) as actual
  from journal_entries j, jsonb_array_elements(j.lines) l join gl_accounts a on a.code=l->>'acct' where j.reversed_of is null and a.kind in ('DOANH_THU','CHI_PHI') group by 1,2,3,4,5)
select coalesce(b.farm_id,act.farm_id) as farm_id, coalesce(b.year,act.year) as year, coalesce(b.month,act.month) as month, coalesce(b.cc,act.cc) as cc, coalesce(b.kind,act.kind) as kind, coalesce(b.budget,0) as budget, coalesce(act.actual,0) as actual, coalesce(act.actual,0)-coalesce(b.budget,0) as variance,
  case when coalesce(b.budget,0)>0 then round(100.0*coalesce(act.actual,0)/b.budget,0) end as pct
from b full outer join act on act.farm_id=b.farm_id and act.year=b.year and act.month=b.month and act.cc=b.cc and act.kind=b.kind;
grant select on v_budget_vs_actual to app_user;
-- Dòng tiền dự báo 13 tuần
create or replace view v_cashflow_forecast as
with wk as (select generate_series(date_trunc('week', now())::date, date_trunc('week', now())::date + interval '12 weeks', interval '1 week')::date as week_start),
f as (select id as farm_id from farms where status='ACTIVE'),
recv as (select farm_id, date_trunc('week', ts + make_interval(days => coalesce((select credit_days from partners p where p.id=s.partner_id),15)))::date as w, sum(amount) as amt from sales s where status='ACTIVE' and not paid group by 1,2),
avg_sales as (select farm_id, coalesce(sum(amount),0)/8 as wk_avg from sales where status='ACTIVE' and ts>now()-interval '8 weeks' group by 1),
po_due as (select farm_id, date_trunc('week', ts + interval '14 days')::date as w, sum(total) as amt from purchase_orders where po_status in ('DUYET','DA_NHAN') and not exists (select 1 from expense_requests e where e.po_id=purchase_orders.id and e.paid_at is not null) group by 1,2),
avg_exp as (select farm_id, coalesce(sum(amount),0)/8 as wk_avg from expense_requests where paid_at>now()-interval '8 weeks' group by 1),
payroll as (select farm_id, coalesce(sum(net),0) as monthly from payslips where month=(select max(month) from payslips) group by 1),
fixed as (select farm_id, coalesce(sum(amount),0) as monthly from cc_fixed_costs where month=(select max(month) from cc_fixed_costs) group by 1),
cash as (select farm_id, coalesce(sum((l->>'debit')::numeric-(l->>'credit')::numeric),0) as bal from journal_entries j, jsonb_array_elements(j.lines) l where l->>'acct' in ('111','112') and j.reversed_of is null group by 1)
select f.farm_id, wk.week_start,
  coalesce(r.amt,0) as receivable_due, round(coalesce(a.wk_avg,0)) as sales_expected,
  coalesce(p.amt,0) as po_due, round(coalesce(e.wk_avg,0)) as expense_expected, round(coalesce(pr.monthly,0)/4.33) as payroll_wk, round(coalesce(fx.monthly,0)/4.33) as fixed_wk,
  round(coalesce(r.amt,0)+coalesce(a.wk_avg,0) - coalesce(p.amt,0) - coalesce(e.wk_avg,0) - coalesce(pr.monthly,0)/4.33 - coalesce(fx.monthly,0)/4.33) as net_wk,
  round(coalesce(c.bal,0) + sum(coalesce(r.amt,0)+coalesce(a.wk_avg,0) - coalesce(p.amt,0) - coalesce(e.wk_avg,0) - coalesce(pr.monthly,0)/4.33 - coalesce(fx.monthly,0)/4.33) over (partition by f.farm_id order by wk.week_start)) as cash_end
from f cross join wk left join recv r on r.farm_id=f.farm_id and r.w=wk.week_start left join avg_sales a on a.farm_id=f.farm_id left join po_due p on p.farm_id=f.farm_id and p.w=wk.week_start left join avg_exp e on e.farm_id=f.farm_id left join payroll pr on pr.farm_id=f.farm_id left join fixed fx on fx.farm_id=f.farm_id left join cash c on c.farm_id=f.farm_id order by 1,2;
grant select on v_cashflow_forecast to app_user;
-- Báo cáo định kỳ: cấu hình người nhận + lịch (tuần/tháng) → job gửi email (kênh EMAIL) kèm link trang in
create table if not exists report_schedules(id serial primary key, farm_id text, kind text not null, -- bao-cao-tuan|pl-thang|canh-bao-ngay
  cron text default 'weekly', -- weekly (thứ 2 07:00) | monthly (ngày 3 07:00) | daily (07:00)
  recipients text[] default '{owner,director}', channels text[] default '{app,email}', active bool default true, last_sent timestamptz);
alter table report_schedules enable row level security; drop policy if exists p_all on report_schedules; create policy p_all on report_schedules for all using (true) with check (app_role() in ('owner','director','it_engineer')); grant select, insert, update on report_schedules to app_user; grant usage, select on all sequences in schema public to app_user;
insert into report_schedules(farm_id,kind,cron,recipients,channels) select id,'bao-cao-tuan','weekly','{owner,director}','{app,email}' from farms where status='ACTIVE' on conflict do nothing;
insert into report_schedules(farm_id,kind,cron,recipients,channels) select id,'pl-thang','monthly','{owner,director,accountant}','{app,email}' from farms where status='ACTIVE' on conflict do nothing;
