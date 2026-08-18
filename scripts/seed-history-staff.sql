-- ---------- 11. CƠ CẤU NHÂN SỰ ĐẦY ĐỦ (công ty mẹ + trại F01): login = mã ngắn, PIN 1234, ngày vào làm rải 30 tháng, lương cơ bản ----------
insert into staff(id, org_id, farm_id, full_name, role, dept, position, position_code, phone, login, pin_hash, farm_ids, active, hired_on, salary_base, contract_kind, dob, email)
select v.id, 'ITRAN', v.farm, v.name, v.role, v.dept, v.pos, v.pc, '09'||lpad(((row_number() over ())*7919 % 100000000)::text, 8, '0'), v.login, crypt('1234', gen_salt('bf', 6)), case when v.farm is null then '{F01,F99}' else array[v.farm] end::text[], true, (current_date - (v.months||' months')::interval)::date, v.sal, case when v.role='worker' then 'HD_12T' else 'HD_KXDTH' end, (date '1985-01-01' + (((row_number() over ())*137 % 5000))::int)::date, v.login||'@itranfarm.vn'
from (values
 ('NS-101',null,'Nguyễn Văn Đầu Tư','owner','HDQT','Chủ tịch HĐQT',null,'chutich',36,0),
 ('NS-102',null,'Trần Thị Điều Hành','director','BGD','Tổng giám đốc',null,'tgd',34,45000000),
 ('NS-103',null,'Lê Minh Tài','accountant','TCKT','Kế toán trưởng',null,'ktt-tc',33,25000000),
 ('NS-104',null,'Phạm Thu Hằng','accountant','TCKT','Kế toán tổng hợp',null,'kt-th',20,14000000),
 ('NS-105',null,'Ngô Thị Quỹ','accountant','TCKT','Thủ quỹ – kế toán thanh toán',null,'thuquy',18,11000000),
 ('NS-106',null,'Đặng Nhân Sự','director','HCNS','Trưởng phòng HC–NS–Đào tạo',null,'tp-hcns',30,20000000),
 ('NS-107',null,'Vũ Thị Đào Tạo','team_lead','HCNS','Chuyên viên đào tạo – SOP',null,'daotao',16,12000000),
 ('NS-108',null,'Bùi Chất Lượng','auditor','QA','Trưởng phòng QA/QC – Tuân thủ',null,'tp-qa',28,22000000),
 ('NS-109',null,'Hoàng Thị Kiểm','auditor','QA','QC viên – lấy mẫu – audit nội bộ',null,'qc1',14,11000000),
 ('NS-110',null,'Trịnh Kinh Doanh','director','KDM','Trưởng phòng Kinh doanh – Marketing',null,'tp-kd',30,22000000),
 ('NS-111',null,'Lý Thị Bán','worker','KDM','NVKD B2B – bao tiêu','A9','nvkd1',22,10000000),
 ('NS-112',null,'Mai Văn Online','worker','KDM','NVKD online – sàn TMĐT','A9','nvkd2',12,10000000),
 ('NS-113',null,'Đỗ Thị Chăm','worker','KDM','CSKH – hotline – nhận nuôi','A9','cskh',15,9000000),
 ('NS-114',null,'Phan Cung Ứng','tech_head','CCU','Trưởng phòng Chuỗi cung ứng – Mua hàng',null,'tp-ccu',29,20000000),
 ('NS-115',null,'Cao Thị Mua','worker','CCU','Nhân viên mua hàng','A8','muahang',20,10000000),
 ('NS-116',null,'Lâm Công Nghệ','it_engineer','CNTB','Trưởng phòng Công nghệ – Dữ liệu',null,'tp-cn',30,25000000),
 ('NS-117',null,'Tô Nghiên Cứu','tech_head','RD','Trưởng R&D – Đổi mới',null,'rd1',12,20000000),
 ('NS-118',null,'Hồ Xuất Khẩu','director','XNK','Trưởng phòng XNK – Thị trường QT',null,'xnk1',10,22000000),
 ('NS-119',null,'Dương Nhân Rộng','director','MR','Ban Phát triển dự án – Nhượng quyền',null,'mr1',8,22000000),
 ('NS-121','F01','Nguyễn Kỹ Thuật','tech_head','KTCN','KTT Kỹ thuật – Thú y trưởng',null,'ktt-ty',30,18000000),
 ('NS-122','F01','Trần Bác Sĩ','team_lead','KTCN','Bác sĩ thú y',null,'bsty',24,13000000),
 ('NS-123','F01','Lê Trồng Trọt','tech_head','TT','KTT Trồng trọt – Sinh khối',null,'ktt-tt',30,17000000),
 ('NS-124','F01','Phạm Văn Đồng','team_lead','TT','Trưởng nhóm đồng ruộng',null,'tn-tt',26,11000000),
 ('NS-125','F01','Ngô Văn Cỏ','worker','TT','CN đồng cỏ – tưới','A5','cn-co1',24,8000000),
 ('NS-126','F01','Đinh Văn Bắp','worker','TT','CN bắp sinh khối – ủ chua','A5','cn-bap',22,8000000),
 ('NS-127','F01','Vũ Thị Rau','worker','TT','CN nhà lưới rau – nấm','A5','cn-rau',14,7500000),
 ('NS-128','F01','Bùi Văn Lúa','worker','TT','CN lúa – liên kết hộ','A5','cn-lua',20,7500000),
 ('NS-129','F01','Hoàng Văn Bò','worker','KTCN','CN chuồng bò vỗ béo','A1','cn-bo2',18,8000000),
 ('NS-130','F01','Trịnh Thị Bê','worker','KTCN','CN bê – cai sữa','A2','cn-be',12,7500000),
 ('NS-131','F01','Lý Văn Dê','worker','KTCN','CN đàn dê','A2','cn-de',20,7500000),
 ('NS-132','F01','Mai Thị Trứng','worker','KTCN','CN gà đẻ ca 2 – phân loại trứng','A3','cn-ga2',10,7500000),
 ('NS-133','F01','Đỗ Văn Thịt','worker','KTCN','CN gà thịt','A3','cn-gathit',9,7500000),
 ('NS-134','F01','Phan Sinh Học','team_lead','SH','Trưởng nhóm khu D (trùn/BSF/biogas)',null,'tn-sh',26,11000000),
 ('NS-135','F01','Cao Văn Trùn','worker','SH','CN trùn – compost','A6','cn-trun',20,7500000),
 ('NS-136','F01','Lâm Thị BSF','worker','SH','CN BSF – bếp rác','A6','cn-bsf',10,7500000),
 ('NS-137','F01','Tô Văn Ép','worker','D5','CN ép viên – trộn TMR ca 2','A7','cn-d5-2',16,8000000),
 ('NS-138','F01','Hồ Thị Đóng','worker','D5','CN đóng gói – tem','A7','cn-donggoi',12,7500000),
 ('NS-139','F01','Dương Văn Kho','team_lead','CCU','Thủ kho trưởng',null,'thukho',24,11000000),
 ('NS-140','F01','Nguyễn Văn Xe','worker','CCU','Tài xế xe tải/lạnh','A8','taixe',18,9000000),
 ('NS-141','F01','Trần Thiết Bị','worker','CNTB','KT viên thiết bị – hiệu chuẩn – IoT','A12','ktv-tb',15,10000000),
 ('NS-142','F01','Lê Thị Chế Biến','team_lead','D5','Trưởng nhóm sơ chế – kho lạnh',null,'tn-cb',14,11000000),
 ('NS-143','F01','Phạm Văn Sơ','worker','D5','CN sơ chế – hút chân không','A7','cn-soche',8,7500000),
 ('NS-144','F01','Ngô Thị Lễ Tân','worker','DL','Lễ tân – đặt phòng – tour','A13','letan',12,8000000),
 ('NS-145','F01','Đinh Văn Bếp','worker','DL','Bếp trưởng farm-to-table','A13','bep',12,10000000),
 ('NS-146','F01','Vũ Thị Buồng','worker','DL','Buồng phòng – vệ sinh','A13','buong',8,7000000),
 ('NS-147','F01','Bùi Văn Hành Chính','worker','HCNS','Hành chính – chấm công – y tế trại','A14','hanhchinh',20,8500000),
 ('NS-148','F01','Hoàng Văn Bảo Vệ 2','worker','HCNS','Bảo vệ ca đêm','A11','baove2',20,7000000)
) v(id, farm, name, role, dept, pos, pc, login, months, sal)
where not exists (select 1 from staff s where s.id=v.id or s.login=v.login);
insert into staff(id, org_id, farm_id, full_name, role, dept, position, phone, login, pin_hash, farm_ids, active, hired_on, left_on, salary_base) values
 ('NS-190','ITRAN','F01','Nguyễn Văn Nghỉ','worker','TT','CN đồng cỏ (đã nghỉ)','0912000190','cn-nghi1',crypt('1234',gen_salt('bf',6)),'{F01}',false,current_date-800,current_date-300,7000000),
 ('NS-191','ITRAN','F01','Trần Thị Chuyển','worker','KTCN','CN gà (chuyển F99)','0912000191','cn-nghi2',crypt('1234',gen_salt('bf',6)),'{F01}',false,current_date-700,current_date-100,7500000)
