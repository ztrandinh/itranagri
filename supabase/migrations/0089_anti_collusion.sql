-- 0089 · CHỐNG THÔNG ĐỒNG / BAO CHE / LƯỜI giữa trưởng phòng ↔ giám sát
-- Nguyên tắc: (1) máy chọn mẫu, không phải người; (2) mọi chấm ĐẠT của người bị đối chiếu với dữ liệu tự động; (3) kiểm chéo mù ngẫu nhiên bởi người khác; (4) tín hiệu bất thường tự tính → tuyến 3 kiểm đột xuất; (5) kênh phản ánh ẩn danh lên Chủ tịch/TGĐ; (6) hậu quả gắn thẳng vào bậc/thưởng.

-- 1) Kiểm chéo mù: máy bốc mẫu ĐẠT tuần này của mỗi GS → giao GS khác (hoặc audit/GĐ) chấm lại độc lập
create table if not exists cross_checks(
  id uuid primary key default gen_random_uuid(), farm_id text not null, week_start date not null, original_check_id uuid not null, original_supervisor text not null,
  target_dept text, target_staff_id text, criteria_id text, checker_id text not null, status text not null default 'MO' check (status in ('MO','XONG','BO_QUA')),
  result text, note text, evidence_url text, created_at timestamptz default now(), done_at timestamptz, mismatch boolean, unique (original_check_id, checker_id)
);
create index if not exists ix_cross_checks_wk on cross_checks(farm_id, week_start);
alter table cross_checks enable row level security; drop policy if exists p_all on cross_checks; create policy p_all on cross_checks for all using (can_see_farm(farm_id)) with check (true); grant select, insert, update on cross_checks to app_user;
create or replace function gen_cross_checks(p_farm text) returns int language plpgsql as $$
declare n int := 0; g record; r record; chk text; pct numeric; wk date := date_trunc('week', current_date)::date;
begin
  pct := setting_num('gs.cross_check_pct', p_farm, 20);
  for g in select supervisor_id, count(*) cnt from supervision_checks where farm_id=p_farm and week_start=wk and result='DAT' group by 1 loop
    for r in select c.* from supervision_checks c where c.farm_id=p_farm and c.week_start=wk and c.result='DAT' and c.supervisor_id=g.supervisor_id
             and not exists (select 1 from cross_checks x where x.original_check_id=c.id) order by random() limit greatest(2, least(5, ceil(g.cnt*pct/100.0)))::int loop
      -- người chấm lại: GS khác không cùng phòng gốc với đối tượng, không phải người bị kiểm; nếu không có → auditor/GĐ
      select s.id into chk from staff s where s.active and s.id<>g.supervisor_id and s.id is distinct from r.target_staff_id and coalesce(s.dept,'') <> coalesce(r.target_dept,(select dept from staff where id=r.target_staff_id),'')
        and (current_grade(s.id,'GS') is not null or s.role in ('auditor')) and (s.farm_id=p_farm or s.farm_id is null) order by random() limit 1;
      if chk is null then select id into chk from staff where farm_id=p_farm and role='director' and active order by random() limit 1; end if;
      if chk is null then continue; end if;
      insert into cross_checks(farm_id,week_start,original_check_id,original_supervisor,target_dept,target_staff_id,criteria_id,checker_id) values (p_farm,wk,r.id,g.supervisor_id,r.target_dept,r.target_staff_id,r.criteria_id,chk) on conflict do nothing;
      insert into tasks(farm_id,kind,title,detail,target_type,target_id,assignee_id,due_at,priority,source)
        values (p_farm,'KIEM_CHEO','Kiểm chéo mù: '||coalesce((select name from supervision_criteria where id=r.criteria_id), r.item)||' — '||coalesce((select full_name from staff where id=r.target_staff_id), r.target_dept, ''),
          jsonb_build_object('note','Máy bốc mẫu. Chấm ĐỘC LẬP, không hỏi người chấm gốc; bắt buộc ảnh bằng chứng.','check_id',r.id,'week',wk),'staff',coalesce(r.target_staff_id,r.target_dept),chk,(wk+6)::timestamptz + interval '17 hours','CAO','CROSS_CHECK');
      n := n+1;
    end loop;
  end loop; return n;
