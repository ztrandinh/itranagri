import { NextResponse } from "next/server";
import { adminPool } from "@/lib/db";
/** Trang QR công khai (không auth): lô SKU (F01-LOT-…) hoặc con vật (qr_token / mã). Chỉ trả dữ liệu công khai, rate-limit ở proxy/CDN. */
export async function GET(_: Request, { params }: { params: Promise<{ lot: string }> }) {
  const { lot } = await params; const key = decodeURIComponent(lot);
  const p = adminPool();
  const l = (await p.query("select l.id, l.lot_no, l.mfg_date, l.expiry_date, l.status, p.name as product, p.sku, f.name as farm, f.province from lots l join products p on p.sku=l.sku join farms f on f.id=l.farm_id where l.id=$1", [key])).rows[0];
  if (l) {
    const chain = (await p.query("select input_lot, batch_code, ts from v_trace_links where output_lot=$1", [key])).rows;
    const batch = chain.length ? (await p.query("select batch_code, line, ts, ccp_readings from batch_logs where batch_code = any($1) and status='ACTIVE'", [chain.map((c) => c.batch_code)])).rows : [];
    return NextResponse.json({ kind: "LOT", lot: l, inputs: chain, batches: batch.map((b) => ({ ...b, ccp_ok: Array.isArray(b.ccp_readings) ? (b.ccp_readings as { ok?: boolean }[]).every((c) => c.ok !== false) : true })), story: "Một vòng tròn — không gì bị bỏ đi." });
  }
  const a = (await p.query("select a.id, a.visual_tag, a.species, a.breed, a.sex, a.birth_date, a.status, a.last_weight_kg, a.last_weight_at, f.name as farm, f.province, g.name as group_name from animals a join farms f on f.id=a.farm_id left join animal_groups g on g.id=a.group_id where a.qr_token=$1 or a.id=$1", [key])).rows[0];
  if (a) {
    const ev = (await p.query("select ts, event_type, value, unit from animal_events where animal_id=$1 and status='ACTIVE' and event_type in ('CAN','VACCINE','DE','CAI_SUA','PHAN_LOAI','CHUYEN','NHAP') order by ts desc limit 30", [a.id])).rows;
    return NextResponse.json({ kind: "ANIMAL", animal: a, events: ev, story: "Một vòng tròn — không gì bị bỏ đi." });
  }
  return NextResponse.json({ error: "NOT_FOUND" }, { status: 404 });
}
