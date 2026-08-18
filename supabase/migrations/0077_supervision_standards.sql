-- 0077 · TIÊU CHUẨN GIÁM SÁT & CHẤM ĐIỂM theo nhóm công việc (vị trí A1…A14 / phòng ban)
-- Mỗi tiêu chí: giám sát CÁI GÌ (đã ghi chưa? đúng giờ chưa? đủ số lượng chưa? có bỏ sót? đúng SOP?), CÁCH ĐO (auto = SQL trên dữ liệu vận hành, hoặc manual = quan sát tại chỗ), TRỌNG SỐ, ngưỡng đạt.
-- Điểm tuần của người/bộ phận = Σ trọng số × mức đạt (0–100). Hệ thống tự chấm phần auto hằng ngày; giám sát viên xác nhận + chấm phần manual (checklist trên điện thoại). Lỗi → điểm trừ theo mức độ (0075).
create table if not exists supervision_criteria(
  id text primary key, org_id text default 'ITRAN', position_code text, dept_code text, name text not null, what text, -- mô tả cái cần kiểm
  method text not null default 'AUTO' check (method in ('AUTO','MANUAL')), sql text, -- AUTO: trả về (staff_id, value numeric, target numeric) cho tuần [$2,$3) trại $1
  unit text, target numeric, direction text default '>=' check (direction in ('>=','<=','=')), weight numeric not null default 10, severity text default 'TRUNG', frequency text default 'TUAN', sop_code text, active bool default true, position int default 100);
grant select, insert, update on supervision_criteria to app_user;
-- ===== Tiêu chí AUTO dùng chung (mọi vị trí) =====
insert into supervision_criteria(id, position_code, dept_code, name, what, method, sql, unit, target, direction, weight, severity, position) values
 ('SC-ALL-01', null, null, 'Hoàn thành việc đúng hạn', 'Việc được giao trong tuần: % xong trước hạn (tasks assignee/role)', 'AUTO',
  $$select s.id as staff_id, round(100.0*count(*) filter (where t.status='XONG' and t.done_at<=t.due_at)/nullif(count(*),0),0) as value, 90 as target from staff s left join tasks t on t.farm_id=s.farm_id and (t.assignee_id=s.id or (t.assignee_id is null and t.role_hint=s.role and t.detail->>'dept'=s.dept)) and t.due_at>=$2 and t.due_at<$3 where s.farm_id=$1 and s.active group by s.id$$, '%', 90, '>=', 20, 'TRUNG', 1),
 ('SC-ALL-02', null, null, 'Không bỏ sót việc (quá hạn chưa làm)', 'Số việc quá hạn còn mở cuối tuần', 'AUTO',
  $$select s.id, count(t.id) as value, 0 as target from staff s left join tasks t on t.farm_id=s.farm_id and t.assignee_id=s.id and t.status='MO' and t.due_at<$3 where s.farm_id=$1 and s.active group by s.id$$, 'việc', 0, '<=', 15, 'NANG', 2),
 ('SC-ALL-03', null, null, 'Ghi chép hằng ngày đầy đủ', 'Số ngày trong tuần có ít nhất 1 bản ghi do người này tạo (bảng sự kiện) / số ngày làm việc', 'AUTO',
  $$with days as (select generate_series($2::date, $3::date - 1, '1 day') d), rec as (select created_by, ts::date d from feed_logs where farm_id=$1 and ts>=$2 and ts<$3 union select created_by, ts::date from animal_events where farm_id=$1 and ts>=$2 and ts<$3 union select created_by, ts::date from crop_logs where farm_id=$1 and ts>=$2 and ts<$3 union select created_by, ts::date from inventory_moves where farm_id=$1 and ts>=$2 and ts<$3 union select created_by, ts::date from batch_logs where farm_id=$1 and ts>=$2 and ts<$3 union select created_by, ts::date from checklist_runs where farm_id=$1 and ts>=$2 and ts<$3 union select created_by, ts::date from sales where farm_id=$1 and ts>=$2 and ts<$3 union select created_by, ts::date from gate_logs where farm_id=$1 and ts>=$2 and ts<$3 union select created_by, ts::date from harvests where farm_id=$1 and ts>=$2 and ts<$3 union select created_by, ts::date from irrigation_logs where farm_id=$1 and ts>=$2 and ts<$3)
   select s.id, count(distinct r.d) as value, 6 as target from staff s left join rec r on r.created_by=s.id where s.farm_id=$1 and s.active and s.role='worker' group by s.id$$, 'ngày', 6, '>=', 15, 'TRUNG', 3),
 ('SC-ALL-04', null, null, 'Checklist ca đạt (all_green)', '% checklist ca do người này ghi đạt toàn bộ', 'AUTO',
  $$select s.id, round(100.0*count(*) filter (where c.all_green)/nullif(count(*),0),0), 90 from staff s left join checklist_runs c on c.farm_id=s.farm_id and c.created_by=s.id and c.ts>=$2 and c.ts<$3 and c.status='ACTIVE' where s.farm_id=$1 and s.active group by s.id$$, '%', 90, '>=', 10, 'NHE', 4),
 ('SC-ALL-05', null, null, 'Ghi đúng giờ (không backfill trễ)', '% bản ghi tạo trong vòng 2 giờ sau thời điểm sự kiện', 'AUTO',
  $$with e as (select created_by, ts, created_at from feed_logs where farm_id=$1 and ts>=$2 and ts<$3 union all select created_by, ts, created_at from animal_events where farm_id=$1 and ts>=$2 and ts<$3 union all select created_by, ts, created_at from crop_logs where farm_id=$1 and ts>=$2 and ts<$3 union all select created_by, ts, created_at from inventory_moves where farm_id=$1 and ts>=$2 and ts<$3)
   select s.id, round(100.0*count(*) filter (where e.created_at - e.ts <= interval '2 hours')/nullif(count(*),0),0), 85 from staff s left join e on e.created_by=s.id where s.farm_id=$1 and s.active and s.role='worker' group by s.id$$, '%', 85, '>=', 10, 'NHE', 5),
 ('SC-ALL-06', null, null, 'Đào tạo tuần hoàn thành', 'Buổi học/dạy tuần đã XONG', 'AUTO',
  $$select s.id, count(t.id) filter (where t.status='XONG') as value, count(t.id) as target from staff s left join training_sessions t on t.farm_id=s.farm_id and (t.trainee_id=s.id or t.trainer_id=s.id) and t.week_start>=$2 and t.week_start<$3 where s.farm_id=$1 and s.active group by s.id$$, 'buổi', 1, '>=', 10, 'TRUNG', 6),
 ('SC-ALL-07', null, null, 'Chấm công đủ ca', 'Số ngày chấm công / ngày làm việc trong tuần', 'AUTO',
  $$select s.id, count(a.id), 6 from staff s left join attendance a on a.farm_id=s.farm_id and a.staff_id=s.id and a.day>=$2 and a.day<$3 where s.farm_id=$1 and s.active group by s.id$$, 'ngày', 6, '>=', 5, 'NHE', 7)
