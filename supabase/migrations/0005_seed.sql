-- fix: settings GLOBAL scope
alter table settings drop constraint if exists settings_farm_id_fkey;
alter table settings alter column farm_id set default 'GLOBAL';
drop policy if exists p_sel on settings; create policy p_sel on settings for select using (farm_id='GLOBAL' or can_see_farm(farm_id));
drop policy if exists p_ins on settings; create policy p_ins on settings for insert with check ((farm_id = app_farm() or (farm_id='GLOBAL' and app_role() in ('owner','it_engineer','director'))) and app_role() not in ('auditor','anon','worker'));
-- 0005 · SEED · ITRAN (org) · vùng · F01 (trại gốc) · F99 (sandbox) · nhân sự · danh mục · cấu hình
insert into orgs(id,name,brand) values ('ITRAN','Công ty ITRAN FARM','ITRAN FARM') on conflict do nothing;
insert into regions(id,org_id,name,provinces,params) values
 ('BAC-BAI-SONG','ITRAN','Đồng bằng Bắc – bãi sông','{"Hà Nội","Hưng Yên","Bắc Ninh"}','{"lich_vu":"bac","vaccine":["LMLM","THT","VDNC"],"lu_cap":[3.5,4.2,4.8],"gia_bo_hoi":85000}'),
 ('DBSCL','ITRAN','Đồng bằng sông Cửu Long','{"Đồng Tháp","An Giang"}','{"lich_vu":"nam","vaccine":["LMLM","THT","VDNC"],"gia_bo_hoi":82000}'),
 ('TRUNG-DU','ITRAN','Trung du miền núi phía Bắc','{"Phú Thọ","Hòa Bình"}','{"lich_vu":"bac","vaccine":["LMLM","THT","VDNC"]}')
on conflict do nothing;
insert into farms(id,org_id,region_id,legal_entity,kind,name,province,s_ha,k_factor,scale_band,modules) values
 ('F01','ITRAN','BAC-BAI-SONG','Công ty TNHH ITRAN F01','CAMPUS','ITRAN F01 — trại gốc bãi sông','Hưng Yên',30.7,23,'30-60ha','{"bo":true,"ga":true,"ras":true,"trun":true,"d5":true,"resort":false}'),
 ('F99','ITRAN','BAC-BAI-SONG',null,'SANDBOX','F99 — Sandbox thử nghiệm/đào tạo','—',12,25,'10-30ha','{"bo":true,"ga":true,"ras":true,"trun":true,"d5":true}')
on conflict do nothing;

-- Nhân sự (PIN mặc định 1234 — đổi ngay khi go-live)
insert into staff(id,org_id,farm_id,full_name,role,dept,position,phone,login,pin_hash,farm_ids) values
 ('NS-001','ITRAN',null,'Chủ đầu tư','owner','HQ','Chủ đầu tư','0900000001','owner',crypt('1234',gen_salt('bf')),'{F01,F99}'),
 ('NS-002','ITRAN','F01','Giám đốc trại F01','director','BGĐ','Giám đốc trại','0900000002','gd',crypt('1234',gen_salt('bf')),'{F01}'),
 ('NS-003','ITRAN','F01','KTT Chăn nuôi','tech_head','SXCN','Kỹ thuật trưởng chăn nuôi','0900000003','ktt-cn',crypt('1234',gen_salt('bf')),'{F01}'),
 ('NS-004','ITRAN','F01','KTT Sinh học','tech_head','SHTT','Kỹ thuật trưởng sinh học','0900000004','ktt-sh',crypt('1234',gen_salt('bf')),'{F01}'),
 ('NS-005','ITRAN','F01','KS Công nghệ – Dữ liệu','it_engineer','CN','Kỹ sư công nghệ','0900000005','ks-cn',crypt('1234',gen_salt('bf')),'{F01,F99}'),
 ('NS-006','ITRAN','F01','Trưởng nhóm đại gia súc','team_lead','SXCN','Trưởng nhóm','0900000006','tn-bo',crypt('1234',gen_salt('bf')),'{F01}'),
 ('NS-011','ITRAN','F01','CN TMR (A1)','worker','SXCN','A1 TMR','0900000011','a1',crypt('1234',gen_salt('bf')),'{F01}'),
 ('NS-012','ITRAN','F01','CN Sinh sản–bê (A2)','worker','SXCN','A2 Sinh sản','0900000012','a2',crypt('1234',gen_salt('bf')),'{F01}'),
 ('NS-013','ITRAN','F01','CN Gà (A3)','worker','SXCN','A3 Gà','0900000013','a3',crypt('1234',gen_salt('bf')),'{F01}'),
 ('NS-014','ITRAN','F01','CN RAS (A4)','worker','SXCN','A4 RAS','0900000014','a4',crypt('1234',gen_salt('bf')),'{F01}'),
 ('NS-015','ITRAN','F01','Lái máy (A5)','worker','SHTT','A5 Lái máy','0900000015','a5',crypt('1234',gen_salt('bf')),'{F01}'),
 ('NS-016','ITRAN','F01','CN Khu D (A6)','worker','SHTT','A6 Khu D','0900000016','a6',crypt('1234',gen_salt('bf')),'{F01}'),
 ('NS-017','ITRAN','F01','Vận hành D5 (A7)','worker','SHTT','A7 D5','0900000017','a7',crypt('1234',gen_salt('bf')),'{F01}'),
 ('NS-018','ITRAN','F01','Kho – giao (A8)','worker','KD','A8 Kho','0900000018','a8',crypt('1234',gen_salt('bf')),'{F01}'),
 ('NS-019','ITRAN','F01','Kinh doanh (A9)','worker','KD','A9 KD','0900000019','a9',crypt('1234',gen_salt('bf')),'{F01}'),
 ('NS-020','ITRAN','F01','Bảo vệ (A11)','worker','HCNS','A11 Bảo vệ','0900000020','a11',crypt('1234',gen_salt('bf')),'{F01}'),
 ('NS-030','ITRAN',null,'Kiểm toán','auditor','HQ','Kiểm toán độc lập','0900000030','audit',crypt('1234',gen_salt('bf')),'{F01,F99}'),
 ('NS-031','ITRAN','F01','Kế toán thuê ngoài','accountant','HCNS','Kế toán','0900000031','kt',crypt('1234',gen_salt('bf')),'{F01}')
