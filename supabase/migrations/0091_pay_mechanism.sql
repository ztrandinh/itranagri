-- 0091 · CƠ CHẾ LƯƠNG – THƯỞNG 4 lớp gắn bậc/ghế/KPI/cống hiến · định biên theo kế hoạch năm · SOP cốt lõi theo khối GS
-- Lớp 1: lương vị trí (salary_scales theo position_code/vai) × hệ số bậc (staff_grades.salary_coef) × ngày công
-- Lớp 2: KPI tháng (payroll.kpi_bonus_base_pct × điểm KPI) + thưởng điều kiện tháng (bonus_eval → apply_bonus_to_payroll)
-- Lớp 3: phụ cấp: ghế then chốt (key_positions.allowance), biệt phái GS, độc hại/ca đêm (staff.allowances jsonb)
-- Lớp 4: thưởng cống hiến quý/năm (điểm cống hiến v_contribution × đơn giá) → bonus_ledger THUONG_QUY → lương tháng kế
create table if not exists salary_scales(
  id uuid primary key default gen_random_uuid(), org_id text not null default 'ITRAN', farm_id text, scope_kind text not null check (scope_kind in ('POSITION','ROLE')), scope_code text not null,
  base_amount numeric not null, effective_from date not null default current_date, version int not null default 1, active boolean default true, note text, created_at timestamptz default now()
);
create unique index if not exists ux_salary_scales on salary_scales(org_id, coalesce(farm_id,''), scope_kind, scope_code, version);
alter table salary_scales enable row level security; drop policy if exists p_all on salary_scales; create policy p_all on salary_scales for all using (farm_id is null or can_see_farm(farm_id)) with check (true); grant select, insert, update on salary_scales to app_user;
alter table key_positions add column if not exists allowance numeric default 0;
-- Thang lương mặc định (đăng ký Sở LĐ = phiên bản này; sửa ở Quản trị DL › salary_scales)
insert into salary_scales(scope_kind, scope_code, base_amount, note) values
 ('POSITION','A1',7000000,'Trộn TMR / vận hành D5'),('POSITION','A2',7000000,'Chăm sóc bò / sinh sản'),('POSITION','A3',6500000,'Chăm sóc gà'),('POSITION','A4',7000000,'Khu D sinh học'),('POSITION','A5',7500000,'Nhập đàn / cân / lái máy'),
 ('POSITION','A6',7000000,'Ruộng / máy nông nghiệp'),('POSITION','A7',7000000,'Chế biến / đóng gói'),('POSITION','A8',7500000,'Thủ kho'),('POSITION','A9',7000000,'Bán hàng / POS'),('POSITION','A10',6000000,'Cổng / bảo vệ'),
 ('POSITION','A11',7500000,'Bảo trì / điện / IoT'),('POSITION','A12',6500000,'Lễ tân / buồng'),('POSITION','A13',7000000,'Hướng dẫn tour'),('POSITION','A14',7000000,'Bếp / F&B'),
 ('ROLE','worker',6500000,'Công nhân chưa gán vị trí'),('ROLE','team_lead',9000000,'Tổ trưởng / trưởng nhóm'),('ROLE','tech_head',12000000,'KTT / trưởng phòng'),('ROLE','accountant',11000000,'Kế toán'),('ROLE','auditor',10000000,'Giám sát / audit'),('ROLE','it_engineer',12000000,'Kỹ sư'),('ROLE','director',18000000,'Giám đốc trại'),('ROLE','owner',0,'Chủ đầu tư')