on conflict do nothing;
update staff set sop_certs = to_jsonb(array['SOP-AT-02','SOP-AT-01'] || case dept when 'TT' then array['SOP-TT-01','SOP-TT-02'] when 'KTCN' then array['SOP-BO-07','SOP-BO-08'] when 'D5' then array['SOP-CB-01','SOP-SH-05'] when 'SH' then array['SOP-SH-01','SOP-SH-02'] when 'CCU' then array['SOP-HC-02'] else '{}'::text[] end) where farm_id='F01' and active and coalesce(jsonb_array_length(coalesce(sop_certs,'[]'::jsonb)),0)=0;
-- chấm công 90 ngày
do $$ declare r record; d date; i int; begin
  for r in select id from staff where farm_id='F01' and active loop
    for i in 0..89 loop d := current_date - i; if extract(dow from d) between 1 and 6 then
      insert into attendance(farm_id, staff_id, day, shift, check_in, check_out, hours, method) values ('F01', r.id, d, 'SANG', d + time '06:30' + ((i*13)%20||' minutes')::interval, d + time '17:00' + ((i*7)%30||' minutes')::interval, 8.5, 'IMPORT') on conflict do nothing; end if; end loop;
  end loop;
exception when others then raise notice 'attendance skip: %', sqlerrm; end $$;
select 'staff active' as t, count(*) from staff where active;