end $$;
-- Ghi kết quả kiểm chéo: chèn 1 supervision_check của người chấm lại (để agree_pct tự tính) + đánh dấu lệch
create or replace function submit_cross_check(p_id uuid, p_by text, p_result text, p_note text, p_evidence text) returns jsonb language plpgsql as $$
declare x record; o record; mm boolean; newid uuid;
begin
  select * into x from cross_checks where id=p_id and checker_id=p_by and status='MO'; if x is null then raise exception 'ERR_NOT_FOUND'; end if;
  select * into o from supervision_checks where id=x.original_check_id;
  insert into supervision_checks(farm_id, created_by, client_ref, supervisor_id, target_dept, target_staff_id, sop_code, criteria_id, week_start, item, result, severity, note, evidence_url)
    values (x.farm_id, p_by, 'XC-'||p_id, p_by, o.target_dept, o.target_staff_id, o.sop_code, o.criteria_id, o.week_start, o.item, p_result, case when p_result='LOI' then 'TRUNG' end, '[kiểm chéo] '||coalesce(p_note,''), p_evidence) returning id into newid;
  mm := (p_result <> o.result);
  update cross_checks set status='XONG', result=p_result, note=p_note, evidence_url=p_evidence, done_at=now(), mismatch=mm where id=p_id;
  update tasks set status='XONG', done_by=p_by, done_at=now() where farm_id=x.farm_id and kind='KIEM_CHEO' and detail->>'check_id'=x.original_check_id::text and assignee_id=p_by and status<>'XONG';
  if mm then
    insert into notifications(farm_id,staff_id,level,title,body,link,source,source_id)
      select x.farm_id, s.id, 'CAM', 'Kiểm chéo LỆCH: '||(select full_name from staff where id=x.original_supervisor)||' chấm ĐẠT, người kiểm chéo thấy LỖI', coalesce(o.item,'')||' — '||coalesce(o.target_dept,'')||' '||coalesce(o.target_staff_id,''), '/giam-sat?tab=chong', 'cross_check', p_id::text
      from staff s where s.role in ('director','owner') and (s.farm_id=x.farm_id or s.farm_id is null) limit 3;
  end if;
  return jsonb_build_object('mismatch', mm, 'check_id', newid);
end $$;
grant execute on function gen_cross_checks(text), submit_cross_check(uuid,text,text,text,text) to app_user;
-- 2) Mẫu ngẫu nhiên do máy chọn: mỗi tuần, mỗi GS phải chấm N mục do máy bốc (không tự chọn ai/cái gì), bắt buộc ảnh
create or replace function gen_random_spot_checks(p_farm text) returns int language plpgsql as $$
declare n int := 0; g record; r record; wk date := date_trunc('week', current_date)::date; k int;
begin
  k := setting_num('gs.random_spots_per_week', p_farm, 3)::int;
  for g in select a.supervisor_id, array_agg(distinct a.target_dept) depts from supervision_assignments a where a.farm_id=p_farm and a.active and a.target_dept is not null group by 1 loop
    for r in select s.id staff_id, s.full_name, s.dept, c.id crit_id, c.name from staff s join supervision_criteria c on c.method='MANUAL' and c.active and (c.dept_code is null or c.dept_code=s.dept) and (c.position_code is null or c.position_code=s.position_code)
             where s.farm_id=p_farm and s.active and s.dept = any(g.depts) order by random() limit k loop
      if exists (select 1 from tasks where farm_id=p_farm and kind='KIEM_NGAU_NHIEN' and assignee_id=g.supervisor_id and detail->>'week'=wk::text and detail->>'staff'=r.staff_id and detail->>'crit'=r.crit_id) then continue; end if;
      insert into tasks(farm_id,kind,title,detail,target_type,target_id,assignee_id,due_at,priority,source)
        values (p_farm,'KIEM_NGAU_NHIEN','Mẫu máy bốc: '||r.name||' — '||r.full_name||' ('||r.dept||')', jsonb_build_object('note','Máy chọn ngẫu nhiên — chấm đúng mục này, bắt buộc ảnh bằng chứng','week',wk,'staff',r.staff_id,'crit',r.crit_id),'staff',r.staff_id,g.supervisor_id,(wk+4)::timestamptz + interval '17 hours','BINH_THUONG','RANDOM_SPOT');
      n := n+1;
    end loop;
  end loop; return n;
