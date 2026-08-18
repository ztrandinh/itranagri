-- 0063 · quyền delete plan_lines cho publish lại; plan_feed_demand chấp nhận '' = null
grant delete on plan_lines to app_user;

create or replace function plan_feed_demand(p_farm text, p_scenario text default null) returns table(class_code text, class_name text, head numeric, kg_per_head_day numeric, kg_per_day numeric, days int, kg_period numeric, recipe_id text) language plpgsql stable as $$
declare sc record; v_days int := 180; v_safe numeric := 10; v_has_herd bool := false; begin
  if p_scenario is not null then select * into sc from plan_scenarios where id=p_scenario; if found then v_days := coalesce(sc.horizon_days,180); v_safe := coalesce(sc.safety_pct,10); v_has_herd := sc.herd is not null; end if; end if;
  return query
  with h as (
    select (e->>'class_code') as cc, (e->>'head')::numeric as n from plan_scenarios s, jsonb_array_elements(s.herd) e where p_scenario is not null and s.id=p_scenario and s.herd is not null
    union all
    select hb.class_code, hb.head from herd_by_class(p_farm) hb where not v_has_herd)
  select h.cc, c.name, h.n,
    coalesce((select n1.value from norms n1 where n1.kind=coalesce(c.feed_norm_key,'TA_KG_CON_NGAY') and n1.subject in (h.cc, c.species_code) and (n1.farm_id=p_farm or n1.farm_id is null) order by (n1.subject=h.cc) desc, (n1.farm_id=p_farm) desc nulls last limit 1),0) as kph,
    h.n * coalesce((select n1.value from norms n1 where n1.kind=coalesce(c.feed_norm_key,'TA_KG_CON_NGAY') and n1.subject in (h.cc, c.species_code) and (n1.farm_id=p_farm or n1.farm_id is null) order by (n1.subject=h.cc) desc, (n1.farm_id=p_farm) desc nulls last limit 1),0),
    v_days,
    h.n * coalesce((select n1.value from norms n1 where n1.kind=coalesce(c.feed_norm_key,'TA_KG_CON_NGAY') and n1.subject in (h.cc, c.species_code) and (n1.farm_id=p_farm or n1.farm_id is null) order by (n1.subject=h.cc) desc, (n1.farm_id=p_farm) desc nulls last limit 1),0) * v_days * (1 + v_safe/100),
    cr.recipe_id
  from h left join animal_classes c on c.code=h.cc left join class_recipes cr on cr.class_code=h.cc where h.n>0; end $$;

create or replace function plan_supply(p_farm text, p_scenario text default null) returns table(
  sku text, sku_name text, source text, crop_code text, crop_name text, demand_kg numeric, per_day_kg numeric, stock_kg numeric, po_kg numeric, harvest_expected_kg numeric, shortage_kg numeric,
  ha_needed numeric, ha_current numeric, ha_gap numeric, yield_kg_ha_period numeric, lead_days int, dept text, action text) language plpgsql stable as $$
