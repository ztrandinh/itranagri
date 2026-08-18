-- 0067 · herd_forecast: tránh trùng tên cột với biến trả về (plpgsql)
create or replace function herd_forecast(p_farm text, p_days int) returns table(class_code text, class_name text, head_now numeric, head_forecast numeric, births numeric, exits numeric) language plpgsql stable as $$
declare v_fat_days int := coalesce((select (value#>>'{}')::int from settings where key='fattening.days' and (farm_id=p_farm or farm_id is null) order by (farm_id=p_farm) desc limit 1), 90); begin
  return query
  with base as (select a.id, a.species, a.sex, a.birth_date, a.class_code as cls, a.created_at::date as in_date from animals a where a.farm_id=p_farm and a.status not in ('CHET','LOAI','XUAT','DA_BAN')),
  fut as (select b.id,
             case when b.species='BO' and b.birth_date is not null and (b.cls is null or b.cls in ('BO-BE','BO-TO')) then case when (current_date + p_days) - b.birth_date <= 180 then 'BO-BE' when (current_date + p_days) - b.birth_date <= 540 then 'BO-TO' when b.sex='M' then 'BO-VO-BEO' else 'BO-CAI-SS' end
                  else derive_class(b.species, b.sex, b.birth_date, b.cls) end as cc_fut,
             (derive_class(b.species, b.sex, b.birth_date, b.cls)='BO-VO-BEO' and (current_date + p_days) - b.in_date >= v_fat_days) as will_exit
          from base b),
  preg as (select e.animal_id, max(e.ts)::date + 283 as due from animal_events e join base b on b.id=e.animal_id where e.farm_id=p_farm and e.status='ACTIVE' and ((e.event_type='KHAM_THAI' and coalesce(e.detail->>'result','+') in ('+','CO','DUONG')) or e.event_type='PHOI')
            and not exists (select 1 from animal_events d where d.animal_id=e.animal_id and d.event_type='DE' and d.ts>e.ts) group by e.animal_id),
  births_c as (select count(*)::numeric as nb from preg where due between current_date and current_date + p_days),
  now_c as (select h.class_code as cc, h.class_name as cn, h.head as hn from herd_by_class(p_farm) h),
  fut_c as (select f.cc_fut as cc, count(*) filter (where not f.will_exit)::numeric as nf, count(*) filter (where f.will_exit)::numeric as ex from fut f group by f.cc_fut),
  grp as (select h.class_code as cc, h.head as hg from herd_by_class(p_farm) h where h.class_code not like 'BO-%' and h.class_code not like 'DE-%')
  select coalesce(n.cc, f.cc), coalesce(n.cn, c.name), coalesce(n.hn,0),
    coalesce(f.nf, g.hg, 0) + case when coalesce(n.cc, f.cc)='BO-BE' then (select nb from births_c) else 0 end,
    case when coalesce(n.cc, f.cc)='BO-BE' then (select nb from births_c) else 0 end, coalesce(f.ex,0)
  from now_c n full join fut_c f on f.cc=n.cc left join grp g on g.cc=coalesce(n.cc, f.cc) left join animal_classes c on c.code=coalesce(n.cc, f.cc)
  where coalesce(n.hn,0)>0 or coalesce(f.nf,0)>0 or coalesce(f.ex,0)>0 order by 1; end $$;
