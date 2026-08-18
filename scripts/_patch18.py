import io, os
R = "F:/ITRAN FARM/itran-os/"
def w(p, s): os.makedirs(os.path.dirname(R + p) or R, exist_ok=True); io.open(R + p, "w", encoding="utf-8", newline="\n").write(s); print("w", p)
def rw(p, fn): s = io.open(R + p, encoding="utf-8").read(); n = fn(s); assert n != s, p; io.open(R + p, "w", encoding="utf-8", newline="\n").write(n); print("ok", p)
w("src/app/ban-do/page.tsx", '''import { Page } from "@/components/withSession"; import { MapPanel } from "@/components/panels/More";
export default function P() { return <Page title="Bản đồ trại — ô thửa · khu · trạng thái">{(s) => <MapPanel sess={s} />}</Page>; }
''')
w("src/app/khau-phan/page.tsx", '''import { Page } from "@/components/withSession"; import { RationPanel } from "@/components/panels/More";
export default function P() { return <Page title="Tối ưu khẩu phần giá rẻ nhất">{(s) => <RationPanel sess={s} />}</Page>; }
''')
w("src/app/co2e/page.tsx", '''import { Page } from "@/components/withSession"; import { GhgPanel } from "@/components/panels/More";
export default function P() { return <Page title="Phát thải CO2e & tuần hoàn">{() => <GhgPanel />}</Page>; }
''')
w("src/app/in-an/page.tsx", '''import { Page } from "@/components/withSession"; import { PrintCenter } from "@/components/panels/More";
export default function P() { return <Page title="In ấn — hóa đơn · phiếu cân · hợp đồng · nhãn QR · biểu mẫu · báo cáo">{(s) => <PrintCenter sess={s} />}</Page>; }
''')
# Kế toán: GL tab; Nhân sự: chấm công
rw("src/components/panels/Depts.tsx", lambda s: s.replace('import { PlPanel, KpiLuongPanel } from "@/components/panels/Extra";', 'import { PlPanel, KpiLuongPanel } from "@/components/panels/Extra";\nimport { GlPanel, AttendancePanel } from "@/components/panels/More";').replace('      <PlPanel sess={sess} />', '      <GlPanel sess={sess} />\n      <PlPanel sess={sess} />').replace('      <KpiLuongPanel sess={sess} />', '      <AttendancePanel sess={sess} />\n      <KpiLuongPanel sess={sess} />'))
# Portal đối tác
w("src/app/api/public/partner/[token]/route.ts", '''import { NextResponse } from "next/server";
import { adminPool } from "@/lib/db";
/** PORTAL ĐỐI TÁC (khách B2B / NCC) theo token: GET → hồ sơ, đơn, công nợ, lô + COA + chứng nhận; POST {lines:[{sku,qty}], deliver_date, note} → tạo đơn (orders) + event order.created */
export async function GET(_req: Request, { params }: { params: Promise<{ token: string }> }) {
  const { token } = await params; const p = adminPool();
  const pt = (await p.query("select id, name, kind, farm_id, phone, credit_limit, credit_days, approved from partners where portal_token=$1 and active", [token])).rows[0]; if (!pt) return NextResponse.json({ error: "ERR_NOT_FOUND" }, { status: 404 });
  const farm = pt.farm_id ?? "F01";
  const orders = (await p.query("select id, order_date, deliver_date, lines, total, status, note from orders where partner_id=$1 order by order_date desc limit 50", [pt.id])).rows;
  const sales = (await p.query("select ts, sku, lot_id, qty, price, amount, paid, invoice_no from sales where partner_id=$1 and status='ACTIVE' order by ts desc limit 100", [pt.id])).rows;
  const receivable = (await p.query("select coalesce(sum(amount),0) as v from sales where partner_id=$1 and status='ACTIVE' and not paid", [pt.id])).rows[0].v;
  const products = (await p.query("select pr.sku, pr.name, pr.unit, pl.price from products pr left join lateral (select price from price_list where subject=pr.sku and kind='NIEM_YET' order by version desc limit 1) pl on true where pr.active and pr.kind in ('THANH_PHAM','LANH') order by pr.name")).rows;
  const certs = (await p.query("select s.name, c.cert_number, c.body, c.valid_to, c.status from certifications c join standards s on s.code=c.standard_code where (c.farm_id=$1 or c.farm_id is null) and c.status='HIEU_LUC'", [farm])).rows;
  const icfs = (await p.query("select pct, level from v_icfs_summary where farm_id=$1", [farm])).rows[0];
  const lots = (await p.query("select distinct l.id, l.sku, l.mfg_date, l.expiry_date, l.coa_url from sales s join lots l on l.id=s.lot_id where s.partner_id=$1 order by l.mfg_date desc nulls last limit 30", [pt.id])).rows;
  return NextResponse.json({ partner: pt, orders, sales, receivable, products, certs, icfs, lots });
}
export async function POST(req: Request, { params }: { params: Promise<{ token: string }> }) {
  const { token } = await params; const p = adminPool(); const b = await req.json().catch(() => ({}));
  const pt = (await p.query("select id, farm_id, name from partners where portal_token=$1 and active", [token])).rows[0]; if (!pt) return NextResponse.json({ error: "ERR_NOT_FOUND" }, { status: 404 });
  const lines = (Array.isArray(b.lines) ? b.lines : []).filter((l: { sku?: string; qty?: number }) => l.sku && Number(l.qty) > 0); if (!lines.length) return NextResponse.json({ error: "ERR_EMPTY" }, { status: 400 });
  const farm = pt.farm_id ?? "F01"; const priced = [] as { sku: string; qty: number; price: number }[];
  for (const l of lines) { const pr = (await p.query("select price from price_list where subject=$1 and kind='NIEM_YET' order by version desc limit 1", [l.sku])).rows[0]; priced.push({ sku: l.sku, qty: Number(l.qty), price: Number(pr?.price ?? 0) }); }
  const total = priced.reduce((a, l) => a + l.qty * l.price, 0); const id = (await p.query("select next_code_free($1,'DH','orders',5) as c", [farm])).rows[0].c;
  await p.query("insert into orders(id,farm_id,partner_id,channel,order_date,deliver_date,lines,total,status,cutoff_ok,created_by,note) values ($1,$2,$3,1,current_date,$4,$5,$6,'MOI',$7,$8,$9)", [id, farm, pt.id, b.deliver_date ?? null, JSON.stringify(priced), total, new Date().getHours() < 15, "PORTAL:" + pt.id, b.note ?? null]);
  await p.query("select publish_event($1,'order.created',$2)", [farm, JSON.stringify({ table: "orders", id, partner: pt.name, total, source: "portal" })]);
  return NextResponse.json({ ok: true, id, total });
}
''')
w("src/app/doi-tac/[token]/page.tsx", '''"use client";
import { use, useEffect, useState } from "react";
type R = Record<string, unknown>;
const vnd = (v: unknown) => Number(v ?? 0).toLocaleString("vi-VN") + " đ"; const d = (v: unknown) => (v ? new Date(String(v)).toLocaleDateString("vi-VN") : "");
/** PORTAL ĐỐI TÁC B2B (không cần tài khoản, theo link riêng): đặt hàng theo bảng giá · đơn của tôi · công nợ · lô đã mua + COA + truy xuất · chứng nhận & ICFS của trại */
export default function P({ params }: { params: Promise<{ token: string }> }) {
  const { token } = use(params); const [j, setJ] = useState<R | null>(null); const [cart, setCart] = useState<Record<string, number>>({}); const [dd, setDd] = useState(""); const [msg, setMsg] = useState("");
  const load = () => fetch(`/api/public/partner/${token}`).then((r) => r.json()).then(setJ);
  useEffect(() => { load(); }, [token]); // eslint-disable-line react-hooks/exhaustive-deps
  if (!j) return <main className="min-h-screen flex items-center justify-center text-slate-500">Đang tải…</main>; if (j.error) return <main className="min-h-screen flex items-center justify-center">Liên kết không hợp lệ.</main>;
  const pt = j.partner as R; const P = (j.products as R[]) ?? []; const total = P.reduce((a, p) => a + (cart[String(p.sku)] ?? 0) * Number(p.price ?? 0), 0);
  return (<main className="min-h-screen bg-slate-50"><div className="max-w-3xl mx-auto p-4 space-y-4">
    <div className="rounded-2xl bg-white p-4 shadow"><div className="text-xs uppercase tracking-widest text-emerald-700 font-bold">ITRAN FARM · cổng đối tác</div><h1 className="text-xl font-black">{String(pt.name)}</h1><div className="text-sm text-slate-600">Hạn mức {vnd(pt.credit_limit)} · {String(pt.credit_days ?? 0)} ngày · công nợ hiện tại <b className={Number(j.receivable) > 0 ? "text-red-700" : ""}>{vnd(j.receivable)}</b> · trại đạt ICFS {String((j.icfs as R)?.pct ?? "—")}% ({String((j.icfs as R)?.level ?? "")}) · <a className="underline" href="/chuan" target="_blank">tiêu chuẩn</a></div><div className="text-xs mt-1">Chứng nhận hiệu lực: {((j.certs as R[]) ?? []).map((c) => `${c.name} (${c.body ?? ""}, đến ${d(c.valid_to)})`).join(" · ") || "đang cập nhật"}</div></div>
    <div className="rounded-2xl bg-white p-4 shadow"><b>Đặt hàng</b><table className="w-full text-sm mt-2"><tbody>{P.map((p) => <tr key={String(p.sku)} className="border-t"><td className="py-1">{String(p.name)} <span className="text-xs text-slate-500">{String(p.unit ?? "")}</span></td><td className="text-right">{p.price ? vnd(p.price) : "liên hệ"}</td><td className="text-right w-28"><input type="number" min={0} className="w-24 rounded-lg border px-2 py-1 text-right" value={cart[String(p.sku)] ?? ""} onChange={(e) => setCart({ ...cart, [String(p.sku)]: Number(e.target.value) })} /></td></tr>)}</tbody></table><div className="flex gap-2 items-center mt-2 text-sm"><input type="date" className="rounded-lg border px-2 py-1" value={dd} onChange={(e) => setDd(e.target.value)} /><span className="ml-auto font-bold">Tạm tính {vnd(total)}</span><button className="rounded-xl bg-emerald-600 text-white px-4 py-2 font-bold" disabled={!total} onClick={async () => { const lines = Object.entries(cart).filter(([, q]) => q > 0).map(([sku, qty]) => ({ sku, qty })); const r = await fetch(`/api/public/partner/${token}`, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ lines, deliver_date: dd || null }) }).then((x) => x.json()); setMsg(r.ok ? `Đã đặt đơn ${r.id} — trại sẽ xác nhận` : r.error); setCart({}); load(); }}>Đặt hàng</button></div>{msg && <div className="text-sm text-emerald-700 mt-1">{msg}</div>}</div>
    <div className="rounded-2xl bg-white p-4 shadow"><b>Đơn của tôi</b><table className="w-full text-sm mt-1"><tbody>{((j.orders as R[]) ?? []).map((o) => <tr key={String(o.id)} className="border-t"><td className="py-1 font-mono text-xs">{String(o.id)}</td><td>{d(o.order_date)} → giao {d(o.deliver_date)}</td><td className="text-xs">{((o.lines as R[]) ?? []).map((l) => `${l.sku}×${l.qty}`).join(", ")}</td><td className="text-right">{vnd(o.total)}</td><td><span className="rounded-full bg-slate-100 px-2 text-xs">{String(o.status)}</span></td></tr>)}</tbody></table></div>
    <div className="rounded-2xl bg-white p-4 shadow"><b>Đã mua · lô · truy xuất · COA</b><table className="w-full text-sm mt-1"><tbody>{((j.sales as R[]) ?? []).slice(0, 30).map((s, i) => <tr key={i} className="border-t"><td className="py-1 text-xs">{d(s.ts)}</td><td>{String(s.sku)}</td><td className="font-mono text-xs">{s.lot_id ? <a className="underline" href={`/trace/${s.lot_id}`} target="_blank">{String(s.lot_id)}</a> : ""}</td><td className="text-right">{String(s.qty)}</td><td className="text-right">{vnd(s.amount)}</td><td>{s.paid ? "✓" : <span className="text-red-700">chưa TT</span>}</td></tr>)}</tbody></table><div className="text-xs mt-1">COA theo lô: {((j.lots as R[]) ?? []).filter((l) => l.coa_url).map((l) => <a key={String(l.id)} className="underline mr-2" href={String(l.coa_url)} target="_blank">{String(l.id)}</a>)}</div></div>
    <div className="text-center text-xs text-slate-500">Dữ liệu trực tiếp từ ITRAN OS · <a className="underline" href="/chuan">ICFS công khai</a></div>
  </div></main>);
}
''')
rw("src/proxy.ts", lambda s: s.replace('pathname.startsWith("/khach/") ||', 'pathname.startsWith("/khach/") || pathname.startsWith("/doi-tac/") ||'))
# Hướng dẫn sử dụng (theo vai) — trang trong app
w("src/app/huong-dan/page.tsx", '''import { Page } from "@/components/withSession"; import HuongDan from "@/components/panels/HuongDan";
export default function P() { return <Page title="Hướng dẫn sử dụng theo vai">{(s) => <HuongDan sess={s} />}</Page>; }
''')
w("src/components/panels/HuongDan.tsx", '''"use client";
import { useState } from "react";
import type { Sess } from "@/components/Shell";
const G: Record<string, { title: string; steps: string[] }[]> = {
  worker: [
    { title: "Mỗi ca 3 việc", steps: ["Mở app → 🏠 Trang chủ → «Ca của tôi» (hoặc chấm công ▶ Vào ca ở Nhân sự nếu tổ yêu cầu).", "Làm việc trong danh sách «Việc của tôi» (việc do quy trình/vòng theo dõi tự sinh): bấm việc → ghi bằng form 3 chạm (chọn đối tượng → nhập số → Lưu). Mất mạng vẫn ghi được, tự đồng bộ khi có sóng (xem ⏳ góc phải).", "Cuối ca: giao ca (ghi chú) và ■ Ra ca."] },
    { title: "Ghi đúng đối tượng", steps: ["Gõ mã/tên vào ô 🔍 (bò B004, ô R3, mặt hàng…) → mở trang 360 → xem/ghi.", "Bò/dê: quét/gõ RFID hoặc thẻ; bê chưa có tai vẫn ghi (chờ gắn tai).", "Sai trong 72h: tự sửa (bản mới); sau 72h: báo tổ trưởng lập phiếu điều chỉnh."] },
    { title: "Phiếu giấy", steps: ["Khi không có máy: ghi BM01–BM10 (in ở In ấn), số hóa vào «Phiếu giấy» trong 24h, ghi số phiếu."] },
  ],
  team_lead: [
    { title: "Đầu ca", steps: ["Xem «Đàn › 🔄 Vòng theo dõi» (cân/vaccine/tẩy KST/khám thai đến hạn) và «Phê duyệt» (checklist tổ).", "Phân việc: Ca của tôi → tạo việc → gán người."] },
    { title: "Nhập lô đàn", steps: ["Đàn › ⬆ Nhập lô đàn: nhập nguồn/giấy kiểm dịch/giá → dán danh sách RFID|thẻ|giới|ngày sinh|kg từ Excel/máy đọc (hoặc chỉ số con) → hệ thống sinh mã cá thể, cách ly 21 ngày, sổ đàn K8, việc theo dõi."] },
    { title: "Kho", steps: ["Kho › Nhập/Xuất theo lô (FEFO), Kiểm kê tuần/tháng, chênh lệch → phiếu điều chỉnh (KTT duyệt).", "Mỗi dòng có 📈 để xem biến động so kỳ trước."] },
  ],
  tech_head: [
    { title: "Kỹ thuật", steps: ["KTT: duyệt điều chỉnh/checklist, kế hoạch khẩu phần (Kế hoạch), Thú y (điều trị – ngưng thuốc – vaccine).", "Canh tác: mở mùa vụ → vật tư có PHI → thu hoạch (bị chặn khi còn cách ly) → xuất Nhật ký sản xuất.", "Khẩu phần: /khau-phan tính khẩu phần rẻ nhất theo giá kho.", "Đối tượng: định nghĩa loài/lớp/cây/biến đầu vào–ra; Vòng theo dõi: sửa tham số theo loài/lớp."] },
    { title: "Quy trình & chuẩn", steps: ["Tổ chức › Khai báo quy trình: thêm/xóa bước, bộ phận, công cụ, vật tư, đầu vào/ra, biểu mẫu bắt buộc → Xuất bản (phòng ban nhận thông báo) → ▶ Chạy.", "Tuân thủ: tự đánh giá điều khoản (đạt/NC/N/A), đóng NC, sổ chứng nhận; ICFS tự chấm ở /chuan."] },
  ],
  director: [
    { title: "Mỗi sáng 5 phút", steps: ["Dashboard GĐ → cảnh báo ĐỎ → Phê duyệt (chi 2 chữ ký, PO, nghỉ phép) → Đối soát đêm (lệch >5%).", "Số liệu › Mọi trường: bất kỳ cột số nào cũng vẽ được, so kỳ trước, bấm cột ra bản ghi gốc."] },
    { title: "Công ty · trại", steps: ["Công ty › Khai báo trại (9 kho/12 CC/khu tự sinh) → Hồ sơ trại (diện tích, hạ tầng, nhân sự, giấy phép).", "Quản trị DL: thêm/sửa/gỡ/nhập CSV/xuất/lịch sử mọi bảng — admin được báo mọi thay đổi.", "Kế toán: cân đối phát sinh (GL tự hạch toán), P&L phân hệ, VietQR thu tiền, xuất CSV cho MISA/Fast; In ấn: hóa đơn, phiếu cân, HĐ, nhãn QR, báo cáo tuần."] },
  ],
  owner: [
    { title: "Chủ đầu tư", steps: ["Trang chủ → Công ty (so sánh trại, ICFS, P&L) → Cảnh báo ĐỎ → Phê duyệt chi >50tr.", "/chuan công khai cho đối tác/cơ quan; portal khách nhận nuôi /khach/{token}; portal đối tác /doi-tac/{token} (link trong Đối tác).", "Sao lưu tự động 01:15 (pg_dump + ZIP CSV → BACKUP_DIR); job đêm; thông báo Zalo/SMS/Email cấu hình ở Quản trị DL › integrations."] },
  ],
  accountant: [{ title: "Kế toán", steps: ["Đề nghị chi (đính kèm chứng từ) → Phê duyệt → chi & ghi paid → GL tự sinh bút toán.", "Đối chiếu ngân hàng (nhập sao kê), khóa kỳ, bảng kê thuế (sales-tax), TT66, gói audit sha256.", "Kênh/POS: hóa đơn POS → sales; công nợ theo đối tác; VietQR in trên hóa đơn."] }],
  it_engineer: [{ title: "Hệ thống", steps: ["Thiết bị/cảm biến: IoT ingest bằng API key (Quản trị DL › api_keys), MQTT bridge POST /api/ingest/sensor.", "Cảnh báo: luật cấu hình; kênh Zalo/SMS/Email trong integrations; webhook đối tác.", "Docker/compose/CI có sẵn; migrate `pnpm db:migrate`; backup ở BACKUP_DIR; khóa/mở khóa tài khoản, reset PIN.", "Thêm bảng/cột → tự có biểu đồ, quản trị, CSV; thêm đối tượng 360 = 1 dòng cấu hình."] }],
  auditor: [{ title: "Kiểm toán / QA", steps: ["Audit › gói audit sha256; Đối soát RC1–RC16; Tuân thủ: 19 chuẩn, ma trận yêu cầu → bằng chứng; ICFS; lịch sử thay đổi danh mục (audit_log)."] }],
};
export default function HuongDan({ sess }: { sess: Sess }) {
  const [role, setRole] = useState(sess.role in G ? sess.role : "worker");
  return (<div className="space-y-3"><div className="flex gap-2 flex-wrap">{Object.keys(G).map((r) => <button key={r} className={`px-3 py-1.5 rounded-xl text-sm font-semibold ${role === r ? "bg-emerald-600 text-white" : "bg-white border"}`} onClick={() => setRole(r)}>{r}</button>)}<a className="ml-auto underline text-sm self-center" href="/to-chuc">quy trình đầy đủ</a></div>
    {G[role].map((sec) => <div key={sec.title} className="card"><b>{sec.title}</b><ol className="list-decimal pl-5 mt-1 space-y-1 text-sm">{sec.steps.map((s, i) => <li key={i}>{s}</li>)}</ol></div>)}
    <div className="text-xs text-slate-500">Điện thoại: mở trình duyệt Chrome → «Thêm vào màn hình chính» để dùng như app (PWA), ghi được khi mất mạng.</div></div>);
}
''')
# nav additions
rw("src/components/Shell.tsx", lambda s: s.replace('{ href: "/kho", label: "Kho" }, { href: "/thiet-bi", label: "Thiết bị" }, { href: "/truy-xuat", label: "Truy xuất" }]', '{ href: "/kho", label: "Kho" }, { href: "/khau-phan", label: "Khẩu phần tối ưu", roles: ["tech_head", "director", "owner"] }, { href: "/thiet-bi", label: "Thiết bị" }, { href: "/truy-xuat", label: "Truy xuất" }, { href: "/ban-do", label: "Bản đồ" }, { href: "/in-an", label: "In ấn" }]').replace('{ href: "/tuan-thu", label: "Tuân thủ · chứng nhận", roles: ["director", "owner", "tech_head", "auditor", "it_engineer", "accountant"] }]', '{ href: "/tuan-thu", label: "Tuân thủ · chứng nhận", roles: ["director", "owner", "tech_head", "auditor", "it_engineer", "accountant"] }, { href: "/co2e", label: "CO2e", roles: ["director", "owner", "tech_head", "auditor"] }]'))
