-- 0061 · RLS approval_matrix (farm_id null = toàn org); grant legal_entities RLS-free (danh mục org)
alter table approval_matrix enable row level security; drop policy if exists p_all on approval_matrix; create policy p_all on approval_matrix for all using (farm_id is null or can_see_farm(farm_id)) with check (true);
-- period trong journal_entries là date (ngày đầu tháng) → view xuất text YYYY-MM
drop view if exists v_consolidated; drop view if exists v_gl_by_entity;
create view v_gl_by_entity as
select coalesce(f.legal_entity_id, 'LE-'||f.id) as legal_entity_id, le.name as entity_name, j.farm_id, to_char(j.period,'YYYY-MM') as period, (l->>'acct') as account, a.name as account_name, a.kind,
  sum((l->>'debit')::numeric) as debit, sum((l->>'credit')::numeric) as credit
from journal_entries j join farms f on f.id=j.farm_id left join legal_entities le on le.id=coalesce(f.legal_entity_id, 'LE-'||f.id), jsonb_array_elements(j.lines) l left join gl_accounts a on a.code=(l->>'acct')
group by 1,2,3,4,5,6,7;
create view v_consolidated as
select period, account, account_name, kind, sum(debit) as debit, sum(credit) as credit, sum(debit)-sum(credit) as net, count(distinct legal_entity_id) as entities,
  sum(debit) filter (where account in ('136','336')) as intercompany_dr, sum(credit) filter (where account in ('136','336')) as intercompany_cr
from v_gl_by_entity group by period, account, account_name, kind;
grant select on v_gl_by_entity to app_user; grant select on v_consolidated to app_user;
