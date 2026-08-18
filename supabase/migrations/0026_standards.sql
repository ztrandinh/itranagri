-- 0026 · TIÊU CHUẨN & CHỨNG NHẬN (ISO/VietGAP/GlobalG.A.P./HACCP/Halal/hữu cơ EU–USDA–JAS/ASC/BRC…): yêu cầu → bằng chứng (bảng/hồ sơ/quy trình/checklist) → ma trận tuân thủ → sổ chứng nhận
create table if not exists standards(code text primary key, name text not null, issuer text, scope text, -- TRONG_TROT|CHAN_NUOI|THUY_SAN|CHE_BIEN|QUAN_LY|THI_TRUONG
  region text, version text, url text, description text, required_for text[] default '{}', position int default 0, active bool default true);
create table if not exists standard_requirements(id serial primary key, standard_code text references standards, clause text not null, title text not null, requirement text, level text default 'MAJOR', -- MAJOR|MINOR|RECOMMEND|CRITICAL
  evidence_tables text[] default '{}', evidence_records text[] default '{}', process_codes text[] default '{}', checklist_sop text, frequency text, owner_dept text, unique(standard_code, clause));
create table if not exists certifications(id text primary key, farm_id text, org_id text default 'ITRAN', standard_code text references standards, body text, cert_number text, scope text, issued_on date, valid_to date, status text default 'HIEU_LUC', -- CHUAN_BI|DANH_GIA|HIEU_LUC|TAM_DINH_CHI|HET_HAN|THU_HOI
  next_audit date, file text, note text, created_at timestamptz default now(), created_by text);
create table if not exists compliance_checks(id uuid primary key default gen_random_uuid(), farm_id text not null, standard_code text, requirement_id int references standard_requirements, checked_at timestamptz default now(), checked_by text, result text, -- DAT|KHONG_DAT|KHONG_AP_DUNG
  evidence text, nc_severity text, corrective_action text, due_date date, closed_at timestamptz);
do $$ declare t text; begin foreach t in array array['standards','standard_requirements','certifications','compliance_checks'] loop
  execute format('alter table %I enable row level security', t); execute format('drop policy if exists p_all on %I', t);
  if t in ('certifications','compliance_checks') then execute format('create policy p_all on %I for all using (farm_id is null or can_see_farm(farm_id)) with check (true)', t); else execute format('create policy p_all on %I for all using (true) with check (app_role() in (''owner'',''director'',''it_engineer'',''tech_head'',''auditor''))', t); end if;
  execute format('grant select, insert, update on %I to app_user', t);
  execute format('drop trigger if exists audit_%1$s on %1$s; create trigger audit_%1$s after insert or update or delete on %1$s for each row execute function itran_audit()', t); end loop;
  grant usage, select on all sequences in schema public to app_user; end $$;
