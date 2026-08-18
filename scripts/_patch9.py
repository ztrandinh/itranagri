import io
R = "F:/ITRAN FARM/itran-os/"
p = R + "src/app/api/actions/route.ts"; s = io.open(p, encoding="utf-8").read()
new = '''        case "save_process": {
          if (!["owner","director","it_engineer","tech_head"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          const code = String(b.code ?? "").toUpperCase(); if (!/^P-[A-Z0-9-]{2,30}$/.test(code)) throw new Error("ERR_BAD_CODE: mã dạng P-XX-NN");
          const ex = (await c.query("select status from processes where code=$1", [code])).rows[0];
          if (!ex) await c.query("insert into processes(code,dept_code,name,kind,object_type,trigger_text,description,sla,owner_role,kpi,ui_path,status,farm_id,created_by,coverage,position,auto_start) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,'NHAP',$12,$13,'DA_CO',99,$14)", [code, b.dept_code, b.name, b.kind ?? "CORE", b.object_type ?? null, b.trigger_text ?? null, b.description ?? null, b.sla ?? null, b.owner_role ?? null, b.kpi ?? null, b.ui_path ?? null, b.scope === "GLOBAL" ? null : s.farmId, s.staffId, JSON.stringify(b.auto_start ?? {})]);
          else await c.query("update processes set dept_code=$2,name=$3,kind=$4,object_type=$5,trigger_text=$6,description=$7,sla=$8,owner_role=$9,kpi=$10,ui_path=$11,auto_start=$12 where code=$1", [code, b.dept_code, b.name, b.kind ?? "CORE", b.object_type ?? null, b.trigger_text ?? null, b.description ?? null, b.sla ?? null, b.owner_role ?? null, b.kpi ?? null, b.ui_path ?? null, JSON.stringify(b.auto_start ?? {})]);
          return { ok: true, code };
        }
        case "save_step": {
          if (!["owner","director","it_engineer","tech_head"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          const st = b.step ?? {}; const code = String(b.code);
          const stepNo = Number(st.step_no) || Number((await c.query("select coalesce(max(step_no),0)+1 as n from process_steps where process_code=$1", [code])).rows[0].n);
          const tools = Array.isArray(st.tools) ? st.tools : String(st.tools ?? "").split(",").map((x: string) => x.trim()).filter(Boolean);
          await c.query(`insert into process_steps(process_code,step_no,name,actor_role,dept_code,action,system_where,control,output,tools,materials,inputs,outputs,duration_min,sla_hours,form_table,notify_roles,required,parallel_group,checklist)
            values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20)
            on conflict (process_code, step_no) do update set name=excluded.name, actor_role=excluded.actor_role, dept_code=excluded.dept_code, action=excluded.action, system_where=excluded.system_where, control=excluded.control, output=excluded.output, tools=excluded.tools, materials=excluded.materials, inputs=excluded.inputs, outputs=excluded.outputs, duration_min=excluded.duration_min, sla_hours=excluded.sla_hours, form_table=excluded.form_table, notify_roles=excluded.notify_roles, required=excluded.required, parallel_group=excluded.parallel_group, checklist=excluded.checklist`,
            [code, stepNo, st.name ?? `Bước ${stepNo}`, st.actor_role ?? null, st.dept_code ?? null, st.action ?? null, st.system_where ?? null, st.control ?? null, st.output ?? null, tools, JSON.stringify(st.materials ?? []), st.inputs ?? null, st.outputs ?? null, st.duration_min ?? null, st.sla_hours ?? null, st.form_table ?? null, Array.isArray(st.notify_roles) ? st.notify_roles : [], st.required ?? true, st.parallel_group ?? null, JSON.stringify(st.checklist ?? [])]);
          return { ok: true, step_no: stepNo };
        }
        case "delete_step": {
          if (!["owner","director","it_engineer","tech_head"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          await c.query("insert into audit_log(farm_id,table_name,pk,action,before,by_staff,by_role) select $3, 'process_steps', process_code||'#'||step_no, 'DELETE', to_jsonb(process_steps), $4, $5 from process_steps where process_code=$1 and step_no=$2", [b.code, b.step_no, s.farmId, s.staffId, s.role]);
          await c.query("delete from process_steps where process_code=$1 and step_no=$2", [b.code, b.step_no]);
          await c.query("with o as (select id, row_number() over (order by step_no) as rn from process_steps where process_code=$1) update process_steps p set step_no = -o.rn from o where p.id=o.id", [b.code]);
          await c.query("update process_steps set step_no = -step_no where process_code=$1 and step_no < 0", [b.code]);
          return { ok: true };
        }
        case "move_step": {
          const dir = Number(b.dir); const a = Number(b.step_no); const bNo = a + dir;
          await c.query("update process_steps set step_no=-1 where process_code=$1 and step_no=$2", [b.code, a]);
          await c.query("update process_steps set step_no=$3 where process_code=$1 and step_no=$2", [b.code, bNo, a]);
          await c.query("update process_steps set step_no=$2 where process_code=$1 and step_no=-1", [b.code, bNo]);
          return { ok: true };
        }
        case "publish_process": { if (!["owner","director","it_engineer","tech_head"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("select publish_process($1,$2)", [b.code, s.staffId]); return { ok: true }; }
        case "unpublish_process": { if (!["owner","director","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("update processes set status=$2 where code=$1", [b.code, b.status ?? "NHAP"]); return { ok: true }; }
        case "start_run": { const r = await c.query("select start_process_run($1,$2,$3,$4,$5,$6,$7) as id", [s.farmId, b.code, s.staffId, b.ref_table ?? null, b.ref_id ?? null, b.title ?? null, JSON.stringify(b.context ?? {})]); return { ok: true, run_id: r.rows[0].id }; }
        case "complete_step": { const r = await c.query("select complete_run_step($1,$2,$3,$4,$5) as r", [b.run_id, b.step_no, s.staffId, b.output ?? null, b.note ?? null]); return { ok: true, result: r.rows[0].r }; }
        case "cancel_run": { if (!["owner","director","it_engineer","tech_head"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("update process_runs set status='HUY', finished_at=now(), note=$2 where id=$1", [b.run_id, b.note ?? null]); await c.query("update tasks set status='BO_QUA' where ref_table='process_runs' and ref_id=$1 and status in ('MO','DANG_LAM')", [String(b.run_id)]); return { ok: true }; }
'''
s = s.replace('        default: throw new Error("ERR_UNKNOWN_ACTION");', new + '        default: throw new Error("ERR_UNKNOWN_ACTION");', 1)
io.open(p, "w", encoding="utf-8", newline="\n").write(s)

