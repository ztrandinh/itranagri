-- 0058 · TÀI CHÍNH: AP aging + lịch trả NCC, khoản vay + lịch trả nợ + lãi vào GL, ma trận ủy quyền = dữ liệu (approval_matrix), bảo hiểm vật nuôi/tài sản + bồi thường,
--        tổng hợp thuế GTGT đầu ra/đầu vào, hợp nhất đa pháp nhân (legal_entities + v_consolidated), lịch thanh toán tổng (AP + vay + thuế)
-- 1) Pháp nhân & hợp nhất
create table if not exists legal_entities(
  id text primary key, org_id text not null default 'ITRAN', name text not null, tax_code text, address text, kind text default 'CTY_TNHH', -- CTY_TNHH|CTY_CP|HTX|HO_KD|CHI_NHANH
  parent_id text references legal_entities, ownership_pct numeric default 100, currency text default 'VND', fiscal_year_start int default 1, bank_account text, bank_bin text, active bool default true, attrs jsonb default '{}'::jsonb);
grant select, insert, update on legal_entities to app_user;
alter table farms add column if not exists legal_entity_id text references legal_entities;
insert into legal_entities(id, name, tax_code) select 'LE-'||f.id, coalesce(f.legal_entity, 'ITRAN '||f.id), f.tax_code from farms f where f.legal_entity is not null and not exists (select 1 from legal_entities where id='LE-'||f.id);
update farms f set legal_entity_id='LE-'||f.id where legal_entity_id is null and exists (select 1 from legal_entities where id='LE-'||f.id);
-- Số dư TK theo pháp nhân (từ journal_entries.lines [{account, debit, credit}]) — hợp nhất = cộng dồn, loại trừ nội bộ theo cặp 136/336 nếu có
create or replace view v_gl_by_entity as
select coalesce(f.legal_entity_id, 'LE-'||f.id) as legal_entity_id, le.name as entity_name, j.farm_id, j.period, (l->>'account') as account, a.name as account_name, a.kind,
  sum((l->>'debit')::numeric) as debit, sum((l->>'credit')::numeric) as credit
from journal_entries j join farms f on f.id=j.farm_id left join legal_entities le on le.id=coalesce(f.legal_entity_id, 'LE-'||f.id), jsonb_array_elements(j.lines) l left join gl_accounts a on a.code=(l->>'account')
group by 1,2,3,4,5,6,7;
grant select on v_gl_by_entity to app_user;
create or replace view v_consolidated as
select period, account, account_name, kind, sum(debit) as debit, sum(credit) as credit, sum(debit)-sum(credit) as net, count(distinct legal_entity_id) as entities,
  sum(debit) filter (where account in ('136','336')) as intercompany_dr, sum(credit) filter (where account in ('136','336')) as intercompany_cr
from v_gl_by_entity group by period, account, account_name, kind;
grant select on v_consolidated to app_user;
insert into gl_accounts(code, name, kind, active) values ('136','Phải thu nội bộ','TAI_SAN',true),('336','Phải trả nội bộ','NO',true),('635','Chi phí tài chính (lãi vay)','CHI_PHI',true),('242','Chi phí trả trước (bảo hiểm)','TAI_SAN',true) on conflict (code) do nothing;

-- 2) AP aging + lịch trả NCC (từ purchase_orders đã nhận + expense_requests đã duyệt chưa trả)
alter table purchase_orders add column if not exists paid_at timestamptz; alter table purchase_orders add column if not exists payment_due date; alter table purchase_orders add column if not exists invoice_no text; alter table purchase_orders add column if not exists paid_amount numeric default 0;
alter table partners add column if not exists supplier_terms_days int;
create or replace view v_ap_aging as
select p.farm_id, p.supplier_id as partner_id, pt.name as partner_name, 'PO' as kind, p.id as ref_id, p.ts::date as doc_date, p.invoice_no, p.total as amount, coalesce(p.paid_amount,0) as paid, p.total - coalesce(p.paid_amount,0) as unpaid,
  coalesce(p.payment_due, (coalesce(p.received_at, p.ts)::date + coalesce(pt.supplier_terms_days, 15))) as due_date,
  greatest(current_date - coalesce(p.payment_due, (coalesce(p.received_at, p.ts)::date + coalesce(pt.supplier_terms_days, 15))), 0) as days_overdue
