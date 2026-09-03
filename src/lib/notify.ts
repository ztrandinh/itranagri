import { withCtx, adminPool, type Ctx } from "./db";
import { logger } from "./logger";
const sysCtx = (farmId: string): Ctx => ({ orgId: "ITRAN", farmId, role: "it_engineer", staffId: "SYSTEM", farmIds: [farmId] });
const LV: Record<string, number> = { XANH: 0, INFO: 0, VANG: 1, CAM: 2, DO: 3 };

/** Giải người nhận: 'owner' | 'director' | 'tech_head' | 'worker:A1' | 'NS-012' | 'all' → danh sách staff_id trong trại (owner/auditor thấy mọi trại) */
export async function resolveRecipients(farmId: string, recipients: string[]): Promise<string[]> {
  const out = new Set<string>();
  const staff = (await adminPool().query("select id, role, position, farm_id, farm_ids from staff where active and (farm_id=$1 or farm_id is null or $1 = any(farm_ids))", [farmId])).rows;
  for (const r of recipients ?? []) {
    if (r === "all") staff.forEach((s) => out.add(s.id));
    else if (r.startsWith("NS-")) out.add(r);
    else if (r.startsWith("worker:")) { const pos = r.split(":")[1]; staff.filter((s) => s.role === "worker" && String(s.position ?? "").startsWith(pos)).forEach((s) => out.add(s.id)); }
    // GĐ TRẠI-LOCAL: sự kiện vận hành của trại chỉ ping GĐ trại đó, KHÔNG ping GĐ chức năng công ty
    // (XNK/Marketing/HCNS/Nhân rộng — farm_id null). Fallback: trại chưa có GĐ riêng → mọi GĐ.
    else if (r === "director:farm") { const local = staff.filter((s) => s.role === "director" && s.farm_id === farmId); (local.length ? local : staff.filter((s) => s.role === "director")).forEach((s) => out.add(s.id)); }
    else staff.filter((s) => s.role === r).forEach((s) => out.add(s.id));
  }
  return [...out];
}