on conflict do nothing;

-- Trung tâm chi phí, kho, vị trí (F01 & F99)
insert into cost_centers(id,farm_id,name) select f||'-'||c, f, n from farms x cross join lateral (values
 ('CC-BO','Bò'),('CC-GA','Gà'),('CC-RAS','RAS'),('CC-TRUN','Trùn–BSF'),('CC-D5','Xưởng thức ăn D5'),('CC-TT','Trồng trọt'),('CC-CB','Chế biến'),('CC-KD','Kinh doanh'),('CC-DL','Du lịch'),('CC-HC','HC-TC-NS'),('CC-CN','Công nghệ'),('CC-VIEN','Kinh tế viền')) as t(c,n), (select id as f from farms) ff where x.id=ff.f on conflict do nothing;
insert into warehouses(id,farm_id,code,name,unit_kind,count_cycle,temp_monitored)
select f.id||'-'||k.code, f.id, k.code, k.name, k.u, k.c, k.t from farms f cross join (values
 ('K1','Vật tư – thuốc – vaccine','SKU','THANG',false),('K2','Nguyên liệu thô mua','KG','THANG',false),('K3','Bán thành phẩm TA (hào ủ, cỏ, silo)','KG','THANG',false),
 ('K4','Thức ăn thành phẩm','KG','TUAN',false),('K5','Thành phẩm SKU','SKU','TUAN',false),('K6','Kho lạnh','KG','TUAN',true),
 ('K7','Nhiên liệu','L','TUAN',false),('K8','Sổ đàn (tồn kho sống)','CON','TUAN',false),('K9','Bao bì – tem','CAI','THANG',false)) as k(code,name,u,c,t) on conflict do nothing;
insert into locations(id,farm_id,code,name,kind,elevation_tier) values
 ('F01-KHU-C','F01','KHU-C','Khu chuồng bò','KHU','T1'),('F01-CH-NAI-1','F01','NAI-1','Dãy nái 1','CHUONG','T1'),('F01-CH-VO-1','F01','VO-1','Chuồng vỗ béo 1','CHUONG','T1'),
 ('F01-CH-CL','F01','CACH-LY','Chuồng cách ly','CHUONG','T1'),('F01-GA-DE','F01','GA-DE','Khối gà đẻ','CHUONG','T2'),('F01-GA-THIT','F01','GA-THIT','Khối gà thịt','CHUONG','T2'),
 ('F01-RAS','F01','RAS','Nhà RAS','KHU','T1'),('F01-KHU-D','F01','KHU-D','Khu D sinh học','KHU','T1'),('F01-TR-01','F01','TR-01','Luống trùn 01','O','T1'),('F01-TR-02','F01','TR-02','Luống trùn 02','O','T1'),
 ('F01-D5','F01','D5','Xưởng thức ăn D5','NHA','T1'),('F01-CONG','F01','CONG','Cổng lõi + cân','TRAM','T1'),('F01-TRAM-DAU','F01','TRAM-DAU','Trạm dầu','TRAM','T1') on conflict do nothing;

-- Sản phẩm/SKU/vật tư (org scope)
insert into products(sku,org_id,name,kind,unit,unit2,value_tier,shelf_life_days,default_warehouse,lot_tracked,coa_required) values
 ('SKU-PTR-25','ITRAN','ITRAN Phân trùn 25kg','THANH_PHAM','bao',null,2,365,'K5',true,false),
 ('SKU-TRUNG-10','ITRAN','ITRAN Trứng thảo dược vỉ 10','THANH_PHAM','vi','qua',2,21,'K5',true,false),
 ('SKU-TMR-25','ITRAN','ITRAN TMR ủ chua bao 25kg','THANH_PHAM','bao',null,3,60,'K4',true,false),
 ('SKU-NAM-1','ITRAN','Nấm bào ngư tươi kg','THANH_PHAM','kg',null,1,5,'K6',true,false),
 ('SKU-BO-HOI','ITRAN','Bò hơi','THANH_PHAM','kg','con',1,null,'K8',false,false),
 ('NL-ROM','ITRAN','Rơm cuộn','NGUYEN_LIEU','kg','cuon',null,180,'K2',true,false),
 ('NL-BA-BIA','ITRAN','Bã bia','NGUYEN_LIEU','kg',null,null,7,'K2',true,false),
 ('NL-BAP-U','ITRAN','Bắp sinh khối ủ chua','BAN_TP','kg',null,null,120,'K3',true,false),
 ('NL-CO-TUOI','ITRAN','Cỏ tươi cắt','BAN_TP','kg',null,null,2,'K3',true,false),
 ('NL-RI-MAT','ITRAN','Rỉ mật','NGUYEN_LIEU','kg',null,null,365,'K2',true,true),
 ('NL-KHOANG','ITRAN','Premix khoáng','NGUYEN_LIEU','kg',null,null,365,'K2',true,true),
 ('TA-VIEN-GA','ITRAN','Viên D5 gà đẻ','BAN_TP','kg',null,null,45,'K4',true,false),
 ('TA-TMR-VO','ITRAN','TMR pha vỗ béo','BAN_TP','kg',null,null,2,'K4',true,false),
 ('TH-OXY','ITRAN','Oxytetracycline 100ml','THUOC','lo','ml',null,730,'K1',true,true),
 ('VX-LMLM','ITRAN','Vaccine LMLM','VACCINE','lieu',null,null,365,'K1',true,true),
 ('TINH-BRAHMAN','ITRAN','Tinh bò Brahman','GIONG','lieu',null,null,3650,'K1',true,true),
 ('NL-DAU','ITRAN','Dầu diesel','NHIEN_LIEU','l',null,null,null,'K7',false,false),
 ('BB-TEM','ITRAN','Tem truy xuất cuộn','BAO_BI','cai',null,null,null,'K9',true,false),
 ('BB-BAO-25','ITRAN','Bao PP 25kg','BAO_BI','cai',null,null,null,'K9',false,false)
