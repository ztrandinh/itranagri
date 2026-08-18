-- 0036 · BẢNG LƯƠNG ĐẦY ĐỦ (lương cơ bản × công + KPI + phụ cấp − BHXH/BHYT/BHTN − thuế TNCN − tạm ứng, hạch toán 334) · TSCĐ & KHẤU HAO đường thẳng hằng tháng (211/214/627,642) · KHÓA KỲ chặn GL & bút toán · LANDED COST → giá vốn bình quân
-- ===== 1. Tham số lương (settings, sửa được) =====
insert into settings(farm_id,key,value,version) values
 ('GLOBAL','payroll.bhxh_employee_pct','8',1),('GLOBAL','payroll.bhyt_employee_pct','1.5',1),('GLOBAL','payroll.bhtn_employee_pct','1',1),
 ('GLOBAL','payroll.bhxh_employer_pct','17.5',1),('GLOBAL','payroll.bhyt_employer_pct','3',1),('GLOBAL','payroll.bhtn_employer_pct','1',1),
 ('GLOBAL','payroll.giam_tru_ban_than','11000000',1),('GLOBAL','payroll.giam_tru_phu_thuoc','4400000',1),('GLOBAL','payroll.standard_days','26',1),('GLOBAL','payroll.kpi_bonus_base_pct','20',1)
on conflict do nothing;
alter table staff add column if not exists dependents int default 0, add column if not exists allowances jsonb default '{}'::jsonb, add column if not exists insurance_salary numeric, add column if not exists bank_account text;
create table if not exists payroll_runs(id uuid primary key default gen_random_uuid(), farm_id text not null, month date not null, status text default 'NHAP', -- NHAP|DUYET|DA_TRA
  total_gross numeric, total_net numeric, total_employer numeric, computed_at timestamptz default now(), computed_by text, approved_by text, approved_at timestamptz, paid_at timestamptz, note text, unique(farm_id, month));
create table if not exists payslips(id uuid primary key default gen_random_uuid(), run_id uuid references payroll_runs on delete cascade, farm_id text not null, staff_id text not null, month date not null,
  base_salary numeric default 0, standard_days numeric default 26, work_days numeric default 0, paid_leave_days numeric default 0, unpaid_days numeric default 0, salary_by_days numeric default 0,
  kpi_score numeric, kpi_bonus numeric default 0, allowances numeric default 0, other_add numeric default 0, gross numeric default 0,
  ins_salary numeric default 0, bhxh numeric default 0, bhyt numeric default 0, bhtn numeric default 0, taxable numeric default 0, pit numeric default 0, advances numeric default 0, other_deduct numeric default 0, net numeric default 0,
  employer_ins numeric default 0, detail jsonb default '{}'::jsonb, unique(run_id, staff_id));
do $$ declare t text; begin foreach t in array array['payroll_runs','payslips'] loop execute format('alter table %I enable row level security', t); execute format('drop policy if exists p_all on %I', t); execute format('create policy p_all on %I for all using (can_see_farm(farm_id) and (app_role() in (''owner'',''director'',''accountant'',''it_engineer'') or (%s))) with check (app_role() in (''owner'',''director'',''accountant''))', t, case when t='payslips' then 'staff_id=app_staff()' else 'false' end); execute format('grant select, insert, update on %I to app_user', t); end loop; end $$;
-- Thuế TNCN lũy tiến (Luật thuế TNCN VN, biểu 7 bậc/tháng)
create or replace function pit_progressive(p_taxable numeric) returns numeric language plpgsql immutable as $$
declare t numeric := greatest(p_taxable,0); tax numeric := 0; begin
  if t <= 5e6 then return round(t*0.05); end if; tax := 5e6*0.05; t := t-5e6;
  if t <= 5e6 then return round(tax + t*0.10); end if; tax := tax + 5e6*0.10; t := t-5e6;
  if t <= 8e6 then return round(tax + t*0.15); end if; tax := tax + 8e6*0.15; t := t-8e6;
  if t <= 14e6 then return round(tax + t*0.20); end if; tax := tax + 14e6*0.20; t := t-14e6;
  if t <= 20e6 then return round(tax + t*0.25); end if; tax := tax + 20e6*0.25; t := t-20e6;
  if t <= 28e6 then return round(tax + t*0.30); end if; tax := tax + 28e6*0.30; t := t-28e6;
  return round(tax + t*0.35); end $$;
