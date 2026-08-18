-- 0015 · cc_of_move: nhận diện đích theo mã khu (GA/RAS/BO) khi from_to không phải group id
create or replace function cc_of_move(p_farm text, p_reason text, p_from_to text, p_sku text) returns text language sql stable as $$
  select coalesce(
    (select cost_center from animal_groups g where g.farm_id=p_farm and g.id=p_from_to),
    case when upper(coalesce(p_from_to,'')) like 'GA%' then 'CC-GA' when upper(coalesce(p_from_to,'')) like 'RAS%' then 'CC-RAS' when upper(coalesce(p_from_to,'')) like '%NAI%' or upper(coalesce(p_from_to,'')) like '%VO%' then 'CC-BO'
         when p_reason='XUAT_SX' and p_from_to in ('D5','KHU-D') then 'CC-D5' when p_reason='XUAT_SX' and p_from_to like '%-TB-%' then 'CC-TT' end,
    (select cost_center from products p where p.sku=p_sku), 'CC-HC') $$;