on conflict do nothing;

-- Đối tác
insert into partners(id,org_id,farm_id,kind,name,phone,channel,credit_days,approved,approved_at) values
 ('NCC-0001','ITRAN','F01','NCC','HTX Rơm Khoái Châu','0911000001',null,null,true,current_date),
 ('NCC-0002','ITRAN','F01','NCC','Nhà máy bia Hưng Yên (bã bia)','0911000002',null,null,true,current_date),
 ('NCC-0003','ITRAN','F01','NCC','Cty thú y Vetco (thuốc/vaccine)','0911000003',null,null,true,current_date),
 ('KH-0001','ITRAN','F01','KH','Trại bò Bình Minh (mua TMR bao)','0912000001',1,15,true,current_date),
 ('KH-0002','ITRAN','F01','KH','Nhà vườn Hoa Sen (phân trùn)','0912000002',1,15,true,current_date),
 ('KH-0003','ITRAN','F01','KH','Khách lẻ quầy trại','0912000003',2,0,true,current_date),
 ('KH-0004','ITRAN','F01','KH','Anh Minh – nhận nuôi online','0912000004',3,0,true,current_date)
on conflict do nothing;

-- Thiết bị
insert into devices(id,farm_id,kind,name,brand,fuel_l_per_h,maint_cycle_h,machine_hours) values
 ('F01-TB-001','F01','MAY_KEO','Máy kéo 90HP','Kubota',9,250,120),('F01-TB-002','F01','MAY_THU','Máy thu sinh khối tự nạp',null,14,200,60),
 ('F01-TB-003','F01','XE_TRON','Xe trộn TMR 2m³',null,3,150,40),('F01-TB-010','F01','CAN_CAU','Cân cầu khu D 40T',null,null,null,null),
 ('F01-TB-011','F01','CAN_XE_TRON','Cân xe trộn BLE',null,null,null,null),('F01-TB-020','F01','SENSOR_DO','Cảm biến DO bể RAS 1',null,null,null,null),
 ('F01-TB-021','F01','SENSOR_TEMP','Nhiệt kho lạnh K6',null,null,null,null),('F01-TB-030','F01','CAMERA','Camera cổng lõi',null,null,null,null)
on conflict do nothing;

-- Công thức
insert into recipes(id,farm_id,name,species_phase,version,components,protein_pct,active,approved_by,approved_at) values
 ('RC-TMR-VO','F01','TMR vỗ béo pha 2','BO/VO2',1,'[{"sku":"NL-BAP-U","pct":45,"order":1},{"sku":"NL-ROM","pct":15,"order":2},{"sku":"NL-BA-BIA","pct":25,"order":3},{"sku":"NL-KHOANG","pct":3,"order":5},{"sku":"NL-RI-MAT","pct":4,"order":6},{"sku":"NL-CO-TUOI","pct":8,"order":4}]',13.5,true,'NS-003',now()),
 ('RC-GA-DE','F01','Viên gà đẻ','GA/DE',1,'[{"sku":"NL-BAP-U","pct":55},{"sku":"NL-KHOANG","pct":5},{"sku":"NL-BA-BIA","pct":25},{"sku":"NL-RI-MAT","pct":5},{"sku":"NL-ROM","pct":10}]',17,true,'NS-003',now())
on conflict do nothing;

-- Lô đất
insert into plots(id,farm_id,name,area_ha,elevation_tier,kind,rotation_group,current_crop,geom) values
 ('F01-LO-G1A','F01','Lô G1A bắp sinh khối',2.5,'T2','HOA_MAU','G1','BAP','{"type":"Polygon","coordinates":[[[105.9,20.7],[105.905,20.7],[105.905,20.704],[105.9,20.704],[105.9,20.7]]]}'),
 ('F01-LO-G2A','F01','Lô G2A sắn',2.5,'T2','HOA_MAU','G2','SAN','{"type":"Polygon","coordinates":[[[105.905,20.7],[105.91,20.7],[105.91,20.704],[105.905,20.704],[105.905,20.7]]]}'),
 ('F01-LO-K01','F01','Ô cỏ K01 Mombasa',0.3,'T3','CO_O',null,'CO','{"type":"Polygon","coordinates":[[[105.9,20.704],[105.902,20.704],[105.902,20.706],[105.9,20.706],[105.9,20.704]]]}'),
 ('F01-LO-K02','F01','Ô cỏ K02 Mulato',0.3,'T3','CO_O',null,'CO',null),
 ('F01-LO-VIEN-01','F01','Tuyến cau trục chính',0.4,'T2','VIEN',null,'CAU',null)