insert into standards(code,name,issuer,scope,region,description,required_for,position) values
('VIETGAP-TT','VietGAP trồng trọt (TCVN 11892-1:2017)','Bộ NN&PTNT / VN','TRONG_TROT','VN','Thực hành nông nghiệp tốt: đất–nước, giống, phân, BVTV, thu hoạch, truy xuất, người lao động','{SIEU_THI,XUAT_KHAU_ASEAN}',1),
('VIETGAP-CN','VietGAHP chăn nuôi (QĐ 4653/2015, bò/gà/lợn)','Bộ NN&PTNT / VN','CHAN_NUOI','VN','ATSH, giống, thức ăn, thú y, chất thải, ghi chép, truy xuất','{SIEU_THI,HORECA}',2),
('VIETGAP-TS','VietGAP thủy sản (QĐ 3824/2014)','Bộ NN&PTNT / VN','THUY_SAN','VN','Ao/RAS: giống, nước, thức ăn, thuốc, thu hoạch','{SIEU_THI}',3),
('ORGANIC-VN','Hữu cơ Việt Nam (TCVN 11041; NĐ 109/2018)','Bộ KHCN / VN','TRONG_TROT','VN','Chuyển đổi, đầu vào cho phép, cách ly, không GMO, sổ sách','{HUU_CO_NOI_DIA}',4),
('EU-ORGANIC','EU Organic (Reg. (EU) 2018/848)','EU','TRONG_TROT','EU','Hữu cơ châu Âu: chuyển đổi 2–3 năm, đầu vào Annex, phúc lợi động vật, kiểm soát nhóm','{XUAT_KHAU_EU}',5),
('USDA-NOP','USDA Organic (NOP 7 CFR 205)','USDA / Mỹ','TRONG_TROT','US','Kế hoạch hệ thống hữu cơ (OSP), chất được phép (National List), lưu hồ sơ 5 năm','{XUAT_KHAU_MY}',6),
('JAS-ORGANIC','JAS Organic (Nhật)','MAFF / Nhật','TRONG_TROT','JP','Hữu cơ Nhật, người xếp loại (grader) nội bộ','{XUAT_KHAU_NHAT}',7),
('GLOBALGAP','GlobalG.A.P. IFA v6 (Crops / Livestock / Aquaculture)','GlobalG.A.P. / EU','TRONG_TROT','GLOBAL','ATTP, môi trường, phúc lợi lao động, truy xuất GGN','{XUAT_KHAU_EU,SIEU_THI_QT}',8),
('ISO22000','ISO 22000:2018 (FSMS)','ISO','CHE_BIEN','GLOBAL','Hệ thống quản lý ATTP: PRP, HACCP, truy xuất, thu hồi','{CHE_BIEN,XUAT_KHAU}',9),
('HACCP','HACCP (Codex CXC 1-1969, TCVN 5603)','Codex','CHE_BIEN','GLOBAL','7 nguyên tắc: mối nguy, CCP, giới hạn tới hạn, giám sát, khắc phục, thẩm tra, hồ sơ','{CHE_BIEN,HORECA}',10),
('HALAL','Halal (MUI / JAKIM / GCC · TCVN 12944)','Cơ quan Halal','CHE_BIEN','GLOBAL','Nguyên liệu, giết mổ, tách biệt, truy xuất, giám sát Halal','{XUAT_KHAU_HALAL,TRUNG_DONG}',11),
('BRCGS','BRCGS Food Safety v9','BRC / Anh','CHE_BIEN','GLOBAL','Chuẩn bán lẻ Anh/EU: HACCP, văn hóa ATTP, kiểm soát nhà máy','{SIEU_THI_QT}',12),
('ASC','ASC (Aquaculture Stewardship Council)','ASC','THUY_SAN','GLOBAL','Thủy sản bền vững: môi trường, xã hội, thức ăn, kháng sinh','{XUAT_KHAU_EU}',13),
('ISO9001','ISO 9001:2015 (QMS)','ISO','QUAN_LY','GLOBAL','Quản lý chất lượng: quy trình, KPI, cải tiến','{}',14),
('ISO14001','ISO 14001:2015 (EMS)','ISO','QUAN_LY','GLOBAL','Quản lý môi trường: khía cạnh, tuân thủ, quan trắc','{GIAY_PHEP_MT}',15),
('RAINFOREST','Rainforest Alliance 2020','RA','TRONG_TROT','GLOBAL','Nông nghiệp bền vững, xã hội, đa dạng sinh học','{XUAT_KHAU_EU}',16),
('CN-GB','Trung Quốc: GACC đăng ký vùng trồng/cơ sở đóng gói (Lệnh 248/249)','GACC / TQ','THI_TRUONG','CN','Mã vùng trồng, cơ sở đóng gói, kiểm dịch, dư lượng','{XUAT_KHAU_TQ}',17),
('KR-MFDS','Hàn Quốc: MFDS PLS dư lượng + KFDA','MFDS / HQ','THI_TRUONG','KR','Danh mục dư lượng mặc định 0,01 ppm','{XUAT_KHAU_HAN}',18)
on conflict (code) do update set name=excluded.name, description=excluded.description, required_for=excluded.required_for;
insert into standard_requirements(standard_code,clause,title,requirement,level,evidence_tables,evidence_records,process_codes,frequency,owner_dept) values
('VIETGAP-TT','1','Đánh giá & lựa chọn vùng sản xuất','Đất, nước không ô nhiễm; phân tích định kỳ','MAJOR','{lab_samples,plots}','{HS-DAT-NUOC}','{P-TT-03,P-CT-01}','Năm','TT'),
('VIETGAP-TT','2','Giống & gốc ghép','Nguồn gốc rõ, hồ sơ giống','MAJOR','{crop_seasons}','{HS-CANH-TAC}','{P-CT-02}','Vụ','TT'),
('VIETGAP-TT','3','Quản lý đất & giá thể','Không xói mòn, phân tích đất','MINOR','{lab_samples,crop_logs}','{HS-DAT-NUOC}','{P-CT-03}','Năm','TT'),
('VIETGAP-TT','4','Phân bón & chất bổ sung','Danh mục cho phép, ghi chép liều/ngày/người','MAJOR','{crop_inputs}','{HS-CANH-TAC}','{P-CT-03}','Mỗi lần','TT'),
('VIETGAP-TT','5','Nước tưới','Nguồn, phân tích vi sinh/kim loại','MAJOR','{lab_samples,sensor_reads}','{HS-DAT-NUOC}','{P-CT-03}','Năm','TT'),
('VIETGAP-TT','6','Thuốc BVTV & hóa chất','Danh mục cho phép, PHI, người phun có chứng chỉ, kho riêng','CRITICAL','{crop_inputs,staff}','{HS-CANH-TAC}','{P-CT-04}','Mỗi lần','TT'),
('VIETGAP-TT','7','Thu hoạch & xử lý sau thu hoạch','Đúng PHI, dụng cụ sạch, tách biệt, ghi lô','MAJOR','{harvests,inventory_moves}','{HS-THU-HOACH}','{P-TT-02,P-CT-06}','Mỗi lần','TT'),
('VIETGAP-TT','8','Quản lý chất thải','Thu gom, xử lý bao bì thuốc','MINOR','{batch_logs,incidents}','{HS-MOI-TRUONG}','{P-SH-01}','Tháng','SH'),
('VIETGAP-TT','9','Người lao động','Tập huấn, sức khỏe, PPE','MAJOR','{staff,checklist_runs}','{HS-NHAN-SU}','{P-NS-02}','Năm','HCNS'),
('VIETGAP-TT','10','Ghi chép, lưu hồ sơ, truy xuất, thu hồi','Nhật ký sản xuất ≥3 năm, truy được lô','CRITICAL','{crop_seasons,crop_logs,harvests,lots}','{HS-CANH-TAC,HS-TRUY-XUAT}','{P-TT-02,P-QA-02}','Liên tục','QA'),
('VIETGAP-TT','11','Kiểm tra nội bộ','Tự đánh giá ≥1 lần/năm, khắc phục','MAJOR','{compliance_checks}','{HS-AUDIT}','{P-QA-01}','Năm','QA'),
('VIETGAP-TT','12','Khiếu nại & giải quyết','Sổ khiếu nại','MINOR','{customer_messages,incidents}','{HS-BAN-HANG}','{P-QA-02}','Mỗi lần','KDM'),
('VIETGAP-CN','1','Địa điểm & chuồng trại','Cách ly khu dân cư, ATSH, hàng rào, hố sát trùng','MAJOR','{facilities,locations,gate_logs}','{HS-PHAP-LY}','{P-VN-05}','Năm','KTCN'),
('VIETGAP-CN','2','Con giống','Nguồn gốc, kiểm dịch, cách ly 21 ngày','MAJOR','{intake_lots,animals}','{HS-SO-DAN}','{P-KT-01,P-VN-02}','Mỗi lô','KTCN'),
('VIETGAP-CN','3','Thức ăn & nước uống','Nguồn gốc, không cấm, kiểm nước','MAJOR','{feed_logs,recipes,lab_samples}','{HS-THUC-AN}','{P-D5-01,P-VN-03}','Tháng','D5'),
('VIETGAP-CN','4','Thú y & thuốc','Phác đồ, ngưng thuốc, sổ thuốc, kê đơn','CRITICAL','{animal_events,treatment_protocols}','{HS-THU-Y}','{P-KT-03,P-VN-06}','Mỗi lần','KTCN'),
('VIETGAP-CN','5','Vệ sinh & ATSH','Sát trùng, khách, xe, quần áo','MAJOR','{checklist_runs,gate_logs}','{HS-ATTP}','{P-VN-05}','Ngày','KTCN'),
('VIETGAP-CN','6','Chất thải & môi trường','Biogas/compost, nước thải đạt QCVN','MAJOR','{batch_logs,sensor_reads}','{HS-MOI-TRUONG}','{P-SH-01,P-SH-02}','Tháng','SH'),
('VIETGAP-CN','7','Ghi chép & truy xuất','Sổ đàn, sự kiện cá thể, xuất bán','CRITICAL','{animals,animal_events}','{HS-SO-DAN}','{P-VN-07}','Liên tục','KTCN'),
('VIETGAP-CN','8','Người lao động','Tập huấn, SK, PPE','MAJOR','{staff}','{HS-NHAN-SU}','{P-NS-02}','Năm','HCNS'),
('GLOBALGAP','AF','All Farm Base: quản lý trại, hồ sơ, sức khỏe & an toàn NLĐ, môi trường, truy xuất GGN','Hồ sơ ≥2 năm, đánh giá rủi ro, đào tạo, GGN','MAJOR','{documents,staff,checklist_runs,lots}','{HS-AUDIT,HS-NHAN-SU}','{P-QA-01}','Năm','QA'),
('GLOBALGAP','CB','Crops Base: giống, đất, phân, tưới, IPM/BVTV, dư lượng, thu hoạch','MRL thị trường đích, phân tích dư lượng theo rủi ro','CRITICAL','{crop_seasons,crop_inputs,harvests,lab_samples}','{HS-CANH-TAC,HS-THU-HOACH}','{P-TT-02,P-CT-04}','Vụ','TT'),
('GLOBALGAP','LB','Livestock Base: định danh, thức ăn, thú y, phúc lợi, vận chuyển','Mỗi con có mã, sổ thuốc, phúc lợi 5 tự do','MAJOR','{animals,animal_events,feed_logs}','{HS-SO-DAN,HS-THU-Y}','{P-KT-01,P-KT-03}','Liên tục','KTCN'),
('GLOBALGAP','AB','Aquaculture Base: giống, nước, thức ăn, thuốc, thu hoạch','Chất lượng nước, không kháng sinh cấm','MAJOR','{animal_groups,sensor_reads,feed_logs}','{HS-SO-DAN}','{P-VN-09}','Liên tục','KTCN'),
('GLOBALGAP','FV','Fruit & Vegetables: vệ sinh thu hoạch, sơ chế, nước rửa, kho lạnh','Đánh giá rủi ro vệ sinh, tách biệt','MAJOR','{harvests,batch_logs,sensor_reads}','{HS-THU-HOACH,HS-ATTP}','{P-CT-06}','Mỗi lô','D5'),
('ISO22000','4-7','Bối cảnh, lãnh đạo, hoạch định, hỗ trợ (nguồn lực, năng lực, truyền thông, tài liệu)','Chính sách ATTP, mục tiêu, đào tạo, kiểm soát tài liệu','MAJOR','{sops,staff,documents}','{HS-ATTP,HS-NHAN-SU}','{P-QA-01,P-NS-02}','Năm','QA'),
('ISO22000','8.2','PRP (chương trình tiên quyết)','Vệ sinh, dịch hại, nước, chất thải, bảo trì, hiệu chuẩn','MAJOR','{checklist_runs,calibrations,tasks}','{HS-ATTP,HS-THIET-BI}','{P-D5-02,P-CN-01}','Ngày','D5'),
('ISO22000','8.3','Truy xuất nguồn gốc','1 bước trước – 1 bước sau, thu hồi mô phỏng','CRITICAL','{lots,inventory_moves,batch_logs}','{HS-TRUY-XUAT}','{P-QA-02,P-SX-03}','Quý','QA'),
('ISO22000','8.5','Phân tích mối nguy & kế hoạch HACCP/OPRP','Sơ đồ quy trình, CCP, giới hạn, giám sát','CRITICAL','{batch_logs,checklist_runs}','{HS-ATTP}','{P-D5-02}','Mỗi mẻ','D5'),
('ISO22000','8.9','Kiểm soát sản phẩm không phù hợp, khắc phục, thu hồi','NC log, hành động khắc phục, thu hồi','MAJOR','{incidents,compliance_checks,lots}','{HS-ATTP}','{P-QA-02}','Mỗi lần','QA'),
('ISO22000','9-10','Đánh giá kết quả, audit nội bộ, cải tiến','Audit nội bộ, xem xét lãnh đạo, KPI','MAJOR','{compliance_checks,kpi_results}','{HS-AUDIT}','{P-QA-01}','Năm','QA'),
('HACCP','1-7','7 nguyên tắc HACCP','Mối nguy → CCP → giới hạn → giám sát → khắc phục → thẩm tra → hồ sơ','CRITICAL','{batch_logs,checklist_runs,calibrations}','{HS-ATTP}','{P-D5-02}','Mỗi mẻ','D5'),
('HALAL','1','Nguyên liệu Halal & không haram','Danh mục nguyên liệu có chứng nhận, không cồn/heo','CRITICAL','{products,partners,documents}','{HS-TRUY-XUAT}','{P-KHO-01}','Mỗi lô','QA'),
('HALAL','2','Giết mổ theo nghi thức (nếu có)','Người Hồi giáo, quy trình, giám sát','CRITICAL','{batch_logs}','{HS-ATTP}','{P-VN-07}','Mỗi lần','D5'),
('HALAL','3','Tách biệt & không nhiễm chéo','Kho, dây chuyền, dụng cụ riêng; vệ sinh (sertu)','MAJOR','{warehouses,locations,checklist_runs}','{HS-KHO}','{P-KHO-03}','Ngày','CCU'),
('HALAL','4','Truy xuất & nhãn Halal','Lô, logo, hồ sơ NCC','MAJOR','{lots,products}','{HS-TRUY-XUAT}','{P-SX-03}','Mỗi lô','QA'),
('HALAL','5','Ban Halal nội bộ & đào tạo','Người phụ trách, đào tạo','MINOR','{staff}','{HS-NHAN-SU}','{P-NS-02}','Năm','QA'),
('EU-ORGANIC','1','Chuyển đổi (2 năm cây hàng năm/3 năm lâu năm) & song song','Ghi ngày bắt đầu, tách biệt lô hữu cơ','CRITICAL','{crop_seasons,plots}','{HS-CANH-TAC}','{P-CT-01}','Năm','TT'),
('EU-ORGANIC','2','Đầu vào chỉ trong Annex (phân, BVTV, TACN)','Kiểm tra danh mục trước dùng','CRITICAL','{crop_inputs,feed_logs,products}','{HS-CANH-TAC,HS-THUC-AN}','{P-CT-03,P-CT-04}','Mỗi lần','TT'),
('EU-ORGANIC','3','Chăn nuôi hữu cơ: thức ăn hữu cơ, phúc lợi, không kháng sinh dự phòng','Mật độ, chăn thả, ngưng thuốc x2','MAJOR','{feed_logs,animal_events}','{HS-THU-Y}','{P-KT-03,P-VN-03}','Liên tục','KTCN'),
('EU-ORGANIC','4','Sổ sách & cân bằng khối lượng','Đầu vào–đầu ra khớp, kiểm tra hàng năm','MAJOR','{inventory_moves,harvests,recon_results}','{HS-KHO}','{P-CCU-02}','Năm','QA'),
('EU-ORGANIC','5','Chứng nhận & nhãn EU','Cơ quan kiểm soát, COI nhập khẩu','MAJOR','{certifications,trade_documents}','{HS-XNK}','{P-XNK-01}','Năm','XNK'),
('USDA-NOP','1','Organic System Plan (OSP)','Kế hoạch hệ thống hữu cơ, cập nhật hàng năm','MAJOR','{documents,crop_seasons}','{HS-CANH-TAC}','{P-QA-01}','Năm','QA'),
('USDA-NOP','2','National List – chất cho phép/cấm','Kiểm soát đầu vào','CRITICAL','{crop_inputs,products}','{HS-CANH-TAC}','{P-CT-04}','Mỗi lần','TT'),
('USDA-NOP','3','Lưu hồ sơ 5 năm & truy xuất','Hồ sơ đầy đủ, kiểm toán khối lượng','MAJOR','{audit_log,lots}','{HS-AUDIT}','{P-QT-02}','Liên tục','QA'),
('ASC','1','Tuân thủ pháp luật & vị trí','Giấy phép, ĐTM','MAJOR','{documents}','{HS-PHAP-LY}','{P-SH-02}','Năm','QA'),
('ASC','2','Môi trường: nước thải, thức ăn (FFDR), thoát ra','Quan trắc nước, nguồn thức ăn','MAJOR','{sensor_reads,feed_logs}','{HS-MOI-TRUONG}','{P-VN-09}','Tháng','KTCN'),
('ASC','3','Sức khỏe & kháng sinh','Không kháng sinh cấm, thú y kê đơn','CRITICAL','{animal_events}','{HS-THU-Y}','{P-KT-03}','Mỗi lần','KTCN'),
('ASC','4','Xã hội & lao động','HĐLĐ, an toàn, không lao động trẻ em','MAJOR','{staff}','{HS-NHAN-SU}','{P-NS-04}','Năm','HCNS'),
('CN-GB','1','Mã số vùng trồng & cơ sở đóng gói (GACC)','Đăng ký, nhật ký, giám sát dịch hại','CRITICAL','{plots,crop_seasons,facilities}','{HS-CANH-TAC}','{P-XNK-01}','Năm','XNK'),
('KR-MFDS','1','PLS dư lượng','Chỉ dùng hoạt chất có MRL Hàn Quốc; phân tích trước xuất','CRITICAL','{crop_inputs,lab_samples}','{HS-CANH-TAC}','{P-XNK-01}','Mỗi lô','XNK')
on conflict (standard_code, clause) do update set title=excluded.title, requirement=excluded.requirement, evidence_tables=excluded.evidence_tables, evidence_records=excluded.evidence_records, process_codes=excluded.process_codes;
-- View tuân thủ: theo trại × chuẩn: số yêu cầu, có bằng chứng dữ liệu 90 ngày (bảng có bản ghi), kết quả kiểm tra gần nhất
create or replace function itran_table_has_rows(p_table text, p_farm text, p_days int) returns bool language plpgsql stable as $$
declare n int; has_ts bool; has_farm bool; begin
  if to_regclass(p_table) is null then return false; end if;
  select exists(select 1 from information_schema.columns where table_name=p_table and column_name='ts'), exists(select 1 from information_schema.columns where table_name=p_table and column_name='farm_id') into has_ts, has_farm;
  execute format('select count(*) from %I where 1=1 %s %s limit 1', p_table, case when has_farm then format('and farm_id=%L', p_farm) else '' end, case when has_ts then format('and ts >= now() - interval ''%s days''', p_days) else '' end) into n;
  return n > 0; end $$;
