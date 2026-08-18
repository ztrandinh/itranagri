-- 0021 · ĐỊNH NGHĨA ĐỐI TƯỢNG (master taxonomy): 1) Con người – vai trò – vị trí  2) Vật nuôi – loài – phân lớp  3) Cây trồng – nhóm  4) Sản phẩm/vật tư – nhóm
--        Mọi số liệu sản xuất/tồn kho/tài chính đều treo vào các đối tượng này. Danh mục = dữ liệu (sửa trong Quản trị DL), có audit.
-- ===== 1. CON NGƯỜI =====
create table if not exists roles_catalog(code text primary key, name text not null, description text, level int, scope text, -- HQ|FARM|BOTH
  can_write text[] default '{}', can_approve text[] default '{}', dashboards text[] default '{}', position int default 0);
insert into roles_catalog(code,name,description,level,scope,can_write,can_approve,dashboards,position) values
('owner','Chủ đầu tư / HĐQT','Xem mọi trại, duyệt chi >50tr, khai báo trại, phân quyền; không ghi nghiệp vụ hàng ngày',0,'HQ','{settings,norms,alert_rules,farms,staff}','{expense>50tr,farm.create,period.lock}','{/hq,/ke-toan,/so-lieu}',1),
('director','Giám đốc (công ty mẹ hoặc trại)','Điều hành, duyệt chi 20–50tr, duyệt kế hoạch, giao ca; đọc mọi phân hệ trong trại',1,'BOTH','{tasks,orders,contracts,expense_requests,staff}','{expense≤50tr,adjustments,checklists,po}','{/gd,/ke-hoach,/nhan-su}',2),
('tech_head','Kỹ thuật trưởng (chăn nuôi/thú y/trồng trọt/D5)','Chịu trách nhiệm kỹ thuật – SOP – KPI kỹ thuật; duyệt điều chỉnh; tạo luật cảnh báo',2,'FARM','{animal_events,feed_plans,crop_seasons,crop_inputs,recipes,sops,alert_rules}','{adjustments,checklists,tasks}','{/ktt,/thu-y,/canh-tac}',3),
('team_lead','Tổ trưởng / trưởng ca','Ghi mọi sự kiện, tự supersede ≤72h, phân việc trong ca; duyệt checklist tổ',3,'FARM','{*events}','{checklist_run}','{/ca,/dan,/kho}',4),
('worker','Công nhân (vị trí A1–A11)','Ghi 3 chạm theo vị trí; xem việc của mình; không duyệt',4,'FARM','{events theo vị trí}','{}','{/ca}',5),
('accountant','Kế toán / mua hàng / kho','Chi – thu – công nợ – ngân hàng – PO – kiểm kê; không sửa sự kiện kỹ thuật',2,'BOTH','{expense_requests,purchase_orders,price_list,bank_statement_lines,cc_fixed_costs,inventory_moves}','{expense≤20tr,adjustments}','{/ke-toan,/kho}',6),
('it_engineer','Kỹ sư công nghệ / hệ thống','Thiết bị – cảm biến – hiệu chuẩn – job – tích hợp – quản trị dữ liệu; không duyệt tiền',2,'HQ','{devices,calibrations,integrations,webhooks,settings,alert_rules,*master}','{}','{/thiet-bi,/quan-tri,/canh-bao}',7),
('auditor','Kiểm toán / QA nội bộ','Chỉ đọc mọi trại + xuất gói audit; không ghi',2,'HQ','{}','{}','{/audit,/doi-soat}',8),
('customer','Khách hàng (portal nhận nuôi)','Chỉ xem cá thể/HĐ của mình qua token; nhắn tin',9,'BOTH','{customer_messages}','{}','{/khach}',9)
on conflict (code) do update set name=excluded.name, description=excluded.description, can_write=excluded.can_write, can_approve=excluded.can_approve, dashboards=excluded.dashboards;
create table if not exists positions_catalog(code text primary key, name text not null, dept_code text, role_code text, sops text[] default '{}', forms text[] default '{}', kpis text[] default '{}', headcount_norm text, position int default 0);
insert into positions_catalog(code,name,dept_code,role_code,forms,kpis,headcount_norm,position) values
('A1','Trộn TMR / vận hành D5','D5','worker','{feed_logs,batch_logs}','{Sai số mẻ ≤3%}','1/5 tấn·ngày',1),('A2','Chăm sóc bò / sinh sản / điều trị','KTCN','worker','{animal_events}','{Đậu thai,Chết %}','1/40 con',2),('A3','Chăm sóc gà 2 khối','KTCN','worker','{animal_events,inventory_moves}','{Tỷ lệ đẻ}','1/2000 con',3),('A4','Khu D sinh học (trùn/BSF/biogas)','SH','worker','{batch_logs}','{Tái sử dụng %}','1 khu',4),('A5','Nhập đàn / cách ly / cân','KTCN','worker','{animal_events,weigh_tickets}','{100% có mã}','theo lô',5),('A6','Ruộng / máy nông nghiệp / thu hoạch','TT','worker','{crop_logs,crop_inputs,harvests}','{Năng suất,PHI=0}','1/5 ha',6),('A7','Chế biến / đóng gói / kho lạnh','D5','worker','{batch_logs,checklist_runs}','{CCP=0}','theo ca',7),('A8','Thủ kho 9 kho','CCU','worker','{inventory_moves,stocktakes}','{Chênh ≤1%}','1/trại',8),('A9','Bán hàng / POS / CSKH','KDM','worker','{sales,pos_receipts,orders}','{Doanh thu,Đúng hẹn}','1/trại',9),('A10','Cổng / cân / bảo vệ','CCU','worker','{gate_logs,weigh_tickets}','{100% xe có phiếu}','2 ca',10),('A11','Bảo trì / điện / IoT','CNTB','worker','{calibrations,tasks}','{Uptime}','1/trại',11),('A12','Lễ tân / buồng / phục vụ (du lịch)','DL','worker','{hosp_bookings,hosp_folio}','{Công suất,Đánh giá}','theo phòng',12),('A13','Hướng dẫn tour / trải nghiệm','DL','worker','{hosp_tours}','{Đánh giá}','1/30 khách',13),('A14','Bếp / F&B','DL','worker','{hosp_folio,inventory_moves}','{Biên F&B}','theo pax',14)
on conflict (code) do update set name=excluded.name, dept_code=excluded.dept_code, forms=excluded.forms;
alter table staff add column if not exists position_code text;
update staff set position_code = substring(position from '^(A[0-9]+)') where position_code is null and position ~ '^A[0-9]+';
-- ===== 2. VẬT NUÔI =====
create table if not exists species(code text primary key, name text not null, group_name text, -- GIA_SUC|GIA_CAM|THUY_SAN|CON_TRUNG|KHAC
  identify_level text not null default 'CA_THE', -- CA_THE (bắt buộc mã từng con) | LO (lô nhập) | DAN (đàn/khối)
  unit text default 'con', biomass_unit text, gestation_days int, cycle_days int, adult_weight_kg numeric, products text[] default '{}', -- SKU đầu ra
  norms jsonb default '{}'::jsonb, module text, position int default 0, active bool default true);