create or replace function setting_num(p_key text, p_farm text, p_default numeric) returns numeric language sql stable as $$ select coalesce((select (value#>>'{}')::numeric from settings where key=p_key and farm_id in (p_farm,'GLOBAL') order by (farm_id=p_farm) desc, version desc limit 1), p_default) $$;
-- Tính bảng lương tháng
create or replace function compute_payroll(p_farm text, p_month date, p_by text) returns uuid language plpgsql as $$
declare rid uuid; s record; std numeric := setting_num('payroll.standard_days',p_farm,26); wd numeric; pl numeric; ul numeric; base numeric; byday numeric; kpi numeric; kb numeric; alw numeric; gross numeric; ins numeric; bhxh numeric; bhyt numeric; bhtn numeric; taxable numeric; pit numeric; adv numeric; net numeric; emp_ins numeric; tg numeric := 0; tn numeric := 0; te numeric := 0; begin
  if exists (select 1 from period_locks where farm_id=p_farm and period_end >= (p_month + interval '1 month' - interval '1 day')::date) then raise exception 'ERR_PERIOD_LOCKED'; end if;
  insert into payroll_runs(farm_id,month,computed_by) values (p_farm,p_month,p_by) on conflict (farm_id,month) do update set computed_at=now(), computed_by=p_by, status='NHAP' returning id into rid;
  delete from payslips where run_id=rid;
  for s in select * from staff where active and (farm_id=p_farm or p_farm = any(farm_ids)) and role<>'customer' loop
    select coalesce(count(distinct day),0) into wd from attendance where farm_id=p_farm and staff_id=s.id and date_trunc('month',day)=p_month and check_in is not null;
    select coalesce(sum(days) filter (where kind in ('PHEP','OM','THAI_SAN')),0), coalesce(sum(days) filter (where kind in ('KHONG_LUONG','VIEC_RIENG')),0) into pl, ul from leave_requests where farm_id=p_farm and staff_id=s.id and status='DUYET' and date_trunc('month',from_date)=p_month;
    if wd = 0 and pl = 0 then wd := std; end if; -- chưa chấm công → tính đủ (ghi rõ trong detail)
    base := coalesce(s.salary_base,0); byday := round(base * least(wd + pl, std) / std);
    select score into kpi from v_staff_kpi_month where farm_id=p_farm and staff_id=s.id and month=p_month; kb := round(base * setting_num('payroll.kpi_bonus_base_pct',p_farm,20)/100 * coalesce(kpi,0)/100);
    alw := coalesce((select sum((v#>>'{}')::numeric) from jsonb_each(coalesce(s.allowances,'{}'::jsonb)) as e(k,v)),0);
    gross := byday + kb + alw; ins := coalesce(s.insurance_salary, base);
    bhxh := round(ins*setting_num('payroll.bhxh_employee_pct',p_farm,8)/100); bhyt := round(ins*setting_num('payroll.bhyt_employee_pct',p_farm,1.5)/100); bhtn := round(ins*setting_num('payroll.bhtn_employee_pct',p_farm,1)/100);
    taxable := gross - bhxh - bhyt - bhtn - setting_num('payroll.giam_tru_ban_than',p_farm,11e6) - coalesce(s.dependents,0)*setting_num('payroll.giam_tru_phu_thuoc',p_farm,4.4e6); pit := pit_progressive(taxable);
    select coalesce(sum(amount),0) into adv from expense_requests where farm_id=p_farm and requested_by=s.id and purpose ilike 'tạm ứng%' and status='DUYET' and paid_at is not null and date_trunc('month',paid_at)=p_month;
    net := gross - bhxh - bhyt - bhtn - pit - adv; emp_ins := round(ins*(setting_num('payroll.bhxh_employer_pct',p_farm,17.5)+setting_num('payroll.bhyt_employer_pct',p_farm,3)+setting_num('payroll.bhtn_employer_pct',p_farm,1))/100);
    insert into payslips(run_id,farm_id,staff_id,month,base_salary,standard_days,work_days,paid_leave_days,unpaid_days,salary_by_days,kpi_score,kpi_bonus,allowances,gross,ins_salary,bhxh,bhyt,bhtn,taxable,pit,advances,net,employer_ins,detail)
    values (rid,p_farm,s.id,p_month,base,std,wd,pl,ul,byday,kpi,kb,alw,gross,ins,bhxh,bhyt,bhtn,greatest(taxable,0),pit,adv,net,emp_ins,jsonb_build_object('attendance_used', wd, 'note', case when wd=std and pl=0 then 'chưa có chấm công → tạm tính đủ công' else null end, 'allowances', s.allowances));
    tg := tg + gross; tn := tn + net; te := te + emp_ins;
  end loop;
  update payroll_runs set total_gross=tg, total_net=tn, total_employer=te where id=rid; return rid; end $$;
-- Duyệt bảng lương → GL: Nợ 622/627/642 (gross + BH chủ) / Có 334 (net), 338 (BH), 333 (thuế)
create or replace function approve_payroll(p_run uuid, p_by text) returns void language plpgsql as $$
declare r record; g numeric; n numeric; ins numeric; pit numeric; emp numeric; begin
  select * into r from payroll_runs where id=p_run; if r is null then raise exception 'ERR_NOT_FOUND'; end if; if r.computed_by = p_by then raise exception 'ERR_SELF_APPROVE'; end if;
  select coalesce(sum(gross),0), coalesce(sum(net),0), coalesce(sum(bhxh+bhyt+bhtn),0), coalesce(sum(pit),0), coalesce(sum(employer_ins),0) into g,n,ins,pit,emp from payslips where run_id=p_run;
  perform gl_post(r.farm_id,'payroll_runs',p_run::text,'Lương tháng '||to_char(r.month,'MM/YYYY'), jsonb_build_array(jsonb_build_object('acct','622','debit',g+emp,'credit',0), jsonb_build_object('acct','334','debit',0,'credit',n), jsonb_build_object('acct','338','debit',0,'credit',ins+emp), jsonb_build_object('acct','333','debit',0,'credit',pit), jsonb_build_object('acct','111','debit',0,'credit',g+emp-n-ins-emp-pit)), now(), p_by);
  update payroll_runs set status='DUYET', approved_by=p_by, approved_at=now() where id=p_run;
  perform publish_event(r.farm_id,'payroll.approved',jsonb_build_object('run',p_run,'month',r.month,'net',n)); end $$;
grant execute on function compute_payroll(text,date,text), approve_payroll(uuid,text), pit_progressive(numeric), setting_num(text,text,numeric) to app_user;
-- ===== 2. TSCĐ & khấu hao =====
create table if not exists fixed_assets(id text primary key, farm_id text not null, name text not null, kind text, -- NHA_XUONG|MAY_MOC|PHUONG_TIEN|THIET_BI|VAT_NUOI_SS|CAY_LAU_NAM|KHAC
  facility_id text, device_id text, cost numeric not null, salvage numeric default 0, life_months int not null, start_date date not null, method text default 'DUONG_THANG', cost_center text, gl_expense text default '627',
  accumulated numeric default 0, status text default 'DANG_DUNG', -- DANG_DUNG|THANH_LY|HET_KHAU_HAO
  disposed_at date, note text, created_at timestamptz default now(), created_by text, attrs jsonb default '{}'::jsonb);
create table if not exists depreciation_entries(id uuid primary key default gen_random_uuid(), farm_id text not null, asset_id text references fixed_assets, month date not null, amount numeric not null, journal_id uuid, created_at timestamptz default now(), unique(asset_id, month));
do $$ declare t text; begin foreach t in array array['fixed_assets','depreciation_entries'] loop execute format('alter table %I enable row level security', t); execute format('drop policy if exists p_all on %I', t); execute format('create policy p_all on %I for all using (can_see_farm(farm_id)) with check (true)', t); execute format('grant select, insert, update on %I to app_user', t); end loop; end $$;
drop trigger if exists audit_fixed_assets on fixed_assets; create trigger audit_fixed_assets after insert or update or delete on fixed_assets for each row execute function itran_audit();
create or replace function run_depreciation(p_farm text, p_month date) returns int language plpgsql as $$
declare a record; amt numeric; jid uuid; n int := 0; begin
  if exists (select 1 from period_locks where farm_id=p_farm and period_end >= (p_month + interval '1 month' - interval '1 day')::date) then raise exception 'ERR_PERIOD_LOCKED'; end if;
  for a in select * from fixed_assets where farm_id=p_farm and status='DANG_DUNG' and start_date <= (p_month + interval '1 month' - interval '1 day')::date loop
    if exists (select 1 from depreciation_entries where asset_id=a.id and month=p_month) then continue; end if;
    amt := round((a.cost - coalesce(a.salvage,0)) / a.life_months); if a.accumulated + amt > a.cost - coalesce(a.salvage,0) then amt := a.cost - coalesce(a.salvage,0) - a.accumulated; end if; if amt <= 0 then update fixed_assets set status='HET_KHAU_HAO' where id=a.id; continue; end if;
    jid := gl_post(p_farm,'depreciation',a.id||':'||to_char(p_month,'YYYY-MM'),'Khấu hao '||a.name||' '||to_char(p_month,'MM/YYYY'), jsonb_build_array(jsonb_build_object('acct',coalesce(a.gl_expense,'627'),'debit',amt,'credit',0,'cc',a.cost_center), jsonb_build_object('acct','214','debit',0,'credit',amt)), (p_month + interval '1 month' - interval '1 day')::timestamptz, 'SYSTEM');
    insert into depreciation_entries(farm_id,asset_id,month,amount,journal_id) values (p_farm,a.id,p_month,amt,jid); update fixed_assets set accumulated=accumulated+amt where id=a.id; n := n+1;
  end loop; return n; end $$;
grant execute on function run_depreciation(text,date) to app_user;
create or replace view v_fixed_assets as select a.*, a.cost - coalesce(a.salvage,0) - a.accumulated as remaining, round(100.0*a.accumulated/nullif(a.cost - coalesce(a.salvage,0),0),1) as pct_dep, (select count(*) from depreciation_entries d where d.asset_id=a.id) as months_done from fixed_assets a;
grant select on v_fixed_assets to app_user;
-- ===== 3. Khóa kỳ chặn GL =====
create or replace function gl_post(p_farm text, p_ref_table text, p_ref_id text, p_memo text, p_lines jsonb, p_ts timestamptz default now(), p_by text default null) returns uuid language plpgsql security definer as $$
declare d numeric; c numeric; i uuid; begin
  if exists (select 1 from period_locks where farm_id=p_farm and period_end >= p_ts::date) then raise exception 'ERR_PERIOD_LOCKED: kỳ đến % đã khóa — bút toán % phải ghi vào kỳ mở', (select max(period_end) from period_locks where farm_id=p_farm), p_memo; end if;
  select coalesce(sum((l->>'debit')::numeric),0), coalesce(sum((l->>'credit')::numeric),0) into d, c from jsonb_array_elements(p_lines) l;
  if round(d,0) <> round(c,0) then raise exception 'ERR_GL_UNBALANCED: no % <> co %', d, c; end if;
  if exists (select 1 from journal_entries where ref_table=p_ref_table and ref_id=p_ref_id and reversed_of is null) then return null; end if;
  insert into journal_entries(farm_id,ts,period,ref_table,ref_id,memo,lines,total,posted_by) values (p_farm,p_ts,date_trunc('month',p_ts)::date,p_ref_table,p_ref_id,p_memo,p_lines,d,p_by) returning id into i; return i; end $$;
-- Bút toán tay qua Quản trị DL cũng bị chặn khi kỳ khóa
create or replace function itran_je_lock() returns trigger language plpgsql as $$ begin if exists (select 1 from period_locks where farm_id=new.farm_id and period_end >= new.ts::date) then raise exception 'ERR_PERIOD_LOCKED'; end if; if new.period is null then new.period := date_trunc('month', new.ts)::date; end if; return new; end $$;
drop trigger if exists je_lock on journal_entries; create trigger je_lock before insert on journal_entries for each row execute function itran_je_lock();
-- ===== 4. Landed cost → giá vốn bình quân lô =====
-- lots.avg_cost = (Σ qty×unit_cost + landed phân bổ) / Σ qty của các lần nhập; cập nhật khi nhập mua hoặc khi thêm landed_costs (theo shipment → lô qua shipments.lots)
create or replace function itran_lot_avg_cost() returns trigger language plpgsql as $$
begin if new.direction=1 and new.lot_id is not null and coalesce(new.unit_cost,0)>0 then
  update lots l set avg_cost = (select round(sum(qty*unit_cost)/nullif(sum(qty),0),2) from inventory_moves m where m.lot_id=l.id and m.direction=1 and m.status='ACTIVE' and coalesce(m.unit_cost,0)>0) where l.id=new.lot_id; end if; return new; end $$;
drop trigger if exists lot_avg_cost on inventory_moves; create trigger lot_avg_cost after insert on inventory_moves for each row execute function itran_lot_avg_cost();
create or replace function apply_landed_cost(p_shipment text) returns int language plpgsql as $$
declare sh record; total numeric; l text; n int := 0; lot_qty numeric; sum_qty numeric := 0; alloc numeric; begin
  select * into sh from shipments where id=p_shipment; if sh is null then raise exception 'ERR_NOT_FOUND'; end if;
  select coalesce(sum(amount_vnd),0) into total from landed_costs where shipment_id=p_shipment and kind<>'HANG'; if total=0 then return 0; end if;
  for l in select jsonb_array_elements_text(coalesce(sh.lots,'[]'::jsonb)) loop select coalesce(sum(qty),0) into lot_qty from inventory_moves where lot_id=l and direction=1 and status='ACTIVE'; sum_qty := sum_qty + lot_qty; end loop;
  if sum_qty=0 then return 0; end if;
  for l in select jsonb_array_elements_text(coalesce(sh.lots,'[]'::jsonb)) loop select coalesce(sum(qty),0) into lot_qty from inventory_moves where lot_id=l and direction=1 and status='ACTIVE'; alloc := total * lot_qty / sum_qty;
    update lots set avg_cost = round((coalesce(avg_cost,0)*lot_qty + alloc)/nullif(lot_qty,0),2), attrs = coalesce(attrs,'{}'::jsonb) || jsonb_build_object('landed_alloc', alloc, 'shipment', p_shipment) where id=l; n := n+1; end loop; return n; end $$;
alter table lots add column if not exists attrs jsonb default '{}'::jsonb;
grant execute on function apply_landed_cost(text) to app_user;
insert into event_topics(topic,producer_dept,consumer_depts,description,source_table,wired) values ('payroll.approved','TCKT','{HCNS,BGD}','Bảng lương tháng đã duyệt → hạch toán 334/338/333, chuyển khoản','payroll_runs',true) on conflict (topic) do nothing;
