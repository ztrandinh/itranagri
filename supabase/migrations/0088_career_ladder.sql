-- 0088 · BẬC cá nhân (4 bậc, gắn lương) · GHẾ theo định biên · NGẠCH GIÁM SÁT–KẾ THỪA (công ty mẹ, luân chuyển 8 khối) · BẢN ĐỒ KẾ THỪA · nhịp tuần CAPA GS↔trưởng phòng · điểm cống hiến
-- Nguyên tắc: bậc = của cá nhân, không giới hạn; chức = ghế theo định biên. Mọi tiêu chí là DỮ LIỆU (grade_scales.criteria) có phiên bản. Mọi bằng chứng tự tính từ dữ liệu vận hành.

-- ========== 1) Bảng bậc & tiêu chí (dữ liệu, có phiên bản) ==========
create table if not exists grade_scales(
  org_id text not null default 'ITRAN', track text not null check (track in ('CM','GS')), code text not null, name text not null, rank int not null,
  salary_coef numeric not null default 1, criteria jsonb not null default '{}', perks text, version int not null default 1, active boolean default true,
  primary key (org_id, track, code, version)
);
grant select on grade_scales to app_user; alter table grade_scales enable row level security; drop policy if exists p_all on grade_scales; create policy p_all on grade_scales for all using (true) with check (true);
grant insert, update on grade_scales to app_user;
-- criteria keys: min_months · comp_level (HOC/THUC_HANH/THUAN_THUC/DAY_DUOC) · comp_pct (% SOP vị trí đạt ≥ comp_level) · sup_avg_min (điểm GS TB) · sup_months (số tháng liền) · kpi_hit_min/kpi_of (tháng đạt thưởng / tháng xét)
--   · severe_free_months (không lỗi nặng) · teach_sessions_min · trainee_pass_pct_min · initiatives_min · acting_stints_min (kỳ làm quyền ≥ acting_days) · acting_days · blocks_min (GS: số khối đạt/8) · rating_min (GS: điểm chấm ngược 1–5) · dept_improve_min (GS: phòng kiểm tăng điểm sau 2 quý) · gs_months (tháng làm GS)
insert into grade_scales(track,code,name,rank,salary_coef,criteria,perks) values
 ('CM','B1','Tập sự',1,1.00,'{"min_months":0}','Lương cơ bản; chỉ ghi, có người kèm'),
 ('CM','B2','Thạo việc',2,1.15,'{"min_months":3,"comp_level":"THUC_HANH","comp_pct":100,"sup_avg_min":80,"sup_months":3,"ontime_min":90}','+1 bậc lương; tự ghi không cần kèm'),
 ('CM','B3','Chính',3,1.35,'{"min_months":12,"comp_level":"THUAN_THUC","comp_pct":80,"kpi_hit_min":9,"kpi_of":12,"severe_free_months":6,"sup_avg_min":85,"sup_months":3}','+1 bậc lương; được cử THAY NGƯỜI và kèm B1; đủ điều kiện vào ngạch Giám sát'),
 ('CM','B4','Thợ cả / Chuyên gia',4,1.60,'{"min_months":24,"comp_level":"DAY_DUOC","comp_pct":50,"teach_sessions_min":6,"trainee_pass_pct_min":80,"initiatives_min":1,"kpi_hit_min":9,"kpi_of":12,"severe_free_months":12}','Phụ cấp; ứng viên ghế tổ trưởng/trưởng phòng; nhánh chuyên gia không bắt buộc làm quản lý'),
 ('GS','GS1','Giám sát viên tập sự',1,1.35,'{"entry_grade":"B3","gs_months":0}','Kiểm 1 khối khác khối gốc; chấm điểm, chưa quyết'),
 ('GS','GS2','Giám sát viên',2,1.55,'{"gs_months":6,"weekly_fill_min":90,"agree_min":85,"blocks_min":2,"rating_min":3.5,"field_days_min":8}','Kiểm 2–3 khối; là NGƯỜI THAY mặc định khi trưởng phòng nghỉ'),
 ('GS','GS3','Giám sát trưởng',3,1.85,'{"gs_months":18,"blocks_min":6,"acting_stints_min":2,"acting_days":14,"dept_improve_min":10,"rating_min":4,"agree_min":85}','Điều phối tổ GS; ký CAPA; đề xuất thưởng/kỷ luật; họp S&OP'),
 ('GS','PGD','Phó GĐ trại (dự bị)',4,2.20,'{"gs_months":30,"blocks_min":8,"acting_stints_min":3,"acting_days":14,"led_plan_or_audit":1,"rating_min":4}','Duyệt cấp 2; thay GĐ khi vắng; ứng viên GĐ trại / GĐ trại mới khi nhân rộng')