insert into species(code,name,group_name,identify_level,unit,gestation_days,cycle_days,adult_weight_kg,products,module,position) values
('BO','Bò (sinh sản + vỗ béo)','GIA_SUC','CA_THE','con',283,null,450,'{SKU-BO-HOI,SKU-BE-GIONG,SKU-SUA}','bo',1),('DE','Dê','GIA_SUC','CA_THE','con',150,null,45,'{SKU-DE-HOI,SKU-SUA-DE}','de',2),('CUU','Cừu','GIA_SUC','CA_THE','con',150,null,50,'{}','de',3),('HEO','Heo','GIA_SUC','LO','con',114,180,110,'{}','core',4),
('GA','Gà (đẻ + thịt)','GIA_CAM','DAN','con',null,120,2.2,'{SKU-TRUNG-10,SKU-GA-1}','ga',5),('VIT','Vịt','GIA_CAM','DAN','con',null,70,3,'{}','ga',6),('NGAN','Ngan/ngỗng','GIA_CAM','DAN','con',null,90,4,'{}','ga',7),
('CA','Cá (RAS/ao)','THUY_SAN','DAN','kg',null,180,null,'{SKU-CA-1}','ras',8),('LUON','Lươn','THUY_SAN','DAN','kg',null,240,null,'{}','ras',9),('ECH','Ếch','THUY_SAN','DAN','kg',null,90,null,'{}','ras',10),('TOM','Tôm','THUY_SAN','DAN','kg',null,100,null,'{}','ras',11),
('TRUN','Trùn quế','CON_TRUNG','DAN','kg',null,60,null,'{SKU-PTR-25,SKU-TRUN-TUOI}','trun',12),('BSF','Ruồi lính đen','CON_TRUNG','DAN','kg',null,45,null,'{SKU-AU-TRUNG-BSF}','trun',13),('ONG','Ong mật','CON_TRUNG','DAN','đàn',null,365,null,'{SKU-MAT-ONG}','core',14)
on conflict (code) do update set name=excluded.name, group_name=excluded.group_name, identify_level=excluded.identify_level, products=excluded.products;
-- Phân lớp vật nuôi theo giai đoạn/mục đích (để đếm đàn theo lớp: bò cái sinh sản, bò tơ, bê, bò vỗ béo, đực giống…)
create table if not exists animal_classes(code text primary key, species_code text references species, name text not null, sex text, age_from_days int, age_to_days int, purpose text, -- SINH_SAN|VO_BEO|GIONG|HAU_BI|DE_TRUNG|THIT|KHAC
  feed_norm_key text, position int default 0);