from purchase_orders p left join partners pt on pt.id=p.supplier_id where p.po_status in ('DUYET','NHAN','DONG','HOAN_TAT') and p.paid_at is null and p.total - coalesce(p.paid_amount,0) > 0
union all
select e.farm_id, null, e.cost_center, 'CHI', e.id::text, e.ts::date, null, e.amount, 0, e.amount, e.ts::date + 7, greatest(current_date - (e.ts::date + 7), 0)
from expense_requests e where e.status='DUYET' and e.paid_at is null;
grant select on v_ap_aging to app_user;
create or replace view v_ap_summary as
select farm_id, partner_id, partner_name, sum(unpaid) as unpaid, sum(unpaid) filter (where days_overdue=0) as not_due, sum(unpaid) filter (where days_overdue between 1 and 30) as d1_30, sum(unpaid) filter (where days_overdue between 31 and 60) as d31_60, sum(unpaid) filter (where days_overdue>60) as d60p, max(days_overdue) as max_overdue, count(*) as n_docs
from v_ap_aging group by farm_id, partner_id, partner_name;
grant select on v_ap_summary to app_user;
-- ghi nhận trả NCC: cập nhật PO + bút toán 331/112
create or replace function pay_supplier(p_po text, p_amount numeric, p_ref text default null) returns void language plpgsql as $$
declare po record; begin
  select * into po from purchase_orders where id=p_po; if not found then raise exception 'ERR_NOT_FOUND'; end if;
  update purchase_orders set paid_amount = coalesce(paid_amount,0) + p_amount, paid_at = case when coalesce(paid_amount,0) + p_amount >= total then now() else paid_at end where id=p_po;
  perform gl_post(po.farm_id, 'purchase_orders', p_po, 'Trả NCC '||coalesce(po.supplier_id,'')||' '||coalesce(p_ref,''), jsonb_build_array(jsonb_build_object('account','331','debit',p_amount,'credit',0), jsonb_build_object('account','112','debit',0,'credit',p_amount)), now(), app_staff());
end $$;
grant execute on function pay_supplier(text,numeric,text) to app_user;

-- 3) Khoản vay + lịch trả nợ (niên kim / gốc đều) + hạch toán lãi hằng tháng
create table if not exists loans(
  id text primary key, farm_id text not null references farms, legal_entity_id text references legal_entities, lender text not null, kind text default 'NGAN_HANG', -- NGAN_HANG|CA_NHAN|QUY|TRAI_PHIEU|THUE_TC
  contract_no text, principal numeric not null, currency text default 'VND', rate_pct numeric not null, rate_kind text default 'CO_DINH', -- CO_DINH|THA_NOI
  start_date date not null, term_months int not null, method text default 'GOC_DEU' check (method in ('GOC_DEU','NIEN_KIM','CUOI_KY')), grace_months int default 0, collateral text, purpose text,
  status text default 'DANG_VAY' check (status in ('DANG_VAY','TAT_TOAN','QUA_HAN','HUY')), note text, doc_url text, created_at timestamptz default now(), created_by text default app_staff(), attrs jsonb default '{}'::jsonb);
create table if not exists loan_schedule(
  id text primary key, loan_id text not null references loans on delete cascade, seq int not null, due_date date not null, principal numeric not null, interest numeric not null, balance_after numeric not null,
  paid_principal numeric default 0, paid_interest numeric default 0, paid_at timestamptz, gl_ref uuid, status text default 'CHO' check (status in ('CHO','DA_TRA','TRE','MOT_PHAN')), unique(loan_id, seq));
alter table loans enable row level security; drop policy if exists p_all on loans; create policy p_all on loans for all using (can_see_farm(farm_id)) with check (true); grant select, insert, update on loans to app_user;
alter table loan_schedule enable row level security; drop policy if exists p_all on loan_schedule; create policy p_all on loan_schedule for all using (exists (select 1 from loans l where l.id=loan_schedule.loan_id and can_see_farm(l.farm_id))) with check (true); grant select, insert, update, delete on loan_schedule to app_user;
create or replace function gen_loan_schedule(p_loan text) returns int language plpgsql as $$
declare l record; bal numeric; r numeric; pmt numeric; i int; pr numeric; it numeric; n int := 0; pay_months int; begin
  select * into l from loans where id=p_loan; if not found then raise exception 'ERR_NOT_FOUND'; end if;
  delete from loan_schedule where loan_id=p_loan and status='CHO' and paid_at is null;
  bal := l.principal; r := l.rate_pct/100/12; pay_months := l.term_months - coalesce(l.grace_months,0);
  if l.method='NIEN_KIM' and r>0 then pmt := bal * r / (1 - power(1+r, -pay_months)); end if;
  for i in 1..l.term_months loop
    it := round(bal * r);
    if i <= coalesce(l.grace_months,0) then pr := 0;
    elsif l.method='CUOI_KY' then pr := case when i=l.term_months then bal else 0 end;
    elsif l.method='NIEN_KIM' and r>0 then pr := round(pmt - it);
    else pr := round(l.principal / pay_months); end if;
    if i=l.term_months then pr := bal; end if;
    bal := bal - pr;
    insert into loan_schedule(id, loan_id, seq, due_date, principal, interest, balance_after) values (p_loan||'-'||lpad(i::text,3,'0'), p_loan, i, (l.start_date + (i||' months')::interval)::date, pr, it, greatest(bal,0)) on conflict (loan_id, seq) do nothing;
    n := n+1;
  end loop; return n; end $$;
