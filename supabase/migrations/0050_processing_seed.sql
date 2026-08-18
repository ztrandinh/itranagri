-- 0050 · sửa trạng thái đơn trong mrp_run (NHAP/CHOT/GIAO) + seed BOM/nhãn/bao bì mẫu cho SKU-TMR-25 & SKU-TRUNG-10 (F01)
create or replace function mrp_run(p_farm text, p_days int default 14) returns table(component_sku text, component_name text, unit text, req_qty numeric, available numeric, shortage numeric, is_packaging bool, sources text) language sql stable as $$
  with demand as (
    select sku, sum(qty_plan - coalesce(qty_done,0)) as qty, 'KHSX' as src from production_plans where farm_id=p_farm and status in ('KE_HOACH','DANG_SX') and week_start <= current_date + p_days group by sku
    union all
    select (l->>'sku'), sum((l->>'qty')::numeric), 'DON' from orders o, jsonb_array_elements(o.lines) l where o.farm_id=p_farm and o.status='CHOT' and coalesce(o.deliver_date, current_date) <= current_date + p_days group by 1
    union all
    select sku, sum(qty), 'LSX' from production_orders where farm_id=p_farm and status in ('MO','DANG_SX') group by sku),
  req as (select e.component_sku, e.unit, sum(e.req_qty) as req_qty, bool_or(e.is_packaging) as is_packaging, string_agg(distinct d.src, ',') as sources from demand d, lateral mrp_explode(p_farm, d.sku, d.qty) e group by e.component_sku, e.unit),
  st as (select sku, sum(available) as available from v_stock_available where farm_id=p_farm group by sku)
  select r.component_sku, p.name, r.unit, round(r.req_qty,2), round(coalesce(st.available,0),2), round(greatest(r.req_qty - coalesce(st.available,0), 0),2), r.is_packaging, r.sources
  from req r join products p on p.sku=r.component_sku left join st on st.sku=r.component_sku order by greatest(r.req_qty - coalesce(st.available,0), 0) desc $$;
-- BOM 2 cấp: SKU-TMR-25 (bao 25kg) = 25 kg TA-TMR-VO + 1 bao PP + 1 tem;  TA-TMR-VO (100 kg) = bắp ủ 45 + rơm 15 + bã bia 25 + cỏ 8 + rỉ mật 4 + khoáng 3
insert into bom_headers(id, farm_id, sku, version, name, batch_size, unit, yield_pct, line, status, approved_by, approved_at) values
 ('BOM-TMR-25-1','F01','SKU-TMR-25',1,'Đóng bao TMR 25kg',1,'bao',100,'DONG_GOI','BAN_HANH','NS-001',now()),
 ('BOM-TA-TMR-VO-1','F01','TA-TMR-VO',1,'Trộn TMR pha vỗ béo (mẻ 100 kg)',100,'kg',98,'D5_TMR','BAN_HANH','NS-001',now()),
 ('BOM-TRUNG-10-1','F01','SKU-TRUNG-10',1,'Vỉ trứng 10 + tem',1,'vi',100,'DONG_GOI','BAN_HANH','NS-001',now())
on conflict do nothing;
insert into bom_lines(id, bom_id, component_sku, qty, unit, scrap_pct, is_packaging, stage, seq) values
 ('BL-1','BOM-TMR-25-1','TA-TMR-VO',25,'kg',0.5,false,'CAN',1),('BL-2','BOM-TMR-25-1','BB-BAO-25',1,'cai',1,true,'DONG',2),('BL-3','BOM-TMR-25-1','BB-TEM',1,'cai',2,true,'DAN_TEM',3),
 ('BL-4','BOM-TA-TMR-VO-1','NL-BAP-U',45,'kg',0,false,'THO',1),('BL-5','BOM-TA-TMR-VO-1','NL-ROM',15,'kg',0,false,'THO',2),('BL-6','BOM-TA-TMR-VO-1','NL-BA-BIA',25,'kg',0,false,'THO',3),('BL-7','BOM-TA-TMR-VO-1','NL-CO-TUOI',8,'kg',0,false,'THO',4),('BL-8','BOM-TA-TMR-VO-1','NL-RI-MAT',4,'kg',0,false,'TINH',5),('BL-9','BOM-TA-TMR-VO-1','NL-KHOANG',3,'kg',0,false,'TINH',6),
 ('BL-10','BOM-TRUNG-10-1','BB-TEM',1,'cai',2,true,'DAN_TEM',2)
