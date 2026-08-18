-- 0069 · NHÓM DỰ TRỮ (danh mục chuyên nghiệp): mỗi mặt hàng thuộc 1 nhóm dự trữ; người dùng CHỌN mặt hàng nào theo dõi dự trữ (products.reserve);
--        dashboard hiện thẻ theo nhóm (tổng tồn, ngày còn min, cần bổ sung) + danh sách chọn cho từng nhóm; mặt hàng chọn theo dõi hiện cả khi tồn = 0
create table if not exists stock_groups(code text primary key, name text not null, block text not null check (block in ('DAU_VAO','DAU_RA','CONG_CU')), kind_default text, unit_default text default 'kg', examples text, position int default 100, icon text);
grant select, insert, update on stock_groups to app_user;
insert into stock_groups(code, name, block, kind_default, unit_default, examples, position, icon) values
 ('THO_XANH','Thức ăn thô xanh (cắt tươi)','DAU_VAO','BAN_TP','kg','cỏ Mombasa/VA06/Ruzi cắt tươi, thân bắp tươi, lá chuối, cây họ đậu',10,'🌿'),
 ('U_CHUA','Thức ăn ủ chua / dự trữ thô','DAU_VAO','BAN_TP','kg','bắp sinh khối ủ chua, cỏ ủ, cao lương ủ, rơm ủ urê',11,'🫙'),
 ('PHU_PHAM','Phụ phẩm & khô','DAU_VAO','NGUYEN_LIEU','kg','rơm rạ, bã bia, bã đậu nành, bã mía, vỏ khoai mì, cám gạo, thân lá sau thu',12,'🌾'),
 ('TINH_BOT','Thức ăn tinh / củ hạt','DAU_VAO','NGUYEN_LIEU','kg','ngô hạt, khoai mì lát, khoai lang, cám ngô, tấm, đậu nành, khô dầu',13,'🌽'),
 ('KHOANG_PHU_GIA','Khoáng – phụ gia – rỉ mật','DAU_VAO','NGUYEN_LIEU','kg','premix khoáng, muối, đá liếm, rỉ mật, urê, men vi sinh, enzyme',14,'🧂'),
 ('TA_THANH_PHAM','Thức ăn thành phẩm/viên (D5)','DAU_VAO','BAN_TP','kg','TMR trộn sẵn, viên gà đẻ, viên gà thịt, viên cá/lươn',15,'🥣'),
 ('GIONG_CAY','Giống cây trồng','DAU_VAO','GIONG','kg','hạt bắp sinh khối, hom cỏ, giống lúa, hom mì, giống rau, meo nấm',20,'🌱'),
 ('GIONG_VAT','Giống vật nuôi / tinh','DAU_VAO','GIONG','lieu','tinh bò Brahman/BBB, gà con 1 ngày, lươn/cá giống, dê giống',21,'🐣'),
 ('PHAN_BON','Phân bón – vôi – cải tạo đất','DAU_VAO','PHAN_BON','kg','phân trùn tự có, phân chuồng ủ, NPK, vôi, biochar, đạm cá',30,'🪴'),
 ('BVTV','Thuốc BVTV – sinh học','DAU_VAO','VAT_TU','lit','chế phẩm Bt, nấm xanh, dầu neem, bẫy pheromone, thuốc hóa học cục bộ',31,'🧴'),
 ('THU_Y','Thuốc thú y – vaccine – sát trùng','DAU_VAO','THUOC','lo','kháng sinh, tẩy KST, vaccine LMLM/THT/Newcastle, iodine, anolyte, vôi bột',32,'💉'),
 ('NHIEN_LIEU','Nhiên liệu – năng lượng','DAU_VAO','NHIEN_LIEU','l','dầu diesel, xăng, gas, nhớt, than củi',40,'⛽'),
 ('BAO_BI','Bao bì – tem – vật tư đóng gói','DAU_VAO','BAO_BI','cai','bao PP 25kg, vỉ trứng, thùng carton, tem QR, màng co, túi hút chân không',41,'📦'),
 ('VAT_TU_KHAC','Vật tư tiêu hao khác','DAU_VAO','VAT_TU','cai','dây, lưới, bạt ủ, ống tưới, găng tay, khẩu trang',42,'🧰'),
 ('SP_CHAN_NUOI','Sản phẩm chăn nuôi','DAU_RA','THANH_PHAM','kg','bò hơi, dê hơi, gà thịt, trứng, lươn/cá thương phẩm, sữa',50,'🥩'),
 ('SP_TRONG_TROT','Sản phẩm trồng trọt','DAU_RA','THANH_PHAM','kg','rau, nấm, trái cây, lúa gạo, bắp hạt, khoai',51,'🥬'),
 ('SP_CHE_BIEN','Sản phẩm chế biến – đóng gói','DAU_RA','THANH_PHAM','cai','trứng vỉ 10, thịt sơ chế hút chân không, sấy, TMR bao 25kg bán ra',52,'🏷'),
 ('SP_SINH_HOC','Sản phẩm sinh học (khu D)','DAU_RA','THANH_PHAM','kg','phân trùn, trùn tươi, BSF ấu trùng, compost, biochar, giấm gỗ, điện biogas',53,'♻'),
 ('CONG_CU','Công cụ – dụng cụ','CONG_CU','CONG_CU','cai','cuốc, xẻng, búa, kìm, bình phun, xe rùa, cân, bảo hộ',90,'🔧')