on conflict do nothing;

-- Đàn/nhóm & lô nhập & 20 bò
insert into animal_groups(id,farm_id,species,kind,block,name,location_id,head_count,started_at,all_in_all_out) values
 ('F01-GA-L01','F01','GA','GA_DE','DE','Gà đẻ lứa 01 (3.000 mái)','F01-GA-DE',3000,current_date-120,false),
 ('F01-GT-L01','F01','GA','GA_THIT','THIT','Gà thịt lứa 01','F01-GA-THIT',1500,current_date-30,true),
 ('F01-RAS-B01','F01','LUON','RAS',null,'Bể lươn 01','F01-RAS',2000,current_date-60,false),
 ('F01-RAS-B02','F01','LUON','RAS',null,'Bể lươn 02','F01-RAS',2000,current_date-60,false),
 ('F01-DAN-NAI-01','F01','BO','BO_NHOM',null,'Đàn nái dãy 1','F01-CH-NAI-1',0,current_date-90,false),
 ('F01-DAN-VO-01','F01','BO','BO_NHOM',null,'Đàn vỗ béo 1','F01-CH-VO-1',0,current_date-90,false)
on conflict do nothing;
insert into intake_lots(id,farm_id,kind,date,source_partner_id,quarantine_until,vet_cert_no,price,head_count) values
 ('F01-LN-2026-001','F01','MUA',current_date-95,'NCC-0003',current_date-74,'KD-2026-0451',32000000,15),
 ('F01-LN-2026-002','F01','SINH',current_date-20,null,null,null,null,5) on conflict do nothing;
insert into animals(id,farm_id,species,breed,sex,birth_date,rfid,visual_tag,source,intake_lot_id,group_id,status,location_id,last_weight_kg,last_weight_at,unit_value,cost_center)
select 'F01-BO-'||lpad(g::text,5,'0'),'F01','BO',case when g%3=0 then 'Brahman lai' else 'Sind lai' end,'F',(current_date - (900+g*17))::date,
       '704'||lpad((100000000000+g)::text,12,'0'),'B'||lpad(g::text,3,'0'),'MUA','F01-LN-2026-001','F01-DAN-NAI-01',
       (array['HAU_BI','PHOI','KHAM_THAI','MANG_THAI','CHO_PHOI'])[1+(g%5)],'F01-CH-NAI-1',300+g*7,current_date-3,28000000+g*200000,'F01-CC-BO'
from generate_series(1,15) g on conflict do nothing;
insert into animals(id,farm_id,species,breed,sex,birth_date,dam_id,rfid,visual_tag,source,intake_lot_id,group_id,status,location_id,last_weight_kg,last_weight_at,unit_value,cost_center)
select 'F01-BO-'||lpad((15+g)::text,5,'0'),'F01','BO','Sind lai',case when g%2=0 then 'M' else 'F' end,(current_date - 20 + g)::date,'F01-BO-'||lpad(g::text,5,'0'),
       '704'||lpad((100000000015+g)::text,12,'0'),'C'||lpad(g::text,3,'0'),'SINH','F01-LN-2026-002','F01-DAN-NAI-01','THEO_ME','F01-CH-NAI-1',35+g,current_date-3,6000000,'F01-CC-BO'
from generate_series(1,5) g on conflict do nothing;
update animal_groups set head_count=(select count(*) from animals where group_id='F01-DAN-NAI-01') where id='F01-DAN-NAI-01';
insert into group_membership(animal_id,group_id) select id, group_id from animals where farm_id='F01' on conflict do nothing;