declare days int := 180; sc record; begin
  if p_scenario is not null then select * into sc from plan_scenarios where id=p_scenario; if found then days := coalesce(sc.horizon_days, 180); end if; end if;
  return query
  with fd as (select * from plan_feed_demand(p_farm, p_scenario)),
  need as (select (c->>'sku') as sku, sum(fd.kg_period * (c->>'pct')::numeric/100) as kg, sum(fd.kg_per_day * (c->>'pct')::numeric/100) as kgd from fd join recipes r on r.id=fd.recipe_id, jsonb_array_elements(r.components) c group by 1),
  st as (select a.sku, sum(a.available) as kg from v_stock_available a where a.farm_id=p_farm group by a.sku),
  po as (select (l->>'sku') as sku, sum((l->>'qty')::numeric) as kg from purchase_orders p, jsonb_array_elements(p.lines) l where p.farm_id=p_farm and p.po_status in ('DUYET','NHAN') and p.received_at is null group by 1),
  hv as (select m.sku, sum(greatest(coalesce(cs.target_yield_kg,0) - coalesce(cs.actual_yield_kg,0),0) / coalesce(m.fresh_per_sku,1)) as kg from crop_seasons cs join sku_crop_map m on (m.crop_code=cs.crop_code or cs.crop_code = any(m.alt_crops)) where cs.farm_id=p_farm and cs.status in ('DANG_TRONG','THU_HOACH') group by m.sku),
  land as (select m.sku, sum(p.area_ha) as ha from plots p join sku_crop_map m on (m.crop_code=p.crop_code or p.crop_code = any(m.alt_crops)) where p.farm_id=p_farm and p.active group by m.sku)
  select n.sku, pr.name, coalesce(m.source,'MUA'), m.crop_code, cr.name, round(n.kg), round(n.kgd,1), round(coalesce(st.kg,0)), round(coalesce(po.kg,0)), round(coalesce(hv.kg,0)),
    round(greatest(n.kg - coalesce(st.kg,0) - coalesce(po.kg,0) - coalesce(hv.kg,0), 0)) as short,
    case when cr.yield_norm_kg_ha>0 then round((n.kg * coalesce(m.fresh_per_sku,1)) / (cr.yield_norm_kg_ha * greatest(coalesce(cr.cuts_per_year,1),1) * days/365.0), 2) end as ha_needed,
    coalesce(land.ha,0), case when cr.yield_norm_kg_ha>0 then round((n.kg * coalesce(m.fresh_per_sku,1)) / (cr.yield_norm_kg_ha * greatest(coalesce(cr.cuts_per_year,1),1) * days/365.0) - coalesce(land.ha,0), 2) end,
    case when cr.yield_norm_kg_ha>0 then round(cr.yield_norm_kg_ha * greatest(coalesce(cr.cuts_per_year,1),1) * days/365.0) end, m.lead_days,
    case when coalesce(m.source,'MUA') in ('TRONG') then 'TT' when coalesce(m.source,'MUA')='CA_HAI' then 'TT+CCU' else 'CCU' end,
    case when greatest(n.kg - coalesce(st.kg,0) - coalesce(po.kg,0) - coalesce(hv.kg,0), 0) = 0 then 'ĐỦ'
         when coalesce(m.source,'MUA')='TRONG' then 'TRỒNG THÊM '||coalesce(round(greatest((n.kg * coalesce(m.fresh_per_sku,1)) / nullif(cr.yield_norm_kg_ha * greatest(coalesce(cr.cuts_per_year,1),1) * days/365.0,0) - coalesce(land.ha,0),0),2)::text,'?')||' ha '||coalesce(cr.name,'')||' (lead '||coalesce(m.lead_days,0)||' ngày) + mua bù ngắn hạn'
         when coalesce(m.source,'MUA')='CA_HAI' then 'MUA '||round(greatest(n.kg - coalesce(st.kg,0) - coalesce(po.kg,0) - coalesce(hv.kg,0), 0))||' kg + gom phụ phẩm ruộng'
         else 'MUA '||round(greatest(n.kg - coalesce(st.kg,0) - coalesce(po.kg,0) - coalesce(hv.kg,0), 0))||' kg (PO, lead '||coalesce(m.lead_days,0)||' ngày)' end
  from need n join products pr on pr.sku=n.sku left join sku_crop_map m on m.sku=n.sku left join crops cr on cr.code=m.crop_code left join st on st.sku=n.sku left join po on po.sku=n.sku left join hv on hv.sku=n.sku left join land on land.sku=n.sku
  order by short desc; end $$;

