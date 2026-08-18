-- 0008 · sửa view tỷ lệ đẻ (quy đổi vỉ→quả theo unit2_factor), thêm view rollup ngày cho analytics nhanh
create or replace view v_kpi_lay_rate as
select m.farm_id, date_trunc('day', m.ts)::date as day, sum(m.qty*coalesce(p.unit2_factor,1)) as eggs,
  (select sum(head_count) from animal_groups g where g.farm_id=m.farm_id and g.kind='GA_DE' and g.status='ACTIVE') as hens,
  round(100.0*sum(m.qty*coalesce(p.unit2_factor,1))/nullif((select sum(head_count) from animal_groups g where g.farm_id=m.farm_id and g.kind='GA_DE' and g.status='ACTIVE'),0),1) as lay_pct
from inventory_moves m join products p on p.sku=m.sku where m.status='ACTIVE' and m.direction=1 and m.reason='NHAP_SX' and p.sku like 'SKU-TRUNG%' group by m.farm_id, date_trunc('day', m.ts);
-- RC6 dùng unit2_factor thay vì ×10 cứng
update rc_rules set side_b_sql='select coalesce(sum(m.qty*coalesce(p.unit2_factor,1)),0) from inventory_moves m join products p on p.sku=m.sku where m.farm_id=$1 and m.status=''ACTIVE'' and m.direction=1 and p.sku like ''SKU-TRUNG%'' and m.ts::date=$2' where code='RC6';
grant select on v_kpi_lay_rate to app_user;