on conflict (id) do nothing;
-- ===== Tiêu chí theo VỊ TRÍ (auto + manual) =====
insert into supervision_criteria(id, position_code, dept_code, name, what, method, sql, unit, target, direction, weight, severity, sop_code, position) values
 -- A1 TMR / chuồng bò
 ('SC-A1-01','A1',null,'Cho ăn 2 cữ/ngày đủ 7 ngày','Số cữ feed_logs bò trong tuần (chuẩn 14)','AUTO',$$select s.id, count(f.id), 14 from staff s left join feed_logs f on f.farm_id=s.farm_id and f.created_by=s.id and f.recipe_id like 'RC-TMR%' and f.ts>=$2 and f.ts<$3 where s.farm_id=$1 and s.position_code='A1' group by s.id$$,'cữ',14,'>=',20,'NANG','SOP-BO-07',10),
 ('SC-A1-02','A1',null,'Sai số cân TMR ≤3%','TB |thực − kế hoạch|/kế hoạch','AUTO',$$select s.id, round(avg(abs(f.qty_kg-f.planned_kg)/nullif(f.planned_kg,0))*100,1), 3 from staff s left join feed_logs f on f.farm_id=s.farm_id and f.created_by=s.id and f.ts>=$2 and f.ts<$3 and f.planned_kg>0 where s.farm_id=$1 and s.position_code='A1' group by s.id$$,'%',3,'<=',15,'TRUNG','SOP-BO-07',11),
 ('SC-A1-03','A1',null,'Máng sạch, nước uống tự do','Quan sát tại chỗ: máng không dư ôi, vòi nước chảy, không rò','MANUAL',null,'đạt/lỗi',1,'>=',10,'TRUNG','SOP-BO-07',12),
 ('SC-A1-04','A1',null,'Ảnh máng sau cữ ăn','% cữ có ảnh minh chứng','AUTO',$$select s.id, round(100.0*count(*) filter (where cardinality(f.photo_urls)>0)/nullif(count(*),0),0), 80 from staff s left join feed_logs f on f.farm_id=s.farm_id and f.created_by=s.id and f.ts>=$2 and f.ts<$3 where s.farm_id=$1 and s.position_code='A1' group by s.id$$,'%',80,'>=',5,'NHE','SOP-BO-07',13),
 -- A2 sinh sản – bê
 ('SC-A2-01','A2',null,'Ghi động dục/phối/khám thai đúng ngày','Số sự kiện sinh sản ghi trong tuần (đàn nái ≥ 40 → kỳ vọng ≥ 4)','AUTO',$$select s.id, count(e.id), 4 from staff s left join animal_events e on e.farm_id=s.farm_id and e.created_by=s.id and e.event_type in ('DONG_DUC','PHOI','KHAM_THAI','DE') and e.ts>=$2 and e.ts<$3 where s.farm_id=$1 and s.position_code='A2' group by s.id$$,'sự kiện',4,'>=',20,'NANG','SOP-BO-02',10),
 ('SC-A2-02','A2',null,'Bê sinh có hồ sơ trong 24h','% bê sinh (DE) có hồ sơ animals tạo ≤24h','AUTO',$$select s.id, round(100.0*count(*) filter (where a.created_at - e.ts <= interval '24 hours')/nullif(count(*),0),0), 100 from staff s left join animal_events e on e.farm_id=s.farm_id and e.created_by=s.id and e.event_type='DE' and e.ts>=$2 and e.ts<$3 left join animals a on a.dam_id=e.animal_id and a.birth_date=e.ts::date where s.farm_id=$1 and s.position_code='A2' group by s.id$$,'%',100,'>=',15,'NANG','SOP-BO-04',11),
 ('SC-A2-03','A2',null,'Cân bê 2 tuần/lần','Số bê được cân trong 14 ngày / số bê','AUTO',$$select s.id, round(100.0*count(distinct e.animal_id)/nullif((select count(*) from animals a where a.farm_id=s.farm_id and a.status not in ('CHET','XUAT') and a.birth_date>current_date-180),0),0), 100 from staff s left join animal_events e on e.farm_id=s.farm_id and e.event_type='CAN' and e.ts>=$3::date-14 and e.ts<$3 and e.animal_id in (select id from animals where birth_date>current_date-180) where s.farm_id=$1 and s.position_code='A2' group by s.id$$,'%',100,'>=',10,'TRUNG','SOP-BO-05',12),
 ('SC-A2-04','A2',null,'Chuồng đẻ khô, ổ úm đúng nhiệt','Quan sát: đệm khô, đèn úm 32–35°C tuần đầu','MANUAL',null,'đạt/lỗi',1,'>=',10,'TRUNG','SOP-BO-04',13),
 -- A3 gà
 ('SC-A3-01','A3',null,'Đếm trứng mỗi ngày','Số ngày có SO_LUONG trứng trong tuần','AUTO',$$select s.id, count(distinct e.ts::date), 7 from staff s left join animal_events e on e.farm_id=s.farm_id and e.created_by=s.id and e.event_type='SO_LUONG' and e.ts>=$2 and e.ts<$3 where s.farm_id=$1 and s.position_code='A3' group by s.id$$,'ngày',7,'>=',20,'NANG','SOP-GA-03',10),
 ('SC-A3-02','A3',null,'Ghi gà chết trong ngày','% ngày có ghi CHET (kể cả 0) — bỏ sót = không ghi','AUTO',$$select s.id, count(distinct e.ts::date), 5 from staff s left join animal_events e on e.farm_id=s.farm_id and e.created_by=s.id and e.event_type in ('CHET','SO_LUONG') and e.ts>=$2 and e.ts<$3 where s.farm_id=$1 and s.position_code='A3' group by s.id$$,'ngày',5,'>=',10,'TRUNG','SOP-GA-02',11),
 ('SC-A3-03','A3',null,'Đệm lót khô, anolyte nước uống','Quan sát/đo ppm anolyte đúng ngưỡng','MANUAL',null,'đạt/lỗi',1,'>=',10,'TRUNG','SOP-GA-04',12),
 -- A5 lái máy / trồng trọt
 ('SC-A5-01','A5',null,'Nhật ký lô ghi ngay khi làm','Số crop_logs tuần (cắt/tưới/chăm) ≥ 3','AUTO',$$select s.id, count(c.id), 3 from staff s left join crop_logs c on c.farm_id=s.farm_id and c.created_by=s.id and c.ts>=$2 and c.ts<$3 where s.farm_id=$1 and s.position_code='A5' group by s.id$$,'bản ghi',3,'>=',20,'NANG','SOP-TT-02',10),
 ('SC-A5-02','A5',null,'Nhiên liệu theo định mức','Lít dầu / giờ máy ≤ định mức ×1.1','AUTO',$$select s.id, round(coalesce(sum(c.fuel_l)/nullif(sum(c.machine_hours),0),0),1), 15.4 from staff s left join crop_logs c on c.farm_id=s.farm_id and c.created_by=s.id and c.ts>=$2 and c.ts<$3 and c.machine_hours>0 where s.farm_id=$1 and s.position_code='A5' group by s.id$$,'L/h',15.4,'<=',10,'TRUNG','SOP-TT-05',11),
 ('SC-A5-03','A5',null,'Cắt cỏ đúng lứa (45 ngày)','Ô quá 55 ngày chưa cắt','AUTO',$$select s.id, count(*) filter (where last_cut < $3::date-55), 0 from staff s cross join (select p.id, max(c.ts::date) last_cut from plots p left join crop_logs c on c.plot_id=p.id and c.activity='CAT' where p.farm_id=$1 and p.crop_code like 'CO-%' and p.active group by p.id) x where s.farm_id=$1 and s.position_code='A5' group by s.id$$,'ô',0,'<=',10,'TRUNG','SOP-TT-06',12),
 ('SC-A5-04','A5',null,'Máy sạch, bảo dưỡng đúng lịch','Quan sát + sổ bảo dưỡng','MANUAL',null,'đạt/lỗi',1,'>=',10,'TRUNG','SOP-TT-05',13),
 -- A6 khu D
 ('SC-A6-01','A6',null,'Nạp trùn/BSF hằng ngày ghi mẻ','Số batch_logs khu D trong tuần ≥ 5','AUTO',$$select s.id, count(b.id), 5 from staff s left join batch_logs b on b.farm_id=s.farm_id and b.created_by=s.id and b.line in ('TRUN_NAP','TRUN_THU','BSF','COMPOST','BIOGAS') and b.ts>=$2 and b.ts<$3 where s.farm_id=$1 and s.position_code='A6' group by s.id$$,'mẻ',5,'>=',20,'NANG','SOP-SH-01',10),
 ('SC-A6-02','A6',null,'Nhiệt luống <35°C, ẩm 70–80%','Đo tại chỗ (đo, không đoán)','MANUAL',null,'đạt/lỗi',1,'>=',15,'TRUNG','SOP-SH-01',11),
 -- A7 D5
 ('SC-A7-01','A7',null,'Mẻ có QC + CCP đủ','% mẻ D5 có ccp_readings & qc','AUTO',$$select s.id, round(100.0*count(*) filter (where jsonb_array_length(coalesce(b.ccp_readings,'[]'))>0 and b.qc<>'{}'::jsonb)/nullif(count(*),0),0), 100 from staff s left join batch_logs b on b.farm_id=s.farm_id and b.created_by=s.id and b.line in ('D5_VIEN','D5_TMR','DONG_GOI') and b.ts>=$2 and b.ts<$3 where s.farm_id=$1 and s.position_code='A7' group by s.id$$,'%',100,'>=',20,'NANG','SOP-CB-01',10),
 ('SC-A7-02','A7',null,'Vệ sinh máy cuối ca, lưu mẫu','Quan sát + tủ mẫu 24h','MANUAL',null,'đạt/lỗi',1,'>=',15,'TRUNG','SOP-CB-01',11),
 -- A8 kho
 ('SC-A8-01','A8',null,'Nhập/xuất ghi trong ngày','% phiếu kho ghi ≤ 2h sau giao dịch','AUTO',$$select s.id, round(100.0*count(*) filter (where m.created_at - m.ts <= interval '2 hours')/nullif(count(*),0),0), 90 from staff s left join inventory_moves m on m.farm_id=s.farm_id and m.created_by=s.id and m.ts>=$2 and m.ts<$3 where s.farm_id=$1 and s.position_code='A8' group by s.id$$,'%',90,'>=',15,'TRUNG','SOP-HC-02',10),
 ('SC-A8-02','A8',null,'Kiểm kê tuần đúng lịch','Có stocktake K4/K5 trong tuần','AUTO',$$select s.id, count(distinct st.warehouse_id), 2 from staff s left join stocktakes st on st.farm_id=s.farm_id and st.ts>=$2 and st.ts<$3 where s.farm_id=$1 and s.position_code='A8' group by s.id$$,'kho',2,'>=',15,'TRUNG','SOP-HC-02',11),
 ('SC-A8-03','A8',null,'FEFO – lô cận hạn ưu tiên xuất','Không có lô hết hạn còn tồn','AUTO',$$select s.id, count(*), 0 from staff s cross join (select 1 from v_stock_available a where a.farm_id=$1 and a.expiry_date < current_date and a.available>0) x where s.farm_id=$1 and s.position_code='A8' group by s.id$$,'lô',0,'<=',10,'NANG','SOP-HC-02',12),
 ('SC-A8-04','A8',null,'Kho gọn – bin đúng vị trí – tem đủ','Quan sát tại kho','MANUAL',null,'đạt/lỗi',1,'>=',10,'NHE','SOP-HC-02',13),
 -- A9 kinh doanh
 ('SC-A9-01','A9',null,'Đơn giao đúng hạn','% đơn deliver_date đúng/ sớm','AUTO',$$select s.id, round(100.0*count(*) filter (where o.status='GIAO')/nullif(count(*),0),0), 95 from staff s left join orders o on o.farm_id=s.farm_id and o.created_by=s.id and o.deliver_date>=$2 and o.deliver_date<$3 where s.farm_id=$1 and s.position_code='A9' group by s.id$$,'%',95,'>=',20,'TRUNG','SOP-KD-02',10),
 ('SC-A9-02','A9',null,'Không bán dưới sàn không duyệt','Số phiếu bán giá < sàn không có duyệt','AUTO',$$select s.id, count(*), 0 from staff s left join sales sl on sl.farm_id=s.farm_id and sl.created_by=s.id and sl.ts>=$2 and sl.ts<$3 and sl.price < (select price from price_list p where p.kind='SAN' and p.subject=sl.sku order by valid_from desc limit 1) where s.farm_id=$1 and s.position_code='A9' group by s.id$$,'phiếu',0,'<=',15,'NANG','SOP-KD-01',11),
 -- A11 cổng
 ('SC-A11-01','A11',null,'Xe vào có cân + khử trùng','% gate_logs weighed & anolyte','AUTO',$$select s.id, round(100.0*count(*) filter (where g.weighed and g.anolyte_wash)/nullif(count(*),0),0), 95 from staff s left join gate_logs g on g.farm_id=s.farm_id and g.created_by=s.id and g.ts>=$2 and g.ts<$3 where s.farm_id=$1 and s.position_code='A11' group by s.id$$,'%',95,'>=',25,'NANG','SOP-AT-01',10),
 ('SC-A11-02','A11',null,'Sổ cổng khớp camera','Đối chiếu ngẫu nhiên 5 lượt/tuần','MANUAL',null,'đạt/lỗi',1,'>=',10,'TRUNG','SOP-AT-01',11),
 -- Trưởng nhóm / KTT (team_lead, tech_head) — theo dept
 ('SC-TL-01',null,null,'Duyệt checklist ca trong ngày','% checklist ca của tổ được duyệt ≤ 24h (người duyệt)','AUTO',$$select s.id, round(100.0*count(*) filter (where c.approved_at - c.ts <= interval '24 hours')/nullif(count(*),0),0), 90 from staff s left join checklist_runs c on c.farm_id=s.farm_id and c.approved_by=s.id and c.ts>=$2 and c.ts<$3 where s.farm_id=$1 and s.role in ('team_lead','tech_head') group by s.id$$,'%',90,'>=',15,'TRUNG',null,20),
 ('SC-TL-02',null,null,'Dạy đủ buổi cho cấp dưới','Buổi dạy XONG / cấp dưới có lịch','AUTO',$$select s.id, count(t.id) filter (where t.status='XONG'), count(t.id) from staff s left join training_sessions t on t.farm_id=s.farm_id and t.trainer_id=s.id and t.week_start>=$2 and t.week_start<$3 where s.farm_id=$1 and s.role in ('team_lead','tech_head','director') group by s.id$$,'buổi',1,'>=',15,'TRUNG',null,21),
 ('SC-TL-03',null,null,'Xử lý cảnh báo đỏ ≤ 4h','% alerts mức ĐỎ của bộ phận được ack ≤ 4h','AUTO',$$select s.id, round(100.0*count(*) filter (where a.acked_at - a.ts <= interval '4 hours')/nullif(count(*),0),0), 90 from staff s left join alerts a on a.farm_id=s.farm_id and a.level='DO' and a.ts>=$2 and a.ts<$3 and a.acked_by=s.id where s.farm_id=$1 and s.role in ('team_lead','tech_head') group by s.id$$,'%',90,'>=',10,'NANG',null,22)