on conflict (org_id, coalesce(farm_id,''), scope_kind, scope_code, version) do nothing;
-- Lương lớp 1 của một người = lương vị trí × hệ số bậc (ưu tiên: thang theo trại > thang tổ chức; vị trí > vai); nếu chưa có thang → staff.salary_base
create or replace function pay_base(p_farm text, p_staff text) returns jsonb language plpgsql stable as $$
declare s record; sc record; coef numeric; g text; base numeric; src text;
begin
  select * into s from staff where id=p_staff;
  select * into sc from salary_scales x where x.active and x.effective_from <= current_date and ((x.scope_kind='POSITION' and x.scope_code=s.position_code) or (x.scope_kind='ROLE' and x.scope_code=s.role)) and (x.farm_id=p_farm or x.farm_id is null)
    order by (x.farm_id=p_farm) desc, (x.scope_kind='POSITION') desc, x.version desc limit 1;
  g := coalesce(current_grade(p_staff,'GS'), current_grade(p_staff,'CM'));
  select coalesce(sg.salary_coef, gsc.salary_coef, 1) into coef from staff_grades sg left join grade_scales gsc on gsc.track=sg.track and gsc.code=sg.grade_code and gsc.active where sg.staff_id=p_staff and sg.until is null order by (sg.track='GS') desc, sg.since desc limit 1;
  coef := coalesce(coef, 1);
  if sc.id is not null then base := round(sc.base_amount * coef, -3); src := 'SCALE:'||sc.scope_kind||':'||sc.scope_code||'×'||coef; else base := coalesce(s.salary_base, 0); src := 'staff.salary_base'; end if;
  return jsonb_build_object('base', base, 'scale_amount', sc.base_amount, 'coef', coef, 'grade', g, 'source', src,
    'allowance_key_position', coalesce((select sum(allowance) from key_positions k where k.holder_id=p_staff and (k.farm_id=p_farm)),0),
    'allowance_gs', case when current_grade(p_staff,'GS') is not null and exists (select 1 from supervision_assignments a where a.supervisor_id=p_staff and a.active and a.farm_id=p_farm) then setting_num('pay.gs_secondment_allowance', p_farm, 1000000) else 0 end);
end $$;
grant execute on function pay_base(text,text) to app_user;
-- Bảng lương thật dùng pay_base (giữ nguyên các lớp khác); ghi rõ nguồn trong detail để đối chiếu phụ lục HĐLĐ
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
    gross := byday + kb + alw + qb; ins := coalesce(s.insurance_salary, base);
    bhxh := round(ins*setting_num('payroll.bhxh_employee_pct',p_farm,8)/100); bhyt := round(ins*setting_num('payroll.bhyt_employee_pct',p_farm,1.5)/100); bhtn := round(ins*setting_num('payroll.bhtn_employee_pct',p_farm,1)/100);
    taxable := gross - bhxh - bhyt - bhtn - setting_num('payroll.giam_tru_ban_than',p_farm,11e6) - coalesce(s.dependents,0)*setting_num('payroll.giam_tru_phu_thuoc',p_farm,4.4e6); pit := pit_progressive(taxable);
    select coalesce(sum(amount),0) into adv from expense_requests where farm_id=p_farm and requested_by=s.id and purpose ilike 'tạm ứng%' and status='DUYET' and paid_at is not null and date_trunc('month',paid_at)=p_month;
    net := gross - bhxh - bhyt - bhtn - pit - adv; emp_ins := round(ins*(setting_num('payroll.bhxh_employer_pct',p_farm,17.5)+setting_num('payroll.bhyt_employer_pct',p_farm,3)+setting_num('payroll.bhtn_employer_pct',p_farm,1))/100);
    insert into payslips(run_id,farm_id,staff_id,month,base_salary,standard_days,work_days,paid_leave_days,unpaid_days,salary_by_days,kpi_score,kpi_bonus,allowances,other_add,gross,ins_salary,bhxh,bhyt,bhtn,taxable,pit,advances,net,employer_ins,detail)
    values (rid,p_farm,s.id,p_month,base,std,wd,pl,ul,byday,kpi,kb,alw,qb,gross,ins,bhxh,bhyt,bhtn,greatest(taxable,0),pit,adv,net,emp_ins,jsonb_build_object('attendance_used', wd, 'note', case when wd=std and pl=0 then 'chưa có chấm công → tạm tính đủ công' else null end, 'allowances', s.allowances, 'pay_base', pb, 'quarter_bonus', qb));
    tg := tg + gross; tn := tn + net; te := te + emp_ins;
  end loop;
  update payroll_runs set total_gross=tg, total_net=tn, total_employer=te where id=rid; return rid; end $$;