on conflict (code) do update set name=excluded.name, examples=excluded.examples;
alter table products add column if not exists stock_group text references stock_groups;
alter table products add column if not exists reserve bool default false;
update products set stock_group = case
  when kind='CONG_CU' then 'CONG_CU'
  when sku in ('NL-CO-TUOI') then 'THO_XANH' when sku in ('NL-BAP-U') then 'U_CHUA' when sku in ('NL-ROM','NL-BA-BIA') then 'PHU_PHAM' when sku in ('NL-KHOANG','NL-RI-MAT') then 'KHOANG_PHU_GIA'
  when sku in ('TA-TMR-VO','TA-VIEN-GA') then 'TA_THANH_PHAM' when kind='GIONG' then 'GIONG_VAT' when kind in ('THUOC','VACCINE') then 'THU_Y' when kind='NHIEN_LIEU' then 'NHIEN_LIEU' when kind='BAO_BI' then 'BAO_BI'
  when sku in ('SKU-BO-HOI','SKU-TRUNG-10') then 'SP_CHAN_NUOI' when sku in ('SKU-NAM-1') then 'SP_TRONG_TROT' when sku in ('SKU-PTR-25') then 'SP_SINH_HOC' when sku in ('SKU-TMR-25') then 'SP_CHE_BIEN'
  when kind='THANH_PHAM' then 'SP_CHE_BIEN' when kind='NGUYEN_LIEU' then 'PHU_PHAM' else stock_group end where stock_group is null;
