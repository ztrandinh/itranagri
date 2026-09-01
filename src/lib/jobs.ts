import { withCtx, type Ctx } from "./db";
import { runCustomRules, dispatchEvents } from "./notify";

const sysCtx = (farmId: string): Ctx => ({ orgId: "ITRAN", farmId, role: "it_engineer", staffId: "SYSTEM", farmIds: [farmId] });

/** RECONCILIATION ENGINE — chạy RC rules cho 1 trại/1 ngày; ghi recon_results (bất biến) + alert nếu lệch. */
export async function runRecon(farmId: string, day: string) {
  return withCtx(sysCtx(farmId), async (c) => {
    const rules = (await c.query("select * from rc_rules where active order by code")).rows;
    const out: Record<string, unknown>[] = [];
    for (const r of rules) {
      let a: number | null = null, b: number | null = null, err: string | null = null;
      await c.query("savepoint rc");
      try {
        const ra = (await c.query(r.side_a_sql, r.side_a_sql.includes('$2') ? [farmId, day] : r.side_a_sql.includes('$1') ? [farmId] : [])).rows[0] as unknown as Record<string, unknown> | undefined; a = Number(ra ? Object.values(ra)[0] ?? 0 : 0);
        const rb = (await c.query(r.side_b_sql, r.side_b_sql.includes('$2') ? [farmId, day] : r.side_b_sql.includes('$1') ? [farmId] : [])).rows[0] as unknown as Record<string, unknown> | undefined; b = Number(rb ? Object.values(rb)[0] ?? 0 : 0);
      } catch (e) { err = (e as Error).message.slice(0, 200); await c.query("rollback to savepoint rc"); }
      await c.query("release savepoint rc").catch(() => {});
      let diffPct: number | null = null, status = "OK";
      if (err) status = "LOI";
      else if (r.threshold_mode === "ABS") { diffPct = Math.abs(a! - b!); status = diffPct > Number(r.threshold_pct) ? (r.level === "DO" ? "DO" : "VANG") : "OK"; }
      else { const base = Math.max(Math.abs(a!), Math.abs(b!)); diffPct = base > 0 ? Math.round((Math.abs(a! - b!) / base) * 10000) / 100 : 0; if (a === 0 && b === 0) status = "KHONG_DU_LIEU"; else status = diffPct > Number(r.threshold_pct) ? (r.level === "DO" ? "DO" : "VANG") : "OK"; }
      // idempotent: chạy lại đúng ngày này (retry sau lỗi, hoặc chạy tay lại) ghi đè thay vì nhân đôi (0190)
      await c.query(
        `insert into recon_results(farm_id,rule_code,period,expected,actual,diff_pct,status,detail) values ($1,$2,$3,$4,$5,$6,$7,$8)
         on conflict (farm_id,rule_code,period) do update set expected=excluded.expected, actual=excluded.actual, diff_pct=excluded.diff_pct, status=excluded.status, detail=excluded.detail, ts=now()`,
        [farmId, r.code, day, a, b, diffPct, status, JSON.stringify({ err, threshold: r.threshold_pct, mode: r.threshold_mode })]
      );
      if (status === "DO" || status === "VANG") {
        // chặn bắn lặp alert khi rerun cùng ngày cho cùng rule (trước đây insert vô điều kiện)
        const already = await c.query("select 1 from alerts where farm_id=$1 and rule_code=$2 and ts::date=$3::date", [farmId, r.code, day]);
        if (!already.rows[0]) {
          await c.query("insert into alerts(farm_id,rule_code,level,subject,payload,sent_to) values ($1,$2,$3,$4,$5,$6)", [farmId, r.code, status, `${r.name}: A=${a} B=${b} lệch ${diffPct}${r.threshold_mode === "ABS" ? "" : "%"}`, JSON.stringify({ a, b, diffPct, day }), r.recipients ?? []]);
        }
      }
      out.push({ code: r.code, a, b, diffPct, status, err });
    }
    return out;
  });
}

