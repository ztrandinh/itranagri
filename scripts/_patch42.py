import io
R="F:/ITRAN FARM/itran-os/"
def rw(p, fn): s=io.open(R+p,encoding="utf-8").read(); n=fn(s); assert n!=s, p; io.open(R+p,"w",encoding="utf-8",newline="\n").write(n); print("ok",p)
# 1) queries
rw("src/lib/queries.ts", lambda s: s.replace("  my_inbox:", '''  grade_scales: { sql: "select * from grade_scales where active order by track, rank" },
  staff_grades_all: { sql: "select g.*, s.full_name, s.dept, s.position, (grade_eligibility($1, g.staff_id, g.track)->>'next') as next_grade, (grade_eligibility($1, g.staff_id, g.track)->>'pct') as next_pct from staff_grades g join staff s on s.id=g.staff_id where g.until is null and (g.farm_id=$1 or s.farm_id is null) and s.active order by g.track, s.dept, s.full_name", ttl: 120 },
  grade_reviews: { sql: "select r.*, s.full_name, s.dept from grade_reviews r join staff s on s.id=r.staff_id where r.farm_id=$1 order by r.status='DE_XUAT' desc, r.created_at desc limit 300" },
  my_path: { sql: "select grade_eligibility($1, app_staff(), $2) as e", params: ["track"] },
  gs_coverage_me: { sql: "select * from gs_coverage_done($1, app_staff()) where current_grade(app_staff(),'GS') is not null" },
  gs_coverage_all: { sql: "select s.id as staff_id, s.full_name, s.dept, current_grade(s.id,'GS') as grade_gs, c.* from staff s cross join lateral gs_coverage_done($1, s.id) c where s.active and current_grade(s.id,'GS') is not null order by s.full_name, c.block", ttl: 60 },
  supervisor_ratings: { sql: "select supervisor_id, round(avg((useful+fair+knows)/3.0),2) as avg, count(*) as n from supervisor_ratings where farm_id=$1 and created_at > now() - interval '6 months' group by 1" },
  succession: { sql: "select * from v_succession where farm_id=$1 order by n_successors, title" },
  contribution: { sql: "select *, round(kpi_pts+sup_pts+teach_pts+init_pts+cover_pts) as total from v_contribution where farm_id=$1 or farm_id is null order by total desc limit 200", ttl: 120 },
  my_contribution: { sql: "select * from v_contribution where staff_id=app_staff()" },
  initiatives: { sql: "select i.*, s.full_name from initiatives i join staff s on s.id=i.staff_id where i.farm_id=$1 order by i.created_at desc limit 200" },
  capa_status: { sql: "select * from v_capa_status where farm_id=$1 order by week_start desc, dept" },
  repeat_faults: { sql: "select * from v_repeat_faults where farm_id=$1 order by weeks desc" },
  faults_week: { sql: "select c.*, s.full_name as target_name, cr.name as criteria_name from supervision_checks c left join staff s on s.id=c.target_staff_id left join supervision_criteria cr on cr.id=c.criteria_id where c.farm_id=$1 and c.result='LOI' and c.week_start >= date_trunc('week', current_date)::date - 7 order by c.ts desc" },
  my_field_days: { sql: "select * from gs_field_days where farm_id=$1 and supervisor_id=app_staff() order by day desc limit 30" },
  gs_list: { sql: "select s.id, s.full_name, current_grade(s.id,'GS') as grade_gs from staff s where s.active and current_grade(s.id,'GS') is not null order by s.full_name" },
  my_inbox:''',1))