on conflict do nothing;
-- ========== 2) 8 khối luân chuyển của ngạch GS ==========
create table if not exists gs_blocks(code text primary key, name text not null, depts text[] not null, rank int not null);
grant select on gs_blocks to app_user; alter table gs_blocks enable row level security; drop policy if exists p_all on gs_blocks; create policy p_all on gs_blocks for all using (true) with check (true);
insert into gs_blocks values ('CN','Chăn nuôi – Thú y','{KTCN}',1),('TT','Trồng trọt – Sinh khối','{TT}',2),('SH','Sinh học tuần hoàn khu D','{SH}',3),('D5','Xưởng D5 – Chế biến','{D5}',4),('KHO','Kho – Mua – Vận tải','{CCU}',5),('KD','Kinh doanh – Du lịch – XNK','{KDM,DL,XNK}',6),('TCNS','Tài chính – Nhân sự','{TCKT,HCNS}',7),('TB','Công nghệ – Thiết bị','{CNTB}',8) on conflict do nothing;
-- ========== 3) Bậc của từng người · đề xuất xét quý (3 chữ ký) ==========
create table if not exists staff_grades(
  id uuid primary key default gen_random_uuid(), farm_id text not null, staff_id text not null, track text not null, grade_code text not null,
  since date not null default current_date, until date, status text not null default 'CHINH_THUC' check (status in ('THU_BAC','CHINH_THUC','HA_BAC')), review_id uuid, salary_coef numeric, note text, created_at timestamptz default now(), created_by text
);
create index if not exists ix_staff_grades_cur on staff_grades(staff_id, track) where until is null;
alter table staff_grades enable row level security; drop policy if exists p_all on staff_grades; create policy p_all on staff_grades for all using (can_see_farm(farm_id)) with check (true); grant select, insert, update on staff_grades to app_user;
create table if not exists grade_reviews(
  id uuid primary key default gen_random_uuid(), farm_id text not null, staff_id text not null, track text not null, quarter text not null,
  from_grade text, to_grade text, kind text not null check (kind in ('LEN','GIU','HA','CANH_BAO')), evidence jsonb, score_pct numeric, missing text[],
  status text not null default 'DE_XUAT' check (status in ('DE_XUAT','DA_KY','TU_CHOI','KHANG_NGHI','AP_DUNG')), signs jsonb default '{}', note text, appeal_note text,
  created_at timestamptz default now(), decided_at timestamptz, unique (staff_id, track, quarter)
);
alter table grade_reviews enable row level security; drop policy if exists p_all on grade_reviews; create policy p_all on grade_reviews for all using (can_see_farm(farm_id)) with check (true); grant select, insert, update on grade_reviews to app_user;
-- ========== 4) Ghế then chốt (định biên) & bản đồ kế thừa ==========
create table if not exists key_positions(
  id uuid primary key default gen_random_uuid(), farm_id text not null, code text not null, title text not null, dept text, holder_id text, is_key boolean default true,
  planned_headcount int default 1, year int default extract(year from current_date), min_grade text default 'B3', track text default 'CM', note text, created_at timestamptz default now(), unique (farm_id, code, year)
);
create table if not exists succession_plans(
  id uuid primary key default gen_random_uuid(), farm_id text not null, key_position_id uuid not null references key_positions on delete cascade, successor_id text not null,
  readiness text not null default '2_NAM' check (readiness in ('NGAY','1_NAM','2_NAM')), dev_plan text, updated_at timestamptz default now(), updated_by text, unique (key_position_id, successor_id)
);
alter table key_positions enable row level security; drop policy if exists p_all on key_positions; create policy p_all on key_positions for all using (can_see_farm(farm_id)) with check (true); grant select, insert, update, delete on key_positions to app_user;
alter table succession_plans enable row level security; drop policy if exists p_all on succession_plans; create policy p_all on succession_plans for all using (can_see_farm(farm_id)) with check (true); grant select, insert, update, delete on succession_plans to app_user;
-- ========== 5) GS đi ca thật · chấm ngược GS · sáng kiến ==========
create table if not exists gs_field_days(id uuid primary key default gen_random_uuid(), farm_id text not null, supervisor_id text not null, day date not null default current_date, block text references gs_blocks, dept text, note text, verified_by text, created_at timestamptz default now(), unique (supervisor_id, day));
create table if not exists supervisor_ratings(id uuid primary key default gen_random_uuid(), farm_id text not null, supervisor_id text not null, rated_by text not null, period text not null, useful int check (useful between 1 and 5), fair int check (fair between 1 and 5), knows int check (knows between 1 and 5), note text, created_at timestamptz default now(), unique (supervisor_id, rated_by, period), check (supervisor_id <> rated_by));
create table if not exists initiatives(id uuid primary key default gen_random_uuid(), farm_id text not null, staff_id text not null, title text not null, kind text default 'CAI_TIEN', description text, benefit text, status text not null default 'DE_XUAT' check (status in ('DE_XUAT','DUYET','TU_CHOI','AP_DUNG')), approved_by text, approved_at timestamptz, created_at timestamptz default now());
do $$ declare t text; begin foreach t in array array['gs_field_days','supervisor_ratings','initiatives'] loop
  execute format('alter table %I enable row level security; drop policy if exists p_all on %I; create policy p_all on %I for all using (can_see_farm(farm_id)) with check (true); grant select, insert, update on %I to app_user', t,t,t,t); end loop; end $$;

-- ========== 6) Bằng chứng tự tính ==========
create or replace function current_grade(p_staff text, p_track text) returns text language sql stable as $$
  select grade_code from staff_grades where staff_id=p_staff and track=p_track and until is null order by since desc limit 1 $$;