-- Lô hàng & tồn đầu kỳ (inventory_moves nhập)
select ensure_lot('F01','NL-ROM','R2607-01','NCC-0001',(current_date+150)::date);
select ensure_lot('F01','NL-BA-BIA','BB260815','NCC-0002',(current_date+5)::date);
select ensure_lot('F01','NL-BAP-U','U2606-H1',null,(current_date+90)::date);
select ensure_lot('F01','NL-RI-MAT','RM2605',null,(current_date+300)::date);
select ensure_lot('F01','NL-KHOANG','KH2604','NCC-0003',(current_date+300)::date);
select ensure_lot('F01','NL-CO-TUOI','CO'||to_char(current_date,'YYMMDD'),null,(current_date+2)::date);
select ensure_lot('F01','TH-OXY','OXY2603','NCC-0003',(current_date+400)::date);
select ensure_lot('F01','VX-LMLM','LM2607','NCC-0003',(current_date+200)::date);
select ensure_lot('F01','SKU-PTR-25','F01-ME-260810-01',null,(current_date+360)::date);
select ensure_lot('F01','SKU-TRUNG-10','F01-ME-'||to_char(current_date,'YYMMDD')||'-01',null,(current_date+21)::date);
select ensure_lot('F01','BB-TEM','TEM-2601',null,null);
insert into inventory_moves(farm_id,ts,created_by,source,warehouse_id,sku,lot_id,direction,qty,unit,unit_cost,reason,from_to,weigh_point)
values
 ('F01',now()-interval '20 days','NS-018','IMPORT','F01-K2','NL-ROM','F01-LOT-NL-ROM-R2607-01',1,40000,'kg',1200,'NHAP_MUA','NCC-0001','CAN_CAU_D'),
 ('F01',now()-interval '3 days','NS-018','IMPORT','F01-K2','NL-BA-BIA','F01-LOT-NL-BA-BIA-BB260815',1,8000,'kg',900,'NHAP_MUA','NCC-0002','CAN_CAU_D'),
 ('F01',now()-interval '40 days','NS-018','IMPORT','F01-K3','NL-BAP-U','F01-LOT-NL-BAP-U-U2606-H1',1,120000,'kg',850,'NHAP_SX','LO-G1A','CAN_CAU_D'),
 ('F01',now()-interval '30 days','NS-018','IMPORT','F01-K2','NL-RI-MAT','F01-LOT-NL-RI-MAT-RM2605',1,3000,'kg',5000,'NHAP_MUA','NCC','CUA_KHO'),
 ('F01',now()-interval '30 days','NS-018','IMPORT','F01-K2','NL-KHOANG','F01-LOT-NL-KHOANG-KH2604',1,1500,'kg',18000,'NHAP_MUA','NCC-0003','CUA_KHO'),
 ('F01',now()-interval '30 days','NS-018','IMPORT','F01-K1','TH-OXY','F01-LOT-TH-OXY-OXY2603',1,40,'lo',85000,'NHAP_MUA','NCC-0003','CUA_KHO'),
 ('F01',now()-interval '30 days','NS-018','IMPORT','F01-K1','VX-LMLM','F01-LOT-VX-LMLM-LM2607',1,200,'lieu',22000,'NHAP_MUA','NCC-0003','CUA_KHO'),
 ('F01',now()-interval '8 days','NS-016','IMPORT','F01-K5','SKU-PTR-25','F01-LOT-SKU-PTR-25-F01-ME-260810-01',1,400,'bao',60000,'NHAP_SX','KHU-D','CUA_KHO'),
 ('F01',now()-interval '30 days','NS-018','IMPORT','F01-K9','BB-TEM','F01-LOT-BB-TEM-TEM-2601',1,5000,'cai',300,'NHAP_MUA','NCC','CUA_KHO'),
 ('F01',now()-interval '30 days','NS-015','IMPORT','F01-K7','NL-DAU',null,1,2000,'l',21000,'NHAP_MUA','NCC','TRAM_DAU');

-- Cấu hình (P8)
insert into settings(farm_id,key,value,updated_by) values
 ('GLOBAL','feed.meal_times','["06:00","15:00"]','NS-005'),('GLOBAL','order.cutoff','"15:00"','NS-005'),('GLOBAL','barn.max_temp_c','35','NS-005'),
 ('GLOBAL','silage.days_target','60','NS-005'),('GLOBAL','silage.days_yellow','45','NS-005'),('GLOBAL','silage.days_red','30','NS-005'),
 ('GLOBAL','inventory.diff_red_pct','2','NS-005'),('GLOBAL','paper.digitize_hours','24','NS-005'),('GLOBAL','event.supersede_window_hours','72','NS-005'),
 ('F01','flood.levels_m','[3.5,4.2,4.8]','NS-005') on conflict do nothing;
insert into norms(id,org_id,farm_id,kind,subject,value,unit,note) values
 ('N-PHAN-BO','ITRAN',null,'PHAN_KG_CON_NGAY','BO',15,'kg/con/ngày','FILE GỐC IV'),('N-NUOC-BO','ITRAN',null,'NUOC_L_CON_NGAY','BO',75,'l/con/ngày',null),
 ('N-FCR-VO2','ITRAN',null,'FCR_CHUAN','BO/VO2',8.5,'kg TA/kg tăng',null),('N-TA-BO-NGAY','ITRAN',null,'TA_KG_CON_NGAY','BO',32,'kg tươi/con/ngày','~11,5–12 t/năm'),
 ('N-DAU-TB001','ITRAN','F01','LIT_GIO_MAY','F01-TB-001',9,'l/h',null) on conflict do nothing;

-- Mẫu phiếu giấy
insert into paper_form_templates(code,name,target_table) values ('BM01','FEED_LOG','feed_logs'),('BM02','EVENT_ANIMAL','animal_events'),('BM03','CROP_LOG','crop_logs'),('BM04','BATCH_LOG','batch_logs'),('BM05','INVENTORY_MOVE','inventory_moves'),('BM06','SALE','sales'),('BM07','CHECKLIST_RUN','checklist_runs'),('BM08','GATE_LOG','gate_logs'),('BM09','STOCKTAKE','stocktakes'),('BM10','INCIDENT','incidents') on conflict do nothing;

