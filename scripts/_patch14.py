import io, os
R = "F:/ITRAN FARM/itran-os/"
def w(p, s): os.makedirs(os.path.dirname(R + p), exist_ok=True); io.open(R + p, "w", encoding="utf-8", newline="\n").write(s); print("w", p)
def rw(p, fn): s = io.open(R + p, encoding="utf-8").read(); n = fn(s); assert n != s, p; io.open(R + p, "w", encoding="utf-8", newline="\n").write(n); print("ok", p)
# 1) search không dấu
def srch(s):
    s = s.replace('const like = `%${q}%`;', 'const like = `%${q}%`; // so khớp không dấu qua noaccent()')
    return s.replace(" ilike $2", " ilike $2 or noaccent(coalesce(name,'')) like noaccent($2)") if False else s.replace("id ilike $2 or visual_tag ilike $2 or rfid ilike $2 or breed ilike $2", "noaccent(id||' '||coalesce(visual_tag,'')||' '||coalesce(rfid,'')||' '||coalesce(breed,'')) like noaccent($2)").replace("id ilike $2 or name ilike $2 or species ilike $2)", "noaccent(id||' '||name||' '||species) like noaccent($2))").replace("(id ilike $2 or name ilike $2 or coalesce(current_crop,'') ilike $2 or coalesce(crop_code,'') ilike $2)", "noaccent(id||' '||name||' '||coalesce(current_crop,'')||' '||coalesce(crop_code,'')) like noaccent($2)").replace("(code ilike $2 or name ilike $2 or array_to_string(varieties,' ') ilike $2)", "noaccent(code||' '||name||' '||array_to_string(varieties,' ')) like noaccent($2)").replace("where code ilike $2 or name ilike $2\n", "where noaccent(code||' '||name) like noaccent($2)\n").replace("where sku ilike $2 or name ilike $2", "where noaccent(sku||' '||name) like noaccent($2)").replace("(id ilike $2 or full_name ilike $2 or coalesce(position,'') ilike $2 or coalesce(phone,'') ilike $2)", "noaccent(id||' '||full_name||' '||coalesce(position,'')||' '||coalesce(phone,'')) like noaccent($2)").replace("(id ilike $2 or name ilike $2 or coalesce(phone,'') ilike $2)", "noaccent(id||' '||name||' '||coalesce(phone,'')) like noaccent($2)").replace("(id ilike $2 or name ilike $2)", "noaccent(id||' '||name) like noaccent($2)").replace("(code ilike $2 or name ilike $2)", "noaccent(code||' '||name) like noaccent($2)").replace("(code ilike $2 or crop ilike $2 or coalesce(variety,'') ilike $2)", "noaccent(code||' '||crop||' '||coalesce(variety,'')) like noaccent($2)").replace("where code ilike $2 or name ilike $2\n    union all select 'department'", "where noaccent(code||' '||name) like noaccent($2)\n    union all select 'department'").replace("(code ilike $2 or coalesce(guest_name,'') ilike $2 or coalesce(guest_phone,'') ilike $2)", "noaccent(code||' '||coalesce(guest_name,'')||' '||coalesce(guest_phone,'')) like noaccent($2)")
rw("src/app/api/search/route.ts", srch)
# 2) IoT ingest với API key (api_keys.key_hash = sha256) — thiết bị/gateway/MQTT bridge POST JSON hàng loạt
w("src/app/api/ingest/sensor/route.ts", '''import { NextResponse } from "next/server";
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
  let n = 0; const errors: string[] = [];
  for (const r of rs.slice(0, 5000)) { try { if (!r.device_id || !r.metric || typeof r.value !== "number") throw new Error("thiếu device_id/metric/value"); await p.query("insert into sensor_reads(ts,farm_id,device_id,metric,value,quality) values (coalesce($1::timestamptz, now()),$2,$3,$4,$5,$6)", [r.ts ?? null, farm, r.device_id, r.metric, r.value, r.quality ?? "OK"]); n++; } catch (e) { errors.push(`${r.device_id ?? "?"}/${r.metric ?? "?"}: ${(e as Error).message.slice(0, 80)}`); } }
  await p.query("update api_keys set last_used_at=now() where id=$1", [k.id]);
  return NextResponse.json({ ok: true, inserted: n, errors: errors.slice(0, 20) });
}
''')
# action tạo API key (trả plaintext 1 lần)
rw("src/app/api/actions/route.ts", lambda s: s.replace('        default: throw new Error("ERR_UNKNOWN_ACTION");', '''        case "create_api_key": {
          if (!["owner","it_engineer"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE");
          const raw = "itk_" + [...crypto.getRandomValues(new Uint8Array(24))].map((x) => x.toString(16).padStart(2, "0")).join("");
          const { createHash } = await import("node:crypto"); const h = createHash("sha256").update(raw).digest("hex");
          const r = await c.query("insert into api_keys(org_id,farm_id,name,key_hash,scopes,created_by) values ($1,$2,$3,$4,$5,$6) returning id", [s.orgId, b.farm_id ?? s.farmId, b.name ?? "key", h, Array.isArray(b.scopes) ? b.scopes : ["ingest"], s.staffId]);
          return { ok: true, id: r.rows[0].id, key: raw, note: "Lưu khóa này ngay — hệ thống chỉ giữ sha256" };
        }
        default: throw new Error("ERR_UNKNOWN_ACTION");''', 1))