-- Bảng phủ 8 khối của một GS
create or replace function gs_coverage(p_farm text, p_staff text) returns table(block text, name text, months numeric, sop_passed int, field_days int, acting int, done boolean, current boolean) language sql stable as $$
  select b.code, b.name,
    coalesce((select round(sum(extract(epoch from (least(coalesce(a.to_date,current_date),current_date)::timestamp - a.from_date::timestamp))/86400/30.4)::numeric,1) from supervision_assignments a where a.supervisor_id=p_staff and a.target_dept = any(b.depts)),0) as months,
    (select count(*)::int from training_tests t join sops s on s.code=t.sop_code where t.trainee_id=p_staff and t.passed and s.dept = any(b.depts)) as sop_passed,
    (select count(*)::int from gs_field_days f where f.supervisor_id=p_staff and (f.block=b.code or f.dept = any(b.depts))) as field_days,
    (select count(*)::int from staff_delegations d join staff h on h.id=d.from_staff where d.to_staff=p_staff and d.status in ('ACTIVE','ENDED') and h.dept = any(b.depts) and h.role in ('tech_head','team_lead','director') and (d.to_date - d.from_date + 1) >= setting_num('gs.acting_days', p_farm, 14)) as acting,
    false, exists (select 1 from supervision_assignments a where a.supervisor_id=p_staff and a.active and a.target_dept = any(b.depts) and (a.to_date is null or a.to_date >= current_date))
  from gs_blocks b order by b.rank $$;
create or replace function gs_coverage_done(p_farm text, p_staff text) returns table(block text, name text, months numeric, sop_passed int, field_days int, acting int, done boolean, current boolean) language sql stable as $$
  select block, name, months, sop_passed, field_days, acting,
    (months >= setting_num('gs.block_months', p_farm, 3) and sop_passed >= 1 and field_days >= setting_num('gs.block_field_days', p_farm, 4)) as done, current
  from gs_coverage(p_farm, p_staff) $$;
grant execute on function gs_coverage(text,text), gs_coverage_done(text,text), current_grade(text,text) to app_user;
-- Bằng chứng đầy đủ cho 1 người (mọi ngạch)
create or replace function grade_evidence(p_farm text, p_staff text) returns jsonb language plpgsql stable as $$
declare j jsonb; s record; comp_total int; sup_avg numeric; sup_months int; kpi_hit int; kpi_of int; sev int; teach int; tpass numeric; ini int; acting int; ontime numeric; agree numeric; fill numeric; rating numeric; gs_months numeric; blocks int; improve numeric;
begin
  select * into s from staff where id=p_staff;
  select count(*) into comp_total from v_training_curriculum where staff_id=p_staff;
  select round(avg(m.score),1), count(*) into sup_avg, sup_months from (select score from v_supervision_monthly where staff_id=p_staff order by period desc limit 3) m;
  select count(*) filter (where amount > 0), count(*) into kpi_hit, kpi_of from (select amount from bonus_ledger where staff_id=p_staff and kind='THUONG_THANG' order by period desc limit 12) b;
  select count(*) into sev from supervision_checks where target_staff_id=p_staff and result='LOI' and severity='NANG' and ts > now() - interval '12 months';
  select count(*) into teach from training_sessions where trainer_id=p_staff and status='XONG' and held_at > now() - interval '12 months';
  select round(100.0*count(*) filter (where t.passed)/nullif(count(*),0),0) into tpass from training_tests t join training_sessions ts on ts.id=t.session_id where ts.trainer_id=p_staff and t.taken_at > now() - interval '12 months';
  select count(*) into ini from initiatives where staff_id=p_staff and status in ('DUYET','AP_DUNG');
  select count(*) into acting from staff_delegations d join staff h on h.id=d.from_staff where d.to_staff=p_staff and h.role in ('tech_head','team_lead','director') and (d.to_date - d.from_date + 1) >= setting_num('gs.acting_days', p_farm, 14);
  select round(100.0*count(*) filter (where created_at <= ts + interval '2 hours')/nullif(count(*),0),0) into ontime from supervision_checks where created_by=p_staff and ts > now() - interval '3 months';
  -- GS: độ khớp kiểm chéo (cùng target, cùng tuần, kết quả trùng), lượt đủ tuần, chấm ngược, tháng làm GS, khối đạt, phòng kiểm khá lên
  select round(100.0*count(*) filter (where c1.result=c2.result)/nullif(count(*),0),0) into agree from supervision_checks c1 join supervision_checks c2 on c2.week_start=c1.week_start and coalesce(c2.target_staff_id,c2.target_dept)=coalesce(c1.target_staff_id,c1.target_dept) and c2.criteria_id=c1.criteria_id and c2.supervisor_id<>c1.supervisor_id where c1.supervisor_id=p_staff and c1.ts > now() - interval '6 months';
  select round(avg(least(100, 100.0*w.n/nullif(w.req,0))),0) into fill from (select week_start, count(*) n, max(coalesce(a.checks_per_week,3)) req from supervision_checks c join supervision_assignments a on a.supervisor_id=c.supervisor_id and a.active where c.supervisor_id=p_staff and c.ts > now() - interval '3 months' group by week_start) w;
  select round(avg((useful+fair+knows)/3.0),2) into rating from supervisor_ratings where supervisor_id=p_staff and created_at > now() - interval '6 months';
  select round(extract(epoch from (now() - min(from_date)::timestamp))/86400/30.4,1) into gs_months from supervision_assignments where supervisor_id=p_staff;
  select count(*) filter (where done) into blocks from gs_coverage_done(p_farm, p_staff);
  select round(avg(cur.score - prev.score),1) into improve from (select dept as target_dept, avg(score) score from v_supervision_dept_weekly where week_start >= current_date - 91 group by 1) cur join (select dept as target_dept, avg(score) score from v_supervision_dept_weekly where week_start >= current_date - 273 and week_start < current_date - 182 group by 1) prev on prev.target_dept=cur.target_dept where cur.target_dept in (select target_dept from supervision_assignments where supervisor_id=p_staff);
  j := jsonb_build_object('months', coalesce(round(extract(epoch from (now() - coalesce(s.hired_on, s.created_at)::timestamp))/86400/30.4,1),0), 'comp_total', comp_total,
    'comp_pct_THUC_HANH', (select round(100.0*count(*) filter (where level in ('THUC_HANH','THUAN_THUC','DAY_DUOC'))/nullif(count(*),0),0) from v_training_curriculum where staff_id=p_staff),
    'comp_pct_THUAN_THUC', (select round(100.0*count(*) filter (where level in ('THUAN_THUC','DAY_DUOC'))/nullif(count(*),0),0) from v_training_curriculum where staff_id=p_staff),
    'comp_pct_DAY_DUOC', (select round(100.0*count(*) filter (where level='DAY_DUOC')/nullif(count(*),0),0) from v_training_curriculum where staff_id=p_staff),
    'sup_avg', sup_avg, 'sup_months', sup_months, 'kpi_hit', kpi_hit, 'kpi_of', kpi_of, 'severe_12m', sev, 'teach_sessions', teach, 'trainee_pass_pct', tpass, 'initiatives', ini, 'acting_stints', acting, 'ontime_pct', ontime,
    'agree_pct', agree, 'weekly_fill_pct', fill, 'rating', rating, 'gs_months', gs_months, 'blocks_done', blocks, 'dept_improve', improve, 'grade_cm', current_grade(p_staff,'CM'), 'grade_gs', current_grade(p_staff,'GS'));
  return j;
