import type { PoolClient } from "pg";
import type { Session } from "@/lib/auth";
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type B = any;
export type ActionHandler = (c: PoolClient, s: Session, b: B) => Promise<unknown>;

export const createTask: ActionHandler = async (c, s, b) => {
  const r = await c.query("insert into tasks(farm_id,kind,title,detail,target_type,target_id,role_hint,assignee_id,sop_code,due_at,priority,source,rule_code) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,coalesce($10::timestamptz,now()),$11,'MANUAL',$12) returning id",
            [s.farmId, b.kind ?? "KHAC", b.title, JSON.stringify(b.detail ?? {}), b.target_type ?? null, b.target_id ?? null, b.role_hint ?? null, b.assignee_id ?? null, b.sop_code ?? null, b.due_at ?? null, b.priority ?? "BINH_THUONG", b.rule_code ?? "MANUAL-" + Date.now()]);
          return { ok: true, id: r.rows[0].id };
};

export const taskStatus: ActionHandler = async (c, s, b) => {
  // Nhận CẢ MỘT NHÓM việc: màn Ca gom việc lặp (120 việc "Cân định kỳ — F01-BO-xxx"
          // hiện thành một thẻ "… — 120 việc"), nên bấm ✓ Xong phải đóng trọn nhóm.
          // Gọi từng id một thì 120 lượt gọi mạng — công nhân ngoài đồng đợi không nổi.
          const ids = (Array.isArray(b.ids) ? (b.ids as string[]) : null) ?? (b.id ? [b.id as string] : []);
          if (!ids.length) return { ok: false, error: "ERR_NO_TASK" };
          const r = await c.query("update tasks set status=$2, done_by=case when $2='XONG' then $3 else done_by end, done_at=case when $2='XONG' then now() else done_at end, done_event_id=coalesce($4::uuid,done_event_id), handover_note=coalesce($5,handover_note), assignee_id=coalesce($6,assignee_id) where id = any($1::uuid[]) and farm_id=$7",
            [ids, b.status, s.staffId, b.done_event_id ?? null, b.handover_note ?? null, b.assignee_id ?? null, s.farmId]);
          return { ok: true, n: r.rowCount };
};

export const generateTasks: ActionHandler = async (c, s) => {
  const r = await c.query("select itran_generate_tasks_v2($1) as n", [s.farmId]); return { ok: true, n: r.rows[0].n };
};