on conflict (id) do nothing;
-- ===== Chấm điểm tuần: hệ thống chạy tiêu chí AUTO → bảng điểm; giám sát ghi MANUAL qua supervision_checks (criteria_id) =====
alter table supervision_checks add column if not exists criteria_id text references supervision_criteria;
alter table supervision_checks add column if not exists week_start date;
create table if not exists supervision_scores(
  id bigserial primary key, farm_id text not null references farms, week_start date not null, staff_id text not null references staff, criteria_id text not null references supervision_criteria,
  method text, value numeric, target numeric, achieved numeric, -- 0..1
  weight numeric, points numeric, source text default 'AUTO', checked_by text, checked_at timestamptz default now(), note text, unique(farm_id, week_start, staff_id, criteria_id));
alter table supervision_scores enable row level security; drop policy if exists p_all on supervision_scores; create policy p_all on supervision_scores for all using (can_see_farm(farm_id)) with check (true); grant select, insert, update, delete on supervision_scores to app_user; grant usage on sequence supervision_scores_id_seq to app_user;
create or replace function run_supervision_auto(p_farm text, p_week date default date_trunc('week', current_date)::date) returns int language plpgsql as $$
declare c record; r record; n int := 0; ach numeric; w_end date := p_week + 7; begin
  for c in select * from supervision_criteria where active and method='AUTO' and sql is not null order by position loop
    begin
      for r in execute c.sql using p_farm, p_week, w_end loop
        -- áp dụng theo vị trí/phòng ban
        if c.position_code is not null and not exists (select 1 from staff s where s.id=r.staff_id and s.position_code=c.position_code) then continue; end if;
        if c.dept_code is not null and not exists (select 1 from staff s where s.id=r.staff_id and s.dept=c.dept_code) then continue; end if;
        if r.value is null then continue; end if;
        ach := case c.direction when '>=' then least(1, r.value/nullif(coalesce(r.target, c.target),0)) when '<=' then case when r.value <= coalesce(r.target,c.target) then 1 else greatest(0, 1 - (r.value - coalesce(r.target,c.target))/greatest(coalesce(r.target,c.target),1)) end else case when r.value = coalesce(r.target,c.target) then 1 else 0 end end;
        if coalesce(r.target,c.target)=0 and c.direction='<=' then ach := case when r.value=0 then 1 else greatest(0, 1 - r.value*0.25) end; end if;
        insert into supervision_scores(farm_id, week_start, staff_id, criteria_id, method, value, target, achieved, weight, points, source)
        values (p_farm, p_week, r.staff_id, c.id, 'AUTO', r.value, coalesce(r.target,c.target), coalesce(ach,0), c.weight, round(c.weight*coalesce(ach,0),2), 'AUTO')
        on conflict (farm_id, week_start, staff_id, criteria_id) do update set value=excluded.value, target=excluded.target, achieved=excluded.achieved, points=excluded.points, checked_at=now();
        n := n+1;
      end loop;
    exception when others then raise notice 'criteria % lỗi: %', c.id, sqlerrm; end;
  end loop;
  -- MANUAL: lấy kết quả giám sát viên ghi trong tuần (DAT=1, LOI=0)
  insert into supervision_scores(farm_id, week_start, staff_id, criteria_id, method, value, target, achieved, weight, points, source, checked_by, note)
  select sc.farm_id, p_week, sc.target_staff_id, sc.criteria_id, 'MANUAL', case when sc.result='DAT' then 1 else 0 end, 1, case when sc.result='DAT' then 1 else 0 end, cr.weight, case when sc.result='DAT' then cr.weight else 0 end, 'GIAM_SAT', sc.supervisor_id, sc.note
  from supervision_checks sc join supervision_criteria cr on cr.id=sc.criteria_id where sc.farm_id=p_farm and sc.status='ACTIVE' and sc.target_staff_id is not null and sc.ts>=p_week and sc.ts<w_end
  on conflict (farm_id, week_start, staff_id, criteria_id) do update set value=excluded.value, achieved=excluded.achieved, points=excluded.points, checked_by=excluded.checked_by, note=excluded.note, checked_at=now();
  return n; end $$;