on conflict do nothing;
insert into packaging_specs(id, sku, level, material, packaging_sku, dims_mm, net_weight_g, gross_weight_g, units_per_pack, packs_per_case, cases_per_pallet, gtin, recyclable, recycle_code, shelf_life_days, storage_temp) values
 ('PK-TMR-25-1','SKU-TMR-25','SO_CAP','Bao PP dệt tráng, lót PE','BB-BAO-25','600×400×150',25000,25150,1,1,40,null,true,'PP-05',90,'Khô mát, tránh nắng'),
 ('PK-TMR-25-3','SKU-TMR-25','VAN_CHUYEN','Pallet gỗ 1000×1200 + màng co',null,'1000×1200×1500',null,1030000,1,40,1,null,true,null,null,null),
 ('PK-TRUNG-1','SKU-TRUNG-10','SO_CAP','Vỉ giấy bột 10 quả + màng co',null,'250×110×70',600,660,10,1,null,null,true,'PAP-21',21,'≤ 25°C, tránh nắng; lạnh 4°C giữ 30 ngày'),
 ('PK-TRUNG-2','SKU-TRUNG-10','THU_CAP','Thùng carton 3 lớp 12 vỉ',null,'380×260×250',7200,7900,12,1,48,null,true,'PAP-20',null,null)
on conflict do nothing;
insert into label_specs(id, sku, version, market, lang, product_name, ingredients, allergens, may_contain, net_content, nutrition, storage, usage_instr, origin, hotline, claims, std_marks, halal, organic, template, shelf_life_days, status, approved_by, approved_at) values
 ('LB-TMR-25-VN-1','SKU-TMR-25',1,'VN','vi','ITRAN TMR ủ chua cho bò thịt (pha vỗ béo)','Bắp sinh khối ủ chua 45%, bã bia 25%, rơm 15%, cỏ tươi 8%, rỉ mật 4%, premix khoáng 3%','{}','{}','25 kg','{"per":"kg VCK","dm_pct":45,"cp_pct":13.5,"me_mcal":2.55,"ndf_pct":42}','Nơi khô mát; đã mở bao dùng trong 24h','Cho ăn 2 cữ 05h30/15h00 theo phiếu cân; không trộn thêm urê','Việt Nam','1900-ITRAN','{Không kháng sinh,Không GMO trong khẩu phần}','{VIETGAP-CN,ICFS}',false,false,'A6',90,'DUYET','NS-001',now()),
 ('LB-TRUNG-10-VN-1','SKU-TRUNG-10',1,'VN','vi','Trứng gà thảo dược ITRAN (vỉ 10)','Trứng gà tươi 100% (gà nuôi thức ăn thảo dược, không kháng sinh)','{EGG}','{}','10 quả (≥ 500 g)','{"per":"100g","energy_kcal":155,"protein_g":12.6,"fat_g":10.6,"sat_fat_g":3.3,"carb_g":1.1,"sugar_g":1.1,"sodium_mg":124}','Bảo quản ≤ 25°C tránh nắng; ngăn mát 4°C tốt nhất','Nấu chín kỹ trước khi dùng','Việt Nam','1900-ITRAN','{Không kháng sinh,Gà chuồng thoáng phúc lợi,Rửa anolyte}','{VIETGAP-CN,ICFS}',true,false,'A7',21,'DUYET','NS-001',now())
on conflict do nothing;