insert into animal_classes(code,species_code,name,sex,age_from_days,age_to_days,purpose,feed_norm_key,position) values
('BO-BE','BO','Bê (0–6 tháng)',null,0,180,'HAU_BI','TA_KG_BE',1),('BO-TO','BO','Bò tơ (6–18 tháng)',null,181,540,'HAU_BI','TA_KG_TO',2),('BO-CAI-SS','BO','Bò cái sinh sản','F',541,null,'SINH_SAN','TA_KG_CON_NGAY',3),('BO-VO-BEO','BO','Bò vỗ béo','M',181,null,'VO_BEO','TA_KG_VB',4),('BO-DUC-GIONG','BO','Bò đực giống','M',541,null,'GIONG','TA_KG_CON_NGAY',5),
('DE-CON','DE','Dê con',null,0,120,'HAU_BI',null,1),('DE-CAI-SS','DE','Dê cái sinh sản','F',121,null,'SINH_SAN',null,2),('DE-THIT','DE','Dê thịt','M',121,null,'VO_BEO',null,3),
('GA-HAU-BI','GA','Gà hậu bị (0–18 tuần)',null,0,126,'HAU_BI',null,1),('GA-DE','GA','Gà đẻ',null,127,null,'DE_TRUNG',null,2),('GA-THIT','GA','Gà thịt',null,0,120,'THIT',null,3),
('CA-GIONG','CA','Cá giống',null,0,60,'GIONG',null,1),('CA-THIT','CA','Cá thương phẩm',null,61,null,'THIT',null,2)
on conflict (code) do update set name=excluded.name;
alter table animals add column if not exists class_code text; alter table animal_groups add column if not exists class_code text;
-- gán lớp tự động cho bò theo tuổi/giới (chạy được lại)
update animals a set class_code = case when species='BO' and age(coalesce(birth_date, current_date-600)) < interval '6 months' then 'BO-BE' when species='BO' and age(coalesce(birth_date, current_date-600)) < interval '18 months' then 'BO-TO' when species='BO' and sex='F' then 'BO-CAI-SS' when species='BO' and sex='M' then 'BO-VO-BEO' else class_code end where class_code is null;
-- ===== 3. CÂY TRỒNG =====
create table if not exists crops(code text primary key, name text not null, sci_name text, group_name text not null, -- SINH_KHOI|LUONG_THUC|RAU|CU|QUA|CAY_CONG_NGHIEP|DUOC_LIEU|HOA|CAY_CHE_BONG|CAY_VIEN|NAM
  life_cycle text not null, -- NGAN_NGAY|LAU_NAM|LUU_GOC (cỏ cắt nhiều lứa)
  cycle_days int, cuts_per_year int, yield_norm_kg_ha numeric, unit text default 'kg', season_hint text, water_need text, organic_ok bool default true, products text[] default '{}', -- SKU đầu ra
  varieties text[] default '{}', norms jsonb default '{}'::jsonb, position int default 0, active bool default true);
