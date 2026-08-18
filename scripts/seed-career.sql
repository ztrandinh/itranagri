-- Seed bậc/ngạch GS/kế thừa cho trại :'farm' (chạy lại được)
delete from succession_plans where farm_id=:'farm'; delete from key_positions where farm_id=:'farm'; delete from staff_grades where farm_id=:'farm'; delete from grade_reviews where farm_id=:'farm';
delete from gs_field_days where farm_id=:'farm'; delete from supervisor_ratings where farm_id=:'farm'; delete from initiatives where farm_id=:'farm';
-- 1) Bậc chuyên môn khởi tạo theo thâm niên & vai (trại đã chạy 30 tháng)
insert into staff_grades(farm_id, staff_id, track, grade_code, since, status, note)
select :'farm', s.id, 'CM',
  case when s.role in ('tech_head','director','owner') then 'B4'
       when s.role='team_lead' then 'B3'
       when coalesce(s.hired_on, s.created_at::date) <= current_date - 730 then 'B3'
       when coalesce(s.hired_on, s.created_at::date) <= current_date - 365 then 'B2'
       when coalesce(s.hired_on, s.created_at::date) <= current_date - 90 then 'B2' else 'B1' end,
  greatest(coalesce(s.hired_on, s.created_at::date), current_date - 400), 'CHINH_THUC', 'khởi tạo theo thâm niên'
from staff s where s.farm_id=:'farm' and s.active;
-- Công ty mẹ (farm_id null): ghi bậc dưới trại F01 để có farm scope
insert into staff_grades(farm_id, staff_id, track, grade_code, since, status, note)
select 'F01', s.id, 'CM', case when s.role in ('director','owner') then 'B4' else 'B3' end, current_date-400, 'CHINH_THUC', 'công ty mẹ' from staff s where s.farm_id is null and s.active and :'farm'='F01' on conflict do nothing;
-- 2) Ngạch GS: trưởng phòng QA = GS3, QC viên = GS1; kiểm toán độc lập (audit) = GS2 (đang kiểm nhiều khối)
insert into staff_grades(farm_id, staff_id, track, grade_code, since, status, note)
select 'F01', id, 'GS', case login when 'tp-qa' then 'GS3' when 'qc1' then 'GS1' when 'audit' then 'GS2' end, current_date-300, 'CHINH_THUC', 'khởi tạo ngạch GS' from staff where login in ('tp-qa','qc1','audit') and :'farm'='F01';
-- Phân công GS theo khối (biệt phái xuống trại): tp-qa đã qua nhiều khối; qc1 khối đầu tiên
insert into supervision_assignments(id,farm_id,supervisor_id,target_dept,scope,checks_per_week,from_date,to_date,active,note)
select gen_random_uuid()::text, :'farm', (select id from staff where login='tp-qa'), d, 'Luân chuyển khối', 3, f, t, act, 'seed career' from (values
 ('KTCN', current_date-600, current_date-500, false), ('TT', current_date-499, current_date-400, false), ('CCU', current_date-399, current_date-300, false), ('D5', current_date-299, current_date-200, false), ('SH', current_date-199, current_date-100, false), ('KDM', current_date-99, null::date, true)) v(d,f,t,act) where :'farm'='F01';
insert into supervision_assignments(id,farm_id,supervisor_id,target_dept,scope,checks_per_week,from_date,to_date,active,note)
select gen_random_uuid()::text, :'farm', (select id from staff where login='qc1'), 'TT', 'Luân chuyển khối', 3, current_date-40, null, true, 'seed career' where :'farm'='F01';
-- 3) GS đi ca thật (1 ngày/tuần)
insert into gs_field_days(farm_id, supervisor_id, day, block, dept, note)
select :'farm', (select id from staff where login='tp-qa'), d::date, b, dp, 'đi ca cùng tổ' from (
  select current_date - 7*g as d, (array['CN','TT','KHO','D5','SH','KD'])[1+((g/13)%6)] as b, (array['KTCN','TT','CCU','D5','SH','KDM'])[1+((g/13)%6)] as dp from generate_series(1,76) g) x on conflict do nothing;