-- Lớp 4: chốt thưởng cống hiến quý → sổ (trả vào lương tháng đầu quý sau); đơn giá & quỹ là settings
create or replace function close_contribution_bonus(p_farm text, p_quarter text, p_by text) returns int language plpgsql as $$
declare n int := 0; r record; unit numeric := setting_num('bonus.contribution_unit', p_farm, 20000); cap numeric := setting_num('bonus.contribution_cap', p_farm, 3000000); pay_month text; y int; q int;
begin
  y := split_part(p_quarter,'-Q',1)::int; q := split_part(p_quarter,'-Q',2)::int; pay_month := to_char(make_date(y, q*3, 1) + interval '1 month', 'YYYY-MM');
  for r in select v.staff_id, round(v.kpi_pts+v.sup_pts+v.teach_pts+v.init_pts+v.cover_pts) as pts from v_contribution v where v.farm_id=p_farm loop
    if r.pts <= 0 then continue; end if;
    insert into bonus_ledger(farm_id, staff_id, period, kind, points, amount, ref_type, ref_id, note, created_at) values (p_farm, r.staff_id, pay_month, 'THUONG_QUY', r.pts, least(r.pts*unit, cap), 'contribution', p_quarter, 'Thưởng cống hiến '||p_quarter||' = '||r.pts||' điểm × '||unit||' (trần '||cap||')', now())
    on conflict do nothing; n := n+1;
  end loop; return n;