create or replace view v_compliance as
select f.id as farm_id, s.code as standard_code, s.name as standard_name, s.scope, count(r.id) as requirements,
  count(r.id) filter (where exists (select 1 from unnest(r.evidence_tables) t where itran_table_has_rows(t, f.id, 90))) as with_evidence_90d,
  count(r.id) filter (where (select result from compliance_checks c where c.farm_id=f.id and c.requirement_id=r.id order by checked_at desc limit 1)='DAT') as checked_ok,
  count(r.id) filter (where (select result from compliance_checks c where c.farm_id=f.id and c.requirement_id=r.id order by checked_at desc limit 1)='KHONG_DAT') as checked_nc,
  (select status from certifications c where c.farm_id=f.id and c.standard_code=s.code order by valid_to desc nulls last limit 1) as cert_status,
  (select valid_to from certifications c where c.farm_id=f.id and c.standard_code=s.code order by valid_to desc nulls last limit 1) as cert_valid_to
from farms f cross join standards s left join standard_requirements r on r.standard_code=s.code where s.active group by f.id, s.code, s.name, s.scope, s.position order by f.id, s.position;
grant select on v_compliance to app_user; grant execute on function itran_table_has_rows(text,text,int) to app_user;
-- Alert: chứng nhận sắp hết hạn (90 ngày) — luật cấu hình kiểu 'due' mở rộng
insert into alert_rules(code,version,farm_id,name,source,expr,level,recipients,channels,description) values ('AL-CERT-EXPIRE',1,'GLOBAL','Chứng nhận sắp hết hạn (90 ngày)','custom','{"type":"cert_expire","value":90}','VANG','{tech_head,director,owner}','{app,zalo}','Từ bảng certifications') on conflict do nothing;
insert into records_catalog(code,name,domain,legal_basis,tables,export_kind,retention_years,owner_role,required_for,description,position) values ('HS-TUAN-THU','Hồ sơ tuân thủ tiêu chuẩn & chứng nhận','QUAN_TRI','VietGAP/GlobalG.A.P./ISO 22000/HACCP/Halal/EU-USDA-JAS Organic/ASC','{standards,standard_requirements,certifications,compliance_checks}','table:compliance_checks',5,'auditor','{XUAT_KHAU,SIEU_THI}','Ma trận yêu cầu → bằng chứng, kết quả tự đánh giá, NC & khắc phục, sổ chứng nhận',21) on conflict (code) do nothing;
-- Nguồn văn bản gốc (đối chiếu — số điều khoản trong bảng là bản tóm tắt để lập ma trận, không thay thế văn bản)
update standards set url = case code
  when 'VIETGAP-TT' then 'https://tieuchuan.vsqi.gov.vn (TCVN 11892-1:2017)' when 'VIETGAP-CN' then 'https://cucchannuoi.gov.vn (QĐ 4653/QĐ-BNN-CN 2015)' when 'VIETGAP-TS' then 'https://tongcucthuysan.gov.vn (QĐ 3824/QĐ-BNN-TCTS 2014)'
  when 'ORGANIC-VN' then 'TCVN 11041-1/2/3:2017; Nghị định 109/2018/NĐ-CP' when 'EU-ORGANIC' then 'https://eur-lex.europa.eu/eli/reg/2018/848' when 'USDA-NOP' then 'https://www.ecfr.gov/current/title-7/part-205'
  when 'JAS-ORGANIC' then 'https://www.maff.go.jp/e/policies/standard/jas/' when 'GLOBALGAP' then 'https://www.globalgap.org/documents/ (IFA v6 Smart/GFS)' when 'ISO22000' then 'https://www.iso.org/standard/65464.html'
  when 'HACCP' then 'Codex CXC 1-1969 (rev. 2020); TCVN 5603:2023' when 'HALAL' then 'TCVN 12944:2020; MS 1500:2019 (JAKIM); GSO 2055-1' when 'BRCGS' then 'https://www.brcgs.com/our-standards/food-safety/'
  when 'ASC' then 'https://asc-aqua.org/what-we-do/our-standards/' when 'ISO9001' then 'https://www.iso.org/standard/62085.html' when 'ISO14001' then 'https://www.iso.org/standard/60857.html'
  when 'RAINFOREST' then 'https://www.rainforest-alliance.org/business/certification/' when 'CN-GB' then 'GACC Decree 248/249 (2021); Nghị định thư VN–TQ theo mặt hàng' when 'KR-MFDS' then 'https://www.mfds.go.kr (PLS 2019)' end;