end $$;
grant execute on function grade_evidence(text,text) to app_user;
-- cờ thông đồng (0089 thay thế bằng phiên bản thật)
create or replace function collusion_flags(p_staff text) returns int language sql stable as $$ select 0 $$;
grant execute on function collusion_flags(text) to app_user;
-- So bằng chứng với tiêu chí bậc kế tiếp → % đạt + danh sách thiếu
create or replace function grade_eligibility(p_farm text, p_staff text, p_track text) returns jsonb language plpgsql stable as $$
declare ev jsonb; cur text; nxt record; c jsonb; total int := 0; ok int := 0; miss text[] := '{}'; v numeric; lvl text;
begin
  ev := grade_evidence(p_farm, p_staff); cur := current_grade(p_staff, p_track);
  select * into nxt from grade_scales g where g.track=p_track and g.active and g.rank = coalesce((select rank from grade_scales where track=p_track and code=cur and active order by version desc limit 1),0)+1 order by version desc limit 1;
  if nxt is null then return jsonb_build_object('current', cur, 'next', null, 'pct', 100, 'missing', '[]'::jsonb, 'evidence', ev); end if;
  c := nxt.criteria;
  if c ? 'entry_grade' then total:=total+1; if (select rank from grade_scales where track='CM' and code=current_grade(p_staff,'CM') order by version desc limit 1) >= (select rank from grade_scales where track='CM' and code=c->>'entry_grade' order by version desc limit 1) then ok:=ok+1; else miss:=miss||('Phải đạt bậc chuyên môn '||(c->>'entry_grade')); end if; end if;
  if c ? 'min_months' then total:=total+1; if (ev->>'months')::numeric >= (c->>'min_months')::numeric then ok:=ok+1; else miss:=miss||('Thâm niên ≥ '||(c->>'min_months')||' tháng (đang '||(ev->>'months')||')'); end if; end if;
  if c ? 'comp_level' then total:=total+1; lvl := c->>'comp_level'; v := coalesce((ev->>('comp_pct_'||lvl))::numeric,0); if v >= (c->>'comp_pct')::numeric then ok:=ok+1; else miss:=miss||('SOP vị trí đạt mức '||lvl||' ≥ '||(c->>'comp_pct')||'% (đang '||v||'%)'); end if; end if;
  if c ? 'sup_avg_min' then total:=total+1; if coalesce((ev->>'sup_avg')::numeric,0) >= (c->>'sup_avg_min')::numeric and coalesce((ev->>'sup_months')::int,0) >= coalesce((c->>'sup_months')::int,1) then ok:=ok+1; else miss:=miss||('Điểm giám sát TB ≥ '||(c->>'sup_avg_min')||' trong '||coalesce(c->>'sup_months','1')||' tháng liền (đang '||coalesce(ev->>'sup_avg','–')||'/'||coalesce(ev->>'sup_months','0')||' th)'); end if; end if;
  if c ? 'ontime_min' then total:=total+1; if coalesce((ev->>'ontime_pct')::numeric,100) >= (c->>'ontime_min')::numeric then ok:=ok+1; else miss:=miss||('Ghi đúng giờ ≥ '||(c->>'ontime_min')||'%'); end if; end if;
  if c ? 'kpi_hit_min' then total:=total+1; -- chưa đủ 12 kỳ thưởng thì tính theo tỷ lệ (tối thiểu 3 kỳ)
    v := case when coalesce((ev->>'kpi_of')::int,0) >= (c->>'kpi_of')::int then (c->>'kpi_hit_min')::numeric else ceil((c->>'kpi_hit_min')::numeric * greatest((ev->>'kpi_of')::int,3) / (c->>'kpi_of')::numeric) end;
    if coalesce((ev->>'kpi_of')::int,0) >= 3 and coalesce((ev->>'kpi_hit')::int,0) >= v then ok:=ok+1; else miss:=miss||('Đạt thưởng KPI ≥ '||v||'/'||greatest(coalesce((ev->>'kpi_of')::int,0),3)||' kỳ đã xét (đang '||coalesce(ev->>'kpi_hit','0')||'/'||coalesce(ev->>'kpi_of','0')||')'); end if; end if;
  if c ? 'severe_free_months' then total:=total+1; if coalesce((ev->>'severe_12m')::int,0) = 0 then ok:=ok+1; else miss:=miss||('Không lỗi NẶNG trong '||(c->>'severe_free_months')||' tháng (đang có '||(ev->>'severe_12m')||')'); end if; end if;
  if c ? 'teach_sessions_min' then total:=total+1; if coalesce((ev->>'teach_sessions')::int,0) >= (c->>'teach_sessions_min')::int then ok:=ok+1; else miss:=miss||('Đã dạy ≥ '||(c->>'teach_sessions_min')||' buổi/12 tháng (đang '||coalesce(ev->>'teach_sessions','0')||')'); end if; end if;
  if c ? 'trainee_pass_pct_min' then total:=total+1; if coalesce((ev->>'trainee_pass_pct')::numeric,0) >= (c->>'trainee_pass_pct_min')::numeric then ok:=ok+1; else miss:=miss||('Học viên đậu ≥ '||(c->>'trainee_pass_pct_min')||'% (đang '||coalesce(ev->>'trainee_pass_pct','–')||')'); end if; end if;
  if c ? 'initiatives_min' then total:=total+1; if coalesce((ev->>'initiatives')::int,0) >= (c->>'initiatives_min')::int then ok:=ok+1; else miss:=miss||('Sáng kiến được duyệt ≥ '||(c->>'initiatives_min')); end if; end if;
  if c ? 'acting_stints_min' then total:=total+1; if coalesce((ev->>'acting_stints')::int,0) >= (c->>'acting_stints_min')::int then ok:=ok+1; else miss:=miss||('Làm QUYỀN trưởng phòng ≥ '||(c->>'acting_stints_min')||' kỳ ≥ '||coalesce(c->>'acting_days','14')||' ngày (đang '||coalesce(ev->>'acting_stints','0')||')'); end if; end if;
  if c ? 'gs_months' and (c->>'gs_months')::numeric > 0 then total:=total+1; if coalesce((ev->>'gs_months')::numeric,0) >= (c->>'gs_months')::numeric then ok:=ok+1; else miss:=miss||('Làm giám sát ≥ '||(c->>'gs_months')||' tháng (đang '||coalesce(ev->>'gs_months','0')||')'); end if; end if;
  if c ? 'blocks_min' then total:=total+1; if coalesce((ev->>'blocks_done')::int,0) >= (c->>'blocks_min')::int then ok:=ok+1; else miss:=miss||('Phủ ≥ '||(c->>'blocks_min')||'/8 khối (đang '||coalesce(ev->>'blocks_done','0')||')'); end if; end if;
  if c ? 'weekly_fill_min' then total:=total+1; if coalesce((ev->>'weekly_fill_pct')::numeric,0) >= (c->>'weekly_fill_min')::numeric then ok:=ok+1; else miss:=miss||('Đủ lượt kiểm tuần ≥ '||(c->>'weekly_fill_min')||'% (đang '||coalesce(ev->>'weekly_fill_pct','–')||')'); end if; end if;
  if c ? 'agree_min' then total:=total+1; if coalesce((ev->>'agree_pct')::numeric,100) >= (c->>'agree_min')::numeric then ok:=ok+1; else miss:=miss||('Khớp kiểm chéo ≥ '||(c->>'agree_min')||'% (đang '||coalesce(ev->>'agree_pct','–')||')'); end if; end if;
  if c ? 'rating_min' then total:=total+1; if coalesce((ev->>'rating')::numeric,0) >= (c->>'rating_min')::numeric then ok:=ok+1; else miss:=miss||('Trưởng phòng chấm ngược ≥ '||(c->>'rating_min')||'/5 (đang '||coalesce(ev->>'rating','–')||')'); end if; end if;
  if c ? 'field_days_min' then total:=total+1; if (select count(*) from gs_field_days where supervisor_id=p_staff and day > current_date-182) >= (c->>'field_days_min')::int then ok:=ok+1; else miss:=miss||('Đi ca thật ≥ '||(c->>'field_days_min')||' ngày/6 tháng'); end if; end if;
  if c ? 'dept_improve_min' then total:=total+1; if coalesce((ev->>'dept_improve')::numeric,0) >= (c->>'dept_improve_min')::numeric then ok:=ok+1; else miss:=miss||('Phòng mình kiểm tăng ≥ '||(c->>'dept_improve_min')||' điểm sau 2 quý (đang '||coalesce(ev->>'dept_improve','–')||')'); end if; end if;
  if c ? 'flags_max' then total:=total+1; if collusion_flags(p_staff) <= (c->>'flags_max')::int then ok:=ok+1; else miss:=miss||('Đang có '||collusion_flags(p_staff)||' cờ đỏ thông đồng/bao che (8 tuần) — phải về 0'); end if; end if;
  if c ? 'led_plan_or_audit' then total:=total+1; if exists (select 1 from initiatives where staff_id=p_staff and kind in ('KE_HOACH_NAM','AUDIT') and status in ('DUYET','AP_DUNG')) then ok:=ok+1; else miss:=miss||'Chủ trì 1 kế hoạch năm hoặc 1 đợt audit chứng nhận'; end if; end if;
  return jsonb_build_object('current', cur, 'next', nxt.code, 'next_name', nxt.name, 'pct', case when total=0 then 100 else round(100.0*ok/total,0) end, 'ok', ok, 'total', total, 'missing', to_jsonb(miss), 'evidence', ev, 'perks', nxt.perks);