insert into gs_field_days(farm_id, supervisor_id, day, block, dept, note) select :'farm', (select id from staff where login='qc1'), current_date - 7*g, 'TT', 'TT', 'đi ca' from generate_series(1,5) g on conflict do nothing;
-- 4) Trưởng phòng chấm ngược GS (6 tháng)
insert into supervisor_ratings(farm_id, supervisor_id, rated_by, period, useful, fair, knows, note)
select :'farm', (select id from staff where login='tp-qa'), h.id, to_char(current_date - (m||' months')::interval, 'YYYY-MM'), 4 + (random()<0.4)::int, 4, 3 + (random()<0.7)::int, null
from staff h, generate_series(0,5) m where h.farm_id=:'farm' and h.role in ('tech_head','team_lead') and h.active on conflict do nothing;
insert into supervisor_ratings(farm_id, supervisor_id, rated_by, period, useful, fair, knows) select :'farm', (select id from staff where login='qc1'), h.id, to_char(current_date, 'YYYY-MM'), 3, 4, 3 from staff h where h.farm_id=:'farm' and h.dept='TT' and h.role in ('tech_head','team_lead') on conflict do nothing;
-- 5) Sáng kiến
insert into initiatives(farm_id, staff_id, title, kind, description, benefit, status, approved_by, approved_at)
select :'farm', s.id, t, 'CAI_TIEN', 'Đề xuất từ hiện trường', b, 'AP_DUNG', (select id from staff where login='gd' limit 1), now() - interval '60 days' from (values
 ('cn-bap','Ủ chua bắp thêm 1% rỉ mật – giảm hỏng 30%','tiết kiệm ~4tr/tháng'), ('thukho','Kệ FIFO cho kho lạnh K5','giảm hàng hết hạn'), ('ktt-tt','Lịch tưới theo ET0 thay vì cố định','tiết kiệm nước 18%'), ('cn-trun','Bổ sung BSF vào compost trùn','tăng năng suất phân 12%')) v(l,t,b) join staff s on s.login=v.l where s.farm_id=:'farm' or s.farm_id is null;
insert into initiatives(farm_id, staff_id, title, kind, status, approved_by, approved_at) select 'F01', id, 'Chủ trì audit VietGAP đợt 2', 'AUDIT', 'AP_DUNG', (select id from staff where login='tgd'), now()-interval '100 days' from staff where login='tp-qa' and :'farm'='F01';
-- 6) Ghế then chốt & kế thừa
insert into key_positions(farm_id, code, title, dept, holder_id, is_key, min_grade, track, note)
select :'farm', v.code, v.title, v.dept, (select id from staff where login=v.l and (farm_id=:'farm' or farm_id is null) limit 1), true, v.mg, v.tr, null from (values
 ('GDT','Giám đốc trại','GDT','gd','PGD','GS'), ('KTT-CN','KTT Chăn nuôi – Thú y','KTCN','ktt-ty','B4','CM'), ('KTT-TT','KTT Trồng trọt – Sinh khối','TT','ktt-tt','B4','CM'), ('KTT-SH','KTT Sinh học tuần hoàn','SH','ktt-sh','B4','CM'), ('KTT-D5','Kỹ thuật trưởng D5','D5','ktt-cn','B4','CM'),
 ('TK','Thủ kho trưởng','CCU','thukho','B3','CM'), ('KT','Kế toán trại','HCNS','kt','B3','CM'), ('BSTY','Bác sĩ thú y','KTCN','bsty','B3','CM'), ('TN-D','Trưởng nhóm khu D','SH','tn-sh','B3','CM'), ('TN-CB','Trưởng nhóm sơ chế – kho lạnh','D5','tn-cb','B3','CM')) v(code,title,dept,l,mg,tr);
insert into succession_plans(farm_id, key_position_id, successor_id, readiness, dev_plan)
select :'farm', k.id, s.id, v.r, v.p from (values
 ('GDT','tp-qa','1_NAM','Đủ 8/8 khối (còn TCNS, TB) + chủ trì kế hoạch năm 2027'), ('KTT-TT','cn-bap','1_NAM','Đạt B4: dạy 6 buổi, DAY_DUOC 50% SOP-TT'), ('KTT-CN','bsty','NGAY','Đã B3, cần 1 kỳ làm quyền ≥14 ngày'),
 ('TK','cn-co1','2_NAM','Học SOP-KH, luân chuyển kho 6 tháng'), ('KTT-SH','cn-trun','2_NAM','B3 → B4; dạy BSF/biogas'), ('BSTY','ktt-ty','NGAY','Kiêm nhiệm')) v(k,l,r,p)
join key_positions k on k.farm_id=:'farm' and k.code=v.k join staff s on s.login=v.l and (s.farm_id=:'farm' or s.farm_id is null);
-- 7) GS đã đậu SOP cốt lõi của các khối đã kiểm (bài thi do KTT khối chấm)
delete from training_tests where note='seed career' and farm_id=:'farm';
insert into training_tests(id, farm_id, trainee_id, examiner_id, sop_code, taken_at, kind, score, max_score, passed, note)
select 'TT-GS-'||:'farm'||'-'||d, :'farm', (select id from staff where login='tp-qa'), (select id from staff where login='gd' limit 1), (select min(code) from sops where dept=d), now() - interval '100 days', 'SOP', 88, 100, true, 'seed career'
from unnest(array['KTCN','TT','CCU','D5','SH']) d on conflict (id) do update set passed=true;
-- 8) GS đậu SOP CỐT LÕI của các khối đã kiểm (gs_block_sops)
insert into training_tests(id, farm_id, trainee_id, examiner_id, sop_code, taken_at, kind, score, max_score, passed, note)
select 'TT-GSB-'||:'farm'||'-'||g.sop_l2_code, :'farm', (select id from staff where login='tp-qa'), (select id from staff where login='gd' limit 1), g.sop_l2_code, now() - interval '120 days', 'SOP', 90, 100, true, 'seed career'
from gs_block_sops g where g.block in ('CN','TT','SH','D5','KHO') on conflict (id) do update set passed=true;
