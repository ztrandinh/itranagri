import { NextResponse } from "next/server";
import { createHash } from "node:crypto";
import { adminPool } from "@/lib/db";
/** IoT INGEST: POST /api/ingest/sensor  header x-api-key  body {farm_id?, readings:[{device_id, metric, value, ts?, quality?}]}
 *  Khóa API tạo ở Quản trị DL › api_keys (lưu sha256; scope 'ingest'). Gateway MQTT/LoRa/ESP32 gọi trực tiếp; partition tháng tự có (ensure_sensor_partitions). */
export async function POST(req: Request) {
  const key = req.headers.get("x-api-key") ?? ""; if (!key) return NextResponse.json({ error: "ERR_NO_KEY" }, { status: 401 });
  const hash = createHash("sha256").update(key).digest("hex"); const p = adminPool();
  const k = (await p.query("select * from api_keys where key_hash=$1 and revoked_at is null and ('ingest' = any(scopes) or 'write' = any(scopes))", [hash])).rows[0];
  if (!k) return NextResponse.json({ error: "ERR_BAD_KEY" }, { status: 403 });
  const b = await req.json().catch(() => null); const farm = String(b?.farm_id ?? k.farm_id ?? ""); const rs: { device_id: string; metric: string; value: number; ts?: string; quality?: string }[] = Array.isArray(b?.readings) ? b.readings : b ? [b] : [];
  if (!farm || !rs.length) return NextResponse.json({ error: "ERR_EMPTY" }, { status: 400 });
  if (k.farm_id && k.farm_id !== farm) return NextResponse.json({ error: "ERR_FARM_SCOPE" }, { status: 403 });
  let n = 0, dup = 0; const errors: string[] = [];
  // dedupe DB thật theo (farm_id, device_id, metric, ts) — gateway MQTT/LoRa retry sau timeout mạng
  // thường gửi lại ĐÚNG bản ghi cũ (cùng ts lấy mẫu) → ON CONFLICT DO NOTHING chặn nhân đôi ở nguồn,
  // thay vì mỗi lần retry lại thêm 1 dòng làm sai lệch cảnh báo nhiệt độ/oxy hòa tan (0194).
  for (const r of rs.slice(0, 5000)) {
    try {
      if (!r.device_id || !r.metric || typeof r.value !== "number") throw new Error("thiếu device_id/metric/value");
      const ins = await p.query("insert into sensor_reads(ts,farm_id,device_id,metric,value,quality) values (coalesce($1::timestamptz, now()),$2,$3,$4,$5,$6) on conflict (farm_id,device_id,metric,ts) do nothing", [r.ts ?? null, farm, r.device_id, r.metric, r.value, r.quality ?? "OK"]);
      if (ins.rowCount) n++; else dup++;
    } catch (e) { errors.push(`${r.device_id ?? "?"}/${r.metric ?? "?"}: ${(e as Error).message.slice(0, 80)}`); }
  }
  await p.query("update api_keys set last_used_at=now() where id=$1", [k.id]);
  return NextResponse.json({ ok: true, inserted: n, duplicate: dup, errors: errors.slice(0, 20) });
}
