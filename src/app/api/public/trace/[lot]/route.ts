import { NextResponse } from "next/server";
import { adminPool } from "@/lib/db";
/** Trang QR công khai (không auth): lô SKU (F01-LOT-…) hoặc con vật (qr_token / mã). Chỉ trả dữ liệu công khai, rate-limit ở proxy/CDN. */
export async function GET(_: Request, { params }: { params: Promise<{ lot: string }> }) {
  const { lot } = await params; const key = decodeURIComponent(lot);
  const p = adminPool();
  const l = (await p.query("select l.id, l.farm_id, l.lot_no, l.mfg_date, l.expiry_date, l.status, p.name as product, p.sku, f.name as farm, f.province from lots l join products p on p.sku=l.sku join farms f on f.id=l.farm_id where l.id=$1", [key])).rows[0];
  if (l) {
    // Truy xuất TOÀN CHUỖI (0201) — trước đây chỉ 1 bước lùi (input_lot trực tiếp), không chạm nguồn
    // gốc thật (harvest/mua) hay điểm cuối thật (bán/cho ăn). Nay đệ quy qua mọi batch_logs liên quan
    // (tới độ sâu 10) rồi tra origin/exit thật cho toàn bộ tập lô trong chuỗi.
    const chainR = (await p.query("select trace_full_chain($1,$2) as j", [l.farm_id ?? "F01", key])).rows[0]?.j ?? {};
    const batchCodes: string[] = ((chainR.batches ?? []) as { batch_code: string }[]).map((b) => b.batch_code);
    const batch = batchCodes.length ? (await p.query("select batch_code, line, ts, ccp_readings from batch_logs where batch_code = any($1) and status='ACTIVE'", [batchCodes])).rows : [];
    return NextResponse.json({
      kind: "LOT", lot: l, chain: chainR,
      batches: batch.map((b) => ({ ...b, ccp_ok: Array.isArray(b.ccp_readings) ? (b.ccp_readings as { ok?: boolean }[]).every((c) => c.ok !== false) : true })),
      story: "Một vòng tròn — không gì bị bỏ đi.",
    });
  }
  const a = (await p.query("select a.id, a.visual_tag, a.species, a.breed, a.sex, a.birth_date, a.status, a.last_weight_kg, a.last_weight_at, f.name as farm, f.province, g.name as group_name from animals a join farms f on f.id=a.farm_id left join animal_groups g on g.id=a.group_id where a.qr_token=$1 or a.id=$1", [key])).rows[0];
  if (a) {
    const ev = (await p.query("select ts, event_type, value, unit from animal_events where animal_id=$1 and status='ACTIVE' and event_type in ('CAN','VACCINE','DE','CAI_SUA','PHAN_LOAI','CHUYEN','NHAP') order by ts desc limit 30", [a.id])).rows;
    return NextResponse.json({ kind: "ANIMAL", animal: a, events: ev, story: "Một vòng tròn — không gì bị bỏ đi." });
  }
  return NextResponse.json({ error: "NOT_FOUND" }, { status: 404 });
}