end $$;
grant execute on function gen_random_spot_checks(text) to app_user;
-- 3) TÍN HIỆU BẤT THƯỜNG tự tính (8 tuần) — không ai nhập, không ai tắt được
create or replace view v_collusion_signals as
with wk as (select generate_series(date_trunc('week', current_date)::date - 49, date_trunc('week', current_date)::date, '7 days')::date w),
-- chỉ xét người thuộc ngạch GS hoặc auditor (tự kiểm tuyến 1 của KTT không tính)
gs as (select id from staff where current_grade(id,'GS') is not null or role='auditor'),
manual as (select c.farm_id, c.supervisor_id, coalesce(c.target_dept, s.dept) dept, c.week_start, c.target_staff_id, c.result, c.created_at, c.evidence_url, c.verified_at, c.ts, c.id from supervision_checks c join gs on gs.id=c.supervisor_id left join staff s on s.id=c.target_staff_id where c.week_start >= date_trunc('week', current_date)::date - 49),
auto_fail as (select farm_id, staff_id, week_start, count(*) filter (where coalesce(achieved,0) < 1) nf, count(*) nt from supervision_scores where method='AUTO' and week_start >= date_trunc('week', current_date)::date - 49 group by 1,2,3)
-- S1: chấm ĐẠT cho người mà dữ liệu tự động tuần đó báo ≥ 2 mục KHÔNG đạt
select m.farm_id, 'S1_DAT_TRAI_DU_LIEU' as signal, 'Chấm ĐẠT trong khi dữ liệu tự động báo lỗi' as label, m.supervisor_id, m.dept, m.week_start, count(*)::numeric as value, 'CAO' as severity
 from manual m join auto_fail a on a.farm_id=m.farm_id and a.staff_id=m.target_staff_id and a.week_start=m.week_start where m.result='DAT' and a.nf >= 2 group by 1,2,3,4,5,6 having count(*) >= 2
union all -- S2: chấm quá nhanh (≥5 lượt trong 3 phút) — chấm cho có
select farm_id, 'S2_CHAM_QUA_NHANH', 'Chấm ≥5 lượt trong 3 phút (chấm cho có)', supervisor_id, dept, week_start, max(cnt)::numeric, 'TRUNG' from (
  select m.farm_id, m.supervisor_id, m.dept, m.week_start, count(*) over (partition by m.supervisor_id, m.week_start order by m.created_at range between interval '3 minutes' preceding and current row) cnt from manual m) z where cnt >= 5 group by 1,2,3,4,5,6
union all -- S3: 4+ tuần liền không ghi lỗi nào cho 1 phòng trong khi tự động báo tỷ lệ không đạt > 20%
select z.farm_id, 'S3_KHONG_LOI_BAT_THUONG', '≥4 tuần không ghi lỗi nào dù dữ liệu tự động >20% không đạt', z.supervisor_id, z.dept, max(z.week_start), count(*)::numeric, 'CAO' from (
  select m.farm_id, m.supervisor_id, m.dept, m.week_start, count(*) filter (where m.result='LOI') nl,
    (select sum(nf)::numeric/nullif(sum(nt),0) from auto_fail a join staff s on s.id=a.staff_id where a.farm_id=m.farm_id and s.dept=m.dept and a.week_start=m.week_start) fail_rate
  from manual m group by 1,2,3,4) z where z.nl=0 and coalesce(z.fail_rate,0) > 0.2 group by 1,2,3,4,5 having count(*) >= 4