create or replace function publish_plan(p_scenario text) returns int language plpgsql as $$
declare sc record; r record; n int := 0; feed_day numeric; begin
  select * into sc from plan_scenarios where id=p_scenario; if not found then raise exception 'ERR_NOT_FOUND'; end if;
  delete from plan_lines where scenario_id=p_scenario;
  for r in select * from plan_supply(sc.farm_id, p_scenario) loop
    insert into plan_lines(scenario_id, farm_id, sku, sku_name, source, crop_code, demand_kg, per_day_kg, stock_kg, po_kg, harvest_expected_kg, shortage_kg, ha_needed, ha_current, ha_gap, dept, action)
    values (p_scenario, sc.farm_id, r.sku, r.sku_name, r.source, r.crop_code, r.demand_kg, r.per_day_kg, r.stock_kg, r.po_kg, r.harvest_expected_kg, r.shortage_kg, r.ha_needed, r.ha_current, r.ha_gap, r.dept, r.action);
    if r.shortage_kg > 0 then
      if r.source='TRONG' and coalesce(r.ha_gap,0) > 0 then
        insert into tasks(id, farm_id, kind, title, detail, due_at, role_hint, target_type, target_id, status, source, priority)
        values (gen_random_uuid(), sc.farm_id, 'KE_HOACH_TRONG', 'KH '||sc.name||': trồng thêm '||r.ha_gap||' ha '||coalesce(r.crop_code,'')||' cho '||r.sku_name, jsonb_build_object('text', r.action||' — nhu cầu '||r.demand_kg||' kg/'||sc.horizon_days||' ngày, thiếu '||r.shortage_kg||' kg', 'scenario_id', p_scenario, 'sku', r.sku, 'ha_gap', r.ha_gap, 'shortage_kg', r.shortage_kg), now()+interval '7 days', 'tech_head', 'sku', r.sku, 'MO', 'PLAN', 'CAO'); n := n+1;
      end if;
      if r.source in ('MUA','CA_HAI') or (r.source='TRONG' and r.lead_days > 30) then
        insert into tasks(id, farm_id, kind, title, detail, due_at, role_hint, target_type, target_id, status, source, priority)
        values (gen_random_uuid(), sc.farm_id, 'KE_HOACH_MUA', 'KH '||sc.name||': mua bù '||r.shortage_kg||' kg '||r.sku_name, jsonb_build_object('text', r.action||' — tồn '||r.stock_kg||', PO về '||r.po_kg||', thu hoạch DK '||r.harvest_expected_kg, 'scenario_id', p_scenario, 'sku', r.sku, 'shortage_kg', r.shortage_kg), now()+interval '5 days', 'accountant', 'sku', r.sku, 'MO', 'PLAN', 'CAO'); n := n+1;
      end if;
    end if;
  end loop;
  -- D5: kế hoạch sản xuất TMR/viên theo ngày (kg/ngày × 7) cho tuần tới
  for r in select fd.recipe_id, sum(fd.kg_per_day) as kgd from plan_feed_demand(sc.farm_id, p_scenario) fd where fd.recipe_id is not null group by fd.recipe_id loop
    insert into tasks(id, farm_id, kind, title, detail, due_at, role_hint, target_type, target_id, status, source, priority)
    values (gen_random_uuid(), sc.farm_id, 'KE_HOACH_SX', 'KH '||sc.name||': D5 sản xuất '||round(r.kgd)||' kg/ngày công thức '||r.recipe_id, jsonb_build_object('text', 'Tuần tới '||round(r.kgd*7)||' kg; kiểm hào ủ/nguyên liệu theo MRP', 'scenario_id', p_scenario, 'recipe_id', r.recipe_id, 'kg_per_day', round(r.kgd)), now()+interval '2 days', 'team_lead', 'recipe', r.recipe_id, 'MO', 'PLAN', 'CAO'); n := n+1;
  end loop;
  update plan_scenarios set status='BAN_HANH', published_at=now(), published_by=app_staff() where id=p_scenario;
  perform publish_event(sc.farm_id, 'plan.published', jsonb_build_object('scenario_id', p_scenario, 'name', sc.name, 'horizon_days', sc.horizon_days, 'tasks', n));
  return n; end $$;