end $$;
grant execute on function close_contribution_bonus(text,text,text) to app_user;
-- Bảng tổng hợp cơ chế thu nhập từng người (để nhân sự tự xem "lương tôi tính thế nào")
create or replace view v_pay_structure as
 select s.farm_id, s.id as staff_id, s.full_name, s.dept, s.position, s.role, current_grade(s.id,'CM') as grade_cm, current_grade(s.id,'GS') as grade_gs,
   (pay_base(coalesce(s.farm_id,'F01'), s.id)->>'scale_amount')::numeric as scale_amount, (pay_base(coalesce(s.farm_id,'F01'), s.id)->>'coef')::numeric as coef, (pay_base(coalesce(s.farm_id,'F01'), s.id)->>'base')::numeric as base_l1,
   (pay_base(coalesce(s.farm_id,'F01'), s.id)->>'allowance_key_position')::numeric + (pay_base(coalesce(s.farm_id,'F01'), s.id)->>'allowance_gs')::numeric + coalesce((select sum((v#>>'{}')::numeric) from jsonb_each(coalesce(s.allowances,'{}'::jsonb)) as e(k,v)),0) as allowances_l3,
   setting_num('bonus.base_'||coalesce(case when current_grade(s.id,'GS') is not null then 'gs' end, s.role), coalesce(s.farm_id,'F01'), 1500000) as bonus_l2_max,
   pay_base(coalesce(s.farm_id,'F01'), s.id)->>'source' as source
 from staff s where s.active;
grant select on v_pay_structure to app_user;
-- ========== Định biên theo kế hoạch năm ==========
create table if not exists headcount_plans(id uuid primary key default gen_random_uuid(), farm_id text not null, year int not null, dept text not null, position_code text, title text, planned int not null default 1, budget_month numeric, note text, created_by text, created_at timestamptz default now());
create unique index if not exists ux_headcount_plans on headcount_plans(farm_id, year, dept, coalesce(position_code,''));
alter table headcount_plans enable row level security; drop policy if exists p_all on headcount_plans; create policy p_all on headcount_plans for all using (can_see_farm(farm_id)) with check (true); grant select, insert, update, delete on headcount_plans to app_user;
create or replace view v_headcount as
 select p.farm_id, p.year, p.dept, p.position_code, p.title, p.planned, p.budget_month,
   (select count(*) from staff s where s.farm_id=p.farm_id and s.active and s.dept=p.dept and (p.position_code is null or s.position_code=p.position_code)) as actual,
   (select coalesce(sum((pay_base(p.farm_id, s.id)->>'base')::numeric),0) from staff s where s.farm_id=p.farm_id and s.active and s.dept=p.dept and (p.position_code is null or s.position_code=p.position_code)) as actual_base_month
 from headcount_plans p;
grant select on v_headcount to app_user;
-- Sinh định biên năm từ thực tế + kế hoạch đàn/ha (gợi ý; HCNS sửa tay)
create or replace function suggest_headcount(p_farm text, p_year int, p_by text) returns int language plpgsql as $$
declare n int := 0; r record; begin
  for r in select dept, position_code, count(*) c, sum((pay_base(p_farm, id)->>'base')::numeric) b from staff where farm_id=p_farm and active and dept is not null group by 1,2 loop
    insert into headcount_plans(farm_id, year, dept, position_code, title, planned, budget_month, note, created_by) values (p_farm, p_year, r.dept, r.position_code, coalesce((select name from positions_catalog where code=r.position_code), r.dept), r.c, r.b, 'gợi ý từ thực tế '||to_char(current_date,'MM/YYYY'), p_by)
    on conflict (farm_id, year, dept, coalesce(position_code,'')) do nothing; n := n+1;
  end loop; return n; end $$;
grant execute on function suggest_headcount(text,int,text) to app_user;
-- ========== SOP cốt lõi theo khối GS ==========
create table if not exists gs_block_sops(block text references gs_blocks, sop_l2_code text, required boolean default true, note text, primary key (block, sop_l2_code));
alter table gs_block_sops enable row level security; drop policy if exists p_all on gs_block_sops; create policy p_all on gs_block_sops for all using (true) with check (true); grant select, insert, update, delete on gs_block_sops to app_user;
insert into gs_block_sops values
 ('CN','SOP-BO-01',true,'Nhập đàn – cách ly'),('CN','SOP-BO-02',true,'Cho ăn – khẩu phần'),('CN','SOP-AT-05',true,'An toàn sinh học'),('CN','SOP-TY-01',true,'Thú y – điều trị – ngưng thuốc'),
 ('TT','SOP-TT-01',true,'Mở mùa vụ – hồ sơ'),('TT','SOP-TT-02',true,'Vật tư – PHI'),('TT','SOP-TT-03',true,'Thu hoạch – nhập kho'),
 ('SH','SOP-AT-06',true,'Khu D – trùn/BSF/biogas'),('D5','SOP-BO-07',true,'TMR – D5'),('D5','SOP-CB-01',true,'Chế biến – CCP'),
 ('KHO','SOP-KH-01',true,'Nhập – xuất – kiểm kê'),('KHO','SOP-AT-01',true,'Cổng – cân'),('KD','SOP-KD-01',true,'Bán hàng – công nợ'),
 ('TCNS','SOP-HC-01',true,'Hành chính – nhân sự'),('TCNS','SOP-HC-03',true,'Đào tạo – giám sát'),('TB','SOP-CN-01',true,'Thiết bị – hiệu chuẩn – IoT')
on conflict do nothing;
-- gs_coverage: nếu khối đã định nghĩa SOP cốt lõi thì đậu = đậu ĐỦ SOP cốt lõi (theo mã L2, khớp bài thi sop_code bắt đầu bằng mã L2)
create or replace function gs_coverage(p_farm text, p_staff text) returns table(block text, name text, months numeric, sop_passed int, field_days int, acting int, done boolean, current boolean) language sql stable as $$
  select b.code, b.name,
    coalesce((select round(sum(extract(epoch from (least(coalesce(a.to_date,current_date),current_date)::timestamp - a.from_date::timestamp))/86400/30.4)::numeric,1) from supervision_assignments a where a.supervisor_id=p_staff and a.target_dept = any(b.depts)),0) as months,
    case when exists (select 1 from gs_block_sops g where g.block=b.code and g.required)
      then (select count(*)::int from gs_block_sops g where g.block=b.code and g.required and exists (select 1 from training_tests t where t.trainee_id=p_staff and t.passed and (t.sop_code=g.sop_l2_code or t.sop_code like g.sop_l2_code||'.%')))
           - (select count(*)::int from gs_block_sops g where g.block=b.code and g.required) + 1 -- =1 khi đủ, ≤0 khi thiếu
      else (select count(*)::int from training_tests t join sops s on s.code=t.sop_code where t.trainee_id=p_staff and t.passed and s.dept = any(b.depts)) end as sop_passed,
    (select count(*)::int from gs_field_days f where f.supervisor_id=p_staff and (f.block=b.code or f.dept = any(b.depts))) as field_days,
    (select count(*)::int from staff_delegations d join staff h on h.id=d.from_staff where d.to_staff=p_staff and d.status in ('ACTIVE','ENDED') and h.dept = any(b.depts) and h.role in ('tech_head','team_lead','director') and (d.to_date - d.from_date + 1) >= setting_num('gs.acting_days', p_farm, 14)) as acting,
    false, exists (select 1 from supervision_assignments a where a.supervisor_id=p_staff and a.active and a.target_dept = any(b.depts) and (a.to_date is null or a.to_date >= current_date))
  from gs_blocks b order by b.rank $$;