update products set reserve = true where kind not in ('DICH_VU','CONG_CU') and stock_group is not null;
-- Danh mục mặt hàng dự trữ phổ biến để người dùng tick chọn (chưa theo dõi: reserve=false)
insert into products(sku, org_id, name, kind, unit, stock_group, reserve, active, shelf_life_days) select v.sku, 'ITRAN', v.name, g.kind_default, v.unit, v.grp, false, true, v.sl from (values
 ('NL-CO-U','Cỏ ủ chua (hào/túi)','kg','U_CHUA',180),('NL-CAO-LUONG-U','Cao lương ngọt ủ chua','kg','U_CHUA',180),('NL-ROM-URE','Rơm ủ urê','kg','U_CHUA',60),('NL-CO-VA06','Cỏ VA06 cắt tươi','kg','THO_XANH',2),('NL-CO-RUZI','Cỏ Ruzi/Mulato cắt tươi','kg','THO_XANH',2),('NL-THAN-BAP','Thân lá bắp tươi','kg','THO_XANH',2),('NL-LA-CHUOI','Thân/lá chuối','kg','THO_XANH',2),
 ('NL-BA-DAU','Bã đậu nành','kg','PHU_PHAM',3),('NL-BA-MIA','Bã mía','kg','PHU_PHAM',30),('NL-VO-KHOAI-MI','Vỏ/bã khoai mì','kg','PHU_PHAM',7),('NL-CAM-GAO','Cám gạo','kg','PHU_PHAM',60),
 ('NL-NGO-HAT','Ngô hạt','kg','TINH_BOT',180),('NL-KHOAI-MI-LAT','Khoai mì lát khô','kg','TINH_BOT',180),('NL-KHOAI-LANG','Khoai lang củ','kg','TINH_BOT',30),('NL-CAM-NGO','Cám ngô','kg','TINH_BOT',60),('NL-DAU-NANH','Đậu nành hạt','kg','TINH_BOT',180),('NL-KHO-DAU','Khô dầu đậu nành','kg','TINH_BOT',120),('NL-TAM','Tấm gạo','kg','TINH_BOT',120),
 ('NL-MUOI','Muối ăn','kg','KHOANG_PHU_GIA',720),('NL-DA-LIEM','Đá liếm khoáng','cai','KHOANG_PHU_GIA',720),('NL-URE','Urê thức ăn','kg','KHOANG_PHU_GIA',365),('NL-MEN-VS','Men vi sinh/EM','lit','KHOANG_PHU_GIA',180),
 ('TA-VIEN-GA-THIT','Viên gà thịt','kg','TA_THANH_PHAM',60),('TA-VIEN-CA','Viên cá/lươn','kg','TA_THANH_PHAM',90),('TA-DE','Thức ăn hỗn hợp dê','kg','TA_THANH_PHAM',60),
 ('GI-BAP-SK','Hạt giống bắp sinh khối','kg','GIONG_CAY',365),('GI-HOM-CO','Hom cỏ giống','kg','GIONG_CAY',7),('GI-LUA','Giống lúa','kg','GIONG_CAY',180),('GI-HOM-MI','Hom khoai mì','bo','GIONG_CAY',14),('GI-RAU','Hạt giống rau','goi','GIONG_CAY',365),('GI-MEO-NAM','Meo nấm','bich','GIONG_CAY',30),
 ('GI-GA-CON','Gà con 1 ngày tuổi','con','GIONG_VAT',1),('GI-LUON','Lươn/cá giống','con','GIONG_VAT',1),('GI-DE','Dê giống','con','GIONG_VAT',1),('TINH-BBB','Tinh bò BBB','lieu','GIONG_VAT',3650),
 ('PB-NPK','Phân NPK','kg','PHAN_BON',720),('PB-VOI','Vôi bột','kg','PHAN_BON',720),('PB-HUU-CO','Phân hữu cơ ủ hoai','kg','PHAN_BON',180),('PB-BIOCHAR','Biochar','kg','PHAN_BON',3650),
 ('BVTV-BT','Chế phẩm Bt','lit','BVTV',365),('BVTV-NEEM','Dầu neem','lit','BVTV',365),('BVTV-NAM-XANH','Nấm xanh Metarhizium','kg','BVTV',180),('BVTV-PHEROMONE','Bẫy pheromone','cai','BVTV',180),
 ('VX-THT','Vaccine tụ huyết trùng','lo','THU_Y',365),('VX-NEWCASTLE','Vaccine Newcastle','lo','THU_Y',365),('TH-IVER','Ivermectin (tẩy KST)','lo','THU_Y',720),('TH-IODINE','Iodine sát trùng','lit','THU_Y',720),('TH-ANOLYTE','Anolyte (nước điện hóa)','lit','THU_Y',7),('TH-VOI-BOT','Vôi bột khử trùng','kg','THU_Y',720),
 ('NL-XANG','Xăng','l','NHIEN_LIEU',180),('NL-GAS','Gas','kg','NHIEN_LIEU',720),('NL-NHOT','Nhớt máy','l','NHIEN_LIEU',720),
 ('BB-VI-TRUNG','Vỉ trứng 10','cai','BAO_BI',3650),('BB-THUNG','Thùng carton','cai','BAO_BI',3650),('BB-TUI-HCK','Túi hút chân không','cai','BAO_BI',3650),('BB-MANG-CO','Màng co','cuon','BAO_BI',3650),
 ('VT-BAT-U','Bạt ủ chua','cai','VAT_TU_KHAC',720),('VT-DAY-LUOI','Dây, lưới','cuon','VAT_TU_KHAC',720),
 ('SKU-DE-HOI','Dê hơi','kg','SP_CHAN_NUOI',1),('SKU-GA-THIT','Gà thịt hơi','kg','SP_CHAN_NUOI',1),('SKU-LUON','Lươn thương phẩm','kg','SP_CHAN_NUOI',2),('SKU-SUA','Sữa tươi','l','SP_CHAN_NUOI',2),
 ('SKU-RAU','Rau ăn lá','kg','SP_TRONG_TROT',3),('SKU-LUA','Lúa (thóc)','kg','SP_TRONG_TROT',365),('SKU-BAP-HAT','Bắp hạt','kg','SP_TRONG_TROT',180),('SKU-KHOAI','Khoai lang/mì củ','kg','SP_TRONG_TROT',30),
 ('SKU-THIT-BO-HCK','Thịt bò sơ chế hút chân không','kg','SP_CHE_BIEN',7),('SKU-THIT-DE-HCK','Thịt dê sơ chế','kg','SP_CHE_BIEN',7),('SKU-TRUNG-30','Trứng vỉ 30','vi','SP_CHE_BIEN',21),('SKU-SAY','Sản phẩm sấy','kg','SP_CHE_BIEN',180),
 ('SKU-TRUN-TUOI','Trùn tươi','kg','SP_SINH_HOC',2),('SKU-BSF','Ấu trùng BSF','kg','SP_SINH_HOC',2),('SKU-COMPOST','Compost','kg','SP_SINH_HOC',365),('SKU-BIOCHAR','Biochar bán','kg','SP_SINH_HOC',3650),('SKU-GIAM-GO','Giấm gỗ','l','SP_SINH_HOC',720)
) v(sku,name,unit,grp,sl) join stock_groups g on g.code=v.grp where not exists (select 1 from products p where p.sku=v.sku);
-- Dashboard: nền = mặt hàng ĐƯỢC CHỌN theo dõi (reserve) × trại ∪ mặt hàng đang có tồn; kèm nhóm
drop view if exists v_stock_dashboard;
create view v_stock_dashboard as
with fx as (select id as farm_id from farms where status is distinct from 'DONG'),
bal as (select m.farm_id, w.block, m.sku, sum(m.direction*m.qty) as qty, max(m.ts) as last_move from inventory_moves m join warehouses w on w.id=m.warehouse_id where m.status='ACTIVE' and w.block in ('DAU_VAO','DAU_RA') group by 1,2,3),
items as (select fx.farm_id, g.block, p.sku from fx cross join products p join stock_groups g on g.code=p.stock_group where p.reserve and p.active and g.block in ('DAU_VAO','DAU_RA')
          union select farm_id, block, sku from bal),