-- SOP khung (L2 chính) + 2 SOP mẫu ký
insert into sops(code,org_id,title,dept,l1_chain,l2_group,status) values
 ('SOP-BO-07.2','ITRAN','Trộn & rải TMR pha vỗ béo','BO','Chuỗi bò','Cho ăn TMR ngày','BAN_HANH'),
 ('SOP-TR-01.3','ITRAN','Nạp liệu luống trùn','SH','Chuỗi sinh học','Trùn: nạp–ủ sơ–thu','BAN_HANH'),
 ('SOP-BO-02.1','ITRAN','Nhập đàn – cách ly 21 ngày','BO','Chuỗi bò','Nhập đàn–cách ly','BAN_HANH'),
 ('SOP-BO-04.1','ITRAN','Đỡ đẻ – úm bê','BO','Chuỗi bò','Đỡ đẻ–úm bê','DRAFT'),
 ('SOP-GA-02.1','ITRAN','Chăm gà đẻ ngày','GA','Chuỗi bò','Chăm ngày','BAN_HANH'),
 ('SOP-KHO-01.1','ITRAN','Nhập kho – kiểm COA – FEFO','KHO','Chuỗi hỗ trợ','Mua hàng–kho vật tư','BAN_HANH'),
 ('SOP-AN-01.1','ITRAN','Cổng sinh học – cân – rửa xe','AN','Chuỗi an toàn','Cổng sinh học','BAN_HANH') on conflict do nothing;
insert into sop_versions(sop_code,version,purpose,allowed_roles,tools,frequency,steps,pass_criteria,common_errors,evidence,safety,std_clause,signed_by,signed_at,review_due,status) values
 ('SOP-BO-07.2',3,'Trộn đúng công thức, rải đúng giờ, ghi FEED_LOG','{worker}','Xe trộn 2m³, cân, công thức FMS','05:30 & 15:00',
  '[{"n":1,"a":"Nhận công thức mẻ trên app (QR xe)"},{"n":2,"a":"Cân thô: ủ chua → rơm ủ → thân chuối"},{"n":3,"a":"Cân tinh: viên D5"},{"n":4,"a":"Rỉ mật + khoáng SAU CÙNG"},{"n":5,"a":"Trộn 8–10 phút (không quá 12)"},{"n":6,"a":"Rải đều 2 lượt dọc máng"},{"n":7,"a":"Đẩy thức ăn thừa cũ, ước % thừa"},{"n":8,"a":"Ghi FEED_LOG + ảnh máng"}]',
  'Sai số cân ≤2%; thừa hôm trước 3–5%','Máng ướt mưa → giảm 20% mẻ chiều','FEED_LOG, ảnh máng','Cấm đứng trong bán kính trục trộn','GlobalG.A.P LB; ISO 9001 8.5','NS-002',now()-interval '30 days',current_date+335,'BAN_HANH'),
 ('SOP-TR-01.3',2,'Nạp phân đã ủ sơ đúng cách, trùn ăn hết ≤48h','{worker}','Xe điện ben, nhiệt kế luống','2 ngày/lần/ô',
  '[{"n":1,"a":"Chỉ nhận phân ủ sơ ≥7 ngày, nhiệt đống <35°C (đo)"},{"n":2,"a":"Rải lớp 5–7cm MỘT NỬA mặt luống"},{"n":3,"a":"Không rải khi luống >30°C"},{"n":4,"a":"Tưới ẩm 70–80%"},{"n":5,"a":"Ghi BATCH_LOG ô + khối lượng"},{"n":6,"a":"Tuần: kiểm mật độ trùn 3 điểm/ô"}]',
  'Trùn ăn hết lớp trong ≤48h','Trùn bò lên thành = quá nóng/chua → ngừng nạp, tưới, rắc vôi mép','BATCH_LOG, ảnh điểm kiểm','—','ISO 14001','NS-002',now()-interval '30 days',current_date+335,'BAN_HANH'),
 ('SOP-GA-02.1',1,'Chăm gà đẻ ngày','{worker}','—','Hằng ngày','[{"n":1,"a":"Nhìn đàn 15 phút, kiểm nipple"},{"n":2,"a":"Nhặt trứng băng chuyền, phân loại"},{"n":3,"a":"Ghi trứng cuối ca, chết/loại"},{"n":4,"a":"Log anolyte nước uống"}]','Đẻ ≥78%; chết tháng ≤0,8%','—','INVENTORY_MOVE trứng, EVENT đàn','Cấm qua khối gà thịt trong ngày','GlobalG.A.P PY','NS-002',now()-interval '20 days',current_date+345,'BAN_HANH')
on conflict do nothing;

-- KPI defs (trích file 06)
insert into kpi_defs(code,version,name,unit,target,yellow,red,period,scope,pay_layer) values
 ('KPI-BE-NAI',1,'Bê cai sữa/nái/năm','',0.85,0.8,0.75,'12M','FARM',2),('KPI-DAU-THAI',1,'Đậu thai/phối','%',55,50,45,'12M','FARM',2),
 ('KPI-ADG-VO',1,'Tăng trọng vỗ béo','g/ngày',900,800,750,'M','GROUP',2),('KPI-SAI-SO-ME',1,'Sai số cân mẻ TMR','%',2,3,5,'D','STAFF',2),
 ('KPI-DE',1,'Tỷ lệ đẻ gà','%',78,75,70,'D','GROUP',2),('KPI-CHET-GA',1,'Chết gà tháng','%',0.8,1,1.5,'M','GROUP',2),
 ('KPI-NGAY-TON-U',1,'Ngày-tồn ủ chua','ngày',60,45,30,'D','FARM',null),('KPI-CHENH-KK',1,'Chênh kiểm kê','%',1,2,3,'M','WAREHOUSE',2),
 ('KPI-CONG-NO',1,'Công nợ ngày','ngày',15,30,60,'D','FARM',2),('KPI-TU-CHU-TA',1,'Tự chủ thức ăn','%',80,70,60,'M','FARM',null),
 ('KPI-NGUON-35',1,'Nguồn nguyên liệu lớn nhất','%',35,35,40,'M','FARM',null),('KPI-HD-TRUOC',1,'% sản lượng có hợp đồng trước','%',70,60,50,'Q','FARM',null)