end $$;
grant execute on function grade_eligibility(text,text,text) to app_user;
-- ========== 7) Xét quý tự động → đề xuất; 3 chữ ký (quản lý · GS · HCNS) → áp dụng (thử bậc 3 tháng) ==========
create or replace function run_grade_review(p_farm text, p_quarter text) returns int language plpgsql as $$
declare n int := 0; r record; e jsonb; trk text; cur text; curc jsonb; below boolean;
begin
  for r in select id, dept, role from staff where farm_id=p_farm and active loop
    foreach trk in array array['CM','GS'] loop
      cur := current_grade(r.id, trk); if trk='GS' and cur is null then continue; end if;
      if cur is null then insert into staff_grades(farm_id,staff_id,track,grade_code,note) values (p_farm,r.id,'CM','B1','khởi tạo') on conflict do nothing; cur:='B1'; end if;
      e := grade_eligibility(p_farm, r.id, trk);
      if e->>'next' is not null and (e->>'pct')::numeric >= 100 then
        insert into grade_reviews(farm_id,staff_id,track,quarter,from_grade,to_grade,kind,evidence,score_pct,missing) values (p_farm,r.id,trk,p_quarter,cur,e->>'next','LEN',e->'evidence',100,'{}') on conflict (staff_id,track,quarter) do nothing; n:=n+1;
      elsif trk='CM' and cur in ('B2','B3','B4') then
        -- cảnh báo tụt: điểm GS 3 tháng < 70 hoặc có lỗi nặng ⇒ CANH_BAO (2 quý liền CANH_BAO ⇒ đề xuất HA ở lần sau)
        below := coalesce((e->'evidence'->>'sup_avg')::numeric,100) < setting_num('grade.warn_sup_avg', p_farm, 70) or coalesce((e->'evidence'->>'severe_12m')::int,0) > 0;
        if below then
          if exists (select 1 from grade_reviews g where g.staff_id=r.id and g.track='CM' and g.kind='CANH_BAO' and g.quarter < p_quarter and g.created_at > now() - interval '7 months') then
            insert into grade_reviews(farm_id,staff_id,track,quarter,from_grade,to_grade,kind,evidence,score_pct,missing) values (p_farm,r.id,trk,p_quarter,cur,(select code from grade_scales where track='CM' and rank=(select rank from grade_scales where track='CM' and code=cur limit 1)-1 limit 1),'HA',e->'evidence',0,array['2 quý liền dưới chuẩn']) on conflict (staff_id,track,quarter) do nothing;
          else
            insert into grade_reviews(farm_id,staff_id,track,quarter,from_grade,to_grade,kind,evidence,score_pct,missing) values (p_farm,r.id,trk,p_quarter,cur,cur,'CANH_BAO',e->'evidence',(e->>'pct')::numeric,array['Dưới chuẩn bậc hiện tại: điểm GS thấp hoặc có lỗi nặng']) on conflict (staff_id,track,quarter) do nothing;
          end if; n:=n+1;
        end if;
      end if;
    end loop;
  end loop;
  -- báo HCNS
  insert into notifications(farm_id,staff_id,level,title,body,link,source,source_id) select p_farm, s.id, 'INFO', 'Xét bậc '||p_quarter||': '||n||' đề xuất chờ ký', 'Hội đồng 3 chữ ký: quản lý trực tiếp · giám sát · HCNS', '/nhan-su?tab=bac', 'grade', p_quarter from staff s where s.dept='HCNS' and s.role in ('director','owner','tech_head') limit 3;
  return n;
