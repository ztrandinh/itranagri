-- 0039 · PHẢ HỆ nhiều đời (đệ quy tổ tiên/hậu duệ, hệ số cận huyết đơn giản) · CẢNH BÁO DỊCH TỄ theo vùng (bệnh/chết tăng bất thường trong bán kính vùng/trại lân cận) · sinh sản: sire từ mã tinh
alter table animals add column if not exists sire_id text;
create or replace function pedigree(p_animal text, p_depth int default 4) returns table(animal_id text, generation int, side text, ancestor_id text, sex text, breed text, birth_date date, path text) language sql stable as $$
  with recursive anc as (
    select a.id as animal_id, 0 as generation, 'SELF'::text as side, a.id as ancestor_id, a.sex, a.breed, a.birth_date, a.id::text as path from animals a where a.id=p_animal
    union all
    select anc.animal_id, anc.generation+1, case when anc.generation=0 then case when p.side='DAM' then 'DAM' else 'SIRE' end else anc.side end,
      p.pid, x.sex, x.breed, x.birth_date, anc.path||'>'||p.pid
    from anc join lateral (select a2.dam_id as pid, 'DAM' as side from animals a2 where a2.id=anc.ancestor_id and a2.dam_id is not null union all select a2.sire_id, 'SIRE' from animals a2 where a2.id=anc.ancestor_id and a2.sire_id is not null) p on true
    left join animals x on x.id=p.pid where anc.generation < p_depth)
  select * from anc where generation>0 order by generation, side $$;
create or replace function descendants(p_animal text, p_depth int default 4) returns table(descendant_id text, generation int, dam_id text, sire_id text, sex text, birth_date date, status text) language sql stable as $$
  with recursive d as (select a.id as descendant_id, 1 as generation, a.dam_id, a.sire_id, a.sex, a.birth_date, a.status from animals a where a.dam_id=p_animal or a.sire_id=p_animal
    union all select a.id, d.generation+1, a.dam_id, a.sire_id, a.sex, a.birth_date, a.status from animals a join d on (a.dam_id=d.descendant_id or a.sire_id=d.descendant_id) where d.generation < p_depth)
  select * from d order by generation, birth_date $$;
-- Kiểm tra cận huyết: cha/mẹ chung trong 3 đời của 2 con định phối
create or replace function inbreeding_risk(p_female text, p_male text) returns jsonb language sql stable as $$
  select jsonb_build_object('shared_ancestors', coalesce((select jsonb_agg(distinct f.ancestor_id) from pedigree(p_female,3) f join pedigree(p_male,3) m on m.ancestor_id=f.ancestor_id),'[]'::jsonb), 'is_parent', (select sire_id=p_male or dam_id=p_male from animals where id=p_female) or (select sire_id=p_female or dam_id=p_female from animals where id=p_male)) $$;
grant execute on function pedigree(text,int), descendants(text,int), inbreeding_risk(text,text) to app_user;
-- sire từ mã tinh: detail.semen_lot ↔ animals.sire_code; khi ghi PHOI có semen_lot → cập nhật con đẻ sau
create or replace function itran_set_sire() returns trigger language plpgsql as $$
begin if new.event_type='DE' and new.animal_id is not null then
  update animals set sire_code = coalesce(sire_code, (select e.detail->>'semen_lot' from animal_events e where e.animal_id=new.animal_id and e.event_type='PHOI' and e.status='ACTIVE' and e.ts < new.ts order by e.ts desc limit 1)) where dam_id=new.animal_id and birth_date >= new.ts::date - 3;
end if; return new; end $$;
drop trigger if exists ae_set_sire on animal_events; create trigger ae_set_sire after insert on animal_events for each row execute function itran_set_sire();
-- ===== Cảnh báo dịch tễ theo VÙNG: bệnh/chết 7 ngày so với 8 tuần trước, gộp các trại cùng region =====
create or replace view v_epi_region as
with f as (select id as farm_id, region_id from farms),
ev as (select a.farm_id, e.ts, e.event_type, coalesce(e.detail->>'disease', e.detail->>'note') as disease from animal_events e join animals a on a.id=e.animal_id where e.status='ACTIVE' and e.event_type in ('BENH','CHET','DIEU_TRI') and e.ts > now() - interval '63 days')
select f.region_id, f.farm_id,
  count(*) filter (where ev.event_type in ('BENH','DIEU_TRI') and ev.ts > now() - interval '7 days') as sick_7d,
  count(*) filter (where ev.event_type='CHET' and ev.ts > now() - interval '7 days') as dead_7d,
  round(count(*) filter (where ev.event_type in ('BENH','DIEU_TRI') and ev.ts <= now() - interval '7 days')/8.0,1) as sick_base_wk,
  round(count(*) filter (where ev.event_type='CHET' and ev.ts <= now() - interval '7 days')/8.0,1) as dead_base_wk,
  (select count(*) from animals x where x.farm_id=f.farm_id and x.status not in ('CHET','XUAT','LOAI')) as head
from f left join ev on ev.farm_id=f.farm_id group by 1,2;
create or replace view v_epi_region_sum as
select region_id, sum(sick_7d) as sick_7d, sum(dead_7d) as dead_7d, sum(sick_base_wk) as sick_base_wk, sum(dead_base_wk) as dead_base_wk, sum(head) as head, count(*) as farms,
  case when sum(dead_7d) >= 3 and sum(dead_7d) > 2*greatest(sum(dead_base_wk),0.5) then 'DO' when sum(sick_7d) >= 5 and sum(sick_7d) > 2*greatest(sum(sick_base_wk),1) then 'CAM' when sum(sick_7d) > 1.5*greatest(sum(sick_base_wk),1) then 'VANG' else 'XANH' end as level
from v_epi_region group by 1;
grant select on v_epi_region, v_epi_region_sum to app_user;
insert into alert_rules(code,version,farm_id,name,source,expr,level,recipients,channels,description) values ('AL-EPI-REGION',1,'GLOBAL','Dịch tễ vùng: bệnh/chết tăng bất thường (7 ngày vs 8 tuần)','custom','{"type":"epi_region"}','DO','{tech_head,director,owner}','{app,zalo,sms}','Gộp các trại cùng vùng; ĐỎ khi chết ≥3 & gấp đôi nền; CAM khi bệnh ≥5 & gấp đôi nền') on conflict do nothing;