on conflict do nothing;

-- Alert rules seed (chọn lọc, dùng expr JSON đơn giản)
insert into alert_rules(code,version,farm_id,name,source,expr,level,recipients,channels,sop_code) values
 ('AL-FEED-MISS',1,'GLOBAL','Thiếu FEED_LOG sau giờ ăn +60 phút','feed','{"type":"missing_event","table":"feed_logs","after_setting":"feed.meal_times","grace_min":60}','VANG','{worker:A1,tech_head}','{app}','SOP-BO-07.2'),
 ('AL-SIL-45',1,'GLOBAL','Ngày-tồn ủ chua < 45','kpi','{"type":"threshold","view":"v_days_silage","col":"days_silage","op":"<","setting":"silage.days_yellow"}','VANG','{tech_head,director}','{app,zalo}',null),
 ('AL-SIL-30',1,'GLOBAL','Ngày-tồn ủ chua < 30','kpi','{"type":"threshold","view":"v_days_silage","col":"days_silage","op":"<","setting":"silage.days_red"}','DO','{tech_head,director}','{app,zalo,sms}',null),
 ('AL-INV-2',1,'GLOBAL','Chênh kiểm kê > 2%','recon','{"type":"recon","rule":"RC5"}','DO','{director,owner}','{app,zalo}',null),
 ('AL-WD',1,'GLOBAL','Xuất con chưa hết ngưng thuốc (chặn)','db','{"type":"db_block"}','DO','{worker:A2,tech_head}','{app}',null),
 ('AL-DEATH-POUL',1,'GLOBAL','Gà chết ≥5 con/ngày/khối','event','{"type":"sum_threshold","table":"animal_events","event_type":"CHET","group_kind":"GA","window":"1 day","op":">=","value":5}','DO','{worker:A3,tech_head}','{app,sms}','SOP-GA-02.1'),
 ('AL-PAPER-24H',1,'GLOBAL','Phiếu giấy >24h chưa số hóa','recon','{"type":"recon","rule":"RC11"}','VANG','{team_lead}','{app}',null),
 ('AL-PAPER-SERIAL',1,'GLOBAL','Số seri phiếu nhảy quãng','recon','{"type":"recon","rule":"RC11b"}','DO','{tech_head,director}','{app}',null),
 ('AL-BACKUP-FAIL',1,'GLOBAL','Backup/xuất CSV lỗi','system','{"type":"job_fail","job":"backup"}','DO','{it_engineer,director}','{app,zalo}',null),
 ('AL-FEFO',1,'GLOBAL','Lô còn <20% hạn','kpi','{"type":"rows","view":"v_fefo_red"}','VANG','{worker:A8}','{app}',null),
 ('AL-DEV-MAINT',1,'GLOBAL','Máy đến giờ bảo dưỡng','device','{"type":"maint_due"}','XANH','{worker:A5}','{app}',null)
on conflict do nothing;