end $$;
create or replace function sign_grade_review(p_id uuid, p_by text, p_slot text) returns jsonb language plpgsql as $$
declare g record; sg jsonb; nsign int; me record;
begin
  select * into g from grade_reviews where id=p_id; if g is null then raise exception 'ERR_NOT_FOUND'; end if;
  if g.staff_id = p_by then raise exception 'ERR_SELF_APPROVE'; end if;
  if g.status not in ('DE_XUAT','DA_KY','KHANG_NGHI') then raise exception 'ERR_STATUS'; end if;
  select * into me from staff where id=p_by;
  -- ràng buộc ghế ký: manager = quản lý trực tiếp/GĐ; gs = ngạch GS hoặc QA; hcns = phòng HCNS hoặc GĐ/chủ
  if p_slot='manager' and not (me.id = (select manager_id from staff where id=g.staff_id) or me.role in ('director','owner')) then raise exception 'ERR_SLOT_MANAGER'; end if;
  if p_slot='gs' and not (current_grade(p_by,'GS') is not null or me.dept='QA' or me.role in ('auditor')) then raise exception 'ERR_SLOT_GS'; end if;
  if p_slot='hcns' and not (me.dept='HCNS' or me.role in ('director','owner')) then raise exception 'ERR_SLOT_HCNS'; end if;
  sg := coalesce(g.signs,'{}'::jsonb) || jsonb_build_object(p_slot, jsonb_build_object('by',p_by,'at',now()));
  nsign := (case when sg ? 'manager' then 1 else 0 end)+(case when sg ? 'gs' then 1 else 0 end)+(case when sg ? 'hcns' then 1 else 0 end);
  update grade_reviews set signs=sg, status=case when nsign>=3 then 'AP_DUNG' else 'DA_KY' end, decided_at=case when nsign>=3 then now() end where id=p_id;
  if nsign >= 3 and g.kind in ('LEN','HA') then
    update staff_grades set until=current_date where staff_id=g.staff_id and track=g.track and until is null;
    insert into staff_grades(farm_id,staff_id,track,grade_code,since,status,review_id,salary_coef,created_by)
      values (g.farm_id,g.staff_id,g.track,g.to_grade,current_date, case when g.kind='LEN' then 'THU_BAC' else 'HA_BAC' end, p_id, (select salary_coef from grade_scales where track=g.track and code=g.to_grade and active order by version desc limit 1), p_by);
    insert into notifications(farm_id,staff_id,level,title,body,link,source,source_id) values (g.farm_id,g.staff_id,'INFO', case when g.kind='LEN' then '🎉 Bạn được lên bậc '||g.to_grade||' (thử bậc 3 tháng)' else 'Bạn bị hạ bậc xuống '||g.to_grade end, 'Xem "Đường lên của tôi" ở Tài khoản.', '/tai-khoan', 'grade', p_id::text);
  end if;
  return jsonb_build_object('signs', nsign, 'applied', nsign>=3);