grant execute on function run_supervision_auto(text,date) to app_user;
-- Bảng điểm tuần theo người (0–100) + xếp loại; bộ phận = TB người
create or replace view v_supervision_weekly as
select s.farm_id, s.week_start, s.staff_id, st.full_name, st.dept, st.position_code, st.role,
  round(100*sum(s.points)/nullif(sum(s.weight),0),1) as score, count(*) as n_criteria, count(*) filter (where s.method='MANUAL') as n_manual, count(*) filter (where s.achieved<1) as n_short,
  string_agg(case when s.achieved<0.8 then cr.name||' ('||coalesce(s.value::text,'')||'/'||coalesce(s.target::text,'')||')' end, ' · ') as shortfalls,
  case when 100*sum(s.points)/nullif(sum(s.weight),0) >= 90 then 'A' when 100*sum(s.points)/nullif(sum(s.weight),0) >= 75 then 'B' when 100*sum(s.points)/nullif(sum(s.weight),0) >= 60 then 'C' else 'D' end as grade
from supervision_scores s join staff st on st.id=s.staff_id join supervision_criteria cr on cr.id=s.criteria_id group by 1,2,3,4,5,6,7;
grant select on v_supervision_weekly to app_user;
create or replace view v_supervision_dept_weekly as
select farm_id, week_start, dept, round(avg(score),1) as score, count(*) as staff_n, count(*) filter (where grade in ('C','D')) as low_n from v_supervision_weekly group by 1,2,3;
grant select on v_supervision_dept_weekly to app_user;
-- Việc cho giám sát viên mỗi tuần: checklist MANUAL cho từng người trong phạm vi + xác nhận điểm AUTO thấp
create or replace function gen_supervision_tasks(p_farm text, p_week date default date_trunc('week', current_date)::date) returns int language plpgsql as $$
declare a record; n int := 0; cnt int; begin
  for a in select * from supervision_assignments where farm_id=p_farm and active loop
    select count(*) into cnt from staff s join supervision_criteria c on c.method='MANUAL' and c.active and (c.position_code=s.position_code or (c.position_code is null and c.dept_code=s.dept)) where s.farm_id=p_farm and s.active and (a.target_staff_id=s.id or (a.target_staff_id is null and s.dept=a.target_dept));
    if not exists (select 1 from tasks t where t.farm_id=p_farm and t.kind='GIAM_SAT' and t.assignee_id=a.supervisor_id and t.target_id=a.id and t.created_at>=p_week) then
      insert into tasks(id, farm_id, kind, title, detail, due_at, assignee_id, target_type, target_id, status, source, priority)
      values (gen_random_uuid(), p_farm, 'GIAM_SAT', 'Giám sát tuần '||to_char(p_week,'DD/MM')||': '||coalesce(a.target_dept, a.target_staff_id)||' — '||cnt||' tiêu chí quan sát + xác nhận điểm auto', jsonb_build_object('assignment_id', a.id, 'target_dept', a.target_dept, 'target_staff_id', a.target_staff_id, 'checks_per_week', a.checks_per_week, 'text', 'Mở /giam-sat → chấm từng tiêu chí (đạt/lỗi, mức độ, ảnh); hệ thống đã chấm phần tự động'), (p_week+5)::timestamptz + interval '17 hours', a.supervisor_id, 'supervision_assignment', a.id, 'MO', 'SUPERVISION', 'CAO');
      n := n+1;
    end if;
  end loop; return n; end $$;
grant execute on function gen_supervision_tasks(text,date) to app_user;
-- bonus_eval: dùng điểm giám sát tuần → nếu điểm TB tháng < 60 (D) thì không đủ điều kiện; điểm lỗi vẫn trừ theo 0075
create or replace view v_supervision_monthly as
select farm_id, staff_id, to_char(week_start,'YYYY-MM') as period, round(avg(score),1) as score, count(*) as weeks, min(grade) as worst_grade from v_supervision_weekly group by 1,2,3;
grant select on v_supervision_monthly to app_user;