union all -- S4: xác nhận "đã khắc phục" quá nhanh (<24h sau lỗi) ≥3 lần
select farm_id, 'S4_XAC_NHAN_QUA_NHANH', 'Xác nhận khắc phục <24h sau lỗi ≥3 lần', supervisor_id, dept, week_start, count(*)::numeric, 'TRUNG' from manual where result='LOI' and verified_at is not null and verified_at < ts + interval '24 hours' group by 1,2,3,4,5,6 having count(*) >= 3
union all -- S5: kiểm chéo lệch ≥2 lần/8 tuần
select farm_id, 'S5_KIEM_CHEO_LECH', 'Kiểm chéo mù phát hiện lệch (ĐẠT↔LỖI)', original_supervisor, target_dept, max(week_start), count(*)::numeric, 'CAO' from cross_checks where mismatch and week_start >= date_trunc('week', current_date)::date - 49 group by 1,2,3,4,5 having count(*) >= 2
union all -- S6: GS kiểm chính phòng gốc của mình
select a.farm_id, 'S6_KIEM_PHONG_GOC', 'Giám sát viên đang kiểm chính phòng gốc của mình', a.supervisor_id, a.target_dept, current_date, 1, 'CAO' from supervision_assignments a join staff s on s.id=a.supervisor_id where a.active and a.target_dept is not null and s.dept=a.target_dept and s.role<>'auditor' and current_grade(s.id,'GS') is not null
union all -- S7: lỗi ghi không có ảnh bằng chứng ≥ 70% trong tuần (≥5 lượt)
select farm_id, 'S7_KHONG_BANG_CHUNG', 'Chấm không kèm ảnh bằng chứng ≥70%', supervisor_id, dept, week_start, round(100.0*count(*) filter (where evidence_url is null)/count(*)), 'THAP' from manual group by 1,2,3,4,5,6 having count(*) >= 5 and count(*) filter (where evidence_url is null) >= 0.7*count(*)
union all -- S8: trưởng phòng chấm GS 5/5 trong khi phòng đó tự động không đạt >20% và GS không ghi lỗi (đổi chác)
select r.farm_id, 'S8_CHAM_NGUOC_DOI_CHAC', 'Trưởng phòng chấm GS 5/5 nhưng phòng có dữ liệu xấu và GS không ghi lỗi', r.supervisor_id, h.dept, date_trunc('week', current_date)::date, 1, 'TRUNG'
 from supervisor_ratings r join staff h on h.id=r.rated_by where r.useful=5 and r.fair=5 and r.knows=5 and r.created_at > now() - interval '8 weeks'
  and exists (select 1 from manual m where m.supervisor_id=r.supervisor_id and m.dept=h.dept) and not exists (select 1 from manual m where m.supervisor_id=r.supervisor_id and m.dept=h.dept and m.result='LOI')
  and (select sum(nf)::numeric/nullif(sum(nt),0) from auto_fail a join staff s on s.id=a.staff_id where s.dept=h.dept and a.farm_id=r.farm_id) > 0.2;
grant select on v_collusion_signals to app_user;
-- Cặp GS ↔ phòng có ≥2 tín hiệu (hoặc 1 tín hiệu CAO) → cờ đỏ, tuyến 3 kiểm đột xuất
create or replace view v_collusion_pairs as
 select farm_id, supervisor_id, (select full_name from staff where id=v.supervisor_id) supervisor_name, dept, count(*) n_signals, count(*) filter (where severity='CAO') n_cao, array_agg(distinct signal) signals, max(week_start) last_week,
   case when count(*) filter (where severity='CAO') >= 1 or count(*) >= 2 then 'DO' when count(*) >= 1 then 'VANG' else 'XANH' end as level
 from v_collusion_signals v group by 1,2,4;
grant select on v_collusion_pairs to app_user;
-- Cờ đỏ → việc kiểm đột xuất cho tuyến 3 (audit/GĐ) + báo Chủ tịch/TGĐ; số cờ trong 8 tuần đi vào bằng chứng lên bậc GS
create or replace function gen_collusion_audits(p_farm text) returns int language plpgsql as $$
declare n int := 0; r record; who text;
begin
  for r in select * from v_collusion_pairs where farm_id=p_farm and level='DO' loop
    if exists (select 1 from tasks where farm_id=p_farm and kind='KIEM_DOT_XUAT' and status in ('MO','DANG_LAM') and detail->>'supervisor'=r.supervisor_id and detail->>'dept'=coalesce(r.dept,'')) then continue; end if;
    select id into who from staff where (farm_id=p_farm or farm_id is null) and active and role='auditor' and id<>r.supervisor_id order by random() limit 1;
    if who is null then select id into who from staff where farm_id=p_farm and role='director' and active limit 1; end if;
    insert into tasks(farm_id,kind,title,detail,target_type,target_id,assignee_id,due_at,priority,source)
      values (p_farm,'KIEM_DOT_XUAT','Kiểm đột xuất (tuyến 3): cặp GS '||coalesce(r.supervisor_name,r.supervisor_id)||' ↔ phòng '||coalesce(r.dept,'?')||' có '||r.n_signals||' tín hiệu bất thường',
        jsonb_build_object('supervisor',r.supervisor_id,'dept',r.dept,'signals',to_jsonb(r.signals),'note','Đi kiểm không báo trước, đối chiếu dữ liệu tự động, phỏng vấn công nhân, chụp ảnh'), 'dept', r.dept, who, now() + interval '3 days', 'KHAN', 'ANTI_COLLUSION');
    insert into notifications(farm_id,staff_id,level,title,body,link,source) select p_farm, s.id, 'DO', 'Cờ đỏ thông đồng: GS '||coalesce(r.supervisor_name,'')||' ↔ '||coalesce(r.dept,''), array_to_string(r.signals, ', '), '/giam-sat?tab=chong', 'anti_collusion' from staff s where s.role in ('owner','director') and (s.farm_id=p_farm or s.farm_id is null) limit 4;
    n := n+1;
  end loop; return n;
