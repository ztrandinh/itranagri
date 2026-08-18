-- 0059 · sửa khóa dòng GL 'acct' (không phải 'account'), kind gl_accounts, trạng thái PO/animal thật
create or replace view v_gl_by_entity as
select coalesce(f.legal_entity_id, 'LE-'||f.id) as legal_entity_id, le.name as entity_name, j.farm_id, j.period, (l->>'acct') as account, a.name as account_name, a.kind,
  sum((l->>'debit')::numeric) as debit, sum((l->>'credit')::numeric) as credit
from journal_entries j join farms f on f.id=j.farm_id left join legal_entities le on le.id=coalesce(f.legal_entity_id, 'LE-'||f.id), jsonb_array_elements(j.lines) l left join gl_accounts a on a.code=(l->>'acct')
group by 1,2,3,4,5,6,7;
grant select on v_gl_by_entity to app_user;
create or replace view v_consolidated as
select period, account, account_name, kind, sum(debit) as debit, sum(credit) as credit, sum(debit)-sum(credit) as net, count(distinct legal_entity_id) as entities,
  sum(debit) filter (where account in ('136','336')) as intercompany_dr, sum(credit) filter (where account in ('136','336')) as intercompany_cr
from v_gl_by_entity group by period, account, account_name, kind;
grant select on v_consolidated to app_user;
update gl_accounts set kind='NO_PHAI_TRA' where code in ('336') and kind='NO';
create or replace function pay_supplier(p_po text, p_amount numeric, p_ref text default null) returns void language plpgsql as $$
declare po record; begin
  select * into po from purchase_orders where id=p_po; if not found then raise exception 'ERR_NOT_FOUND'; end if;
  update purchase_orders set paid_amount = coalesce(paid_amount,0) + p_amount, paid_at = case when coalesce(paid_amount,0) + p_amount >= total then now() else paid_at end where id=p_po;
  perform gl_post(po.farm_id, 'purchase_orders', p_po, 'Trả NCC '||coalesce(po.supplier_id,'')||' '||coalesce(p_ref,''), jsonb_build_array(jsonb_build_object('acct','331','debit',p_amount,'credit',0), jsonb_build_object('acct','112','debit',0,'credit',p_amount)), now(), app_staff());
end $$;

create or replace function pay_loan_installment(p_sched text, p_ref text default null) returns void language plpgsql as $$
declare s record; l record; g uuid; begin
  select * into s from loan_schedule where id=p_sched; if not found then raise exception 'ERR_NOT_FOUND'; end if; select * into l from loans where id=s.loan_id;
  g := gl_post(l.farm_id, 'loan_schedule', p_sched, 'Trả nợ vay '||l.lender||' kỳ '||s.seq||' '||coalesce(p_ref,''), jsonb_build_array(jsonb_build_object('acct','341','debit',s.principal,'credit',0), jsonb_build_object('acct','635','debit',s.interest,'credit',0), jsonb_build_object('acct','112','debit',0,'credit',s.principal+s.interest)), now(), app_staff());
  update loan_schedule set paid_principal=principal, paid_interest=interest, paid_at=now(), gl_ref=g, status='DA_TRA' where id=p_sched;
  if not exists (select 1 from loan_schedule where loan_id=s.loan_id and status<>'DA_TRA') then update loans set status='TAT_TOAN' where id=s.loan_id; end if;
end $$;

create or replace function receive_claim(p_claim text, p_amount numeric) returns void language plpgsql as $$
declare c record; begin
  select * into c from insurance_claims where id=p_claim; if not found then raise exception 'ERR_NOT_FOUND'; end if;
  update insurance_claims set paid_amount=coalesce(paid_amount,0)+p_amount, paid_at=current_date, status='DA_NHAN' where id=p_claim;
  perform gl_post(c.farm_id, 'insurance_claims', p_claim, 'Bồi thường bảo hiểm '||p_claim, jsonb_build_array(jsonb_build_object('acct','112','debit',p_amount,'credit',0), jsonb_build_object('acct','711','debit',0,'credit',p_amount)), now(), app_staff());
end $$;