p = R + "src/lib/notify.ts"; s = io.open(p, encoding="utf-8").read()
s = s.replace('''    else if (e.topic === "customer.message") {''', '''    else if (e.topic === "process.published") { const depts = (pl.depts as string[]) ?? []; const roles = (pl.roles as string[]) ?? []; const st = (await p.query("select id from staff where active and (dept = any($1) or role = any($2)) and ($3::text is null or farm_id=$3 or farm_id is null or $3 = any(farm_ids))", [depts, roles, farm])).rows; recips = [...new Set([...st.map((x) => String(x.id)), ...(await resolveRecipients(farm ?? "F01", ["director"]))])]; level = "VANG"; title = `Quy trình mới / cập nhật: ${pl.name}`; body = `${pl.code} · ${pl.steps} bước · phòng: ${depts.join(", ")} · bởi ${pl.by}. Bạn được đưa vào quy trình này.`; link = `/to-chuc?tab=quytrinh&p=${pl.code}`; sourceId = `${pl.code}:${e.id}`; }
    else if (e.topic === "process.finished") { recips = await resolveRecipients(farm ?? "F01", ["director", "tech_head"]); title = `Hoàn tất quy trình ${pl.code}: ${pl.title}`; link = "/to-chuc?tab=chay"; sourceId = String(pl.run_id); }
    else if (e.topic === "customer.message") {''', 1)
s = s.replace('''    await p.query("update event_bus set processed_at=now() where id=$1", [e.id]);
  }
  return n;''', '''    // Tự chạy quy trình theo sự kiện (processes.auto_start.topic)
    if (farm) { const autos = (await p.query("select code from processes where status='BAN_HANH' and auto_start->>'topic'=$1 and (farm_id is null or farm_id=$2)", [e.topic, farm])).rows; for (const a of autos) { try { await p.query("select start_process_run($1,$2,'SYSTEM',$3,$4,$5,$6)", [farm, a.code, String(pl.table ?? e.topic), String(pl.id ?? pl.alert_id ?? e.id), `${e.topic} ${pl.id ?? ""}`, JSON.stringify(pl)]); } catch (err) { console.error("auto_start", a.code, (err as Error).message); } } }
    await p.query("update event_bus set processed_at=now() where id=$1", [e.id]);
  }
  return n;''', 1)
io.open(p, "w", encoding="utf-8", newline="\n").write(s)

p = R + "src/lib/queries.ts"; s = io.open(p, encoding="utf-8").read()
s = s.replace("  departments: {", '''  process_runs: { sql: "select * from v_process_runs where farm_id=$1 order by status='DANG_CHAY' desc, started_at desc limit 200" },
  process_run_steps: { sql: "select s.*, r.process_code from process_run_steps s join process_runs r on r.id=s.run_id where r.farm_id=$1 and r.status='DANG_CHAY' order by s.run_id, s.step_no" },
  process_coverage: { sql: "select * from v_process_coverage" },
  roles_catalog: { sql: "select * from roles_catalog order by position" }, positions_catalog: { sql: "select * from positions_catalog order by position" },
  species: { sql: "select * from species where active order by position" }, animal_classes: { sql: "select * from animal_classes order by species_code, position" }, crops: { sql: "select * from crops where active order by group_name, position" }, product_kinds: { sql: "select * from product_kinds order by position" },
  obj_people: { sql: "select * from v_obj_people order by farm_id, role" }, obj_animals: { sql: "select * from v_obj_animals where farm_id=$1 order by species, class_code" }, obj_crops: { sql: "select * from v_obj_crops where farm_id=$1 order by area_ha desc" }, obj_products: { sql: "select * from v_obj_products" },
  departments: {''', 1)
s = s.replace('processes: { sql: "select p.*, d.name as dept_name from processes p join departments d on d.code=p.dept_code where p.active order by d.position, p.position" }', 'processes: { sql: "select p.*, d.name as dept_name, (select count(*) from process_steps x where x.process_code=p.code) as steps_n from processes p left join departments d on d.code=p.dept_code where p.active order by d.position, p.position, p.code" }')
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("ok")