# 2) actions
rw("src/app/api/actions/route.ts", lambda s: s.replace('        case "delegate": {', '''        case "run_grade_review": { if (!["owner","director","accountant","it_engineer"].includes(s.role) && s.dept !== "HCNS") throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select run_grade_review($1,$2) as n", [s.farmId, b.quarter]); return { ok: true, n: r.rows[0].n }; }
        case "sign_grade": { const r = await c.query("select sign_grade_review($1::uuid,$2,$3) as j", [b.id, s.staffId, b.slot]); return { ok: true, ...r.rows[0].j }; }
        case "reject_grade": { if (!["owner","director","tech_head","team_lead","accountant"].includes(s.role) && s.dept !== "HCNS") throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("update grade_reviews set status='TU_CHOI', note=$3, decided_at=now() where id=$1 and farm_id=$2 and staff_id<>$4", [b.id, s.farmId, b.note ?? null, s.staffId]); return { ok: true }; }
        case "appeal_grade": { await c.query("update grade_reviews set status='KHANG_NGHI', appeal_note=$3 where id=$1 and farm_id=$2 and staff_id=$4", [b.id, s.farmId, b.note ?? null, s.staffId]); return { ok: true }; }
        case "plan_gs_rotation": { if (!["owner","director","auditor","it_engineer"].includes(s.role) && s.dept !== "HCNS") throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select plan_gs_rotation($1, current_date, $2) as n", [s.farmId, s.staffId]); return { ok: true, n: r.rows[0].n }; }
        case "key_position": { if (!["owner","director","it_engineer"].includes(s.role) && s.dept !== "HCNS") throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("insert into key_positions(farm_id,code,title,dept,holder_id,min_grade,track) values ($1,$2,$3,$4,nullif($5,''),$6,$7) on conflict (farm_id,code,year) do update set title=excluded.title, dept=excluded.dept, holder_id=excluded.holder_id, min_grade=excluded.min_grade, track=excluded.track", [s.farmId, b.code, b.title, b.dept ?? null, b.holder_id ?? "", b.min_grade ?? "B3", b.track ?? "CM"]); return { ok: true }; }
        case "succession": { if (!["owner","director","it_engineer","tech_head"].includes(s.role) && s.dept !== "HCNS") throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("insert into succession_plans(farm_id,key_position_id,successor_id,readiness,dev_plan,updated_by) values ($1,$2,$3,$4,$5,$6) on conflict (key_position_id,successor_id) do update set readiness=excluded.readiness, dev_plan=excluded.dev_plan, updated_at=now(), updated_by=excluded.updated_by", [s.farmId, b.key_position_id, b.successor_id, b.readiness ?? "2_NAM", b.dev_plan ?? null, s.staffId]); return { ok: true }; }
        case "initiative": { await c.query("insert into initiatives(farm_id,staff_id,title,benefit,description,kind) values ($1,$2,$3,$4,$5,$6)", [s.farmId, s.staffId, b.title, b.benefit ?? null, b.description ?? null, b.kind ?? "CAI_TIEN"]); return { ok: true }; }
        case "approve_initiative": { if (!["owner","director","tech_head","team_lead","auditor"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("update initiatives set status='DUYET', approved_by=$3, approved_at=now() where id=$1 and farm_id=$2 and staff_id<>$3", [b.id, s.farmId, s.staffId]); return { ok: true }; }
        case "gs_field_day": { await c.query("insert into gs_field_days(farm_id,supervisor_id,day,block,dept,note) values ($1,$2,coalesce($3::date,current_date),$4,$5,$6) on conflict (supervisor_id,day) do update set block=excluded.block, dept=excluded.dept, note=excluded.note", [s.farmId, s.staffId, b.day ?? null, b.block ?? null, b.dept ?? null, b.note ?? null]); return { ok: true }; }
        case "rate_supervisor": { if (!["tech_head","team_lead","director","owner"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("insert into supervisor_ratings(farm_id,supervisor_id,rated_by,period,useful,fair,knows,note) values ($1,$2,$3,to_char(current_date,'YYYY-MM'),$4,$5,$6,$7) on conflict (supervisor_id,rated_by,period) do update set useful=excluded.useful, fair=excluded.fair, knows=excluded.knows, note=excluded.note", [s.farmId, b.supervisor_id, s.staffId, Number(b.useful), Number(b.fair), Number(b.knows), b.note ?? null]); return { ok: true }; }
        case "capa_set": { await c.query("update supervision_checks set corrective=$3, corrective_due=$4::date where id=$1 and farm_id=$2", [b.id, s.farmId, b.corrective, b.due ?? null]); return { ok: true }; }
        case "capa_verify": { await c.query("update supervision_checks set verified_by=$3, verified_at=now() where id=$1 and farm_id=$2 and supervisor_id<>$3 or (id=$1 and farm_id=$2 and $4 in ('auditor','director','owner'))", [b.id, s.farmId, s.staffId, s.role]); return { ok: true }; }
        case "gen_capa": { const r = await c.query("select gen_capa_tasks($1) as n", [s.farmId]); return { ok: true, n: r.rows[0].n }; }
        case "delegate": {''',1))