rw("src/proxy.ts", lambda s: s.replace('pathname.startsWith("/api/public") ||', 'pathname.startsWith("/api/public") || pathname.startsWith("/api/ingest/") || pathname.startsWith("/khach/") ||'))
# 3) Portal khách nhận nuôi (public theo token)
w("src/app/api/public/custody/[token]/route.ts", '''import { NextResponse } from "next/server";
import { adminPool } from "@/lib/db";
/** PORTAL KHÁCH NHẬN NUÔI (token trong HĐ): GET → HĐ, cá thể, sự kiện 90 ngày, ảnh, tin nhắn; POST {body} → tin nhắn cho trại (event customer.message) */
export async function GET(_req: Request, { params }: { params: Promise<{ token: string }> }) {
  const { token } = await params; const p = adminPool();
  const c = (await p.query("select c.*, pt.name as customer_name from custody_contracts c left join partners pt on pt.id=c.partner_id where c.portal_token=$1", [token])).rows[0];
  if (!c) return NextResponse.json({ error: "ERR_NOT_FOUND" }, { status: 404 });
  const ids: string[] = c.animal_ids ?? [];
  const animals = (await p.query("select id, species, breed, sex, birth_date, status, last_weight_kg, last_weight_at, visual_tag, photos, location_id from animals where id = any($1)", [ids])).rows;
  const events = (await p.query("select animal_id, ts, event_type, value, unit, detail, photo_urls from animal_events where animal_id = any($1) and status='ACTIVE' and ts > now() - interval '90 days' and event_type not in ('DIEU_TRI','BENH') order by ts desc limit 200", [ids])).rows;
  const health = (await p.query("select animal_id, count(*) filter (where event_type in ('DIEU_TRI','BENH')) as treatments, max(ts) filter (where event_type='VACCINE') as last_vaccine from animal_events where animal_id = any($1) and status='ACTIVE' group by 1", [ids])).rows;
  const msgs = (await p.query("select * from customer_messages where contract_id=$1 order by ts desc limit 50", [c.id])).rows;
  const live = (await p.query("select value from settings where key='custody.live_hours' order by (farm_id=$1) desc limit 1", [c.farm_id])).rows[0]?.value ?? ["08:00-10:00", "15:00-17:00"];
  return NextResponse.json({ contract: { id: c.id, kind: c.kind, package: c.package, start_date: c.start_date, end_date: c.end_date, status: c.status, customer: c.customer_name, farm: c.farm_id }, animals, events, health, messages: msgs, live_hours: live });
}
export async function POST(req: Request, { params }: { params: Promise<{ token: string }> }) {
  const { token } = await params; const p = adminPool(); const b = await req.json().catch(() => ({}));
  const c = (await p.query("select id, farm_id, animal_ids from custody_contracts where portal_token=$1", [token])).rows[0]; if (!c) return NextResponse.json({ error: "ERR_NOT_FOUND" }, { status: 404 });
  const body = String(b.body ?? "").slice(0, 1000); if (!body) return NextResponse.json({ error: "ERR_EMPTY" }, { status: 400 });
  await p.query("insert into customer_messages(farm_id,contract_id,animal_id,from_customer,body) values ($1,$2,$3,true,$4)", [c.farm_id, c.id, b.animal_id ?? (c.animal_ids ?? [])[0] ?? null, body]);
  await p.query("select publish_event($1,'customer.message',$2)", [c.farm_id, JSON.stringify({ contract: c.id, body })]);
  return NextResponse.json({ ok: true });
}
''')
w("src/app/khach/[token]/page.tsx", '''"use client";
import { use, useEffect, useState } from "react";
type R = Record<string, unknown>;
const d = (v: unknown) => (v ? new Date(String(v)).toLocaleString("vi-VN", { day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit" }) : "");
/** PORTAL KHÁCH (mobile-first, không cần tài khoản): con của tôi · sự kiện · sức khỏe · giờ xem live · nhắn tin trại */
export default function P({ params }: { params: Promise<{ token: string }> }) {
  const { token } = use(params); const [j, setJ] = useState<R | null>(null); const [msg, setMsg] = useState(""); const [err, setErr] = useState("");
  const load = () => fetch(`/api/public/custody/${token}`).then((r) => r.json()).then((x) => (x.error ? setErr("Liên kết không hợp lệ hoặc hợp đồng đã kết thúc") : setJ(x)));
  useEffect(() => { load(); }, [token]); // eslint-disable-line react-hooks/exhaustive-deps
  if (err) return <main className="min-h-screen flex items-center justify-center text-slate-600">{err}</main>;
  if (!j) return <main className="min-h-screen flex items-center justify-center text-slate-500">Đang tải…</main>;
  const c = j.contract as R; const A = (j.animals as R[]) ?? []; const E = (j.events as R[]) ?? []; const H = (j.health as R[]) ?? []; const M = (j.messages as R[]) ?? [];
  return (<main className="min-h-screen bg-emerald-50 text-slate-900"><div className="max-w-xl mx-auto p-4 space-y-4">
    <div className="rounded-2xl bg-white p-4 shadow"><div className="text-xs uppercase tracking-widest text-emerald-700 font-bold">ITRAN FARM · chăm sóc hộ</div><h1 className="text-xl font-black">Xin chào {String(c.customer ?? "quý khách")}</h1><div className="text-sm text-slate-600">HĐ {String(c.id)} · gói {String(c.package ?? c.kind)} · {String(c.start_date)} → {String(c.end_date ?? "…")} · trại {String(c.farm)}</div><div className="mt-2 text-sm">🎥 Giờ xem live: <b>{(j.live_hours as string[]).join(" · ")}</b> — nhắn "xem live" bên dưới, nhân viên sẽ gọi video.</div></div>
    {A.map((a) => { const h = H.find((x) => x.animal_id === a.id); return <div key={String(a.id)} className="rounded-2xl bg-white p-4 shadow"><div className="flex items-center gap-2"><span className="text-3xl">🐄</span><div><div className="font-black text-lg">{String(a.visual_tag ?? a.id)}</div><div className="text-xs text-slate-600">{String(a.species)} · {String(a.breed ?? "")} · {a.sex === "F" ? "cái" : "đực"} · sinh {String(a.birth_date ?? "?")} · {String(a.status)}</div></div><div className="ml-auto text-right"><div className="text-2xl font-black">{a.last_weight_kg ? `${a.last_weight_kg} kg` : "—"}</div><div className="text-[10px] text-slate-500">cân {d(a.last_weight_at)}</div></div></div>
      <div className="text-xs mt-2 flex gap-3"><span>💉 vaccine gần nhất: {h?.last_vaccine ? d(h.last_vaccine) : "—"}</span><span>🩺 điều trị (tổng): {String(h?.treatments ?? 0)}</span></div>
      {Array.isArray(a.photos) && (a.photos as string[]).length > 0 && <div className="flex gap-2 mt-2 overflow-x-auto">{(a.photos as string[]).slice(-6).map((u) => <img key={u} src={u} alt="" className="h-24 w-24 object-cover rounded-xl" />)}</div>}
      <div className="mt-2 max-h-56 overflow-auto text-sm">{E.filter((e) => e.animal_id === a.id).map((e, i) => <div key={i} className="border-t py-1 flex gap-2"><span className="text-xs text-slate-500 w-28 shrink-0">{d(e.ts)}</span><span className="font-semibold">{String(e.event_type)}</span><span>{e.value ? `${e.value} ${e.unit ?? ""}` : ""}</span>{Array.isArray(e.photo_urls) && (e.photo_urls as string[]).length > 0 && <a className="underline text-xs" href={(e.photo_urls as string[])[0]} target="_blank">ảnh</a>}</div>)}{!E.some((e) => e.animal_id === a.id) && <div className="text-slate-500">Chưa có sự kiện 90 ngày.</div>}</div></div>; })}
    <div className="rounded-2xl bg-white p-4 shadow"><div className="font-bold">Nhắn cho trại</div><div className="flex gap-2 mt-2"><input className="flex-1 rounded-xl border px-3 py-3 text-base" placeholder="Ví dụ: cho tôi xem live lúc 15h nhé" value={msg} onChange={(e) => setMsg(e.target.value)} /><button className="rounded-xl bg-emerald-600 text-white px-4 font-bold" onClick={async () => { if (!msg.trim()) return; await fetch(`/api/public/custody/${token}`, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ body: msg }) }); setMsg(""); load(); }}>Gửi</button></div>
      <div className="mt-2 space-y-1 text-sm max-h-64 overflow-auto">{M.map((m) => <div key={String(m.id)} className={`rounded-xl px-3 py-2 ${m.from_customer ? "bg-emerald-100 ml-8" : "bg-slate-100 mr-8"}`}><div className="text-[10px] text-slate-500">{m.from_customer ? "Bạn" : "Trại"} · {d(m.ts)}</div>{String(m.body)}</div>)}</div></div>
    <div className="text-center text-xs text-slate-500">Dữ liệu lấy trực tiếp từ sổ đàn ITRAN OS · truy xuất công khai · <a className="underline" href="/chuan">tiêu chuẩn ICFS</a></div>
  </div></main>);
}
''')
# hồ sơ nhận nuôi: nút mở portal trong BanHang tab nn (nếu có custody rows với portal_token)