insert into crops(code,name,group_name,life_cycle,cycle_days,cuts_per_year,yield_norm_kg_ha,products,varieties,position) values
('CO-MOMBASA','Cỏ Mombasa/Ghine','SINH_KHOI','LUU_GOC',45,7,180000,'{NL-CO-TUOI}','{Mombasa,TD58}',1),('CO-VA06','Cỏ VA06/voi','SINH_KHOI','LUU_GOC',50,6,250000,'{NL-CO-TUOI}','{VA06,Voi xanh}',2),('CO-RUZI','Cỏ Ruzi/Mulato','SINH_KHOI','LUU_GOC',40,7,120000,'{NL-CO-TUOI}','{Ruzi,Mulato II}',3),
('BAP-SK','Bắp sinh khối','SINH_KHOI','NGAN_NGAY',85,3,45000,'{NL-BAP-U}','{NK7328,CP511,SSC586}',4),('CAO-LUONG','Cao lương ngọt','SINH_KHOI','NGAN_NGAY',90,3,60000,'{NL-BAP-U}','{Sugargraze}',5),
('LUA','Lúa','LUONG_THUC','NGAN_NGAY',105,2,6000,'{SKU-GAO,NL-ROM}','{ST25,OM18,Đài thơm 8}',6),('BAP-HAT','Bắp lấy hạt','LUONG_THUC','NGAN_NGAY',100,2,7000,'{NL-BAP-HAT}','{}',7),('KHOAI-LANG','Khoai lang','CU','NGAN_NGAY',110,2,15000,'{}','{}',8),('KHOAI-MI','Khoai mì','CU','NGAN_NGAY',270,1,25000,'{}','{}',9),('DAU-NANH','Đậu nành','LUONG_THUC','NGAN_NGAY',90,2,2200,'{NL-BA-DAU}','{}',10),('DAU-PHONG','Đậu phộng','LUONG_THUC','NGAN_NGAY',95,2,3000,'{}','{}',11),
('RAU-AN-LA','Rau ăn lá (cải, xà lách, muống…)','RAU','NGAN_NGAY',30,8,15000,'{SKU-RAU-1}','{Cải ngọt,Cải thìa,Xà lách,Rau muống}',12),('RAU-AN-QUA','Rau ăn quả (cà chua, dưa leo, ớt, bí)','RAU','NGAN_NGAY',75,3,40000,'{SKU-RAU-1}','{Cà chua,Dưa leo,Ớt,Bí đỏ}',13),('RAU-GIA-VI','Rau gia vị – thảo mộc','RAU','NGAN_NGAY',45,6,8000,'{}','{Húng,Tía tô,Sả,Ngò}',14),
('CHUOI','Chuối','QUA','LAU_NAM',365,1,30000,'{SKU-CHUOI}','{Già Nam Mỹ,Tiêu hồng}',15),('DU-DU','Đu đủ','QUA','LAU_NAM',300,1,40000,'{}','{}',16),('BUOI','Bưởi','QUA','LAU_NAM',1460,1,20000,'{}','{Da xanh,Diễn}',17),('XOAI','Xoài','QUA','LAU_NAM',1460,1,12000,'{}','{}',18),('MIT','Mít','QUA','LAU_NAM',1095,1,25000,'{}','{}',19),('OI','Ổi','QUA','LAU_NAM',365,2,25000,'{}','{}',20),('DUA','Dừa','QUA','LAU_NAM',1825,1,10000,'{}','{}',21),
('CA-PHE','Cà phê','CAY_CONG_NGHIEP','LAU_NAM',1095,1,3000,'{}','{}',22),('TIEU','Hồ tiêu','CAY_CONG_NGHIEP','LAU_NAM',1095,1,2500,'{}','{}',23),('MIA','Mía','CAY_CONG_NGHIEP','LUU_GOC',330,1,70000,'{}','{}',24),
('NGHE','Nghệ','DUOC_LIEU','NGAN_NGAY',270,1,20000,'{}','{}',25),('GUNG','Gừng','DUOC_LIEU','NGAN_NGAY',240,1,15000,'{}','{}',26),('DINH-LANG','Đinh lăng','DUOC_LIEU','LAU_NAM',1095,1,8000,'{}','{}',27),
('NAM','Nấm (rơm/bào ngư)','NAM','NGAN_NGAY',30,10,null,'{}','{Rơm,Bào ngư,Linh chi}',28),('KEO','Keo/tràm (viền, chắn gió)','CAY_VIEN','LAU_NAM',2190,1,null,'{}','{}',29),('TRE','Tre (viền, măng)','CAY_VIEN','LAU_NAM',1095,1,null,'{}','{}',30),('HOA','Hoa (cảnh quan/resort)','HOA','NGAN_NGAY',90,3,null,'{}','{}',31)
on conflict (code) do update set name=excluded.name, group_name=excluded.group_name, life_cycle=excluded.life_cycle, products=excluded.products;
alter table plots add column if not exists crop_code text; alter table crop_seasons add column if not exists crop_code text;
update plots set crop_code = case when current_crop ilike '%co%' or current_crop='CO' then 'CO-MOMBASA' when current_crop ilike '%bap%' or current_crop='BAP' then 'BAP-SK' when current_crop='CAU' then 'BAP-SK' when current_crop='SAN' then 'KHOAI-MI' else crop_code end where crop_code is null;
update crop_seasons s set crop_code = coalesce(s.crop_code, (select p.crop_code from plots p where p.id=s.plot_id));
-- ===== 4. SẢN PHẨM / VẬT TƯ =====
create table if not exists product_kinds(code text primary key, name text not null, flow text, -- DAU_VAO|DAU_RA|TRUNG_GIAN
  default_warehouse text, count_cycle text, position int default 0);
