-- 0031 · Bước chi tiết A→Z cho 16 quy trình lõi còn thiếu · điều khoản 8 chuẩn còn trống (theo cấu trúc văn bản gốc, tóm tắt để lập ma trận)
insert into process_steps(process_code,step_no,name,actor_role,dept_code,action,system_where,control,output,tools,materials,inputs,outputs,sla_hours,form_table) values
-- P-KT-01 nhập đàn & định danh
('P-KT-01',1,'Nhận lô, đối chiếu giấy kiểm dịch & PO','team_lead','KTCN','Kiểm giấy kiểm dịch, số con, nguồn; tạo intake_lots','/dan › Nhập lô','Giấy kiểm dịch hợp lệ','intake_lots','{Máy đọc RFID,Cân}','[]','PO giống, giấy kiểm dịch','intake_lots',4,null),
('P-KT-01',2,'Cân, gắn thẻ tai/RFID, tạo mã cá thể','worker','KTCN','Mỗi con: cân, gắn thẻ, chụp ảnh, tạo animals + animal_tags','/dan › Con mới (A5)','100% có mã trong 24h; bê chưa thẻ = tag_pending','animals,animal_tags','{Kìm bấm thẻ,Máy đọc RFID,Cân}','[{"sku":"THE-TAI","qty":1,"unit":"cái/con"}]','Lô đã nhận','animals',24,'animal_events'),
('P-KT-01',3,'Đưa vào khu cách ly 21 ngày','worker','KTCN','animal_events CACH_LY_VAO; việc theo dõi hằng ngày','/ca A5','Khu cách ly riêng','animal_events','{}','[]','Cá thể có mã','animal_events',2,'animal_events'),
('P-KT-01',4,'Kết thúc cách ly, nhập đàn chính thức, cập nhật sổ đàn K8','tech_head','KTCN','CACH_LY_RA, gán nhóm/chuồng; K8 tự tăng','/dan','Không dấu hiệu bệnh 21 ngày','animal_events,inventory_moves','{}','[]','Kết quả theo dõi','sổ đàn K8, giá trị đàn',24,'animal_events'),
-- P-KT-02 sinh sản
('P-KT-02',1,'Phát hiện động dục','worker','KTCN','Ghi DONG_DUC (giờ, dấu hiệu)','/ca A2','Quan sát 3 lần/ngày','animal_events','{}','[]','Bò cái SS','animal_events',12,'animal_events'),
('P-KT-02',2,'Phối (tinh/nhảy trực tiếp)','tech_head','KTCN','PHOI: lô tinh, kỹ thuật viên; xuất kho tinh','/ca A2, /kho','Phối ≤12h sau động dục','animal_events,inventory_moves','{Súng phối,Bình nitơ}','[{"sku":"TINH-BO","qty":1,"unit":"liều"}]','Động dục ghi nhận','animal_events',12,'animal_events'),
('P-KT-02',3,'Khám thai 30–45 ngày','tech_head','KTCN','KHAM_THAI: kết quả (+/−); nếu − quay bước 1','/thu-y','Máy siêu âm','animal_events','{Máy siêu âm}','[]','Ngày phối','animal_events',48,'animal_events'),
('P-KT-02',4,'Theo dõi mang thai, cạn sữa, chuẩn bị đẻ','worker','KTCN','Chuyển nhóm mang thai; khẩu phần; chuồng đẻ','/dan','Nhóm đúng giai đoạn','animal_events','{}','[]','Kết quả khám thai +','animal_events',24,'animal_events'),
('P-KT-02',5,'Đỡ đẻ, ghi bê, cai sữa','worker','KTCN','DE: số bê, giới, cân sơ sinh → animals (tag_pending); CAI_SUA sau 3–6 tháng','/dan › Con mới','Bê có mẹ (dam_id)','animal_events,animals','{Cân}','[]','Ngày dự sinh','bê mới',24,'animal_events'),
-- P-KT-03 thú y
('P-KT-03',1,'Phát hiện bệnh, cách ly, đo nhiệt','worker','KTCN','BENH: triệu chứng, nhiệt độ; chuyển ô cách ly','/ca A2','Báo KTT ≤2h','animal_events','{Nhiệt kế}','[]','Quan sát ca','animal_events',2,'animal_events'),
('P-KT-03',2,'Chẩn đoán, chọn phác đồ, xuất thuốc K1','tech_head','KTCN','DIEU_TRI: thuốc, liều, lô, ngưng thuốc tự tính từ phác đồ','/thu-y, /kho','Chỉ thuốc trong danh mục; ghi lô','animal_events,inventory_moves','{Dụng cụ tiêm}','[{"sku":"THUOC","qty":1,"unit":"liều"}]','Chẩn đoán','animal_events (withdrawal_until)',4,'animal_events'),
('P-KT-03',3,'Theo dõi điều trị, kết thúc, ghi kết quả','worker','KTCN','Cập nhật kết quả (khỏi/chết/loại)','/ca A2','Đủ liệu trình','animal_events','{}','[]','Phác đồ','animal_events',72,'animal_events'),
('P-KT-03',4,'Chặn xuất bán đến hết ngưng thuốc; sổ thuốc thú y','tech_head','KTCN','Trigger chặn sales; xuất medicine-book cho QA','/thu-y','withdrawal_until','medicine-book','{}','[]','—','HS-THU-Y',0,null),
-- P-D5-01 mẻ TMR
('P-D5-01',1,'Nhận kế hoạch khẩu phần theo nhóm','worker','D5','feed_plans của ngày (kg/nhóm/bữa)','/ke-hoach','KH đã duyệt','feed_plans','{}','[]','Đàn theo lớp','kg KH',1,null),
('P-D5-01',2,'Cân nguyên liệu theo công thức','worker','D5','Xuất K2/K3 từng nguyên liệu; cân bàn','/kho, A1','Sai lệch từng nguyên liệu ≤3%','inventory_moves','{Cân bàn,Máy xúc}','[{"sku":"NL-BAP-U","qty":0,"unit":"kg"},{"sku":"NL-CO-TUOI","qty":0,"unit":"kg"}]','Công thức','inventory_moves',1,'inventory_moves'),
('P-D5-01',3,'Trộn, phát ăn theo nhóm, ghi thực tế','worker','D5','feed_logs: planned vs qty; ảnh','/ca A1','Sai số mẻ ≤3%','feed_logs','{Máy trộn TMR,Xe phát}','[]','Nguyên liệu đã cân','feed_logs',2,'feed_logs'),
('P-D5-01',4,'Ghi ăn thừa & điều chỉnh công thức','tech_head','KTCN','AN_THUA; feed_plan_vs_actual','/ke-hoach','Ăn thừa 3–5%','animal_events,feed_plans','{}','[]','feed_logs','điều chỉnh KH',24,null),
-- P-CCU-01 mua hàng
('P-CCU-01',1,'Xác định nhu cầu (ngày-tồn/kế hoạch)','accountant','CCU','Cảnh báo AL-STOCK-DAYS / season_plans / feed_plans','/kho › Ngày-tồn','Ngưỡng 30 ngày','v_days_of_stock','{}','[]','Tiêu thụ 14 ngày','nhu cầu',24,null),
('P-CCU-01',2,'Lập PO, chọn NCC được duyệt (≤35%/nguồn)','accountant','CCU','create_po: dòng hàng, giá, NCC','/ke-toan › PO','NCC approved; giá vs thị trường','purchase_orders','{}','[]','Nhu cầu','purchase_orders',24,null),
('P-CCU-01',3,'Duyệt PO (không tự duyệt)','director','GDT','po_status DUYET','/phe-duyet','ERR_SELF_APPROVE','purchase_orders','{}','[]','PO','PO duyệt',24,null),
('P-CCU-01',4,'Nhận hàng: cân/đếm, QC, COA, nhập kho theo lô','worker','CCU','gate_logs + weigh_tickets + inventory_moves NHAP_MUA (lot, hạn, giá)','/ca A8/A10','Cân khớp PO ±2%; COA','inventory_moves,weigh_tickets,documents','{Cân 40T}','[]','PO duyệt','inventory_moves',4,'inventory_moves'),
('P-CCU-01',5,'Đối chiếu công nợ, thanh toán','accountant','TCKT','expense_requests/paid; GL 331→111/112','/ke-toan','Hóa đơn hợp lệ','expense_requests,journal_entries','{}','[]','Phiếu nhập','công nợ',72,null),
-- P-CCU-02 kho
('P-CCU-02',1,'Nhập/xuất theo phiếu, quét lô FEFO','worker','CCU','inventory_moves với lot_id; FEFO đỏ chặn','/kho › Nhập/Xuất (A8)','Lô hết hạn không xuất','inventory_moves','{Máy quét QR}','[]','Phiếu/đơn','inventory_moves',1,'inventory_moves'),
('P-CCU-02',2,'Kiểm kê định kỳ (K4–K6 tuần, K1–K3 tháng)','worker','CCU','stocktakes: đếm, chụp ảnh','/kho › Kiểm kê','2 người đếm','stocktakes','{Cân}','[]','Lịch kiểm kê','stocktakes',4,'stocktakes'),
('P-CCU-02',3,'Chênh lệch → phiếu điều chỉnh → duyệt','tech_head','KTCN','adjustments; approve_adjustment (không tự duyệt)','/phe-duyet','Chênh ≤1% mới OK','adjustments,inventory_moves','{}','[]','Kiểm kê','tồn đúng',24,null),
('P-CCU-02',4,'Đối soát cân–kho–sổ (RC) hằng đêm','it_engineer','CNTB','jobs/all → recon_results','/doi-soat','Lệch >5% giải trình','recon_results','{}','[]','Mọi phiếu','RC OK %',24,null),
-- P-DL-02 tiệc
('P-DL-02',1,'Nhận yêu cầu, báo giá (menu × pax)','worker','DL','hosp_events BAO_GIA','/du-lich › Tiệc','Báo giá ≤24h','hosp_events','{}','[]','Yêu cầu khách','báo giá',24,null),
('P-DL-02',2,'Ký/cọc → xác nhận','team_lead','DL','status XAC_NHAN, deposit','/du-lich','Cọc ≥30%','hosp_events','{}','[]','Báo giá','HĐ tiệc',48,null),
('P-DL-02',3,'Chuẩn bị: xuất kho theo menu, phân công nhân sự, dọn địa điểm','team_lead','DL','inventory_moves theo menu×pax; tasks','/kho, /ca','Đủ nguyên liệu trước 24h','inventory_moves,tasks','{Bếp,Bàn ghế,Âm thanh}','[]','Menu×pax','xuất kho',24,'inventory_moves'),
('P-DL-02',4,'Diễn ra, phát sinh vào folio','worker','DL','hosp_folio DICH_VU/PHU_THU','/du-lich','Ghi ngay','hosp_folio','{POS}','[]','Sự kiện','folio',4,'hosp_folio'),
('P-DL-02',5,'Quyết toán, thu tiền, đánh giá khách','accountant','TCKT','folio THANH_TOAN → sales RESORT; HOAN_TAT','/du-lich','Đủ tiền','sales','{}','[]','Folio','doanh thu',24,'hosp_folio'),
-- P-TC-01 chi
('P-TC-01',1,'Lập đề nghị chi (mục đích, CC, chứng từ đính kèm)','worker','*','create_expense + Attachments','/ke-toan','Có chứng từ','expense_requests,documents','{}','[]','Nhu cầu','đề nghị',24,null),
('P-TC-01',2,'Duyệt lần 1 theo hạn mức vai','director','GDT','approve_expense (không tự duyệt)','/phe-duyet','Hạn mức: tổ 2tr, KTT 10tr, GĐ 100tr','expense_requests','{}','[]','Đề nghị','DUYET_1',24,null),
('P-TC-01',3,'Duyệt lần 2 nếu >20tr; >50tr báo chủ','owner','HDQT','approve_expense lần 2; event expense.approved.big','/phe-duyet','2 người khác nhau','expense_requests','{}','[]','DUYET_1','DUYET',24,null),
('P-TC-01',4,'Chi tiền, ghi paid → GL tự hạch toán','accountant','TCKT','paid_at, paid_ref → journal_entries','/ke-toan','Khớp ngân hàng (RC10)','journal_entries,bank_statement_lines','{}','[]','DUYET','sổ chi',24,null),
-- P-HC-01 nhân sự
('P-HC-01',1,'Tuyển & lập hồ sơ, HĐLĐ, tài khoản/PIN','director','HCNS','create_staff; đính kèm HĐLĐ; must_change_pin','/quan-tri?t=staff','HĐLĐ + CCCD','staff,documents','{}','[]','Nhu cầu','tài khoản',72,null),
('P-HC-01',2,'Đào tạo SOP theo vị trí, cấp chứng chỉ, khám SK/ATTP','tech_head','QA','staff.sop_certs, health_check_due','/nhan-su','Đủ trước khi vào ca','staff','{}','[]','Vị trí','chứng chỉ',168,null),
('P-HC-01',3,'Chấm công, ca, giao ca hằng ngày','team_lead','HCNS','attendance check-in/out; shift_notes','/nhan-su › Chấm công, /ca','Giao ca 100%','attendance,shift_notes','{}','[]','Lịch ca','công',24,null),
('P-HC-01',4,'Tính KPI → lương tháng, thưởng phạt','accountant','TCKT','compute_staff_kpi; v_staff_kpi_month; nghỉ phép','/nhan-su › KPI→lương','Ngày 3 hằng tháng','kpi_results,leave_requests','{}','[]','Bản ghi + công','bảng lương',72,null),
('P-HC-01',5,'Nghỉ việc: thu hồi quyền, bàn giao','director','HCNS','active=false, revoke_sessions, biên bản','/quan-tri?t=staff','Bàn giao xong','staff,sessions,documents','{}','[]','Đơn nghỉ','đóng hồ sơ',72,null),
-- P-CN-01 thiết bị
('P-CN-01',1,'Lập lý lịch thiết bị (máy/cảm biến/cân)','it_engineer','CNTB','devices: chu kỳ bảo trì, hiệu chuẩn','/thiet-bi','Đủ serial','devices','{}','[]','Mua/nhập','devices',24,null),
('P-CN-01',2,'Ghi giờ máy & nhiên liệu theo ca','worker','*','crop_logs/batch_logs machine_hours','/ca','Giờ máy hợp lý','crop_logs,batch_logs','{}','[]','Vận hành','giờ máy',1,null),
('P-CN-01',3,'Bảo trì theo chu kỳ (việc tự sinh), hiệu chuẩn cân đúng hạn','worker','CNTB','tasks BAO_DUONG; calibrations','/thiet-bi, /ca A11','Đúng hạn 100%','tasks,calibrations','{Bộ quả cân chuẩn}','[]','Chu kỳ','calibrations',48,'calibrations'),
('P-CN-01',4,'Sự cố thiết bị: báo, sửa, phụ tùng, đóng','it_engineer','CNTB','incidents kind THIET_BI; PO phụ tùng','/gd, /ke-toan','Đóng ≤7 ngày','incidents,purchase_orders','{}','[]','Hỏng','đóng sự cố',168,null),
-- P-QA-01 chứng nhận
('P-QA-01',1,'Chọn chuẩn theo thị trường đích, gap analysis','auditor','QA','/tuan-thu: tự đánh giá từng điều khoản','/tuan-thu','Đủ điều khoản','compliance_checks','{}','[]','Mục tiêu bán','danh sách NC',168,null),
('P-QA-01',2,'Bổ sung SOP/hồ sơ/thiết bị còn thiếu, đào tạo','tech_head','QA','sops, documents, tasks','/sop, /quan-tri','NC đóng','sops,documents','{}','[]','NC','đủ hồ sơ',720,null),
('P-QA-01',3,'Audit nội bộ, khắc phục','auditor','QA','compliance_checks lần 2; đóng NC','/tuan-thu','0 CRITICAL mở','compliance_checks','{}','[]','Hồ sơ','báo cáo audit',168,null),
('P-QA-01',4,'Đánh giá ngoài, nhận chứng nhận, lưu sổ, nhắc tái đánh giá','auditor','QA','certifications (hạn, đánh giá kế); AL-CERT-EXPIRE','/tuan-thu','Chứng nhận còn hạn','certifications','{}','[]','Đăng ký','chứng nhận',720,null),
-- P-QA-02 truy xuất & thu hồi
('P-QA-02',1,'Tiếp nhận khiếu nại/sự cố, xác định lô','worker','KDM','customer_messages/incidents; tra lô QR','/truy-xuat','Truy lô ≤4h','lots,incidents','{}','[]','Khiếu nại','lô liên quan',4,null),
('P-QA-02',2,'Khóa lô, chặn xuất, thông báo khách/kênh','tech_head','QA','lots.status=KHOA; event lot.blocked; notify','/kho','Chặn ngay','lots,notifications','{}','[]','Lô','khóa',2,null),
('P-QA-02',3,'Thu hồi/thu gom, xử lý, phân tích nguyên nhân (5 why), CAPA','tech_head','QA','incidents five_why, capa; batch_logs xử lý','/gd','CAPA có hạn','incidents','{}','[]','Lô khóa','CAPA',72,null),
('P-QA-02',4,'Đóng sự cố, cập nhật SOP, báo cáo','auditor','QA','incidents đóng; sops v+1; báo cơ quan nếu cần','/sop, /audit','Đóng ≤7 ngày','incidents,sops','{}','[]','CAPA','đóng',168,null),
-- P-RD-01
('P-RD-01',1,'Đề xuất đề tài, giả thuyết, KPI đo','tech_head','RD','rd_trials DE_XUAT','/rd','Có KPI đo được','rd_trials','{}','[]','Vấn đề','đề tài',168,null),
('P-RD-01',2,'Duyệt ngân sách & thiết kế nhánh (đối chứng)','director','BGD','rd_trials DUYET; rd_trial_arms','/rd, /phe-duyet','Có nhánh đối chứng','rd_trials,rd_trial_arms','{}','[]','Đề tài','thiết kế',168,null),
('P-RD-01',3,'Chạy thử nghiệm, ghi quan sát, mẫu lab','worker','RD','rd_observations, lab_samples','/rd','Đúng lịch đo','rd_observations,lab_samples','{}','[]','Nhánh','dữ liệu',720,null),
('P-RD-01',4,'Phân tích, kết luận, tri thức hóa → SOP/định mức mới','tech_head','RD','result_summary; knowledge_articles; sops/norms','/rd, /sop','So sánh có ý nghĩa','knowledge_articles,sops,norms','{}','[]','Dữ liệu','SOP mới',168,null),
-- P-MR-01
('P-MR-01',1,'Khảo sát đất–nước–pháp lý–hạ tầng, thế số Lớp B','director','MR','franchise_sites KHAO_SAT; lab_samples','/hq?tab=cty','Đủ pháp lý','franchise_sites,lab_samples','{}','[]','Địa điểm','báo cáo khảo sát',720,null),
('P-MR-01',2,'Thiết kế & dự toán, phê duyệt đầu tư','owner','HDQT','documents bản vẽ; expense/budget','/phe-duyet','HĐQT duyệt','documents,funds','{}','[]','Khảo sát','quyết định',720,null),
('P-MR-01',3,'Khai báo trại (create_farm), khu/kho/CC tự sinh, tuyển & đào tạo','owner','MR','create_farm; create_staff; SOP đào tạo','/hq?tab=cty','9 kho/12 CC/khu','farms,staff','{}','[]','Quyết định','trại mới',720,null),
('P-MR-01',4,'Go-live, checklist chuyển giao, theo dõi 6 tháng theo ICFS','director','MR','transfer_checklists; icfs_score','/tuan-thu, /chuan','ICFS ≥ĐỒNG sau 6 tháng','transfer_checklists,compliance_checks','{}','[]','Trại mới','vận hành',4320,null)
on conflict (process_code, step_no) do update set name=excluded.name, actor_role=excluded.actor_role, dept_code=excluded.dept_code, action=excluded.action, system_where=excluded.system_where, control=excluded.control, output=excluded.output, tools=excluded.tools, materials=excluded.materials, inputs=excluded.inputs, outputs=excluded.outputs, sla_hours=excluded.sla_hours, form_table=excluded.form_table;
update processes p set visible_depts = (select array_agg(distinct x) from (select unnest(coalesce(p.visible_depts,'{}')) as x union select ps.dept_code from process_steps ps where ps.process_code=p.code and ps.dept_code is not null and ps.dept_code<>'*') u) where exists (select 1 from process_steps ps where ps.process_code=p.code);
-- ===== ĐIỀU KHOẢN 8 CHUẨN CÒN TRỐNG =====
insert into standard_requirements(standard_code,clause,title,requirement,level,evidence_tables,evidence_records,process_codes,frequency,owner_dept) values
-- VietGAP thủy sản (QĐ 3824/QĐ-BNN-TCTS): 5 phần: yêu cầu chung, ATTP, sức khỏe thủy sản, môi trường, xã hội
('VIETGAP-TS','1','Yêu cầu chung: pháp lý, hồ sơ, truy xuất, kiểm tra nội bộ','Giấy phép, sơ đồ trại, hồ sơ ≥24 tháng','MAJOR','{documents,animal_groups,compliance_checks}','{HS-PHAP-LY,HS-SO-DAN}','{P-QA-01}','Năm','QA'),
('VIETGAP-TS','2','An toàn thực phẩm: giống, thức ăn, thuốc/hóa chất, thu hoạch','Danh mục cho phép, ngưng thuốc, dụng cụ sạch','CRITICAL','{animal_events,feed_logs,inventory_moves}','{HS-THU-Y,HS-THUC-AN}','{P-VN-09,P-KT-03}','Liên tục','KTCN'),
('VIETGAP-TS','3','Quản lý sức khỏe thủy sản: kế hoạch, ATSH, giám sát bệnh, xử lý chết','Kế hoạch sức khỏe, cách ly, xử lý xác','MAJOR','{animal_events,incidents}','{HS-THU-Y}','{P-VN-09}','Ngày','KTCN'),
('VIETGAP-TS','4','Bảo vệ môi trường: nước cấp/thải, bùn, hóa chất, đa dạng sinh học','Quan trắc nước, xử lý nước thải/bùn','MAJOR','{sensor_reads,lab_samples,batch_logs}','{HS-MOI-TRUONG}','{P-SH-02}','Tháng','SH'),
('VIETGAP-TS','5','Khía cạnh kinh tế – xã hội: lao động, an toàn, cộng đồng','HĐLĐ, đào tạo, an toàn','MINOR','{staff}','{HS-NHAN-SU}','{P-NS-02}','Năm','HCNS'),
-- Hữu cơ VN TCVN 11041-2 (trồng trọt) / -3 (chăn nuôi); NĐ 109/2018
('ORGANIC-VN','1','Chuyển đổi & vùng đệm, cách ly nguồn ô nhiễm','Thời gian chuyển đổi 12 tháng (hàng năm)/18 tháng (lâu năm); vùng đệm','CRITICAL','{crop_seasons,plots}','{HS-CANH-TAC}','{P-CT-01}','Vụ','TT'),
('ORGANIC-VN','2','Vật tư đầu vào cho phép (Phụ lục A/B), không hóa chất tổng hợp, không GMO','Kiểm soát đầu vào theo phụ lục','CRITICAL','{crop_inputs,feed_logs,products}','{HS-CANH-TAC}','{P-CT-03,P-CT-04}','Mỗi lần','TT'),
('ORGANIC-VN','3','Chăn nuôi hữu cơ: giống, thức ăn hữu cơ ≥…%, phúc lợi, không kích thích tăng trưởng','Thức ăn hữu cơ, chuồng thoáng, chăn thả','MAJOR','{feed_logs,animal_events}','{HS-THUC-AN,HS-THU-Y}','{P-VN-03,P-KT-03}','Liên tục','KTCN'),
('ORGANIC-VN','4','Sổ sách, ghi chép, truy xuất, ghi nhãn "hữu cơ"','Sổ theo dõi đầy đủ, nhãn đúng NĐ 109','MAJOR','{crop_logs,harvests,lots}','{HS-CANH-TAC,HS-TRUY-XUAT}','{P-TT-02}','Liên tục','QA'),
('ORGANIC-VN','5','Chứng nhận bởi tổ chức được chỉ định; kiểm tra định kỳ','Chứng nhận & giám sát hằng năm','MAJOR','{certifications}','{HS-TUAN-THU}','{P-QA-01}','Năm','QA'),
-- JAS Organic (MAFF)
('JAS-ORGANIC','1','Kế hoạch sản xuất & người quản lý sản xuất (production process manager) được đào tạo','Nhân sự được MAFF-accredited body công nhận','MAJOR','{staff,documents}','{HS-NHAN-SU}','{P-NS-02}','Năm','QA'),
('JAS-ORGANIC','2','Đầu vào & vật tư theo danh mục JAS; cách ly, tránh nhiễm','Danh mục cho phép JAS','CRITICAL','{crop_inputs}','{HS-CANH-TAC}','{P-CT-04}','Mỗi lần','TT'),
('JAS-ORGANIC','3','Người xếp loại (grader) nội bộ kiểm tra & dán nhãn JAS','Grader ký từng lô','MAJOR','{lots,documents}','{HS-TRUY-XUAT}','{P-SX-03}','Mỗi lô','QA'),
('JAS-ORGANIC','4','Hồ sơ lưu ≥1 năm sau xuất, sẵn sàng kiểm tra','Hồ sơ đầy đủ','MAJOR','{audit_log}','{HS-AUDIT}','{P-QT-02}','Liên tục','QA'),
-- BRCGS Food Safety v9 (9 phần)
('BRCGS','1','Cam kết lãnh đạo & cải tiến liên tục; văn hóa ATTP','Kế hoạch văn hóa ATTP, xem xét lãnh đạo','MAJOR','{documents,compliance_checks}','{HS-AUDIT}','{P-QA-01}','Năm','QA'),
('BRCGS','2','Kế hoạch ATTP – HACCP','Nhóm HACCP, sơ đồ, CCP','CRITICAL','{batch_logs,checklist_runs}','{HS-ATTP}','{P-D5-02}','Mỗi mẻ','D5'),
('BRCGS','3','Hệ thống quản lý ATTP & chất lượng (tài liệu, hồ sơ, audit nội bộ, NCC, truy xuất, khiếu nại, thu hồi)','Sổ NCC được duyệt, truy xuất 4h, mô phỏng thu hồi','CRITICAL','{partners,lots,incidents}','{HS-TRUY-XUAT,HS-KHO}','{P-KHO-01,P-QA-02}','Năm','QA'),
('BRCGS','4','Tiêu chuẩn nhà xưởng: bố trí, vệ sinh, dịch hại, kho, chất thải','Checklist vệ sinh, dịch hại','MAJOR','{checklist_runs,facilities}','{HS-ATTP}','{P-D5-02}','Ngày','D5'),
('BRCGS','5','Kiểm soát sản phẩm: thiết kế, dị ứng, xuất xứ, đóng gói, kiểm nghiệm','Nhãn, dị ứng nguyên liệu, kiểm nghiệm','MAJOR','{products,lab_samples,lots}','{HS-TRUY-XUAT}','{P-SX-03}','Mỗi lô','D5'),
('BRCGS','6','Kiểm soát quy trình: giám sát CCP, cân, hiệu chuẩn','Cân hiệu chuẩn, khối lượng tịnh','MAJOR','{calibrations,batch_logs}','{HS-THIET-BI}','{P-CN-01}','Ngày','CNTB'),
('BRCGS','7','Nhân sự: đào tạo, vệ sinh cá nhân, khám sức khỏe, trang phục','Đào tạo, khám SK','MAJOR','{staff}','{HS-NHAN-SU}','{P-NS-02}','Năm','HCNS'),
('BRCGS','8','Khu vực rủi ro cao/nguy cơ cao (nếu áp dụng)','Phân vùng, kiểm soát chéo','MINOR','{locations}','{HS-ATTP}','{P-D5-02}','Năm','D5'),
('BRCGS','9','Sản phẩm mua bán (traded goods)','Kiểm soát NCC sản phẩm mua về','MINOR','{partners,inventory_moves}','{HS-KHO}','{P-KHO-01}','Năm','CCU'),
-- ISO 9001:2015 (điều 4–10)
('ISO9001','4-6','Bối cảnh, lãnh đạo, hoạch định (rủi ro & cơ hội, mục tiêu chất lượng)','Chính sách, mục tiêu, sổ rủi ro','MAJOR','{documents,kpi_defs}','{HS-AUDIT}','{P-QT-01}','Năm','BGD'),
('ISO9001','7','Hỗ trợ: nguồn lực, năng lực, nhận thức, thông tin dạng văn bản','Đào tạo, kiểm soát tài liệu (SOP có phiên bản)','MAJOR','{sops,staff}','{HS-NHAN-SU}','{P-NS-02}','Năm','QA'),
('ISO9001','8','Điều hành: kiểm soát quá trình, thiết kế, NCC, sản xuất, không phù hợp','Quy trình được kiểm soát (65 QT), NC log','MAJOR','{processes,incidents,partners}','{HS-AUDIT}','{P-QA-02}','Liên tục','QA'),
('ISO9001','9-10','Đánh giá kết quả (KPI, audit nội bộ, xem xét lãnh đạo) & cải tiến','KPI dashboard, audit, hành động khắc phục','MAJOR','{kpi_results,compliance_checks}','{HS-AUDIT}','{P-QA-01}','Năm','BGD'),
-- ISO 14001:2015
('ISO14001','4-6','Bối cảnh, lãnh đạo, hoạch định: khía cạnh môi trường, nghĩa vụ tuân thủ, mục tiêu','Danh mục khía cạnh MT, giấy phép','MAJOR','{documents,incidents}','{HS-MOI-TRUONG,HS-PHAP-LY}','{P-SH-02}','Năm','SH'),
('ISO14001','7-8','Hỗ trợ & điều hành: kiểm soát vận hành (chất thải, nước, hóa chất), chuẩn bị ứng phó khẩn cấp','Kịch bản sự cố, diễn tập','MAJOR','{batch_logs,sensor_reads,sops}','{HS-MOI-TRUONG}','{P-QT-01}','Quý','SH'),
('ISO14001','9-10','Đánh giá kết quả (quan trắc, tuân thủ, audit) & cải tiến','Quan trắc theo giấy phép, báo cáo','MAJOR','{sensor_reads,lab_samples,compliance_checks}','{HS-MOI-TRUONG}','{P-SH-02}','Quý','SH'),
-- Rainforest Alliance 2020 (Farm requirements: 6 chương)
('RAINFOREST','1','Quản lý: kế hoạch, đánh giá rủi ro, khiếu nại, bình đẳng giới','Kế hoạch quản lý, cơ chế khiếu nại','MAJOR','{documents,customer_messages}','{HS-AUDIT}','{P-QT-01}','Năm','BGD'),
('RAINFOREST','2','Truy xuất nguồn gốc (khối lượng cân bằng, tách biệt)','Cân bằng khối lượng lô chứng nhận','CRITICAL','{lots,inventory_moves,harvests}','{HS-TRUY-XUAT}','{P-TT-02}','Mỗi lô','QA'),
('RAINFOREST','3','Thu nhập & trách nhiệm chia sẻ (Sustainability Differential/Investment)','Ghi nhận khoản chi chênh lệch bền vững','MINOR','{expense_requests}','{HS-KE-TOAN}','{P-TC-01}','Năm','TCKT'),
('RAINFOREST','4','Canh tác: giống, đất, IPM, thuốc BVTV (danh mục cấm), thu hoạch','IPM, không thuốc cấm','CRITICAL','{crop_inputs}','{HS-CANH-TAC}','{P-CT-04}','Mỗi lần','TT'),
('RAINFOREST','5','Xã hội: lao động trẻ em/cưỡng bức, lương, an toàn, nhà ở','Đánh giá & giảm thiểu','MAJOR','{staff}','{HS-NHAN-SU}','{P-NS-04}','Năm','HCNS'),
('RAINFOREST','6','Môi trường: rừng & hệ sinh thái, nước, chất thải, năng lượng, GHG','Không phá rừng, quản lý nước/rác/GHG','MAJOR','{plots,sensor_reads,v_ghg_month}','{HS-MOI-TRUONG}','{P-SH-02}','Năm','SH'),
-- Trung Quốc GACC bổ sung
('CN-GB','2','Nhật ký giám sát sinh vật gây hại & vệ sinh cơ sở đóng gói','Sổ giám sát dịch hại, vệ sinh','MAJOR','{crop_logs,checklist_runs}','{HS-CANH-TAC,HS-ATTP}','{P-CT-04,P-CT-06}','Tuần','TT'),
('CN-GB','3','Truy xuất theo mã vùng trồng, nhãn tiếng Trung, kiểm dịch thực vật','Nhãn đúng, Phyto','CRITICAL','{lots,trade_documents}','{HS-XNK}','{P-XNK-01}','Mỗi lô','XNK'),
-- Hàn Quốc bổ sung
('KR-MFDS','2','Kiểm nghiệm dư lượng tại phòng lab được công nhận trước xuất','COA theo lô','CRITICAL','{lab_samples}','{HS-XNK}','{P-XNK-01}','Mỗi lô','XNK')
on conflict (standard_code, clause) do update set title=excluded.title, requirement=excluded.requirement, evidence_tables=excluded.evidence_tables, process_codes=excluded.process_codes;