/** ALERT ENGINE (v1 SQL thuần): ngày-tồn ủ, FEFO, thiếu FEED_LOG, gà chết ≥5, phiếu giấy >24h, máy bảo dưỡng, cách ly kết thúc, sensor DO thấp (nếu có) */
export async function runAlerts(farmId: string) {
  return withCtx(sysCtx(farmId), async (c) => {
    const fired: string[] = [];
    const set = async (k: string, def: number) => Number((await c.query("select value from settings where key=$1 and farm_id in ('GLOBAL',$2) order by (farm_id=$2) desc, version desc limit 1", [k, farmId])).rows[0]?.value ?? def);
    const fire = async (rule: string, level: string, subject: string, payload: Record<string, unknown>, cooldownMin = 720) => {
      const dup = await c.query("select 1 from alerts where farm_id=$1 and rule_code=$2 and subject=$3 and ts > now() - ($4||' minutes')::interval", [farmId, rule, subject, String(cooldownMin)]);
      if (dup.rows[0]) return;
      await c.query("insert into alerts(farm_id,rule_code,level,subject,payload,sent_to) values ($1,$2,$3,$4,$5,$6)", [farmId, rule, level, subject, JSON.stringify(payload), []]); fired.push(rule);
    };
    const ds = (await c.query("select * from v_days_silage where farm_id=$1", [farmId])).rows[0];
    if (ds?.days_silage != null) { const d = Number(ds.days_silage); if (d < await set("silage.days_red", 30)) await fire("AL-SIL-30", "DO", `Ngày-tồn ủ chua ${d} < 30`, ds); else if (d < await set("silage.days_yellow", 45)) await fire("AL-SIL-45", "VANG", `Ngày-tồn ủ chua ${d} < 45`, ds); }
    // GIẢM NHIỄU: trước đây 1 cảnh báo/lô → ~1.400 ping/lần chạy (dedup theo subject nên cooldown vô dụng).
    // Nay GOM 1 cảnh báo tổng/trại; thủ kho xem chi tiết ở trang kho (FEFO). ĐỎ nếu đã có lô quá hạn.
    const fefo = (await c.query("select count(*)::int n, count(*) filter (where expiry_date < current_date)::int expired, coalesce(round(sum(qty)),0)::numeric qty, min(expiry_date) soonest from v_fefo_red where farm_id=$1", [farmId])).rows[0];
    if (Number(fefo.n) > 0) await fire("AL-FEFO", Number(fefo.expired) > 0 ? "DO" : "VANG", `${fefo.n} lô cần xuất theo FEFO — ${fefo.expired} đã quá hạn, tổng ${fefo.qty}`, fefo, 1440);
    // thiếu FEED_LOG sau cữ + 60'
    const meals: string[] = (await c.query("select value from settings where key='feed.meal_times' and farm_id in ('GLOBAL',$1) order by (farm_id=$1) desc limit 1", [farmId])).rows[0]?.value ?? ["06:00", "15:00"];
    const now = new Date(); const hhmm = now.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit", timeZone: "Asia/Ho_Chi_Minh" });
    for (const m of meals) { const [h, mi] = m.split(":").map(Number); const [ch, cm] = hhmm.split(":").map(Number); if (ch * 60 + cm > h * 60 + mi + 60) {
      const groups = (await c.query("select g.id, g.name from animal_groups g where g.farm_id=$1 and g.kind in ('BO_NHOM') and g.head_count>0 and not exists (select 1 from feed_logs f where f.farm_id=$1 and f.dest_group_id=g.id and f.status='ACTIVE' and f.ts::date=current_date and f.ts::time >= ($2||':00')::time - interval '2 hours')", [farmId, m])).rows;
      for (const g of groups) await fire("AL-FEED-MISS", "VANG", `Chưa có FEED_LOG ${g.name} cữ ${m}`, g, 240); } }
    // gà chết ≥5/ngày/khối
    for (const r of (await c.query("select g.name, sum(e.value) as n from animal_events e join animal_groups g on g.id=e.group_id where e.farm_id=$1 and e.status='ACTIVE' and e.event_type='CHET' and g.species='GA' and e.ts::date=current_date group by g.name having sum(e.value)>=5", [farmId])).rows) await fire("AL-DEATH-POUL", "DO", `Gà chết ${r.n} con/ngày tại ${r.name} — khóa chuồng, gọi KTT + thú y`, r);
    // phiếu giấy >24h
    const pp = (await c.query("select count(*) as n from paper_scans where farm_id=$1 and status='ACTIVE' and not digitized and ts < now()-interval '24 hours'", [farmId])).rows[0];
    if (Number(pp.n) > 0) await fire("AL-PAPER-24H", "VANG", `${pp.n} phiếu giấy >24h chưa số hóa`, pp);
    // máy bảo dưỡng
    for (const d of (await c.query("select * from devices where farm_id=$1 and maint_cycle_h is not null and machine_hours >= maint_cycle_h", [farmId])).rows) await fire("AL-DEV-MAINT", "XANH", `Máy ${d.name} đến giờ bảo dưỡng (${d.machine_hours}/${d.maint_cycle_h}h)`, d, 10080);
    // sensor DO (nếu có dữ liệu 15' gần nhất)
    for (const r of (await c.query("select device_id, min(value) as v from sensor_reads where farm_id=$1 and metric='DO' and ts>now()-interval '15 minutes' group by device_id having min(value)<4", [farmId])).rows) await fire("AL-RAS-DO", "DO", `DO ${r.v} mg/l < 4 tại ${r.device_id} — SOP RAS khẩn (sục ắc quy)`, r, 30);
    // nhiệt kho lạnh
    for (const r of (await c.query("select device_id, max(value) as v from sensor_reads where farm_id=$1 and metric='TEMP_COLD' and ts>now()-interval '30 minutes' group by device_id having min(value)>8", [farmId])).rows) await fire("AL-COLD", "DO", `Kho lạnh ${r.device_id} > 8°C 30 phút`, r, 60);
    // xe qua cổng lõi không cân / không anolyte
    for (const r of (await c.query("select plate, ts from gate_logs where farm_id=$1 and status='ACTIVE' and ts::date=current_date and (not weighed or not anolyte_wash)", [farmId])).rows) await fire("AL-GATE", "DO", `Xe ${r.plate} qua cổng không cân/không hố anolyte`, r, 60);
    // thiết bị cảm biến mất tín hiệu > 60'
    for (const r of (await c.query("select d.id, d.name from devices d where d.farm_id=$1 and d.kind like 'SENSOR%' and exists (select 1 from sensor_reads r where r.device_id=d.id) and (select max(ts) from sensor_reads r where r.device_id=d.id) < now()-interval '60 minutes'", [farmId])).rows) await fire("AL-SENSOR-OFF", "VANG", `Cảm biến ${r.name} mất tín hiệu > 60 phút`, r, 240);
    // tồn kho âm
    for (const r of (await c.query("select warehouse_code, sku, qty from v_stock_balance where farm_id=$1 and qty<0", [farmId])).rows) await fire("AL-STOCK-NEG", "VANG", `Tồn âm ${r.sku} tại ${r.warehouse_code}: ${r.qty}`, r, 1440);
    // công nợ >30 ngày
    for (const r of (await c.query("select p.name, sum(s.amount) as unpaid, extract(day from now()-min(s.ts))::int as days from sales s join partners p on p.id=s.partner_id where s.farm_id=$1 and s.status='ACTIVE' and not s.paid group by p.name having extract(day from now()-min(s.ts))>30", [farmId])).rows) await fire("AL-DEBT", "VANG", `${r.name} nợ ${Number(r.unpaid).toLocaleString("vi-VN")} đ quá ${r.days} ngày — ngừng giao`, r, 1440);
    // audit anchor rẻ: digest ngày cho bảng sự kiện
    for (const t of ["animal_events", "feed_logs", "crop_logs", "batch_logs", "inventory_moves", "sales", "paper_scans"]) {
      const d = (await c.query(`select count(*) as n, coalesce(md5(string_agg(id::text, ',' order by id)),'') as dg from ${t} where farm_id=$1 and created_at::date=current_date`, [farmId])).rows[0];
      await c.query("insert into audit_anchors(farm_id,day,table_name,row_count,digest,prev_digest) values ($1,current_date,$2,$3,$4,(select digest from audit_anchors where farm_id=$1 and table_name=$2 and day<current_date order by day desc limit 1)) on conflict (farm_id,day,table_name) do update set row_count=excluded.row_count, digest=excluded.digest", [farmId, t, d.n, d.dg]);
    }
    fired.push(...(await runCustomRules(farmId)));
    // tổng hợp ngày (hôm qua + hôm nay) + snapshot; đảm bảo partition cảm biến
    await c.query("select refresh_agg_daily($1, current_date-1), refresh_agg_daily($1, current_date), ensure_sensor_partitions(), gen_feed_plans($1)", [farmId]);
    await dispatchEvents();
    return fired;
  });
}

/** Backfill agg_daily cho N ngày (dùng khi import/sửa dữ liệu quá khứ) */
export async function backfillAgg(farmId: string, days: number) {
  return withCtx(sysCtx(farmId), async (c) => { for (let i = days; i >= 0; i--) await c.query("select refresh_agg_daily($1, current_date - $2::int)", [farmId, i]); return days; });
}