use14 as (select m.farm_id, w.block, m.sku, sum(m.qty)/14.0 as per_day from inventory_moves m join warehouses w on w.id=m.warehouse_id where m.status='ACTIVE' and m.direction=-1 and m.ts>now()-interval '14 days' and w.block in ('DAU_VAO','DAU_RA') group by 1,2,3),
in14 as (select m.farm_id, w.block, m.sku, sum(m.qty)/14.0 as per_day from inventory_moves m join warehouses w on w.id=m.warehouse_id where m.status='ACTIVE' and m.direction=1 and m.ts>now()-interval '14 days' and w.block in ('DAU_VAO','DAU_RA') group by 1,2,3),
live0 as (select fx.farm_id, d.sku, d.kg_per_day from fx, lateral live_material_demand(fx.farm_id, 0) d),
live30 as (select fx.farm_id, d.sku, d.kg_per_day from fx, lateral live_material_demand(fx.farm_id, 30) d),
live90 as (select fx.farm_id, d.sku, d.kg_per_day from fx, lateral live_material_demand(fx.farm_id, 90) d),
po as (select p.farm_id, (l->>'sku') as sku, sum((l->>'qty')::numeric) as kg from purchase_orders p, jsonb_array_elements(p.lines) l where p.po_status in ('DUYET','NHAN') and p.received_at is null group by 1,2),
hv as (select cs.farm_id, m.sku, sum(greatest(coalesce(cs.target_yield_kg,0)-coalesce(cs.actual_yield_kg,0),0)/coalesce(m.fresh_per_sku,1)) as kg from crop_seasons cs join sku_crop_map m on (m.crop_code=cs.crop_code or cs.crop_code=any(m.alt_crops)) where cs.status in ('DANG_TRONG','THU_HOACH') group by 1,2),
pp as (select farm_id, sku, sum(qty_plan-coalesce(qty_done,0)) as qty from production_plans where status in ('KE_HOACH','DANG_SX') group by 1,2),
pol as (select farm_id, sku, max(max_qty) as max_qty, max(coalesce(rop_qty,min_qty)) as rop, max(lead_time_days) as lead from stock_policies where active group by 1,2),
demand as (select o.farm_id, (l->>'sku') as sku, sum((l->>'qty')::numeric) as qty from orders o, jsonb_array_elements(o.lines) l where o.status='CHOT' group by 1,2)
select it.farm_id, it.block, it.sku, p.name, p.kind, p.unit, p.stock_group, g.name as group_name, g.icon as group_icon, g.position as group_pos, p.reserve, round(coalesce(b.qty,0),1) as qty, b.last_move,
  pol.max_qty, case when pol.max_qty>0 then round(coalesce(b.qty,0)*100/pol.max_qty) end as pct_full,
  round(coalesce(l0.kg_per_day, u.per_day, 0),1) as use_per_day, round(coalesce(i.per_day,0),1) as in_per_day,
  round(coalesce(l30.kg_per_day, l0.kg_per_day, u.per_day, 0),1) as use_per_day_30, round(coalesce(l90.kg_per_day, l0.kg_per_day, u.per_day, 0),1) as use_per_day_90,
  case when l0.kg_per_day is not null then 'DAN_THAT' else 'TB_14_NGAY' end as demand_source,
  case when coalesce(l0.kg_per_day, u.per_day, 0)>0 then round(coalesce(b.qty,0)/coalesce(l0.kg_per_day, u.per_day),0) end as days_left,
  round(coalesce(po.kg,0)) as incoming_po, round(coalesce(hv.kg,0)) as incoming_harvest, round(coalesce(pp.qty,0)) as incoming_production, round(coalesce(demand.qty,0)) as committed_orders,
  round(coalesce(b.qty,0) + coalesce(po.kg,0) + coalesce(pp.qty,0) - coalesce(demand.qty,0) - (coalesce(l0.kg_per_day, u.per_day, 0)+coalesce(l30.kg_per_day, l0.kg_per_day, u.per_day, 0))/2*30) as proj_30,
  round(coalesce(b.qty,0) + coalesce(po.kg,0) + coalesce(hv.kg,0)*0.5 + coalesce(pp.qty,0) - coalesce(demand.qty,0) - (coalesce(l0.kg_per_day, u.per_day, 0)+coalesce(l90.kg_per_day, l0.kg_per_day, u.per_day, 0))/2*60) as proj_60,
  round(coalesce(b.qty,0) + coalesce(po.kg,0) + coalesce(hv.kg,0) + coalesce(pp.qty,0) - coalesce(demand.qty,0) - (coalesce(l0.kg_per_day, u.per_day, 0)+coalesce(l90.kg_per_day, l0.kg_per_day, u.per_day, 0))/2*90) as proj_90,
  round(greatest(coalesce(pol.max_qty, coalesce(l30.kg_per_day, l0.kg_per_day, u.per_day,0)*60) - (coalesce(b.qty,0) + coalesce(po.kg,0) + coalesce(hv.kg,0) - coalesce(l0.kg_per_day, u.per_day, 0)*coalesce(pol.lead,14)), 0)) as need_qty,
  pol.rop, pol.lead,
  case when coalesce(b.qty,0)<=0 and coalesce(l0.kg_per_day, u.per_day, 0)>0 then 'HET' when coalesce(b.qty,0)<=0 then 'TRONG' when pol.rop is not null and b.qty<=pol.rop then 'CHAM_ROP' when coalesce(l0.kg_per_day, u.per_day,0)>0 and b.qty/coalesce(l0.kg_per_day, u.per_day) < coalesce(pol.lead,14) then 'THIEU_SOM' when b.qty + coalesce(po.kg,0) - coalesce(l30.kg_per_day, l0.kg_per_day, u.per_day,0)*30 < 0 then 'AM_30_NGAY' else 'OK' end as flag
from items it join products p on p.sku=it.sku left join stock_groups g on g.code=p.stock_group left join bal b on b.farm_id=it.farm_id and b.block=it.block and b.sku=it.sku
left join use14 u on u.farm_id=it.farm_id and u.block=it.block and u.sku=it.sku left join in14 i on i.farm_id=it.farm_id and i.block=it.block and i.sku=it.sku
left join live0 l0 on l0.farm_id=it.farm_id and l0.sku=it.sku and it.block='DAU_VAO' left join live30 l30 on l30.farm_id=it.farm_id and l30.sku=it.sku and it.block='DAU_VAO' left join live90 l90 on l90.farm_id=it.farm_id and l90.sku=it.sku and it.block='DAU_VAO'
left join po on po.farm_id=it.farm_id and po.sku=it.sku left join hv on hv.farm_id=it.farm_id and hv.sku=it.sku left join pp on pp.farm_id=it.farm_id and pp.sku=it.sku
left join pol on pol.farm_id=it.farm_id and pol.sku=it.sku left join demand on demand.farm_id=it.farm_id and demand.sku=it.sku
where p.kind<>'CONG_CU';
grant select on v_stock_dashboard to app_user;
