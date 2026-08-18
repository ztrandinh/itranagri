import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth";
import { withCtx } from "@/lib/db";
const na = (s: string) => s.normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/đ/g, "d").replace(/Đ/g, "d").toLowerCase();
/** GET /api/list?kind=animals|products|partners|events&q=&status=&group=&location=&attention=1&limit=50&offset=0 — phân trang + tìm không dấu phía server (quy mô nghìn con) */
export async function GET(req: Request) {
  const s = await getSession(); if (!s) return NextResponse.json({ error: "ERR_UNAUTHENTICATED" }, { status: 401 });
  const u = new URL(req.url); const p = (k: string) => u.searchParams.get(k);
  const limit = Math.min(Number(p("limit") ?? 50), 200), offset = Number(p("offset") ?? 0); const q = (p("q") ?? "").trim();
  const farm = p("farm") ?? s.farmId; const args: unknown[] = []; const where: string[] = [];
  const add = (v: unknown) => { args.push(v); return `$${args.length}`; };
  let sql = "", countSql = "";
  switch (p("kind") ?? "animals") {
    case "animals": {
      where.push(`a.farm_id=${add(farm)}`);
      if (q) where.push(`noaccent(coalesce(a.visual_tag,'')||' '||a.id||' '||coalesce(a.rfid,'')||' '||coalesce(a.breed,'')) like ${add("%" + na(q) + "%")}`);
      if (p("status")) where.push(`a.status = ${add(p("status"))}`); else if (!p("all")) where.push("a.status not in ('CHET','XUAT')");
      if (p("group")) where.push(`a.group_id = ${add(p("group"))}`);
      if (p("location")) where.push(`a.location_id = ${add(p("location"))}`);
      if (p("species")) where.push(`a.species = ${add(p("species"))}`);
      if (p("attention")) where.push("(a.status in ('BENH','CACH_LY') or a.withdrawal_until>current_date or a.tag_pending or exists (select 1 from tasks t where t.farm_id=a.farm_id and t.status='MO' and t.target_type='animal' and t.target_id=a.id))");
      sql = `select a.id, a.visual_tag, a.rfid, a.species, a.breed, a.sex, a.birth_date, a.status, a.group_id, g.name as group_name, a.location_id, l.name as location_name, a.last_weight_kg, a.withdrawal_until, a.tag_pending, a.intake_lot_id, a.owner_type,
             case when a.status in ('BENH','CACH_LY') then a.status when a.withdrawal_until>current_date then 'NGUNG_THUOC' when a.tag_pending then 'CHO_TAI' end as attention,
             (select count(*) from tasks t where t.farm_id=a.farm_id and t.status='MO' and t.target_type='animal' and t.target_id=a.id) as open_tasks
             from animals a left join animal_groups g on g.id=a.group_id left join locations l on l.id=a.location_id where ${where.join(" and ")} order by a.location_id, a.visual_tag, a.id limit ${limit} offset ${offset}`;
      countSql = `select count(*) as n from animals a where ${where.join(" and ")}`; break;
    }
    case "products": {
      where.push("a.active"); if (q) where.push(`noaccent(a.name||' '||a.sku) like ${add("%" + na(q) + "%")}`); if (p("kind2")) where.push(`a.kind=${add(p("kind2"))}`);
      sql = `select a.* from products a where ${where.join(" and ")} order by a.kind, a.name limit ${limit} offset ${offset}`; countSql = `select count(*) as n from products a where ${where.join(" and ")}`; break;
    }
    case "partners": {
      where.push(`(a.farm_id=${add(farm)} or a.farm_id is null) and a.active`); if (q) where.push(`noaccent(a.name||' '||a.id||' '||coalesce(a.phone,'')) like ${add("%" + na(q) + "%")}`); if (p("pkind")) where.push(`a.kind=${add(p("pkind"))}`);
      sql = `select a.* from partners a where ${where.join(" and ")} order by a.kind, a.name limit ${limit} offset ${offset}`; countSql = `select count(*) as n from partners a where ${where.join(" and ")}`; break;
    }
    case "events": {
      where.push(`a.farm_id=${add(farm)}`); const code = p("code"); where.push(`(a.animal_id=${add(code)} or a.group_id=${add(code)})`); if (p("type")) where.push(`a.event_type=${add(p("type"))}`);
      sql = `select a.*, s.full_name as by_name from animal_events a left join staff s on s.id=a.created_by where ${where.join(" and ")} order by a.ts desc limit ${limit} offset ${offset}`; countSql = `select count(*) as n from animal_events a where ${where.join(" and ")}`; break;
    }
    default: return NextResponse.json({ error: "ERR_UNKNOWN_KIND" }, { status: 404 });
  }
  try {
    const out = await withCtx({ ...s, farmId: farm }, async (c) => ({ rows: (await c.query(sql, args)).rows, total: Number((await c.query(countSql, args)).rows[0].n) }));
    return NextResponse.json({ ...out, limit, offset });
  } catch (e) { return NextResponse.json({ error: "ERR_QUERY", detail: (e as Error).message }, { status: 500 }); }
}