# 3) jobs: capa Friday + probation + grade quarterly job
rw("src/app/api/jobs/[job]/route.ts", lambda s: s.replace('    if (job === "tasks" || job === "all") { out[`deleg_end:${f}`]', '''    if (job === "capa" || (job === "all" && new Date().getDay() === 5)) { out[`capa:${f}`] = (await adminPool().query("select gen_capa_tasks($1) as n", [f])).rows[0].n; }
    if (job === "grade" || (job === "all" && new Date().getDate() === 1)) { out[`probation:${f}`] = (await adminPool().query("select confirm_probation_grades($1) as n", [f])).rows[0].n; const d = new Date(); if (job === "grade" || d.getMonth() % 3 === 0) out[`grade_review:${f}`] = (await adminPool().query("select run_grade_review($1,$2) as n", [f, `${d.getFullYear()}-Q${Math.floor(d.getMonth() / 3) + 1}`])).rows[0].n; }
    if (job === "tasks" || job === "all") { out[`deleg_end:${f}`]''',1))
# 4) roles: /giam-sat + views (all views default open unless listed)
rw("src/lib/roles.ts", lambda s: s.replace('"/giam-sat": [...MGMT_ROLES, "team_lead"],','"/giam-sat": [...MGMT_ROLES, "team_lead", "worker"],',1))
# 5) admin registry
rw("src/lib/admin.ts", lambda s: s.replace('  { table: "supervision_criteria",', '''  { table: "grade_scales", pk: "code", label: "Bậc · thang bậc & tiêu chí lên bậc (CM 4 bậc · GS 4 bậc) — hệ số lương", group: "Nhân sự", farmScoped: false, softDelete: "active", writeRoles: ["owner", "director", "it_engineer"] },
  { table: "gs_blocks", pk: "code", label: "Bậc · 8 khối luân chuyển ngạch Giám sát", group: "Nhân sự", farmScoped: false, softDelete: null, writeRoles: ["owner", "director", "it_engineer"] },
  { table: "staff_grades", pk: "id", label: "Bậc · bậc từng người (lịch sử)", group: "Nhân sự", farmScoped: true, softDelete: null, writeRoles: ["owner", "director", "it_engineer"] },
  { table: "grade_reviews", pk: "id", label: "Bậc · đề xuất xét quý (3 chữ ký)", group: "Nhân sự", farmScoped: true, softDelete: null, writeRoles: ["owner", "director", "it_engineer"] },
  { table: "key_positions", pk: "id", label: "Ghế then chốt (định biên) & người giữ", group: "Nhân sự", farmScoped: true, softDelete: null, writeRoles: ["owner", "director", "it_engineer"] },
  { table: "succession_plans", pk: "id", label: "Bản đồ kế thừa", group: "Nhân sự", farmScoped: true, softDelete: null, writeRoles: ["owner", "director", "it_engineer"] },
  { table: "initiatives", pk: "id", label: "Sáng kiến – cải tiến", group: "Nhân sự", farmScoped: true, softDelete: null, writeRoles: ["owner", "director", "it_engineer", "tech_head", "team_lead", "worker", "auditor", "accountant"] },
  { table: "gs_field_days", pk: "id", label: "Giám sát · ngày đi ca thật", group: "Nhân sự", farmScoped: true, softDelete: null, writeRoles: ["owner", "director", "it_engineer", "auditor"] },
  { table: "supervisor_ratings", pk: "id", label: "Giám sát · trưởng phòng chấm ngược GS", group: "Nhân sự", farmScoped: true, softDelete: null, writeRoles: ["owner", "director", "it_engineer", "tech_head", "team_lead"] },
  { table: "staff_delegations", pk: "id", label: "Thay người / ủy quyền khi nghỉ", group: "Nhân sự", farmScoped: true, softDelete: null, writeRoles: ["owner", "director", "it_engineer", "tech_head", "team_lead"] },
  { table: "supervision_criteria",''',1))