grant execute on function gen_loan_schedule(text) to app_user;
-- ghi nhận trả kỳ vay: bút toán 341 (gốc) + 635 (lãi) / 112
create or replace function pay_loan_installment(p_sched text, p_ref text default null) returns void language plpgsql as $$
declare s record; l record; g uuid; begin
  select * into s from loan_schedule where id=p_sched; if not found then raise exception 'ERR_NOT_FOUND'; end if; select * into l from loans where id=s.loan_id;
  g := gl_post(l.farm_id, 'loan_schedule', p_sched, 'Trả nợ vay '||l.lender||' kỳ '||s.seq||' '||coalesce(p_ref,''), jsonb_build_array(jsonb_build_object('account','341','debit',s.principal,'credit',0), jsonb_build_object('account','635','debit',s.interest,'credit',0), jsonb_build_object('account','112','debit',0,'credit',s.principal+s.interest)), now(), app_staff());
  update loan_schedule set paid_principal=principal, paid_interest=interest, paid_at=now(), gl_ref=g, status='DA_TRA' where id=p_sched;
  if not exists (select 1 from loan_schedule where loan_id=s.loan_id and status<>'DA_TRA') then update loans set status='TAT_TOAN' where id=s.loan_id; end if;
end $$;
grant execute on function pay_loan_installment(text,text) to app_user;
create or replace view v_loans as
select l.*, (select sum(principal) from loan_schedule x where x.loan_id=l.id and x.status='DA_TRA') as paid_principal, (select sum(interest) from loan_schedule x where x.loan_id=l.id and x.status='DA_TRA') as paid_interest,
  l.principal - coalesce((select sum(principal) from loan_schedule x where x.loan_id=l.id and x.status='DA_TRA'),0) as outstanding,
  (select min(due_date) from loan_schedule x where x.loan_id=l.id and x.status<>'DA_TRA') as next_due, (select principal+interest from loan_schedule x where x.loan_id=l.id and x.status<>'DA_TRA' order by due_date limit 1) as next_amount,
  (select count(*) from loan_schedule x where x.loan_id=l.id and x.status<>'DA_TRA' and x.due_date<current_date) as overdue_installments
from loans l;
grant select on v_loans to app_user;

-- 4) Ma trận ủy quyền = dữ liệu (thay hằng số trong code): loại nghiệp vụ → vai → hạn mức → số chữ ký → báo chủ
create table if not exists approval_matrix(
  id text primary key, org_id text default 'ITRAN', farm_id text, kind text not null, -- CHI|PO|BAN_DUOI_SAN|GIAM_GIA|LUONG|TRA_HANG|DIEU_CHINH_KHO|HOP_DONG|VAY
  role text not null, max_amount numeric, min_signers int default 1, two_sign_over numeric, notify_owner_over numeric, active bool default true, note text, updated_at timestamptz default now(), updated_by text default app_staff());
grant select, insert, update on approval_matrix to app_user;
insert into approval_matrix(id, kind, role, max_amount, min_signers, two_sign_over, notify_owner_over, note) values
 ('AM-CHI-TL','CHI','team_lead',2000000,1,20000000,50000000,'Trưởng nhóm duyệt chi ≤2tr'),('AM-CHI-TH','CHI','tech_head',10000000,1,20000000,50000000,'KTT ≤10tr'),('AM-CHI-DIR','CHI','director',100000000,1,20000000,50000000,'GĐ ≤100tr; >20tr 2 chữ ký; >50tr báo chủ'),('AM-CHI-OWN','CHI','owner',null,1,20000000,null,'Chủ không giới hạn'),('AM-CHI-ACC','CHI','accountant',0,1,null,null,'Kế toán không duyệt chi'),
 ('AM-PO-TH','PO','tech_head',30000000,1,50000000,200000000,'PO vật tư ≤30tr'),('AM-PO-DIR','PO','director',500000000,1,50000000,200000000,''),('AM-PO-OWN','PO','owner',null,1,50000000,null,''),
 ('AM-GG-DIR','GIAM_GIA','director',null,1,null,null,'Bán dưới sàn/giảm giá cần GĐ'),('AM-LUONG-DIR','LUONG','director',null,1,null,null,'Duyệt bảng lương'),('AM-LUONG-OWN','LUONG','owner',null,1,null,null,''),
 ('AM-TRA-TH','TRA_HANG','tech_head',5000000,1,null,null,''),('AM-TRA-DIR','TRA_HANG','director',null,1,null,null,''),('AM-VAY-OWN','VAY','owner',null,2,null,null,'Vay: chủ + GĐ')