end $$;
-- hết 3 tháng thử bậc → chính thức (job đêm)
create or replace function confirm_probation_grades(p_farm text) returns int language sql as $$
  with u as (update staff_grades set status='CHINH_THUC' where farm_id=p_farm and status='THU_BAC' and since <= current_date - 90 and until is null returning 1) select count(*)::int from u $$;
grant execute on function run_grade_review(text,text), sign_grade_review(uuid,text,text), confirm_probation_grades(text) to app_user;
-- ========== 8) Luân chuyển GS tự động, lệch pha (≤1/3 tổ đổi khối mỗi lần) ==========
create or replace function plan_gs_rotation(p_farm text, p_from date default current_date, p_by text default null) returns int language plpgsql as $$
declare n int := 0; g record; nb record; total int; maxmove int; block_months numeric;
begin
  block_months := setting_num('gs.block_months', p_farm, 3);
  select count(*) into total from staff where current_grade(id,'GS') is not null and active; maxmove := greatest(1, ceil(total/3.0));
  for g in select s.id, s.dept from staff s where current_grade(s.id,'GS') is not null and s.active
           and not exists (select 1 from supervision_assignments a where a.supervisor_id=s.id and a.active and a.from_date > p_from - (block_months*30)::int) -- đợt hiện tại chưa đủ tháng thì chưa đổi
           order by (select min(from_date) from supervision_assignments a where a.supervisor_id=s.id and a.active) nulls first loop
    exit when n >= maxmove;
    select c.* into nb from gs_coverage_done(p_farm, g.id) c join gs_blocks b on b.code=c.block where not c.done and not c.current and not (g.dept = any(b.depts)) order by c.months asc, b.rank limit 1;
    if nb is null then continue; end if;
    update supervision_assignments set active=false, to_date=p_from-1 where supervisor_id=g.id and active;
    insert into supervision_assignments(id,farm_id,supervisor_id,target_dept,scope,checks_per_week,from_date,to_date,active,note,created_by)
      select gen_random_uuid()::text, p_farm, g.id, d, 'Luân chuyển khối '||nb.name, setting_num('gs.checks_per_week',p_farm,3)::int, p_from, p_from + (block_months*30)::int, true, 'auto rotation', p_by from unnest((select depts from gs_blocks where code=nb.block)) d;
    insert into notifications(farm_id,staff_id,level,title,body,link,source) values (p_farm,g.id,'INFO','Luân chuyển: bạn kiểm khối '||nb.name||' từ '||to_char(p_from,'DD/MM'),'1 tuần đầu chồng ca với GS cũ; nhớ đi ca thật ≥ 1 ngày/tuần','/giam-sat','gs_rotation');
    n := n+1;
  end loop; return n;