-- RC rules (RC1–RC11 + RC11b, RC12) — SQL 2 vế theo farm & period ($1 farm, $2 date)
insert into rc_rules(code,name,side_a_sql,side_b_sql,threshold_pct,threshold_mode,level,recipients) values
 ('RC1','Thức ăn xuất kho vs cho ăn',
  'select coalesce(sum(qty),0) from inventory_moves m where m.farm_id=$1 and m.status=''ACTIVE'' and m.direction=-1 and m.reason=''XUAT_CHO_AN'' and m.ts::date=$2',
  'select coalesce(sum(qty_kg),0) from feed_logs where farm_id=$1 and status=''ACTIVE'' and ts::date=$2',3,'PCT','VANG','{tech_head,director}'),
 ('RC2','FCR thực vs chuẩn pha (30 ngày)',
  'select coalesce(sum(f.qty_kg),0)/nullif((select coalesce(sum(value),0) from animal_events e where e.farm_id=$1 and e.status=''ACTIVE'' and e.event_type=''CAN'' and e.ts::date between $2::date-30 and $2 and (e.detail->>''gain_kg'') is not null),0) from feed_logs f where f.farm_id=$1 and f.status=''ACTIVE'' and f.dest_group_id=''F01-DAN-VO-01'' and f.ts::date between $2::date-30 and $2',
  'select value from norms where kind=''FCR_CHUAN'' and subject=''BO/VO2'' limit 1',15,'PCT','VANG','{tech_head}'),
 ('RC3','Ruộng thu vs nhập K3 qua cân',
  'select coalesce(sum(qty_kg),0) from crop_logs where farm_id=$1 and status=''ACTIVE'' and activity in (''THU'',''CAT'') and ts::date=$2',
  'select coalesce(sum(qty),0) from inventory_moves m join warehouses w on w.id=m.warehouse_id where m.farm_id=$1 and m.status=''ACTIVE'' and m.direction=1 and w.code=''K3'' and m.ts::date=$2',5,'PCT','VANG','{tech_head}'),
 ('RC4','Phân sinh ra vs phân xử lý (tuần)',
  'select (select coalesce(sum(head_count),0) from v_herd h where h.farm_id=$1) * (select value from norms where kind=''PHAN_KG_CON_NGAY'' limit 1) * 7',
  'select coalesce(sum((i->>''kg'')::numeric),0) from batch_logs b, jsonb_array_elements(b.inputs) i where b.farm_id=$1 and b.status=''ACTIVE'' and b.line in (''TRUN_NAP'',''BIOGAS'',''COMPOST'') and b.ts::date between $2::date-6 and $2',15,'PCT','VANG','{tech_head,director}'),
 ('RC5','Xuất bán K5/K6 vs SALE (tuần)',
  'select coalesce(sum(qty),0) from inventory_moves m join warehouses w on w.id=m.warehouse_id where m.farm_id=$1 and m.status=''ACTIVE'' and m.direction=-1 and m.reason=''XUAT_BAN'' and w.code in (''K5'',''K6'') and m.ts::date between $2::date-6 and $2',
  'select coalesce(sum(qty),0) from sales s where s.farm_id=$1 and s.status=''ACTIVE'' and s.ts::date between $2::date-6 and $2',2,'PCT','DO','{director,owner}'),
 ('RC6','Trứng 3 điểm (đếm băng vs nhập K5 vs bán)',
  'select coalesce(sum(value),0) from animal_events e join animal_groups g on g.id=e.group_id where e.farm_id=$1 and e.status=''ACTIVE'' and e.event_type=''SO_LUONG'' and (e.detail->>''metric'')=''eggs_counted'' and e.ts::date=$2',
  'select coalesce(sum(qty),0)*10 from inventory_moves m join products p on p.sku=m.sku where m.farm_id=$1 and m.status=''ACTIVE'' and m.direction=1 and p.sku like ''SKU-TRUNG%'' and m.ts::date=$2',2,'PCT','VANG','{worker:A3,tech_head}'),
 ('RC7','Nhiên liệu vs giờ máy × định mức (tuần)',
  'select coalesce(sum(qty),0) from inventory_moves m join warehouses w on w.id=m.warehouse_id where m.farm_id=$1 and m.status=''ACTIVE'' and m.direction=-1 and w.code=''K7'' and m.ts::date between $2::date-6 and $2',
  'select coalesce(sum(c.machine_hours*coalesce(d.fuel_l_per_h,8)),0) from crop_logs c join devices d on d.id=c.machine_id where c.farm_id=$1 and c.status=''ACTIVE'' and c.ts::date between $2::date-6 and $2',10,'PCT','VANG','{worker:A5,tech_head}'),
 ('RC8','Thuốc xuất K1 vs liều điều trị',
  'select coalesce(sum(qty),0) from inventory_moves m join products p on p.sku=m.sku where m.farm_id=$1 and m.status=''ACTIVE'' and m.direction=-1 and p.kind=''THUOC'' and m.ts::date=$2',
  'select coalesce(sum((detail->>''dose_units'')::numeric),0) from animal_events where farm_id=$1 and status=''ACTIVE'' and event_type=''DIEU_TRI'' and ts::date=$2',0,'ABS','DO','{tech_head}'),
 ('RC9','Đàn 3 nguồn (sổ đàn vs đếm tay vs camera)',
  'select coalesce(sum(head_count),0) from v_herd where farm_id=$1',
  'select coalesce((select (l->>''counted'')::numeric from stocktakes s, jsonb_array_elements(s.lines) l where s.farm_id=$1 and s.status=''ACTIVE'' and s.warehouse_id=$1||''-K8'' and s.ts::date=$2 limit 1),(select coalesce(sum(head_count),0) from v_herd where farm_id=$1))',0,'ABS','DO','{director}'),
 ('RC10','Tiền vs hàng (SALE thanh toán vs sao kê)',
  'select coalesce(sum(amount),0) from sales where farm_id=$1 and status=''ACTIVE'' and paid and ts::date=$2',
  'select coalesce(sum(amount),0) from sales where farm_id=$1 and status=''ACTIVE'' and paid and ts::date=$2 and payment in (''CK'',''POS'',''VIETQR'')',0.5,'PCT','DO','{accountant,director}'),
 ('RC11','Giấy–số: phiếu chụp >24h chưa số hóa',
  'select count(*) from paper_scans where farm_id=$1 and status=''ACTIVE'' and not digitized and ts < now() - interval ''24 hours''',
  'select 0',0,'ABS','VANG','{team_lead}'),
 ('RC11b','Giấy–số: seri nhảy quãng',
  'select count(*) from (select form_code, (regexp_match(serial, ''(\d+)$''))[1]::int as n from paper_scans where farm_id=$1 and status=''ACTIVE'') s where not exists (select 1 from paper_scans p2 where p2.farm_id=$1 and p2.form_code=s.form_code and (regexp_match(p2.serial, ''(\d+)$''))[1]::int = s.n-1) and s.n > (select min((regexp_match(serial, ''(\d+)$''))[1]::int) from paper_scans p3 where p3.farm_id=$1 and p3.form_code=s.form_code)',
  'select 0',0,'ABS','DO','{tech_head,director}'),
 ('RC12','Tem in (K9 xuất) vs tem dán (BATCH_OUTPUT)',
  'select coalesce(sum(qty),0) from inventory_moves m join products p on p.sku=m.sku where m.farm_id=$1 and m.status=''ACTIVE'' and m.direction=-1 and p.sku=''BB-TEM'' and m.ts::date=$2',
  'select coalesce(sum((o->>''labels'')::numeric),0) from batch_logs b, jsonb_array_elements(b.outputs) o where b.farm_id=$1 and b.status=''ACTIVE'' and b.ts::date=$2',0,'ABS','VANG','{worker:A7,tech_head}')
on conflict do nothing;