on conflict do nothing;
create or replace function approval_limit(p_kind text, p_role text, p_farm text default null) returns table(max_amount numeric, two_sign_over numeric, notify_owner_over numeric, min_signers int) language sql stable as $$
  select max_amount, two_sign_over, notify_owner_over, min_signers from approval_matrix where kind=p_kind and role=p_role and active and (farm_id is null or farm_id=p_farm) order by (farm_id is not null) desc limit 1 $$;
grant execute on function approval_limit(text,text,text) to app_user;

-- 5) Bảo hiểm vật nuôi / tài sản / trách nhiệm + bồi thường
create table if not exists insurance_policies(
  id text primary key, farm_id text not null references farms, insurer text not null, policy_no text, kind text not null, -- VAT_NUOI|TAI_SAN|MUA_MANG|TRACH_NHIEM|XE|CON_NGUOI|HANG_HOA
  subject_type text, subject_ids text[], -- animal|group|asset|vehicle|plot|staff
  coverage text, sum_insured numeric, premium numeric, premium_period text default 'NAM', deductible numeric, start_date date, end_date date, status text default 'HIEU_LUC' check (status in ('HIEU_LUC','HET_HAN','HUY')),
  gl_prepaid bool default true, doc_url text, note text, created_at timestamptz default now(), created_by text default app_staff(), attrs jsonb default '{}'::jsonb);
create table if not exists insurance_claims(
  id text primary key, policy_id text not null references insurance_policies, farm_id text not null references farms, event_date date not null, incident_id text, subject_id text, description text, claimed_amount numeric, approved_amount numeric, paid_amount numeric, paid_at date,
  status text default 'MO' check (status in ('MO','GUI_HS','DUYET','TU_CHOI','DA_NHAN','DONG')), docs text[], note text, created_at timestamptz default now(), created_by text default app_staff());
do $$ declare t text; begin
  foreach t in array array['insurance_policies','insurance_claims'] loop
    execute format('alter table %I enable row level security', t); execute format('drop policy if exists p_all on %I', t);
    execute format('create policy p_all on %I for all using (can_see_farm(farm_id)) with check (true)', t); execute format('grant select, insert, update on %I to app_user', t);
  end loop; end $$;
create or replace view v_insurance as
select p.*, (select count(*) from insurance_claims c where c.policy_id=p.id) as n_claims, (select sum(paid_amount) from insurance_claims c where c.policy_id=p.id) as claims_paid,
  case when p.end_date < current_date then 'HET_HAN' when p.end_date < current_date + 30 then 'SAP_HET' else 'OK' end as expiry_flag,
  case when p.kind='VAT_NUOI' and p.subject_ids is not null then (select count(*) from animals a where a.id = any(p.subject_ids) and a.status='DANG_NUOI') end as animals_alive
from insurance_policies p;
grant select on v_insurance to app_user;
-- bồi thường nhận tiền → 112/711
create or replace function receive_claim(p_claim text, p_amount numeric) returns void language plpgsql as $$
declare c record; begin
  select * into c from insurance_claims where id=p_claim; if not found then raise exception 'ERR_NOT_FOUND'; end if;
  update insurance_claims set paid_amount=coalesce(paid_amount,0)+p_amount, paid_at=current_date, status='DA_NHAN' where id=p_claim;
  perform gl_post(c.farm_id, 'insurance_claims', p_claim, 'Bồi thường bảo hiểm '||p_claim, jsonb_build_array(jsonb_build_object('account','112','debit',p_amount,'credit',0), jsonb_build_object('account','711','debit',0,'credit',p_amount)), now(), app_staff());
end $$;
grant execute on function receive_claim(text,numeric) to app_user;