end $$;
grant execute on function plan_gs_rotation(text,date,text) to app_user;
-- ========== 9) Nhịp tuần: Thứ 6 lỗi → việc CAPA cho trưởng phòng (hạn T2 12h); lỗi lặp 3 tuần → trừ trưởng phòng ==========
create or replace function gen_capa_tasks(p_farm text) returns int language plpgsql as $$
declare n int := 0; r record; head text; wk date := date_trunc('week', current_date)::date;
begin
  for r in select coalesce(c.target_dept, s.dept) dept, count(*) n_loi, count(*) filter (where c.corrective is null) n_open, string_agg(distinct coalesce(cr.name, c.item), '; ') items
           from supervision_checks c left join staff s on s.id=c.target_staff_id left join supervision_criteria cr on cr.id=c.criteria_id
           where c.farm_id=p_farm and c.result='LOI' and c.week_start=wk group by 1 having count(*) filter (where c.corrective is null) > 0 loop
    select id into head from staff where farm_id=p_farm and dept=r.dept and active and role in ('tech_head','team_lead','director') order by role='tech_head' desc, hired_on limit 1;
    if head is null then continue; end if;
    if exists (select 1 from tasks where farm_id=p_farm and kind='CAPA' and assignee_id=head and detail->>'week'=wk::text) then continue; end if;
    insert into tasks(farm_id,kind,title,detail,target_type,target_id,assignee_id,due_at,priority,source,role_hint)
      values (p_farm,'CAPA','CAPA tuần '||to_char(wk,'DD/MM')||': '||r.n_open||' lỗi giám sát chưa có biện pháp — phòng '||r.dept, jsonb_build_object('week',wk,'items',r.items,'n_loi',r.n_loi,'note','Ghi biện pháp khắc phục + người + hạn cho từng lỗi trong Giám sát › Nhịp tuần; nội dung dạy tuần tới lấy từ đây'),
        'dept', r.dept, head, (wk + 7)::timestamptz + interval '12 hours', 'CAO', 'SUPERVISION', null);
    n := n+1;
  end loop; return n;
end $$;
grant execute on function gen_capa_tasks(text) to app_user;
create or replace view v_repeat_faults as
 with w as (select c.farm_id, coalesce(c.target_dept, s.dept) dept, c.criteria_id, cr.name, c.week_start from supervision_checks c left join staff s on s.id=c.target_staff_id left join supervision_criteria cr on cr.id=c.criteria_id where c.result='LOI' and c.week_start >= date_trunc('week', current_date)::date - 21 group by 1,2,3,4,5)
 select farm_id, dept, criteria_id, name, count(*) as weeks, array_agg(week_start order by week_start) as week_list from w group by 1,2,3,4 having count(*) >= 3;
grant select on v_repeat_faults to app_user;
create or replace view v_capa_status as
 select c.farm_id, coalesce(c.target_dept, s.dept) dept, c.week_start, count(*) filter (where c.result='LOI') as loi, count(*) filter (where c.result='LOI' and c.corrective is not null) as co_bien_phap, count(*) filter (where c.result='LOI' and c.verified_at is not null) as da_xac_nhan, count(*) filter (where c.result='LOI' and c.corrective_due < current_date and c.verified_at is null) as qua_han
 from supervision_checks c left join staff s on s.id=c.target_staff_id where c.week_start >= date_trunc('week', current_date)::date - 56 group by 1,2,3;
grant select on v_capa_status to app_user;
-- ========== 10) Điểm cống hiến (công khai, cộng dồn) ==========
create or replace view v_contribution as
 select s.farm_id, s.id as staff_id, s.full_name, s.dept,
  coalesce((select count(*) from bonus_ledger b where b.staff_id=s.id and b.kind='THUONG_THANG' and b.amount>0),0) * setting_num('contrib.kpi_month', s.farm_id, 10) as kpi_pts,
  coalesce((select round(avg(score)) from v_supervision_monthly m where m.staff_id=s.id),0) / 10 * setting_num('contrib.sup_10pts', s.farm_id, 2) as sup_pts,
  coalesce((select count(*) from training_sessions t where t.trainer_id=s.id and t.status='XONG'),0) * setting_num('contrib.teach', s.farm_id, 5) as teach_pts,
  coalesce((select count(*) from initiatives i where i.staff_id=s.id and i.status in ('DUYET','AP_DUNG')),0) * setting_num('contrib.initiative', s.farm_id, 20) as init_pts,
  coalesce((select count(*) from staff_delegations d where d.to_staff=s.id and d.status in ('ACTIVE','ENDED')),0) * setting_num('contrib.delegation', s.farm_id, 8) as cover_pts,
  current_grade(s.id,'CM') as grade_cm, current_grade(s.id,'GS') as grade_gs
 from staff s where s.active;
grant select on v_contribution to app_user;
-- Bản đồ kế thừa: ghế then chốt thiếu người
create or replace view v_succession as
 select k.*, h.full_name as holder_name, (select count(*) from succession_plans p where p.key_position_id=k.id) as n_successors,
   (select string_agg(st.full_name||' ('||p.readiness||')', ', ' order by p.readiness) from succession_plans p join staff st on st.id=p.successor_id where p.key_position_id=k.id) as successors,
   (select count(*) from succession_plans p where p.key_position_id=k.id and p.readiness='NGAY') as ready_now
 from key_positions k left join staff h on h.id=k.holder_id;
grant select on v_succession to app_user;