end $$;
grant execute on function gen_collusion_audits(text) to app_user;
-- 4) Phản ánh ẩn danh lên Chủ tịch/TGĐ (không lưu người gửi; chỉ lưu băm chống spam)
create table if not exists whistle_reports(id uuid primary key default gen_random_uuid(), farm_id text not null, created_at timestamptz default now(), category text not null default 'KHAC', target_dept text, content text not null, reporter_hash text, status text not null default 'MOI' check (status in ('MOI','DANG_XEM','DA_XU_LY','BO_QUA')), handled_by text, handled_at timestamptz, note text);
alter table whistle_reports enable row level security; drop policy if exists p_sel on whistle_reports; create policy p_sel on whistle_reports for select using (can_see_farm(farm_id) and app_role() in ('owner','director'));
drop policy if exists p_ins on whistle_reports; create policy p_ins on whistle_reports for insert with check (true);
drop policy if exists p_upd on whistle_reports; create policy p_upd on whistle_reports for update using (can_see_farm(farm_id) and app_role() in ('owner','director'));
grant select, insert, update on whistle_reports to app_user;
create or replace function whistle_submit(p_farm text, p_category text, p_dept text, p_content text, p_staff text) returns uuid language plpgsql security definer as $$
declare i uuid; h text; begin
  h := md5(coalesce(p_staff,'')||to_char(current_date,'IYYY-IW')||'itran-salt');
  if (select count(*) from whistle_reports where reporter_hash=h) >= 5 then raise exception 'ERR_RATE_LIMIT'; end if;
  insert into whistle_reports(farm_id,category,target_dept,content,reporter_hash) values (p_farm,p_category,p_dept,p_content,h) returning id into i;
  insert into notifications(farm_id,staff_id,level,title,body,link,source,source_id) select p_farm, s.id, 'CAM', 'Phản ánh ẩn danh mới ('||p_category||')', left(p_content, 120), '/giam-sat?tab=chong', 'whistle', i::text from staff s where s.role in ('owner') or (s.role='director' and s.farm_id is null) limit 3;
  return i; end $$;
grant execute on function whistle_submit(text,text,text,text,text) to app_user;
-- 5) Hậu quả tự động: cờ đỏ 8 tuần → chặn lên bậc GS (criteria flags_max) — thêm vào bằng chứng
create or replace function collusion_flags(p_staff text) returns int language sql stable as $$ select count(*)::int from v_collusion_pairs where supervisor_id=p_staff and level='DO' $$;
grant execute on function collusion_flags(text) to app_user;
update grade_scales set criteria = criteria || '{"flags_max":0}' where track='GS' and code in ('GS2','GS3','PGD');
-- 6) Chặn GS chấm phòng gốc của mình (trừ auditor) ngay lúc ghi
create or replace function trg_sup_check_guard() returns trigger language plpgsql as $$
declare sd text; sr text; td text; begin
  select dept, role into sd, sr from staff where id=new.supervisor_id;
  td := coalesce(new.target_dept, (select dept from staff where id=new.target_staff_id));
  if (sr <> 'auditor' or current_grade(new.supervisor_id,'GS') is not null) and sd is not null and td is not null and sd = td and coalesce(new.note,'') not like '[kiểm chéo]%' then raise exception 'ERR_SELF_DEPT: giám sát viên không được chấm phòng gốc của mình'; end if;
  if new.target_staff_id = new.supervisor_id then raise exception 'ERR_SELF_CHECK'; end if;
  return new; end $$;
drop trigger if exists sup_check_guard on supervision_checks; create trigger sup_check_guard before insert on supervision_checks for each row execute function trg_sup_check_guard();