/** Xử lý event_bus chưa xử lý → notifications (fan-out theo luật + sở thích người dùng). Gọi mỗi lần job/alert hoặc theo lịch 1'. */
export async function dispatchEvents(limit = 500): Promise<number> {
  const p = adminPool();
  // Claim atomic bằng 1 câu UPDATE...FOR UPDATE SKIP LOCKED thay vì SELECT rồi xử lý: nếu cron mỗi phút
  // và action run_rules_now (chạy tay) trùng thời điểm, trước đây 2 tiến trình có thể cùng SELECT được
  // cùng 1 event_bus id (chưa ai đánh dấu processed_at) rồi cùng gửi thông báo → nhân đôi (tốn phí SMS/Zalo
  // thật). Đặt processed_at=now() ngay khi claim: nhất quán với thiết kế hiện có (processed_at vốn đã
  // là marker "đã xử lý xong hay lỗi", không phải riêng "thành công") — lỗi xử lý phía dưới chỉ còn cần
  // ghi cột error, không cần set lại processed_at.
  // Trước đây bất kỳ lỗi xử lý nào (0197) cũng coi như "đã xử lý", không dead-letter, không nơi nào đọc
  // lại cột error — mất-là-mất vĩnh viễn dù lỗi chỉ là tạm thời. Nay: claim kèm tăng attempts; lỗi dưới
  // MAX_ATTEMPTS được UNCLAIM (processed_at=null) để lượt dispatch sau thử lại thật; vượt ngưỡng mới đánh
  // dead_letter_at (dừng thử, còn thấy được qua /api/health & truy vấn trực tiếp — không mất trong im lặng).
  const MAX_ATTEMPTS = 5;
  const evs = (await p.query(
    `update event_bus set processed_at = now(), attempts = attempts + 1
     where id in (select id from event_bus where processed_at is null and dead_letter_at is null order by id limit $1 for update skip locked)
     returning *`,
    [limit]
  )).rows;
  let n = 0;
  for (const e of evs) {
   // CÔ LẬP LỖI TỪNG SỰ KIỆN: trước đây một sự kiện hỏng (vd người nhận không còn tồn tại)
   // làm VĂNG cả lượt dispatch, khiến TOÀN BỘ hàng đợi kẹt vĩnh viễn — mọi thông báo/việc
   // đứng lại. Nay bọc try/catch: sự kiện hỏng bị đánh dấu lỗi và BỎ QUA, hàng đợi chảy tiếp.
   try {
    const farm = e.farm_id as string | null; const pl = e.payload as Record<string, unknown>;
    let recips: string[] = [], title = e.topic as string, body = "", level = "INFO", link = "/", sourceId = ""; const source = e.topic as string;
    if (e.topic === "alert.raised") {
      const rule = (await p.query("select recipients, channels, level, name from alert_rules where code=$1 and active order by (farm_id=$2) desc, version desc limit 1", [pl.rule, farm])).rows[0];
      recips = await resolveRecipients(farm!, (rule?.recipients ?? (pl.sent_to as string[]) ?? ["tech_head", "director"]) as string[]);
      // Leo thang: ĐỎ luôn +director. KHÔNG +owner đại trà (gây nhiễu owner khi đa trại);
      // owner chỉ nhận ĐỎ ở các luật đã CẤU HÌNH owner trong recipients (an toàn/dịch tễ/tồn/kiểm kê…).
      if (pl.level === "DO") recips = [...new Set([...recips, ...(await resolveRecipients(farm!, ["director:farm"]))])];
      level = String(pl.level); title = `${pl.level} · ${rule?.name ?? pl.rule}`; body = String(pl.subject ?? ""); link = "/canh-bao"; sourceId = String(pl.alert_id);
      await p.query("update alert_rules set last_fired_at=now(), fire_count=coalesce(fire_count,0)+1 where code=$1", [pl.rule]);
    } else if (e.topic === "task.created") {
      recips = pl.assignee ? [String(pl.assignee)] : await resolveRecipients(farm!, [String(pl.role_hint ?? "tech_head")]);
      if (pl.dept && !pl.assignee) { const inDept = (await p.query("select id from staff where active and dept=$1 and role=$2 and (farm_id=$3 or farm_id is null or $3 = any(farm_ids))", [pl.dept, pl.role_hint ?? "worker", farm])).rows.map((x) => String(x.id)); if (inDept.length) recips = inDept; }
      level = pl.priority === "KHAN" ? "DO" : "VANG"; title = `Việc ${pl.priority}: ${pl.title}`; body = `Hạn ${new Date(String(pl.due)).toLocaleString("vi-VN")}${pl.dept ? ` · bộ phận ${pl.dept}` : ""}`; link = pl.run_id ? "/to-chuc?tab=chay" : "/ca"; sourceId = String(pl.task_id);
    } else if (e.topic === "incident.created") {
      recips = await resolveRecipients(farm!, ["tech_head", "director:farm", ...(["CAO", "NGHIEM_TRONG"].includes(String(pl.severity)) ? ["owner"] : [])]);
      level = ["CAO", "NGHIEM_TRONG"].includes(String(pl.severity)) ? "DO" : "VANG"; title = `Sự cố ${pl.code} · ${pl.kind}/${pl.severity}`; body = String(pl.description ?? ""); link = "/gd"; sourceId = String(pl.incident_id);
    } else if (e.topic === "expense.approved.big") {
      recips = await resolveRecipients(farm!, ["owner"]); level = "VANG"; title = `Chi > 50 triệu đã duyệt: ${Number(pl.amount).toLocaleString("vi-VN")} đ`; body = String(pl.purpose ?? ""); link = "/ke-toan"; sourceId = String(pl.id);
    } else if (e.topic === "farm.created") { recips = await resolveRecipients(farm!, ["owner"]); title = `Trại mới ${pl.farm} — ${pl.name}`; link = "/hq"; }
    else if (e.topic === "master.changed") {
      if (String(pl.by ?? "") === "SYSTEM" || !pl.by) continue;
      // GIẢM NHIỄU (master.changed đẻ ~95% thông báo): chỉ báo khi XÓA/xóa-mềm, hoặc sửa BẢNG CẤU HÌNH nhạy cảm.
      // Thêm/sửa danh mục thường vẫn được ghi audit_log ở nơi khác — không cần phiền owner từng dòng.
      const CFG = ["norms", "price_list", "rc_rules", "alert_rules", "approval_matrix", "settings", "kpi_defs", "legal_entities", "grade_scales", "roles", "positions"];
      const isDel = pl.action === "SOFT_DELETE" || pl.action === "DELETE"; const sensitive = CFG.includes(String(pl.table));
      if (!isDel && !sensitive) continue;
      recips = await resolveRecipients(farm ?? "F01", isDel ? ["owner", "it_engineer"] : ["it_engineer"]);
      level = isDel ? "VANG" : "INFO"; title = `Danh mục ${pl.table}: ${pl.action} ${pl.pk}`; body = `Bởi ${pl.by}${Array.isArray(pl.cols) ? " · cột: " + (pl.cols as string[]).join(", ") : ""}`; link = `/quan-tri?t=${pl.table}&pk=${encodeURIComponent(String(pl.pk))}`; sourceId = `${e.id}`;
    }
    else if (e.topic === "import.done") { recips = await resolveRecipients(farm ?? "F01", ["owner", "it_engineer", "director"]); level = Number(pl.err) > 0 ? "VANG" : "INFO"; title = `Nhập CSV ${pl.table}: ${pl.ok} dòng OK, ${pl.err} lỗi`; body = `Bởi ${pl.by} · ${pl.file ?? ""}`; link = `/quan-tri?t=${pl.table}&tab=nhap`; sourceId = String(pl.batch); }
    else if (e.topic === "order.created") { if (!pl.total) { const o = (await p.query("select o.total, o.attrs, pt.name from orders o left join partners pt on pt.id=o.partner_id where o.id=$1", [String(pl.id)])).rows[0]; if (o) { pl.total = o.total; pl.source = (o.attrs as Record<string, unknown>)?.source ?? pl.source; pl.partner = o.name ?? pl.partner; pl.unmapped = (o.attrs as Record<string, unknown>)?.unmapped ?? 0; } } recips = await resolveRecipients(farm ?? "F01", ["worker:A9", "worker:A8", "director:farm", "accountant"]); level = Number(pl.unmapped ?? 0) > 0 ? "VANG" : "INFO"; title = `Đơn mới ${pl.id} (${pl.source ?? "nội bộ"}) · ${Number(pl.total ?? 0).toLocaleString("vi-VN")} đ`; body = `${pl.partner ?? ""}${Number(pl.unmapped ?? 0) > 0 ? ` · ${pl.unmapped} dòng chưa ánh xạ SKU — Kinh doanh xử lý` : ""} · Kho soạn hàng FEFO · Kế toán theo dõi thu`; link = "/ban-hang?tab=don"; sourceId = String(pl.id); }
    else if (e.topic === "process.published") { const depts = (pl.depts as string[]) ?? []; const roles = (pl.roles as string[]) ?? []; const st = (await p.query("select id from staff where active and (dept = any($1) or role = any($2)) and ($3::text is null or farm_id=$3 or farm_id is null or $3 = any(farm_ids))", [depts, roles, farm])).rows; recips = [...new Set([...st.map((x) => String(x.id)), ...(await resolveRecipients(farm ?? "F01", ["director"]))])]; level = "VANG"; title = `Quy trình mới / cập nhật: ${pl.name}`; body = `${pl.code} · ${pl.steps} bước · phòng: ${depts.join(", ")} · bởi ${pl.by}. Bạn được đưa vào quy trình này.`; link = `/to-chuc?tab=quytrinh&p=${pl.code}`; sourceId = `${pl.code}:${e.id}`; }
    else if (e.topic === "process.finished") { recips = await resolveRecipients(farm ?? "F01", ["director", "tech_head"]); title = `Hoàn tất quy trình ${pl.code}: ${pl.title}`; link = "/to-chuc?tab=chay"; sourceId = String(pl.run_id); }
    else if (e.topic === "customer.message") { recips = await resolveRecipients(farm!, ["worker:A9", "director"]); level = "VANG"; title = `Tin nhắn khách nhận nuôi`; body = String(pl.body ?? ""); link = "/ban-hang"; }
    // Chỉ gửi cho người CÒN TỒN TẠI. Payload sự kiện cũ có thể mang mã nhân sự đã đổi/nghỉ
    // (vd sau chuẩn hoá mã: NS-110 -> ITRAN-NS-00110); chèn thẳng thì vướng khoá ngoại và
    // KẸT CẢ HÀNG ĐỢI. Lọc trước cho chắc — người không còn thì bỏ, không phải lỗi hệ thống.
    if (recips.length) {
      const alive = new Set((await p.query("select id from staff where id = any($1::text[])", [recips])).rows.map((r) => String(r.id)));
      recips = recips.filter((sid) => alive.has(sid));
    }
    for (const sid of recips) {
      const pref = (await p.query("select * from notification_prefs where staff_id=$1 and rule_code in ('*',$2) order by (rule_code='*') limit 1", [sid, String(pl.rule ?? e.topic)])).rows[0];
      if (pref?.muted) continue; if (pref && LV[level] < LV[String(pref.level_min)]) continue;
      const channels: string[] = pref?.channels ?? ["app"];
      // Chống spam thông báo: bỏ qua nếu trùng chính xác (source,source_id) HOẶC đã có 1 tin CÙNG NGUỒN+CÙNG TIÊU ĐỀ chưa đọc trong 24h
      // (alert lặp sinh alert_id mới mỗi lần → nếu chỉ dedup theo source_id sẽ chất đống; gộp theo tiêu đề để 1 tin/ngày/người tới khi đọc).
      const dup = await p.query("select 1 from notifications where staff_id=$1 and source=$2 and (source_id=$3 or (title=$4 and read_at is null and ts > now() - interval '24 hours'))", [sid, source, sourceId, title]);
      if (dup.rows[0]) continue;
      await p.query("insert into notifications(farm_id,staff_id,level,title,body,link,source,source_id,channels,sent) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)", [farm, sid, level, title, body, link, source, sourceId, channels, JSON.stringify({ app: new Date().toISOString(), zalo: channels.includes("zalo") ? "queued" : undefined, sms: channels.includes("sms") ? "queued" : undefined })]);
      n++;
    }
    // Tự chạy quy trình theo sự kiện (processes.auto_start.topic)
    if (farm) { const autos = (await p.query("select code from processes where status='BAN_HANH' and auto_start->>'topic'=$1 and (farm_id is null or farm_id=$2)", [e.topic, farm])).rows; for (const a of autos) { try { await p.query("select start_process_run($1,$2,'SYSTEM',$3,$4,$5,$6)", [farm, a.code, String(pl.table ?? e.topic), String(pl.id ?? pl.alert_id ?? e.id), `${e.topic} ${pl.id ?? ""}`, JSON.stringify(pl)]); } catch (err) { logger.error({ process: a.code, err: (err as Error).message }, "notify: auto_start lỗi"); } } }
   } catch (err) {
     logger.error({ eventId: e.id, topic: e.topic, err: (err as Error).message }, "notify: dispatch event lỗi");
     const msg = (err as Error).message.slice(0, 200);
     if (Number(e.attempts) >= MAX_ATTEMPTS) {
       // vượt ngưỡng thử lại — giữ processed_at (đã claim), đánh dead_letter_at để vận hành thấy được
       // sự kiện thật sự bị bỏ, phân biệt rõ với "đã xử lý thành công".
       await p.query("update event_bus set error=$2, dead_letter_at=now() where id=$1", [e.id, msg]).catch(() => {});
     } else {
       // còn lượt thử — unclaim (processed_at=null) để lượt dispatch kế tiếp thử lại thật, không phải mất-là-mất.
       await p.query("update event_bus set processed_at=null, error=$2 where id=$1", [e.id, msg]).catch(() => {});
     }
   }
  }
  return n;
}

