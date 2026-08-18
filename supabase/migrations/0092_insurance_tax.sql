-- 0092 · Bảo hiểm & thuế TNCN cho từng người dùng: trần đóng BH (settings), thử việc/thời vụ có đóng hay không (settings), ước tính lương–BH–thuế cá nhân, khai người phụ thuộc, lịch sử phiếu lương của tôi
create or replace function compute_payroll(p_farm text, p_month date, p_by text) returns uuid language plpgsql as $$
declare rid uuid; s record; std numeric := setting_num('payroll.standard_days',p_farm,26); wd numeric; pl numeric; ul numeric; base numeric; byday numeric; kpi numeric; kb numeric; alw numeric; gross numeric; ins numeric; bhxh numeric; bhyt numeric; bhtn numeric; taxable numeric; pit numeric; adv numeric; net numeric; emp_ins numeric; tg numeric := 0; tn numeric := 0; te numeric := 0; pb jsonb; qb numeric; begin
  if exists (select 1 from period_locks where farm_id=p_farm and period_end >= (p_month + interval '1 month' - interval '1 day')::date) then raise exception 'ERR_PERIOD_LOCKED'; end if;
  insert into payroll_runs(farm_id,month,computed_by) values (p_farm,p_month,p_by) on conflict (farm_id,month) do update set computed_at=now(), computed_by=p_by, status='NHAP' returning id into rid;
  delete from payslips where run_id=rid;
  for s in select * from staff where active and (farm_id=p_farm or p_farm = any(farm_ids)) and role<>'customer' loop
    select coalesce(count(distinct day),0) into wd from attendance where farm_id=p_farm and staff_id=s.id and date_trunc('month',day)=p_month and check_in is not null;
    select coalesce(sum(days) filter (where kind in ('PHEP','OM','THAI_SAN')),0), coalesce(sum(days) filter (where kind in ('KHONG_LUONG','VIEC_RIENG')),0) into pl, ul from leave_requests where farm_id=p_farm and staff_id=s.id and status='DUYET' and date_trunc('month',from_date)=p_month;
    if wd = 0 and pl = 0 then wd := std; end if;
    pb := pay_base(p_farm, s.id); base := (pb->>'base')::numeric; byday := round(base * least(wd + pl, std) / std);
    select score into kpi from v_staff_kpi_month where farm_id=p_farm and staff_id=s.id and month=p_month; kb := round(base * setting_num('payroll.kpi_bonus_base_pct',p_farm,20)/100 * coalesce(kpi,0)/100);
    alw := coalesce((select sum((v#>>'{}')::numeric) from jsonb_each(coalesce(s.allowances,'{}'::jsonb)) as e(k,v)),0) + (pb->>'allowance_key_position')::numeric + (pb->>'allowance_gs')::numeric;
    -- lớp 4: thưởng quý/năm đã chốt vào sổ cho tháng này
    select coalesce(sum(amount),0) into qb from bonus_ledger where farm_id=p_farm and staff_id=s.id and kind in ('THUONG_QUY','THUONG_NAM') and period=to_char(p_month,'YYYY-MM');
    gross := byday + kb + alw + qb; ins := least(coalesce(s.insurance_salary, base), setting_num('payroll.insurance_cap',p_farm,46800000));
    if coalesce(s.contract_kind,'') in ('THOI_VU','THU_VIEC') and setting_num('payroll.insure_probation',p_farm,0)=0 then ins := 0; end if;
    bhxh := round(ins*setting_num('payroll.bhxh_employee_pct',p_farm,8)/100); bhyt := round(ins*setting_num('payroll.bhyt_employee_pct',p_farm,1.5)/100); bhtn := round(ins*setting_num('payroll.bhtn_employee_pct',p_farm,1)/100);
    taxable := gross - bhxh - bhyt - bhtn - setting_num('payroll.giam_tru_ban_than',p_farm,11e6) - coalesce(s.dependents,0)*setting_num('payroll.giam_tru_phu_thuoc',p_farm,4.4e6); pit := pit_progressive(taxable);
    select coalesce(sum(amount),0) into adv from expense_requests where farm_id=p_farm and requested_by=s.id and purpose ilike 'tạm ứng%' and status='DUYET' and paid_at is not null and date_trunc('month',paid_at)=p_month;
    net := gross - bhxh - bhyt - bhtn - pit - adv; emp_ins := round(ins*(setting_num('payroll.bhxh_employer_pct',p_farm,17.5)+setting_num('payroll.bhyt_employer_pct',p_farm,3)+setting_num('payroll.bhtn_employer_pct',p_farm,1))/100);
    insert into payslips(run_id,farm_id,staff_id,month,base_salary,standard_days,work_days,paid_leave_days,unpaid_days,salary_by_days,kpi_score,kpi_bonus,allowances,other_add,gross,ins_salary,bhxh,bhyt,bhtn,taxable,pit,advances,net,employer_ins,detail)
    values (rid,p_farm,s.id,p_month,base,std,wd,pl,ul,byday,kpi,kb,alw,qb,gross,ins,bhxh,bhyt,bhtn,greatest(taxable,0),pit,adv,net,emp_ins,jsonb_build_object('attendance_used', wd, 'note', case when wd=std and pl=0 then 'chưa có chấm công → tạm tính đủ công' else null end, 'allowances', s.allowances, 'pay_base', pb, 'quarter_bonus', qb));
    tg := tg + gross; tn := tn + net; te := te + emp_ins;
  end loop;
  update payroll_runs set total_gross=tg, total_net=tn, total_employer=te where id=rid; return rid; end $$;
-- Ước tính thu nhập – bảo hiểm – thuế của 1 người theo cấu hình hiện hành (đủ công, KPI 100%), để nhân sự tự xem "tôi được bao nhiêu, đóng bao nhiêu"
create or replace function pay_estimate(p_farm text, p_staff text) returns jsonb language plpgsql stable as $$
declare s record; pb jsonb; base numeric; alw numeric; kb numeric; gross numeric; ins numeric; bhxh numeric; bhyt numeric; bhtn numeric; gt_bt numeric; gt_pt numeric; taxable numeric; pit numeric; net numeric; emp numeric; last_slip jsonb;
begin
  select * into s from staff where id=p_staff; pb := pay_base(p_farm, p_staff); base := (pb->>'base')::numeric;
  alw := coalesce((select sum((v#>>'{}')::numeric) from jsonb_each(coalesce(s.allowances,'{}'::jsonb)) as e(k,v)),0) + (pb->>'allowance_key_position')::numeric + (pb->>'allowance_gs')::numeric;
  kb := round(base * setting_num('payroll.kpi_bonus_base_pct',p_farm,20)/100);
  gross := base + kb + alw;
  ins := least(coalesce(s.insurance_salary, base), setting_num('payroll.insurance_cap',p_farm,46800000));
  if coalesce(s.contract_kind,'') in ('THOI_VU','THU_VIEC') and setting_num('payroll.insure_probation',p_farm,0)=0 then ins := 0; end if;
  bhxh := round(ins*setting_num('payroll.bhxh_employee_pct',p_farm,8)/100); bhyt := round(ins*setting_num('payroll.bhyt_employee_pct',p_farm,1.5)/100); bhtn := round(ins*setting_num('payroll.bhtn_employee_pct',p_farm,1)/100);
  gt_bt := setting_num('payroll.giam_tru_ban_than',p_farm,11e6); gt_pt := coalesce(s.dependents,0)*setting_num('payroll.giam_tru_phu_thuoc',p_farm,4.4e6);
  taxable := greatest(gross - bhxh - bhyt - bhtn - gt_bt - gt_pt, 0); pit := pit_progressive(taxable); net := gross - bhxh - bhyt - bhtn - pit;
  emp := round(ins*(setting_num('payroll.bhxh_employer_pct',p_farm,17.5)+setting_num('payroll.bhyt_employer_pct',p_farm,3)+setting_num('payroll.bhtn_employer_pct',p_farm,1))/100);
  select to_jsonb(p) into last_slip from (select x.month, x.base_salary, x.work_days, x.salary_by_days, x.kpi_bonus, x.allowances, x.other_add, x.gross, x.ins_salary, x.bhxh, x.bhyt, x.bhtn, x.taxable, x.pit, x.advances, x.net, x.employer_ins from payslips x where x.staff_id=p_staff order by x.month desc limit 1) p;
  return jsonb_build_object('pay_base', pb, 'base_l1', base, 'kpi_max', kb, 'allowances', alw, 'gross', gross, 'ins_salary', ins, 'ins_cap', setting_num('payroll.insurance_cap',p_farm,46800000),
    'bhxh', bhxh, 'bhyt', bhyt, 'bhtn', bhtn, 'bhxh_pct', setting_num('payroll.bhxh_employee_pct',p_farm,8), 'bhyt_pct', setting_num('payroll.bhyt_employee_pct',p_farm,1.5), 'bhtn_pct', setting_num('payroll.bhtn_employee_pct',p_farm,1),
    'giam_tru_ban_than', gt_bt, 'dependents', coalesce(s.dependents,0), 'giam_tru_phu_thuoc', gt_pt, 'taxable', taxable, 'pit', pit, 'net', net, 'employer_ins', emp, 'contract_kind', s.contract_kind, 'last_payslip', last_slip);
end $$;
grant execute on function pay_estimate(text,text) to app_user;
-- Biểu thuế TNCN lũy tiến (để hiển thị; pit_progressive dùng đúng biểu này theo luật hiện hành)
create or replace view v_pit_brackets as select * from (values (1,0,5e6,5),(2,5e6,10e6,10),(3,10e6,18e6,15),(4,18e6,32e6,20),(5,32e6,52e6,25),(6,52e6,80e6,30),(7,80e6,null::numeric,35)) t(bac, tu, den, thue_pct);
grant select on v_pit_brackets to app_user;
-- Khai người phụ thuộc: nhân sự tự khai → HCNS duyệt (lưu vào staff.dependents khi duyệt)
create table if not exists dependent_claims(id uuid primary key default gen_random_uuid(), farm_id text not null, staff_id text not null, dependents int not null, note text, status text not null default 'CHO' check (status in ('CHO','DUYET','TU_CHOI')), decided_by text, decided_at timestamptz, created_at timestamptz default now());
alter table dependent_claims enable row level security; drop policy if exists p_all on dependent_claims; create policy p_all on dependent_claims for all using (can_see_farm(farm_id)) with check (true); grant select, insert, update on dependent_claims to app_user;