insert into product_kinds(code,name,flow,default_warehouse,position) values ('GIONG','Giống (cây/con)','DAU_VAO','K1',1),('THUOC','Thuốc thú y – BVTV','DAU_VAO','K1',2),('VACCINE','Vaccine','DAU_VAO','K1',3),('PHAN_BON','Phân bón – cải tạo đất','DAU_VAO','K1',4),('NGUYEN_LIEU','Nguyên liệu thô (thức ăn/chế biến)','DAU_VAO','K2',5),('BAN_TP','Bán thành phẩm (ủ chua, TMR)','TRUNG_GIAN','K3',6),('THUC_AN','Thức ăn thành phẩm','TRUNG_GIAN','K4',7),('THANH_PHAM','Thành phẩm bán (SKU)','DAU_RA','K5',8),('LANH','Hàng lạnh','DAU_RA','K6',9),('NHIEN_LIEU','Nhiên liệu – năng lượng','DAU_VAO','K7',10),('BAO_BI','Bao bì – tem','DAU_VAO','K9',11),('VAT_TU','Vật tư – phụ tùng – dụng cụ','DAU_VAO','K1',12),('DICH_VU','Dịch vụ (tour, phòng, tiệc)','DAU_RA',null,13)
on conflict (code) do update set name=excluded.name;
insert into products(sku,org_id,name,kind,unit,active,default_warehouse) values ('DV-RESORT','ITRAN','Dịch vụ lưu trú/du lịch (gộp)','DICH_VU','lần',true,null),('DV-TOUR','ITRAN','Tour tham quan','DICH_VU','khách',true,null),('DV-TIEC','ITRAN','Tiệc / sự kiện','DICH_VU','suất',true,null),('DV-PHONG','ITRAN','Phòng lưu trú','DICH_VU','đêm',true,null) on conflict do nothing;
-- ===== VIEW TỔNG HỢP ĐỐI TƯỢNG (số lượng theo phân loại) =====
create or replace view v_obj_people as
select coalesce(s.farm_id,'HQ') as farm_id, s.role, r.name as role_name, s.dept, d.short as dept_name, s.position_code, p.name as position_name, count(*) filter (where s.active) as n_active, count(*) filter (where not s.active) as n_inactive
from staff s left join roles_catalog r on r.code=s.role left join departments d on d.code=s.dept left join positions_catalog p on p.code=s.position_code group by 1,2,3,4,5,6,7;
create or replace view v_obj_animals as
select a.farm_id, a.species, sp.name as species_name, sp.group_name, coalesce(a.class_code,'—') as class_code, c.name as class_name, a.status, count(*) as n, coalesce(sum(a.last_weight_kg),0) as kg, coalesce(sum(a.unit_value),0) as value
from animals a left join species sp on sp.code=a.species left join animal_classes c on c.code=a.class_code group by 1,2,3,4,5,6,7
union all
select g.farm_id, g.species, sp.name, sp.group_name, coalesce(g.class_code, g.kind, 'DAN'), coalesce(c.name, g.kind), g.status, coalesce(sum(g.head_count),0), coalesce(sum(g.biomass_kg),0), 0
from animal_groups g left join species sp on sp.code=g.species left join animal_classes c on c.code=g.class_code where sp.identify_level<>'CA_THE' or sp.identify_level is null group by 1,2,3,4,5,6,7;
create or replace view v_obj_crops as
with base as (select p.farm_id, coalesce(p.crop_code, p.current_crop, '—') as crop_code, count(*) as plots_n, coalesce(sum(p.area_ha),0) as area_ha from plots p where coalesce(p.active,true) group by 1,2)
select b.farm_id, b.crop_code, c.name as crop_name, c.group_name, c.life_cycle, b.plots_n, b.area_ha,
  (select count(*) from crop_seasons s where s.farm_id=b.farm_id and s.crop_code=b.crop_code and s.status in ('DANG_TRONG','THU_HOACH')) as seasons_active,
  (select coalesce(sum(h.qty_kg),0) from harvests h join crop_seasons s on s.id=h.season_id where s.farm_id=b.farm_id and s.crop_code=b.crop_code and h.status='ACTIVE' and h.ts >= date_trunc('year', now())) as harvested_ytd_kg
from base b left join crops c on c.code=b.crop_code;
create or replace view v_obj_products as
select pr.kind, pk.name as kind_name, pk.flow, count(*) as skus, (select count(*) from v_stock_balance b where b.sku in (select sku from products x where x.kind=pr.kind)) as sku_in_stock
from products pr left join product_kinds pk on pk.code=pr.kind where pr.active group by 1,2,3;
do $$ declare t text; begin foreach t in array array['roles_catalog','positions_catalog','species','animal_classes','crops','product_kinds'] loop
  execute format('alter table %I enable row level security', t); execute format('drop policy if exists p_all on %I', t); execute format('create policy p_all on %I for all using (true) with check (app_role() in (''owner'',''director'',''it_engineer'',''tech_head''))', t); execute format('grant select, insert, update on %I to app_user', t);
  execute format('drop trigger if exists audit_%1$s on %1$s; create trigger audit_%1$s after insert or update or delete on %1$s for each row execute function itran_audit()', t); end loop; end $$;
grant select on v_obj_people, v_obj_animals, v_obj_crops, v_obj_products to app_user;