export const createFarm: ActionHandler = async (c, s, b) => {
  if (!["owner","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          if (!/^F\d{2,3}$/.test(String(b.id))) throw new Error("ERR_FARM_ID_FORMAT");
          const r = await c.query("select create_farm($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) as id", [b.id, s.orgId, b.region_id ?? null, b.name, b.province ?? null, b.legal_entity ?? null, b.kind ?? "CAMPUS", b.s_ha ?? null, b.k_factor ?? null, JSON.stringify(b.modules ?? {})]);
          await c.query("update staff set farm_ids = array_append(coalesce(farm_ids,'{}'), $1) where id=$2 and not ($1 = any(coalesce(farm_ids,'{}')))", [b.id, s.staffId]);
          return { ok: true, id: r.rows[0].id };
};

export const updateFarm: ActionHandler = async (c, s, b) => {
  if (!["owner","director","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("update farms set name=coalesce($2,name), province=coalesce($3,province), legal_entity=coalesce($4,legal_entity), s_ha=coalesce($5,s_ha), k_factor=coalesce($6,k_factor), modules=coalesce($7::jsonb,modules), status=coalesce($8,status), region_id=coalesce($9,region_id) where id=$1", [b.id, b.name ?? null, b.province ?? null, b.legal_entity ?? null, b.s_ha ?? null, b.k_factor ?? null, b.modules ? JSON.stringify(b.modules) : null, b.status ?? null, b.region_id ?? null]); return { ok: true };
};

export const saveProcess: ActionHandler = async (c, s, b) => {
  if (!["owner","director","it_engineer","tech_head"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          const code = String(b.code ?? "").toUpperCase(); if (!/^P-[A-Z0-9-]{2,30}$/.test(code)) throw new Error("ERR_BAD_CODE: mã dạng P-XX-NN");
          const ex = (await c.query("select status from processes where code=$1", [code])).rows[0];
          if (!ex) await c.query("insert into processes(code,dept_code,name,kind,object_type,trigger_text,description,sla,owner_role,kpi,ui_path,status,farm_id,created_by,coverage,position,auto_start) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,'NHAP',$12,$13,'DA_CO',99,$14)", [code, b.dept_code, b.name, b.kind ?? "CORE", b.object_type ?? null, b.trigger_text ?? null, b.description ?? null, b.sla ?? null, b.owner_role ?? null, b.kpi ?? null, b.ui_path ?? null, b.scope === "GLOBAL" ? null : s.farmId, s.staffId, JSON.stringify(b.auto_start ?? {})]);
          else await c.query("update processes set dept_code=$2,name=$3,kind=$4,object_type=$5,trigger_text=$6,description=$7,sla=$8,owner_role=$9,kpi=$10,ui_path=$11,auto_start=$12, inputs=coalesce($13::jsonb,inputs), outputs=coalesce($14::jsonb,outputs), documents=coalesce($15::jsonb,documents), tools=coalesce($16::text[],tools), visible_depts=array_remove(array[$2::text] || coalesce((select array_agg(distinct x) from (select jsonb_array_elements(coalesce($13::jsonb,inputs))->>'from' as x union select jsonb_array_elements(coalesce($14::jsonb,outputs))->>'to') t where x is not null and x<>'*'), '{}'), null) where code=$1", [code, b.dept_code, b.name, b.kind ?? "CORE", b.object_type ?? null, b.trigger_text ?? null, b.description ?? null, b.sla ?? null, b.owner_role ?? null, b.kpi ?? null, b.ui_path ?? null, JSON.stringify(b.auto_start ?? {}), b.inputs ? JSON.stringify(b.inputs) : null, b.outputs ? JSON.stringify(b.outputs) : null, b.documents ? JSON.stringify(b.documents) : null, Array.isArray(b.tools) ? b.tools : null]);
          return { ok: true, code };
};

export const saveStep: ActionHandler = async (c, s, b) => {
  if (!["owner","director","it_engineer","tech_head"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          const st = b.step ?? {}; const code = String(b.code);
          const stepNo = Number(st.step_no) || Number((await c.query("select coalesce(max(step_no),0)+1 as n from process_steps where process_code=$1", [code])).rows[0].n);
          const tools = Array.isArray(st.tools) ? st.tools : String(st.tools ?? "").split(",").map((x: string) => x.trim()).filter(Boolean);
          await c.query(`insert into process_steps(process_code,step_no,name,actor_role,dept_code,action,system_where,control,output,tools,materials,inputs,outputs,duration_min,sla_hours,form_table,notify_roles,required,parallel_group,checklist)
            values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20)
            on conflict (process_code, step_no) do update set name=excluded.name, actor_role=excluded.actor_role, dept_code=excluded.dept_code, action=excluded.action, system_where=excluded.system_where, control=excluded.control, output=excluded.output, tools=excluded.tools, materials=excluded.materials, inputs=excluded.inputs, outputs=excluded.outputs, duration_min=excluded.duration_min, sla_hours=excluded.sla_hours, form_table=excluded.form_table, notify_roles=excluded.notify_roles, required=excluded.required, parallel_group=excluded.parallel_group, checklist=excluded.checklist`,
            [code, stepNo, st.name ?? `Bước ${stepNo}`, st.actor_role ?? null, st.dept_code ?? null, st.action ?? null, st.system_where ?? null, st.control ?? null, st.output ?? null, tools, JSON.stringify(st.materials ?? []), st.inputs ?? null, st.outputs ?? null, st.duration_min ?? null, st.sla_hours ?? null, st.form_table ?? null, Array.isArray(st.notify_roles) ? st.notify_roles : [], st.required ?? true, st.parallel_group ?? null, JSON.stringify(st.checklist ?? [])]);
          if (st.documents) await c.query("update process_steps set documents=$3 where process_code=$1 and step_no=$2", [code, stepNo, JSON.stringify(st.documents)]);
          // phòng ban trong bước tự vào visible_depts (mỗi bộ phận chỉ thấy quy trình liên quan)
          if (st.dept_code) await c.query("update processes set visible_depts = array(select distinct unnest(visible_depts || array[$2::text])) where code=$1", [code, st.dept_code]);
          return { ok: true, step_no: stepNo };
};

export const deleteStep: ActionHandler = async (c, s, b) => {
  if (!["owner","director","it_engineer","tech_head"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          await c.query("insert into audit_log(farm_id,table_name,pk,action,before,by_staff,by_role) select $3, 'process_steps', process_code||'#'||step_no, 'DELETE', to_jsonb(process_steps), $4, $5 from process_steps where process_code=$1 and step_no=$2", [b.code, b.step_no, s.farmId, s.staffId, s.role]);
          await c.query("delete from process_steps where process_code=$1 and step_no=$2", [b.code, b.step_no]);
          await c.query("with o as (select id, row_number() over (order by step_no) as rn from process_steps where process_code=$1) update process_steps p set step_no = -o.rn from o where p.id=o.id", [b.code]);
          await c.query("update process_steps set step_no = -step_no where process_code=$1 and step_no < 0", [b.code]);
          return { ok: true };
};

export const moveStep: ActionHandler = async (c, s, b) => {
  const dir = Number(b.dir); const a = Number(b.step_no); const bNo = a + dir;
          await c.query("update process_steps set step_no=-1 where process_code=$1 and step_no=$2", [b.code, a]);
          await c.query("update process_steps set step_no=$3 where process_code=$1 and step_no=$2", [b.code, bNo, a]);
          await c.query("update process_steps set step_no=$2 where process_code=$1 and step_no=-1", [b.code, bNo]);
          return { ok: true };
};

export const publishProcess: ActionHandler = async (c, s, b) => {
  if (!["owner","director","it_engineer","tech_head"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("select publish_process($1,$2)", [b.code, s.staffId]); return { ok: true };
};

export const unpublishProcess: ActionHandler = async (c, s, b) => {
  if (!["owner","director","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("update processes set status=$2 where code=$1", [b.code, b.status ?? "NHAP"]); return { ok: true };
};

export const startRun: ActionHandler = async (c, s, b) => {
  const r = await c.query("select start_process_run($1,$2,$3,$4,$5,$6,$7) as id", [s.farmId, b.code, s.staffId, b.ref_table ?? null, b.ref_id ?? null, b.title ?? null, JSON.stringify(b.context ?? {})]); return { ok: true, run_id: r.rows[0].id };
};

export const completeStep: ActionHandler = async (c, s, b) => {
  const r = await c.query("select complete_run_step($1,$2,$3,$4,$5) as r", [b.run_id, b.step_no, s.staffId, b.output ?? null, b.note ?? null]); return { ok: true, result: r.rows[0].r };
};

export const cancelRun: ActionHandler = async (c, s, b) => {
  if (!["owner","director","it_engineer","tech_head"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("update process_runs set status='HUY', finished_at=now(), note=$2 where id=$1", [b.run_id, b.note ?? null]); await c.query("update tasks set status='BO_QUA' where ref_table='process_runs' and ref_id=$1 and status in ('MO','DANG_LAM')", [String(b.run_id)]); return { ok: true };
};

export const createApiKey: ActionHandler = async (c, s, b) => {
  if (!["owner","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          const raw = "itk_" + [...crypto.getRandomValues(new Uint8Array(24))].map((x) => x.toString(16).padStart(2, "0")).join("");
          const { createHash } = await import("node:crypto"); const h = createHash("sha256").update(raw).digest("hex");
          const scopes: string[] = Array.isArray(b.scopes) ? b.scopes : ["ingest"];
          // HMAC-of-body cho scope orders/ingest (0200): secret KÝ riêng, độc lập với khóa bearer ở trên —
          // mã hoá 2 chiều vì webhook/ingest cần server tính lại chữ ký từ nội dung thật khi verify.
          const needsHmac = scopes.includes("orders") || scopes.includes("ingest");
          let hmacSecret: string | null = null;
          const r = needsHmac
            ? await (async () => { const { newHmacSecret } = await import("@/lib/hmac"); const hs = newHmacSecret(); hmacSecret = hs.secret;
                return c.query("insert into api_keys(org_id,farm_id,name,key_hash,scopes,created_by,hmac_secret_enc) values ($1,$2,$3,$4,$5,$6,pgp_sym_encrypt($7,$8)) returning id", [s.orgId, b.farm_id ?? s.farmId, b.name ?? "key", h, scopes, s.staffId, hs.secret, hs.encPassphrase]); })()
            : await c.query("insert into api_keys(org_id,farm_id,name,key_hash,scopes,created_by) values ($1,$2,$3,$4,$5,$6) returning id", [s.orgId, b.farm_id ?? s.farmId, b.name ?? "key", h, scopes, s.staffId]);
          return { ok: true, id: r.rows[0].id, key: raw, hmac_secret: hmacSecret, note: hmacSecret ? "Lưu CẢ HAI ngay — key dùng header x-api-key, hmac_secret dùng ký HMAC-SHA256 lên nội dung gửi (header x-signature). Hệ thống không hiện lại được cả 2 sau lần này." : "Lưu khóa này ngay — hệ thống chỉ giữ sha256" };
};

export const syncLaborBudget: ActionHandler = async (c, s, b) => {
  if (!["owner","director","accountant"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select sync_labor_budget($1,$2,$3) as n", [s.farmId, Number(b.year ?? new Date().getFullYear()), s.staffId]); return { ok: true, n: r.rows[0].n };
};

export const syncProcessCriteria: ActionHandler = async (c, s) => {
  if (!["owner","director","auditor","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select sync_process_criteria() as n"); return { ok: true, n: r.rows[0].n };
};

export const publishYearPlan: ActionHandler = async (c, s, b) => {
  if (!["owner","director"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select publish_year_plan($1) as n", [b.id]); return { ok: true, n: r.rows[0].n };
};

export const publishPlan: ActionHandler = async (c, s, b) => {
  if (!["director","owner","tech_head"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); const r = await c.query("select publish_plan($1) as n", [b.id]); return { ok: true, n: r.rows[0].n };
};

