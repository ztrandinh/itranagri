-- 0044 · Đóng gap còn lại: thêm control có thật cho từng điều khoản chưa map (khiếu nại, chứng nhận/nhãn, kê khai, quyền chủ thể dữ liệu, sự cố 72h, nhãn hợp quy, thu nhập chia sẻ, giết mổ Halal thuê ngoài)
insert into controls(id,kind,ref,description,evidence_query,owner_dept) values
('C-COMPLAINT','FIELD','customer_messages + incidents(kind KHIEU_NAI) + P-QA-02','Sổ khiếu nại & giải quyết có hạn','select count(*) as complaints_365d from customer_messages where farm_id=$1 and from_customer and ts>now()-interval ''365 days''','KDM'),
('C-CERTREG','FIELD','certifications (tổ chức, số, hạn) + AL-CERT-EXPIRE + documents','Sổ chứng nhận & nhãn theo chuẩn (EU/hữu cơ VN/JAS…), tái đánh giá','select count(*) filter (where status=''HIEU_LUC'') as valid, count(*) as total from certifications where farm_id=$1 or farm_id is null','QA'),
('C-DECLARE','FIELD','farms (quy mô, địa điểm, pháp nhân) + documents kind GIAY_PHEP (kê khai UBND) + AL-CERT-EXPIRE','Kê khai chăn nuôi & giấy phép với cơ quan','select count(*) as declarations from documents where farm_id=$1 and kind=''GIAY_PHEP''','GDT'),
('C-DSR','PROCESS','P-CN-02 + audit_log + partners.active/attrs (ẩn danh) — yêu cầu chủ thể dữ liệu ghi thành tasks kind DSR','Quyền chủ thể dữ liệu: xem/sửa/xóa (ẩn danh) trong 72h','select count(*) as dsr_tasks from tasks where farm_id=$1 and kind=''DSR''','CNTB'),
('C-BREACH','PROCESS','incidents kind DU_LIEU + P-QT-01 (báo 24h) + notify owner ≤72h','Sự cố dữ liệu: ghi, báo, khắc phục trong 72h','select count(*) as data_incidents from incidents where farm_id=$1 and kind=''DU_LIEU''','CNTB'),
('C-LABEL','FIELD','products.spec/std_passport + lots + nhãn in (/in/nhan-lo) + documents công bố hợp quy','Nhãn, bao bì, công bố hợp quy/chứng nhận theo lô','select count(*) filter (where gtin is not null) as with_gtin, count(*) as total from products where active and kind in (''THANH_PHAM'',''LANH'')','D5'),
('C-SHAREDVALUE','FIELD','funds (quỹ) + expense_requests + hợp đồng liên kết hộ (partners kind HO)','Thu nhập chia sẻ/đầu tư bền vững cho hộ liên kết được ghi nhận','select count(*) as funds from funds where farm_id=$1','TCKT'),
('C-HALAL-SLAUGHTER','FIELD','Không giết mổ tại trại — hợp đồng lò mổ Halal chứng nhận (documents kind HOP_DONG + trade/partners) + cờ dòng SKU','Giết mổ thuê ngoài tại lò được chứng nhận Halal, tách dòng','select count(*) as halal_docs from documents where (farm_id=$1 or farm_id is null) and (title ilike ''%halal%'' or tags @> ''{halal}'')','KDM')
on conflict (id) do update set ref=excluded.ref, description=excluded.description, evidence_query=excluded.evidence_query;
insert into clause_controls(requirement_id, control_id) select r.id, m.c from standard_requirements r join (values ('VIETGAP-TT','12','C-COMPLAINT'),('HALAL','2','C-HALAL-SLAUGHTER'),('EU-ORGANIC','5','C-CERTREG'),('ORGANIC-VN','2','C-CROPLOG'),('ORGANIC-VN','2','C-ORGANIC'),('ORGANIC-VN','5','C-CERTREG'),('RAINFOREST','3','C-SHAREDVALUE'),('VN-TT66','1','C-DECLARE'),('VN-ND13','2','C-DSR'),('VN-ND13','3','C-BREACH'),('VN-PHANBON','3','C-LABEL')) m(s,cl,c) on m.s=r.standard_code and m.cl=r.clause on conflict do nothing;
select refresh_compliance_gaps();
-- SOP L3 ↔ điều khoản: gắn std_clauses cho SOP tiêu biểu (dropdown trong app dùng standard_requirements)
update sops set std_clauses = array['VIETGAP-CN:2','VN-TT66:2','GLOBALGAP:LB'] where code like 'SOP-BO-01.%';
update sops set std_clauses = array['VIETGAP-CN:4','VN-TT66:4','GLOBALGAP:LB','EU-ORGANIC:3'] where code like 'SOP-BO-08.%';
update sops set std_clauses = array['VIETGAP-TT:4','VIETGAP-TT:6','ORGANIC-VN:2','EU-ORGANIC:2','GLOBALGAP:CB'] where code like 'SOP-TT-02.%';
update sops set std_clauses = array['VIETGAP-TT:7','GLOBALGAP:FV'] where code like 'SOP-TT-03.%';
update sops set std_clauses = array['HACCP:1-7','ISO22000:8.5','BRCGS:2'] where code like 'SOP-CB-0%' ;
update sops set std_clauses = array['VN-PHANBON:2','VN-PHANBON:3'] where code like 'SOP-SH-01.%' or code like 'SOP-SH-04.%';
update sops set std_clauses = array['VIETGAP-CN:1','VIETGAP-CN:5','GLOBALGAP:AF'] where code like 'SOP-AT-01.%' or code like 'SOP-AT-05.%';
update sops set std_clauses = array['VN-ND13:1'] where code like 'SOP-KD-03.%' or code like 'SOP-RS-01.%';
update sops set std_clauses = array['ISO9001:7','GLOBALGAP:AF'] where code like 'SOP-HC-03.%';
update sops set std_clauses = array['ISO22000:8.2','HACCP:1-7'] where code like 'SOP-RS-03.%';