/** Đánh giá LUẬT CẤU HÌNH (source='custom') — người dùng tự tạo trong Cài đặt cảnh báo */
export async function runCustomRules(farmId: string): Promise<string[]> {
  return withCtx(sysCtx(farmId), async (c) => {
    const rules = (await c.query("select * from alert_rules where active and source='custom' and farm_id in ('GLOBAL',$1) order by code", [farmId])).rows;
    const fired: string[] = [];
    const cmp = (v: number, op: string, t: number) => (op === "<" ? v < t : op === "<=" ? v <= t : op === ">" ? v > t : op === ">=" ? v >= t : op === "=" ? v === t : false);
    const fire = async (rule: Record<string, unknown>, subject: string, payload: Record<string, unknown>) => {
      const cd = Number(rule.cooldown_min ?? 720);
      const dup = await c.query("select 1 from alerts where farm_id=$1 and rule_code=$2 and subject=$3 and ts > now() - ($4||' minutes')::interval", [farmId, rule.code, subject, String(cd)]);
      if (dup.rows[0]) return;
      await c.query("insert into alerts(farm_id,rule_code,level,subject,payload,sent_to) values ($1,$2,$3,$4,$5,$6)", [farmId, rule.code, rule.level, subject, JSON.stringify(payload), rule.recipients ?? []]); fired.push(String(rule.code));
    };
    for (const r of rules) {
      const x = r.expr as Record<string, unknown>; const op = String(x.op ?? "<"), val = Number(x.value ?? 0);
      try {
        switch (x.type) {
          case "stock_days": { const rows = (await c.query("select sku, product_name, days, qty from v_days_of_stock where farm_id=$1 and days is not null" + (x.sku && x.sku !== "*" ? " and sku=$2" : ""), x.sku && x.sku !== "*" ? [farmId, x.sku] : [farmId])).rows; for (const s of rows) if (cmp(Number(s.days), op, val)) await fire(r, `${s.product_name} còn ${Number(s.days).toFixed(0)} ngày (tồn ${s.qty}) — đặt mua/mở rộng nguồn`, s); break; }
          case "overdue_tasks": { const n = Number((await c.query("select count(*) as n from tasks where farm_id=$1 and status='MO' and due_at<now()", [farmId])).rows[0].n); if (cmp(n, op, val)) await fire(r, `${n} việc quá hạn`, { n }); break; }
          case "sql_rows": { const sql = String(x.sql ?? ""); if (!/^\s*select/i.test(sql)) break; const rows = (await c.query(sql, [farmId])).rows as Record<string, unknown>[]; for (const d of rows) await fire(r, String(x.message ?? r.name).replace(/\{(\w+)\}/g, (_, k: string) => String(d[k] ?? "")), d); break; }
          case "metric_threshold": {
            const m = String(x.metric); let v: number | null = null;
            if (m === "lay_pct") v = Number((await c.query("select avg(lay_pct) as v from v_kpi_lay_rate where farm_id=$1 and day>=current_date-7", [farmId])).rows[0].v);
            else if (m === "feed_err") v = Number((await c.query("select avg(err_pct) as v from v_kpi_feed_accuracy where farm_id=$1 and day>=current_date-7", [farmId])).rows[0].v);
            else if (m === "deaths_week") v = Number((await c.query("select coalesce(sum(coalesce(value,1)),0) as v from animal_events where farm_id=$1 and status='ACTIVE' and event_type='CHET' and animal_id is not null and ts>=now()-interval '7 days'", [farmId])).rows[0].v);
            else if (m === "days_silage") v = Number((await c.query("select days_silage as v from v_days_silage where farm_id=$1", [farmId])).rows[0]?.v);
            else if (m === "conception_pct") v = Number((await c.query("select conception_pct as v from v_kpi_conception where farm_id=$1", [farmId])).rows[0]?.v);
            else if (m === "receivable_30") v = Number((await c.query("select coalesce(sum(d30p),0) as v from v_receivable_aging where farm_id=$1", [farmId])).rows[0].v);
            else if (m === "red_alerts_open") v = Number((await c.query("select count(*) as v from alerts where farm_id=$1 and level='DO' and acked_at is null", [farmId])).rows[0].v);
            else if (m.startsWith("agg:")) v = Number((await c.query("select coalesce(sum(value),0) as v from agg_daily where farm_id=$1 and metric=$2 and day>=current_date-7", [farmId, m.slice(4)])).rows[0].v);
            if (v != null && !isNaN(v) && cmp(v, op, val)) await fire(r, `${r.name}: ${v.toFixed(1)} ${op} ${val}`, { metric: m, v }); break;
          }
          case "expand_biomass": { const d = Number((await c.query("select days_silage as v from v_days_silage where farm_id=$1", [farmId])).rows[0]?.v ?? 999); const growth = Number((await c.query("select coalesce(sum(head),0) - coalesce((select sum(head) from herd_daily h2 where h2.farm_id=$1 and h2.day=current_date-30),0) as g from herd_daily h where h.farm_id=$1 and h.day=(select max(day) from herd_daily where farm_id=$1)", [farmId])).rows[0]?.g ?? 0); if (d < val && growth >= 0) await fire(r, `Ngày-tồn ủ chua ${d.toFixed(0)} < ${val} với đàn không giảm (${growth >= 0 ? "+" : ""}${growth} con/30 ngày) — cân nhắc mở rộng đất sinh khối/liên kết hộ`, { d, growth }); break; }
          case "missing_event": { const n = Number((await c.query(`select count(*) as n from ${/^[a-z_]+$/.test(String(x.table)) ? x.table : "feed_logs"} where farm_id=$1 and status='ACTIVE' and ts::date=current_date`, [farmId])).rows[0].n); if (n === 0 && new Date().getHours() >= Number(x.after_hour ?? 10)) await fire(r, `Hôm nay chưa có bản ghi ${x.table} sau ${x.after_hour ?? 10}h`, {}); break; }
          case "epi_region": { const rows = (await c.query("select s.* from v_epi_region_sum s where s.region_id=(select region_id from farms where id=$1) and s.level in ('DO','CAM')", [farmId])).rows; for (const d of rows) await fire({ ...r, level: d.level === "DO" ? "DO" : "CAM" }, `Dịch tễ vùng ${d.region_id}: ${d.sick_7d} bệnh / ${d.dead_7d} chết trong 7 ngày (nền ${d.sick_base_wk}/${d.dead_base_wk} mỗi tuần) — cách ly, báo thú y vùng`, d); break; }
          case "cert_expire": { const rows = (await c.query("select id, standard_code, valid_to from certifications where (farm_id=$1 or farm_id is null) and status='HIEU_LUC' and valid_to <= current_date + ($2||' days')::interval", [farmId, String(val || 90)])).rows; for (const d of rows) await fire(r, `Chứng nhận ${d.standard_code} hết hạn ${d.valid_to} — lên lịch tái đánh giá`, d); break; }
          case "due": { const rows = (await c.query("select id, name, calib_due from devices where farm_id=$1 and calib_due <= current_date + ($2||' days')::interval", [farmId, String(val || 7)])).rows; for (const d of rows) await fire(r, `Hiệu chuẩn ${d.name} đến hạn ${d.calib_due}`, d); break; }
        }
      } catch (e) { fired.push(`${r.code}:ERR ${(e as Error).message.slice(0, 60)}`); }
    }
    return fired;
  });
}
