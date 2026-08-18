-- 0029 · DANH MỤC BIẾN ĐẦU VÀO / ĐẦU RA CHĂN NUÔI (và trồng trọt) — mỗi biến chỉ rõ: bảng/cột/loại sự kiện ghi ở đâu, đơn vị, tần suất, cách thu (tay/cảm biến/tự tính), trạng thái đã có hay kế hoạch
create table if not exists variable_catalog(code text primary key, domain text not null, -- CHAN_NUOI|TRONG_TROT|CHE_BIEN|KHO|TAI_CHINH
  direction text not null, -- DAU_VAO|DAU_RA|TRANG_THAI|MOI_TRUONG|KINH_TE
  group_name text, name text not null, unit text, source_table text, source_col text, event_type text, capture text, -- TAY|CAM_BIEN|TU_TINH|NHAP_FILE
  frequency text, level text, -- CA_THE|DAN|CHUONG|TRAI
  formula text, status text default 'DA_CO', -- DA_CO|KE_HOACH
  norm_key text, position int default 0);
alter table variable_catalog enable row level security; drop policy if exists p_all on variable_catalog; create policy p_all on variable_catalog for all using (true) with check (app_role() in ('owner','director','it_engineer','tech_head')); grant select, insert, update on variable_catalog to app_user;
drop trigger if exists audit_variable_catalog on variable_catalog; create trigger audit_variable_catalog after insert or update or delete on variable_catalog for each row execute function itran_audit();
insert into variable_catalog(code,domain,direction,group_name,name,unit,source_table,source_col,event_type,capture,frequency,level,formula,status,position) values
-- ===== ĐẦU VÀO: con giống =====
('CN-IN-01','CHAN_NUOI','DAU_VAO','Con giống','Số con nhập theo lô (loài, giống, giới, tuổi, nguồn, giá)','con','intake_lots','head,species,breed,source,unit_cost',null,'TAY','mỗi lô','DAN',null,'DA_CO',1),
('CN-IN-02','CHAN_NUOI','DAU_VAO','Con giống','Mã cá thể (RFID/thẻ tai/QR), cha, mẹ, ngày sinh, trọng lượng nhập','—','animals','id,rfid,visual_tag,dam_id,sire_code,birth_date,last_weight_kg','NHAP','TAY','mỗi con','CA_THE',null,'DA_CO',2),
('CN-IN-03','CHAN_NUOI','DAU_VAO','Con giống','Tinh/phôi (lô tinh, đực giống, giá)','liều','animal_events','detail.semen_lot','PHOI','TAY','mỗi lần','CA_THE',null,'DA_CO',3),
('CN-IN-04','CHAN_NUOI','DAU_VAO','Con giống','Giấy kiểm dịch, chứng nhận nguồn gốc','file','documents','file,kind',null,'NHAP_FILE','mỗi lô','DAN',null,'DA_CO',4),
-- ===== ĐẦU VÀO: thức ăn – nước =====
('CN-IN-10','CHAN_NUOI','DAU_VAO','Thức ăn','Kg thức ăn phát theo bữa/nhóm/công thức (KH vs thực)','kg','feed_logs','planned_kg,qty_kg,recipe_id,meal',null,'TAY/cân','mỗi bữa','DAN',null,'DA_CO',10),
('CN-IN-11','CHAN_NUOI','DAU_VAO','Thức ăn','Thành phần công thức TMR (nguyên liệu, %, DM, CP, ME)','%','recipes','items,dm_pct,cp_pct',null,'TAY','mỗi công thức','TRAI',null,'DA_CO',11),
('CN-IN-12','CHAN_NUOI','DAU_VAO','Thức ăn','Nguyên liệu nhập kho (cỏ, bắp ủ, cám, khoáng, rỉ mật…) theo lô, giá','kg/đ','inventory_moves','sku,qty,unit_cost,lot_id',null,'TAY/cân','mỗi lần','TRAI',null,'DA_CO',12),
('CN-IN-13','CHAN_NUOI','DAU_VAO','Thức ăn','Thức ăn thừa/ăn thừa (refusal)','kg','animal_events','value','AN_THUA','TAY','mỗi ngày','DAN','feed_kg − refusal = intake','DA_CO',13),
('CN-IN-14','CHAN_NUOI','DAU_VAO','Nước','Nước uống (m³ theo chuồng)','m³','sensor_reads','metric=water_m3',null,'CAM_BIEN','liên tục','CHUONG',null,'DA_CO',14),
('CN-IN-15','CHAN_NUOI','DAU_VAO','Thức ăn','Chất lượng nguyên liệu (ẩm độ, DM, mốc/aflatoxin, COA NCC)','%','lab_samples','results,kind=TA',null,'NHAP_FILE','mỗi lô','TRAI',null,'DA_CO',15),
-- ===== ĐẦU VÀO: thú y =====
('CN-IN-20','CHAN_NUOI','DAU_VAO','Thú y','Thuốc/vaccine dùng: tên, lô, liều, đường, người, ngưng thuốc','ml/liều','animal_events','detail.dose_units,withdrawal_until','DIEU_TRI/VACCINE','TAY','mỗi lần','CA_THE',null,'DA_CO',20),
('CN-IN-21','CHAN_NUOI','DAU_VAO','Thú y','Lịch vaccine & phác đồ chuẩn','—','vaccine_schedules,treatment_protocols','*',null,'TAY','định kỳ','TRAI',null,'DA_CO',21),
('CN-IN-22','CHAN_NUOI','DAU_VAO','Thú y','Sát trùng/vệ sinh chuồng (hóa chất, lượng)','lít','checklist_runs,inventory_moves','results,sku',null,'TAY','mỗi ca','CHUONG',null,'DA_CO',22),
-- ===== ĐẦU VÀO: lao động – thiết bị – năng lượng – chi phí =====
('CN-IN-30','CHAN_NUOI','DAU_VAO','Lao động','Giờ công theo vị trí (A1–A5), người ghi từng bản ghi','giờ','shift_notes,tasks,*.created_by','*',null,'TAY/TU_TINH','mỗi ca','TRAI',null,'DA_CO',30),
('CN-IN-31','CHAN_NUOI','DAU_VAO','Thiết bị','Giờ máy trộn/xe phát, nhiên liệu, điện','giờ/lít/kWh','batch_logs,inventory_moves,sensor_reads','machine_hours,sku=NL-DAU,metric=kwh',null,'TAY/CAM_BIEN','mỗi ca','TRAI',null,'DA_CO',31),
('CN-IN-32','CHAN_NUOI','DAU_VAO','Chi phí','Chi phí phân bổ theo trung tâm chi phí (CC-BO/GA/RAS): thức ăn, thuốc, lao động, khấu hao, cố định','đ','v_pl_cc_month,cc_fixed_costs,expense_requests','*',null,'TU_TINH','tháng','TRAI',null,'DA_CO',32),
('CN-IN-33','CHAN_NUOI','DAU_VAO','Chuồng trại','Diện tích/sức chứa chuồng, mật độ (con/m²), vị trí','m²/con','locations,facilities','capacity,area_m2',null,'TAY','khi đổi','CHUONG','head/capacity','DA_CO',33),
-- ===== TRẠNG THÁI / SỰ KIỆN VÒNG ĐỜI =====
('CN-ST-01','CHAN_NUOI','TRANG_THAI','Sinh trưởng','Cân nặng (kg) từng lần cân, ADG','kg; kg/ngày','animal_events','value','CAN','TAY/BLE cân','tháng','CA_THE','(W2−W1)/ngày','DA_CO',40),
('CN-ST-02','CHAN_NUOI','TRANG_THAI','Sinh trưởng','Điểm thể trạng BCS (1–5)','điểm','animal_events','value','BCS','TAY','tháng','CA_THE',null,'DA_CO',41),
('CN-ST-03','CHAN_NUOI','TRANG_THAI','Sinh sản','Động dục, phối (lần, tinh), khám thai (kết quả), đẻ (số con, khó đẻ), cai sữa, sảy','sự kiện','animal_events','event_type,detail.result','DONG_DUC/PHOI/KHAM_THAI/DE/CAI_SUA','TAY','mỗi lần','CA_THE','đậu thai % = KHAM_THAI(+)/PHOI','DA_CO',42),
('CN-ST-04','CHAN_NUOI','TRANG_THAI','Sinh sản','Khoảng cách lứa đẻ, số lứa (parity), ngày mang thai','ngày','v_animal_parity','*',null,'TU_TINH','tháng','CA_THE',null,'DA_CO',43),
('CN-ST-05','CHAN_NUOI','TRANG_THAI','Sức khỏe','Bệnh (loại, triệu chứng, nhiệt độ), điều trị, kết quả','sự kiện','animal_events','event_type,value=nhiệt độ,detail','BENH/DIEU_TRI','TAY','mỗi lần','CA_THE',null,'DA_CO',44),
('CN-ST-06','CHAN_NUOI','TRANG_THAI','Sức khỏe','Ngưng thuốc còn hiệu lực (chặn bán)','ngày','animals','withdrawal_until',null,'TU_TINH','liên tục','CA_THE',null,'DA_CO',45),
('CN-ST-07','CHAN_NUOI','TRANG_THAI','Di chuyển','Chuyển chuồng/nhóm/trại, cách ly vào/ra, phân loại lớp (bê/tơ/SS/vỗ béo)','sự kiện','animal_events,animals','event_type,location_id,class_code','CHUYEN/CACH_LY_VAO/CACH_LY_RA/PHAN_LOAI','TAY','mỗi lần','CA_THE',null,'DA_CO',46),
('CN-ST-08','CHAN_NUOI','TRANG_THAI','Đàn','Đầu con theo loài/lớp/trạng thái/vị trí mỗi ngày (snapshot)','con','herd_daily,v_obj_animals','head',null,'TU_TINH','ngày','TRAI',null,'DA_CO',47),
('CN-ST-09','CHAN_NUOI','TRANG_THAI','Gia cầm','Số con đàn, tuổi tuần, hao hụt, thu trứng/ngày, trứng loại','con/quả','animal_groups,animal_events','head_count,value','SO_LUONG(metric=eggs_counted)/CHET','TAY/băng chuyền','ngày','DAN','tỷ lệ đẻ = trứng/mái','DA_CO',48),
('CN-ST-10','CHAN_NUOI','TRANG_THAI','Thủy sản','DO, pH, NH3/NO2, nhiệt độ, độ mặn; thả giống, mật độ, thu tỉa','mg/l…','sensor_reads,animal_events','metric,value','THA_GIONG/THU_TIA','CAM_BIEN/TAY','giờ/ngày','DAN','FCR = feed/kg tăng','DA_CO',49),
('CN-ST-11','CHAN_NUOI','TRANG_THAI','Môi trường chuồng','Nhiệt độ, ẩm, NH3, CO2, ánh sáng, tiếng ồn chuồng','°C/%/ppm','sensor_reads','metric,value',null,'CAM_BIEN','liên tục','CHUONG',null,'DA_CO',50),
('CN-ST-12','CHAN_NUOI','TRANG_THAI','Ảnh/video','Ảnh cá thể, ảnh sự kiện, giờ live (khách nhận nuôi)','file','animals.photos,animal_events.photo_urls','*',null,'TAY','mỗi lần','CA_THE',null,'DA_CO',51),
-- ===== ĐẦU RA =====
('CN-OUT-01','CHAN_NUOI','DAU_RA','Sản phẩm','Bò/dê xuất bán (con, kg hơi, giá, khách, hóa đơn)','con/kg/đ','animal_events,sales,weigh_tickets','XUAT,qty,price,amount',null,'TAY/cân','mỗi lần','CA_THE',null,'DA_CO',60),
('CN-OUT-02','CHAN_NUOI','DAU_RA','Sản phẩm','Bê sinh (con, giới, trọng lượng sơ sinh)','con','animal_events,animals','DE,birth_date','DE','TAY','mỗi lần','CA_THE',null,'DA_CO',61),
('CN-OUT-03','CHAN_NUOI','DAU_RA','Sản phẩm','Sữa (kg/ngày/con hoặc bồn), chất lượng (SCC, béo, đạm)','kg','animal_events,inventory_moves,lab_samples','value','VAT_SUA','TAY/cân','ngày','CA_THE/DAN',null,'DA_CO',62),
('CN-OUT-04','CHAN_NUOI','DAU_RA','Sản phẩm','Trứng (quả/vỉ, phân loại A/B/loại), nhập K5','quả','inventory_moves,animal_events','sku=SKU-TRUNG*,qty',null,'TAY/băng chuyền','ngày','DAN','tỷ lệ đẻ','DA_CO',63),
('CN-OUT-05','CHAN_NUOI','DAU_RA','Sản phẩm','Gà thịt/cá/lươn thu hoạch (kg, size, giá)','kg','animal_events,inventory_moves,sales','XUAT/THU_TIA,qty',null,'TAY/cân','mỗi đợt','DAN',null,'DA_CO',64),
('CN-OUT-06','CHAN_NUOI','DAU_RA','Sản phẩm','Phân/chất thải (kg ước theo định mức đầu con) → khu D (trùn/BSF/biogas/compost)','kg','batch_logs.inputs,norms','kg',null,'TAY/TU_TINH','ngày','TRAI','head × định mức phân/ngày','DA_CO',65),
('CN-OUT-07','CHAN_NUOI','DAU_RA','Sản phẩm phụ','Phân trùn, ấu trùng BSF, biogas m³/điện kWh, compost','kg/m³/kWh','batch_logs.outputs,inventory_moves,sensor_reads','kg,qty,metric',null,'TAY/CAM_BIEN','mỗi mẻ','TRAI','tỷ lệ tuần hoàn','DA_CO',66),
('CN-OUT-08','CHAN_NUOI','DAU_RA','Hao hụt','Chết (nguyên nhân, xử lý xác), loại thải, mất','con','animal_events','CHET/LOAI,detail.cause',null,'TAY','mỗi lần','CA_THE','chết % năm','DA_CO',67),
('CN-OUT-09','CHAN_NUOI','DAU_RA','Nước thải','Nước thải m³, chỉ tiêu COD/BOD/N/P sau xử lý','m³/mg/l','sensor_reads,lab_samples','metric,results',null,'CAM_BIEN/NHAP_FILE','ngày/quý','TRAI',null,'DA_CO',68),
('CN-OUT-10','CHAN_NUOI','DAU_RA','Khí thải','Ước phát thải CH4/CO2e theo đầu con & khẩu phần (IPCC Tier 1/2)','kg CO2e','agg_daily','metric=ghg_est',null,'TU_TINH','tháng','TRAI','head × hệ số IPCC','KE_HOACH',69),
-- ===== KINH TẾ / KPI =====
('CN-KPI-01','CHAN_NUOI','KINH_TE','KPI','FCR / chi phí thức ăn trên kg tăng trọng','kg/kg; đ/kg','v_pl_cc_month,agg_daily','*',null,'TU_TINH','tháng','DAN','feed_kg / Δkg','DA_CO',80),
('CN-KPI-02','CHAN_NUOI','KINH_TE','KPI','Giá thành/kg hơi, /quả trứng, /kg cá; biên lợi nhuận theo CC','đ','v_pl_cc_month','*',null,'TU_TINH','tháng','TRAI',null,'DA_CO',81),
('CN-KPI-03','CHAN_NUOI','KINH_TE','KPI','Đậu thai %, khoảng cách lứa đẻ, số bê/năm, tỷ lệ đẻ gà, sống %, ADG, chết %, sai số TMR','%','v_kpi_*','*',null,'TU_TINH','ngày/tháng','TRAI',null,'DA_CO',82),
('CN-KPI-04','CHAN_NUOI','KINH_TE','KPI','Giá trị đàn (sổ đàn K8), khấu hao bò sinh sản','đ','v_herd_value','*',null,'TU_TINH','ngày','TRAI',null,'DA_CO',83),
('CN-KPI-05','CHAN_NUOI','KINH_TE','KPI','Ngày-tồn thức ăn/ủ chua, nhu cầu mua dự báo theo đàn & định mức','ngày','v_days_of_stock,v_days_silage,feed_plans','*',null,'TU_TINH','ngày','TRAI',null,'DA_CO',84),
-- ===== TRỒNG TRỌT (tóm tắt) =====
('TT-IN-01','TRONG_TROT','DAU_VAO','Giống','Giống/lô/nguồn/chứng nhận, lượng gieo','kg/cây','crop_seasons,crop_logs','seed_source,seed_lot,qty_kg',null,'TAY','vụ','Ô',null,'DA_CO',100),
('TT-IN-02','TRONG_TROT','DAU_VAO','Phân bón','Loại/lượng/liều/ha/cách bón/người, hữu cơ được phép','kg','crop_inputs','kind,qty,dose_per_ha,organic_allowed',null,'TAY','mỗi lần','Ô',null,'DA_CO',101),
('TT-IN-03','TRONG_TROT','DAU_VAO','BVTV','Thuốc/liều/đối tượng/PHI/thời tiết/PPE','lít','crop_inputs','phi_days,safe_after,target_pest',null,'TAY','mỗi lần','Ô','safe_after = ts+PHI','DA_CO',102),
('TT-IN-04','TRONG_TROT','DAU_VAO','Nước – đất','Nước tưới m³, ẩm đất, phân tích đất/nước, thời tiết','m³/%','crop_logs,sensor_reads,lab_samples','water_m3,metric,results',null,'TAY/CAM_BIEN','ngày','Ô',null,'DA_CO',103),
('TT-IN-05','TRONG_TROT','DAU_VAO','Máy – lao động','Giờ máy, nhiên liệu, công lao động','giờ/lít','crop_logs','machine_hours,fuel_l,created_by',null,'TAY','mỗi lần','Ô',null,'DA_CO',104),
('TT-OUT-01','TRONG_TROT','DAU_RA','Thu hoạch','Kg thu hoạch/cắt, ẩm độ, phẩm cấp, lô, kho đích, năng suất/ha','kg','harvests,crop_logs','qty_kg,moisture_pct,grade,harvest_lot',null,'TAY/cân','mỗi lần','Ô','kg/ha','DA_CO',110),
('TT-OUT-02','TRONG_TROT','DAU_RA','Sinh khối','Cỏ/bắp ủ chua vào K3, ngày-tồn','kg','inventory_moves,v_days_silage','qty',null,'TAY/cân','mỗi lần','TRAI',null,'DA_CO',111),
('TT-OUT-03','TRONG_TROT','DAU_RA','Phụ phẩm','Rơm, thân bắp, phụ phẩm → khu D/TA','kg','batch_logs,inventory_moves','*',null,'TAY','mỗi lần','TRAI',null,'DA_CO',112),
('TT-KPI-01','TRONG_TROT','KINH_TE','KPI','Năng suất/ha, chi phí/kg, nước/kg, PHI vi phạm, tỷ lệ tự cung sinh khối','—','v_crop_dossier,agg_daily','*',null,'TU_TINH','vụ','Ô',null,'DA_CO',120)
on conflict (code) do update set name=excluded.name, source_table=excluded.source_table, source_col=excluded.source_col, event_type=excluded.event_type, capture=excluded.capture, status=excluded.status, formula=excluded.formula;
-- Bổ sung loại sự kiện chuẩn hóa (event_type là text tự do; đây là danh mục gợi ý cho form)
insert into settings(farm_id,key,value,version) values ('GLOBAL','animal.event_types','["NHAP","CACH_LY_VAO","CACH_LY_RA","PHOI","DONG_DUC","KHAM_THAI","DE","SAY","CAI_SUA","PHAN_LOAI","CAN","BCS","BENH","DIEU_TRI","VACCINE","TAY_KY_SINH","CHUYEN","CHET","LOAI","XUAT","SO_LUONG","AN_THUA","VAT_SUA","THA_GIONG","THU_TIA","GHI_CHU"]',1) on conflict do nothing;