# 6) Shell: Giám sát vào Điều hành & Kế hoạch (đơn vị công ty mẹ), bỏ khỏi QA (không trùng)
def sh(s):
    s=s.replace('{ href: "/canh-bao", label: "Cảnh báo & luật" }, { href: "/hq", label: "Công ty mẹ · đa trại"','{ href: "/giam-sat", label: "Giám sát & kế thừa (tổ GS công ty mẹ)", roles: ["team_lead", "tech_head", "director", "owner", "auditor", "it_engineer", "accountant"] }, { href: "/canh-bao", label: "Cảnh báo & luật" }, { href: "/hq", label: "Công ty mẹ · đa trại"',1)
    s=s.replace('items: [{ href: "/giam-sat", label: "Giám sát & chấm điểm" }, { href: "/tuan-thu", label: "Tuân thủ & chứng nhận" }','items: [{ href: "/tuan-thu", label: "Tuân thủ & chứng nhận" }',1)
    s=s.replace('desc: "Giám sát & chấm điểm, tiêu chuẩn/chứng nhận, truy xuất & thu hồi, đối soát dữ liệu"','desc: "Tuân thủ tiêu chuẩn/chứng nhận (tuyến 3), truy xuất & thu hồi, đối soát dữ liệu"',1)
    s=s.replace('desc: "HĐQT · Ban GĐ · GĐ trại: kế hoạch S&OP, bảng điều hành, điều hành ca, cảnh báo, đa trại"','desc: "HĐQT · Ban GĐ · GĐ trại: kế hoạch S&OP, bảng điều hành, điều hành ca, giám sát (tuyến 2, công ty mẹ), cảnh báo, đa trại"',1)
    return s
rw("src/components/Shell.tsx", sh)
# 8) Depts: NhanSu tab "bac"
def dep(s):
    s=s.replace('import { GlPanel, AttendancePanel } from "@/components/panels/More";','import { GlPanel, AttendancePanel } from "@/components/panels/More";\nimport CareerPanel from "@/components/panels/Career";',1)
    s=s.replace('const [nsTab, setNsTab] = useState<"dt" | "ns">("dt");','const [nsTab, setNsTab] = useState<"dt" | "ns" | "bac">(typeof window !== "undefined" && new URLSearchParams(window.location.search).get("tab") === "bac" ? "bac" : "dt");',1)
    s=s.replace('["ns", "Hồ sơ nhân sự · chứng chỉ SOP · sức khỏe"]]} value={nsTab}','["ns", "Hồ sơ nhân sự · chứng chỉ SOP · sức khỏe"], ["bac", "🪜 Bậc · Ghế · Kế thừa · Tổ giám sát"]]} value={nsTab}',1)
    s=s.replace('{nsTab === "dt" && <DaoTaoThuong sess={sess} />}','{nsTab === "dt" && <DaoTaoThuong sess={sess} />}{nsTab === "bac" && <CareerPanel sess={sess} />}',1)
    return s
rw("src/components/panels/Depts.tsx", dep)
# 9) TaiKhoan: MyPath
rw("src/components/panels/TaiKhoan.tsx", lambda s: s.replace('import { AttendancePanel } from "@/components/panels/More";','import { AttendancePanel } from "@/components/panels/More";\nimport { MyPath } from "@/components/panels/Career";',1).replace('  return (<div className="space-y-3">\n','  return (<div className="space-y-3">\n    <MyPath sess={sess} />\n',1))