-- 6) Thuế GTGT tổng hợp theo kỳ: đầu ra từ sales (giả định VAT theo products.attrs->>'vat_pct' hoặc 0/5/8/10 mặc định 0 cho nông sản sơ chế), đầu vào từ PO (attrs vat_pct)
alter table products add column if not exists vat_pct numeric default 0;
create or replace view v_vat_summary as
with outp as (select s.farm_id, to_char(s.ts,'YYYY-MM') as period, sum(s.amount) as revenue, sum(s.amount * coalesce(p.vat_pct,0)/(100+coalesce(p.vat_pct,0))) as vat_out from sales s left join products p on p.sku=s.sku where s.status='ACTIVE' group by 1,2),
inp as (select po.farm_id, to_char(po.ts,'YYYY-MM') as period, sum(po.total) as purchases, sum(po.total * coalesce((po.note ~ 'VAT10')::int*10, 0)/110.0) as vat_in from purchase_orders po where po.po_status in ('DUYET','NHAN','DONG','HOAN_TAT') group by 1,2)
select coalesce(o.farm_id, i.farm_id) as farm_id, coalesce(o.period, i.period) as period, coalesce(o.revenue,0) as revenue, round(coalesce(o.vat_out,0)) as vat_out, coalesce(i.purchases,0) as purchases, round(coalesce(i.vat_in,0)) as vat_in, round(coalesce(o.vat_out,0) - coalesce(i.vat_in,0)) as vat_payable
from outp o full join inp i on i.farm_id=o.farm_id and i.period=o.period;
grant select on v_vat_summary to app_user;

-- 7) Lịch thanh toán tổng 13 tuần: AP + vay + lương (ước) + thuế
create or replace view v_payment_calendar as
select farm_id, 'NCC' as kind, partner_name as who, ref_id as ref, due_date, unpaid as amount from v_ap_aging
union all select l.farm_id, 'VAY', l.lender, s.id, s.due_date, s.principal+s.interest from loan_schedule s join loans l on l.id=s.loan_id where s.status<>'DA_TRA'
union all select farm_id, 'BAO_HIEM', insurer, id, end_date, premium from insurance_policies where status='HIEU_LUC' and end_date between current_date and current_date+90
union all select farm_id, 'THUE_GTGT', 'Cơ quan thuế', period, (to_date(period||'-01','YYYY-MM-DD') + interval '1 month' + interval '19 days')::date, vat_payable from v_vat_summary where vat_payable>0 and period >= to_char(current_date - interval '2 months','YYYY-MM');
grant select on v_payment_calendar to app_user;
-- audit + cảnh báo
do $$ declare t text; begin
  foreach t in array array['legal_entities','loans','loan_schedule','approval_matrix','insurance_policies','insurance_claims'] loop
    execute format('drop trigger if exists %s_audit on %I', t, t);
    execute format('create trigger %s_audit after insert or update or delete on %I for each row execute function itran_audit()', t, t);
  end loop; end $$;
insert into alert_rules(code, version, farm_id, name, source, expr, level, recipients, channels, cooldown_min, active)
select v.code, 1, 'GLOBAL', v.name, 'custom', v.expr::jsonb, v.level, v.rec::text[], '{app}'::text[], v.cd, true from (values
 ('AL-AP-DUE','Phải trả NCC đến hạn ≤7 ngày / quá hạn','{"type":"sql_rows","sql":"select partner_name as ref, unpaid as value, due_date::text as d from v_ap_aging where farm_id=$1 and due_date <= current_date+7","message":"Trả {ref}: {value} đ hạn {d}"}','VANG','{accountant,director}',1440),
 ('AL-LOAN-DUE','Kỳ trả nợ vay ≤7 ngày / quá hạn','{"type":"sql_rows","sql":"select l.lender as ref, s.principal+s.interest as value, s.due_date::text as d from loan_schedule s join loans l on l.id=s.loan_id where l.farm_id=$1 and s.status<>''DA_TRA'' and s.due_date <= current_date+7","message":"Trả nợ {ref}: {value} đ hạn {d}"}','VANG','{accountant,director,owner}',1440),
 ('AL-INSURANCE','Bảo hiểm sắp hết hạn ≤30 ngày','{"type":"sql_rows","sql":"select insurer||'' ''||coalesce(policy_no,'''') as ref, kind, end_date::text as d from insurance_policies where farm_id=$1 and status=''HIEU_LUC'' and end_date <= current_date+30","message":"Bảo hiểm {kind} {ref} hết hạn {d} — tái tục"}','VANG','{accountant,director}',1440)
) as v(code, name, expr, level, rec, cd) where not exists (select 1 from alert_rules a where a.code=v.code);
