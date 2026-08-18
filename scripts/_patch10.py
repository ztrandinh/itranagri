import io, os
R = "F:/ITRAN FARM/itran-os/"
def w(p, s): os.makedirs(os.path.dirname(R + p), exist_ok=True); io.open(R + p, "w", encoding="utf-8", newline="\n").write(s); print("w", p)
def rw(p, fn): s = io.open(R + p, encoding="utf-8").read(); n = fn(s); assert n != s, p; io.open(R + p, "w", encoding="utf-8", newline="\n").write(n); print("ok", p)
# pages
w("src/app/to-chuc/page.tsx", '''import { Page } from "@/components/withSession"; import ToChuc from "@/components/panels/ToChuc";
export default async function P({ searchParams }: { searchParams: Promise<{ tab?: string; p?: string }> }) { const { tab, p } = await searchParams; return <Page title="Tổ chức — phòng ban · chức năng · quy trình A–Z · đầu vào/đầu ra · event bus · hồ sơ">{(s) => <ToChuc sess={s} initialTab={tab} initialProcess={p} />}</Page>; }
''')
w("src/app/doi-tuong/page.tsx", '''import { Page } from "@/components/withSession"; import DoiTuong from "@/components/panels/DoiTuong";
export default function P() { return <Page title="Đối tượng — con người · vật nuôi · cây trồng · sản phẩm/vật tư">{(s) => <DoiTuong sess={s} />}</Page>; }
''')
w("src/app/canh-tac/page.tsx", '''import { Page } from "@/components/withSession"; import CanhTac from "@/components/panels/CanhTac";
export default function P() { return <Page title="Canh tác — hồ sơ mùa vụ · vật tư & PHI · thu hoạch">{(s) => <CanhTac sess={s} />}</Page>; }
''')
w("src/app/du-lich/page.tsx", '''import { Page } from "@/components/withSession"; import DuLich from "@/components/panels/DuLich";
export default function P() { return <Page title="Du lịch — lưu trú · ẩm thực · tiệc/MICE · tour">{(s) => <DuLich sess={s} />}</Page>; }
''')
w("src/app/xem/[type]/[id]/page.tsx", '''import { Page } from "@/components/withSession"; import Obj360 from "@/components/panels/Obj360";
export default async function P({ params }: { params: Promise<{ type: string; id: string }> }) { const { type, id } = await params; return <Page title={`Xem 360 · ${decodeURIComponent(id)}`}>{(s) => <Obj360 sess={s} type={type} id={decodeURIComponent(id)} />}</Page>; }
''')
w("src/app/trang-chu/page.tsx", '''import { Page } from "@/components/withSession"; import Home from "@/components/panels/Home";
export default function P() { return <Page title="Trang chủ — chọn khu vực">{(s) => <Home sess={s} />}</Page>; }
''')
# Home zones panel
w("src/components/panels/Home.tsx", '''"use client";
import type { Sess } from "@/components/Shell";
import { ZONES } from "@/components/Shell";
import { Search } from "@/components/Search";
/** TRANG CHỦ theo KHU VỰC: mỗi khu = 1 ô lớn, dễ bấm trên điện thoại; chỉ hiện khu vai được vào */
export default function Home({ sess }: { sess: Sess }) {
  const zones = ZONES.filter((z) => z.roles.includes(sess.role) || z.roles.includes("*"));
  return (<div className="space-y-4">
    <div className="card"><div className="font-bold mb-1">Tìm mọi đối tượng — gõ tên/mã: con bò, ô ruộng, mặt hàng, người, khách, thiết bị…</div><Search big /></div>
    <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-3">{zones.map((z) => <div key={z.key} className="card"><div className="text-lg font-black">{z.icon} {z.label}</div><div className="text-xs text-stone-500 mb-2">{z.desc}</div><div className="flex flex-wrap gap-1">{z.items.filter((i) => !i.roles || i.roles.includes(sess.role)).map((i) => <a key={i.href} href={i.href} className="px-3 py-1.5 rounded-xl bg-stone-100 hover:bg-green-100 text-sm font-semibold">{i.label}</a>)}</div></div>)}</div>
  </div>);
}
''')
# Search component
w("src/components/Search.tsx", '''"use client";
import { useEffect, useRef, useState } from "react";
type Hit = { type: string; id: string; title: string; sub: string };
const ICON: Record<string, string> = { animal: "🐄", group: "🐔", plot: "🟩", crop: "🌱", species: "🧬", product: "📦", staff: "👤", partner: "🤝", device: "⚙️", facility: "🏠", location: "📍", warehouse: "🏬", season: "📅", lot: "🏷️", process: "🔁", department: "🏢", booking: "🛏️" };
/** Ô tìm mọi đối tượng: gõ tên → chọn → trang 360 (/xem/{type}/{id}) có đủ số liệu */
export function Search({ big }: { big?: boolean }) {
  const [q, setQ] = useState(""); const [hits, setHits] = useState<Hit[]>([]); const [open, setOpen] = useState(false); const t = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => { if (t.current) clearTimeout(t.current); if (q.trim().length < 1) { setHits([]); return; } t.current = setTimeout(() => { fetch(`/api/search?q=${encodeURIComponent(q)}`).then((r) => r.json()).then((j) => { setHits(j.rows ?? []); setOpen(true); }); }, 250); }, [q]);
  return (<div className={`relative ${big ? "" : "hidden md:block"}`}>
    <input className={big ? "input !text-lg" : "bg-green-900 text-white placeholder:text-green-300 rounded-lg px-3 py-1 text-sm w-48 lg:w-64"} placeholder="🔍 Tìm bò, ô, SKU, người…" value={q} onChange={(e) => setQ(e.target.value)} onFocus={() => hits.length && setOpen(true)} onBlur={() => setTimeout(() => setOpen(false), 200)} onKeyDown={(e) => { if (e.key === "Enter" && hits[0]) location.href = `/xem/${hits[0].type}/${encodeURIComponent(hits[0].id)}`; }} />
    {open && hits.length > 0 && <div className="absolute z-50 mt-1 w-[92vw] sm:w-[520px] max-h-[60vh] overflow-auto bg-white text-stone-900 rounded-2xl shadow-xl border">{hits.map((h) => <a key={h.type + h.id} href={`/xem/${h.type}/${encodeURIComponent(h.id)}`} className="flex items-center gap-2 px-3 py-2 border-b hover:bg-green-50 text-sm"><span>{ICON[h.type] ?? "•"}</span><span className="font-semibold">{h.title}</span><span className="text-xs text-stone-500 truncate">{h.sub}</span><span className="ml-auto text-[10px] uppercase text-stone-400">{h.type}</span></a>)}</div>}
  </div>);
}
''')
# Shell: zones + search + nav grouped
def shell(s):
    s = s.replace('import { Bell } from "@/components/panels/Notify";', 'import { Bell } from "@/components/panels/Notify";\nimport { Search } from "@/components/Search";', 1)
    zones = '''
/** KHU VỰC (phân khu UI cho dễ dùng): mỗi khu gom các màn liên quan; vai nào thấy khu nào */
export const ZONES: { key: string; icon: string; label: string; desc: string; roles: string[]; items: { href: string; label: string; roles?: string[] }[] }[] = [
  { key: "ca", icon: "📝", label: "Ghi chép hàng ngày", desc: "Việc của tôi, 3 chạm theo vị trí, phiếu giấy", roles: ["*"], items: [{ href: "/ca", label: "Ca của tôi" }, { href: "/giay", label: "Phiếu giấy" }, { href: "/sop", label: "SOP" }] },
  { key: "sx", icon: "🐄", label: "Sản xuất: đàn · ruộng · khu D · D5", desc: "Vật nuôi, canh tác, thú y, kế hoạch, sức khỏe đàn", roles: ["*"], items: [{ href: "/dan", label: "Đàn" }, { href: "/canh-tac", label: "Canh tác" }, { href: "/thu-y", label: "Thú y" }, { href: "/ke-hoach", label: "Kế hoạch" }, { href: "/suc-khoe", label: "Sức khỏe" }, { href: "/ktt", label: "KTT" }] },
  { key: "kho", icon: "🏬", label: "Kho · vật tư · mua hàng", desc: "9 kho, FEFO, ngày-tồn, kiểm kê, PO", roles: ["*"], items: [{ href: "/kho", label: "Kho" }, { href: "/thiet-bi", label: "Thiết bị" }, { href: "/truy-xuat", label: "Truy xuất" }] },
  { key: "kd", icon: "💰", label: "Kinh doanh · du lịch · XNK", desc: "Bán hàng, CRM, POS, nhận nuôi, lưu trú, tiệc, tour", roles: ["worker", "team_lead", "director", "owner", "accountant"], items: [{ href: "/ban-hang", label: "Bán hàng" }, { href: "/du-lich", label: "Du lịch" }, { href: "/quan-tri?t=trade_contracts", label: "XNK", roles: ["director", "owner"] }] },
  { key: "tc", icon: "📒", label: "Tài chính · nhân sự", desc: "Kế toán, P&L, KPI→lương, nhân sự", roles: ["director", "owner", "accountant", "auditor"], items: [{ href: "/ke-toan", label: "Kế toán" }, { href: "/nhan-su", label: "Nhân sự" }, { href: "/audit", label: "Xuất dữ liệu" }] },
  { key: "gs", icon: "📊", label: "Giám sát · số liệu · cảnh báo", desc: "Dashboard, biểu đồ mọi trường, đối soát, cảnh báo", roles: ["*"], items: [{ href: "/gd", label: "Dashboard GĐ", roles: ["director", "owner", "tech_head", "accountant"] }, { href: "/so-lieu", label: "Số liệu · biểu đồ" }, { href: "/canh-bao", label: "Cảnh báo" }, { href: "/doi-soat", label: "Đối soát" }] },
  { key: "qt", icon: "🏢", label: "Công ty · tổ chức · quy trình", desc: "Trại, phòng ban, quy trình, đối tượng, quản trị dữ liệu", roles: ["director", "owner", "it_engineer", "tech_head", "accountant", "auditor"], items: [{ href: "/hq", label: "Công ty · trại" }, { href: "/to-chuc", label: "Tổ chức · quy trình" }, { href: "/doi-tuong", label: "Đối tượng" }, { href: "/quan-tri", label: "Quản trị dữ liệu" }] },
];
'''
    s = s.replace("const NAV: Record<string,", zones + "\nconst NAV: Record<string,", 1)
    s = s.replace('<Link href="/" className="font-bold text-lg tracking-tight">ITRAN OS</Link>', '<Link href="/trang-chu" className="font-bold text-lg tracking-tight">ITRAN OS</Link>', 1)
    s = s.replace('          <div className="ml-auto flex items-center gap-2 text-sm">\n            <Bell />', '          <div className="ml-auto flex items-center gap-2 text-sm">\n            <Search />\n            <Bell />', 1)
    # nav: prepend home link
    s = s.replace('{nav.map((n) => <Link key={n.href}', '<Link href="/trang-chu" className={`px-3 py-1.5 rounded-lg text-sm whitespace-nowrap ${path === "/trang-chu" ? "bg-white text-green-900 font-semibold" : "text-green-100 hover:bg-green-700"}`}>🏠 Khu vực</Link>{nav.map((n) => <Link key={n.href}', 1)
    return s
rw("src/components/Shell.tsx", shell)
# ToChuc: add designer + coverage tabs + initial props
def tochuc(s):
    s = s.replace('import type { Sess } from "@/components/Shell";', 'import type { Sess } from "@/components/Shell";\nimport ProcessDesigner from "@/components/panels/ProcessDesigner";', 1)
    s = s.replace('export default function ToChuc({ sess }: { sess: Sess }) {', 'export default function ToChuc({ sess, initialTab, initialProcess }: { sess: Sess; initialTab?: string; initialProcess?: string }) {', 1)
    s = s.replace('const [tab, setTab] = useState<"sodo" | "quytrinh" | "io" | "bus" | "hoso">("sodo"); const [sel, setSel] = useState<string | null>(null); const [selP, setSelP] = useState<string | null>(null);', 'const [tab, setTab] = useState<"sodo" | "quytrinh" | "thietke" | "chay" | "io" | "bus" | "hoso" | "phu">((initialTab as "sodo") ?? "sodo"); const [sel, setSel] = useState<string | null>(null); const [selP, setSelP] = useState<string | null>(initialProcess ?? null); const cov = useData("process_coverage");', 1)
    s = s.replace('[["sodo", `Sơ đồ phòng ban (${D.length})`], ["quytrinh", `Quy trình A–Z (${P.length})`], ["io", "Đầu vào ↔ đầu ra"], ["bus", `Event bus (${T.length})`], ["hoso", `Danh mục hồ sơ (${RC.length})`]]', '[["sodo", `Phòng ban (${D.length})`], ["quytrinh", `Quy trình A–Z (${P.length})`], ["thietke", "🛠 Khai báo quy trình"], ["chay", "▶ Đang chạy"], ["phu", "Độ phủ theo đối tượng"], ["io", "Đầu vào ↔ đầu ra"], ["bus", `Event bus (${T.length})`], ["hoso", `Hồ sơ (${RC.length})`]]', 1)
    s = s.replace('      {tab === "io" && <div className="card p-0 overflow-auto">', '''      {tab === "thietke" && <ProcessDesigner sess={sess} initialCode={selP ?? undefined} />}
      {tab === "chay" && <ProcessDesigner sess={sess} tab="chay" />}
      {tab === "phu" && <div className="card p-0 overflow-auto"><div className="px-3 py-2 bg-stone-100 rounded-t-2xl font-bold">Kiểm kê quy trình theo ĐỐI TƯỢNG × mức phủ (DA_CO = có bảng + màn hình + form · MOT_PHAN = có bảng, dùng qua Quản trị DL · CHUA = chưa)</div><table className="tbl text-sm"><thead><tr><th className="pl-3">Đối tượng</th><th className="text-right">Đã có</th><th className="text-right">Một phần</th><th className="text-right">Chưa</th><th>Quy trình</th></tr></thead><tbody>{[...new Set(P.map((q) => String(q.object_type ?? "")))].map((o) => { const c = (cov.rows ?? []).filter((x) => x.object_type === o); const n = (k: string) => Number(c.find((x) => x.coverage === k)?.n ?? 0); return <tr key={o}><td className="pl-3 font-bold">{o}</td><td className="text-right text-green-700 font-bold">{n("DA_CO")}</td><td className="text-right text-amber-700">{n("MOT_PHAN")}</td><td className="text-right text-red-700">{n("CHUA")}</td><td className="text-xs">{P.filter((q) => q.object_type === o).map((q) => <button key={String(q.code)} className={`mr-1 underline ${q.coverage === "MOT_PHAN" ? "text-amber-700" : ""}`} onClick={() => { setSelP(String(q.code)); setTab("quytrinh"); }}>{String(q.code)}</button>)}</td></tr>; })}</tbody></table><div className="p-3 text-xs text-stone-600">Tổng {P.length} quy trình · thêm quy trình mới ở tab Khai báo (không cần lập trình).</div></div>}
      {tab === "io" && <div className="card p-0 overflow-auto">''', 1)
    # link "Chạy" button in process view
    s = s.replace('<div className="text-lg font-black">{String(p.name)} <span className="text-xs font-mono font-normal">{String(p.code)} · {String(p.kind)}</span></div>', '<div className="text-lg font-black flex items-center gap-2 flex-wrap">{String(p.name)} <span className="text-xs font-mono font-normal">{String(p.code)} · {String(p.kind)} · {String(p.status ?? "")} v{String(p.version ?? 1)}</span>{p.ui_path ? <a className="text-sm underline font-normal" href={String(p.ui_path)}>mở màn hình</a> : null}{canW && <button className="btn-secondary !py-1 !px-3 !text-sm font-normal" onClick={() => setTab("thietke")}>✎ Sửa bước / chạy</button>}</div>', 1)
    return s
rw("src/components/panels/ToChuc.tsx", tochuc)
# exports: crop-dossier + harvest-log
def exp(s):
    return s.replace('        case "recon": return csvRes(', '''        case "crop-dossier": {
          const season = u.searchParams.get("season"); const seasons = await q(season ? "select * from v_crop_dossier where farm_id=$1 and id=$2" : "select * from v_crop_dossier where farm_id=$1 order by sow_date desc", season ? [farm, season] : [farm]);
          const files: Record<string, string> = { "00_mua_vu.csv": csv(seasons) };
          for (const sn of seasons) { const sid = String(sn.id); const pid = String(sn.plot_id); const f0 = String(sn.sow_date ?? "2000-01-01"), t0 = String(sn.harvest_end ?? "2100-01-01");
            files[`${sn.code}/01_nhat_ky_ruong.csv`] = csv(await q("select ts, activity, variety, qty_kg, moisture_pct, machine_id, machine_hours, fuel_l, water_m3, chemical, phi_until, created_by, source, paper_serial from crop_logs where farm_id=$1 and plot_id=$2 and status='ACTIVE' and ts::date between $3 and $4 order by ts", [farm, pid, f0, t0]));
            files[`${sn.code}/02_vat_tu_phan_bvtv.csv`] = csv(await q("select ts, kind, sku, product_name, qty, unit, dose_per_ha, method, target_pest, phi_days, safe_after, weather, organic_allowed, applicator_id, created_by, lot_no from crop_inputs where farm_id=$1 and (season_id=$2 or (plot_id=$3 and ts::date between $4 and $5)) and status='ACTIVE' order by ts", [farm, sid, pid, f0, t0]));
            files[`${sn.code}/03_thu_hoach.csv`] = csv(await q("select ts, crop, variety, qty_kg, moisture_pct, grade, harvest_lot, dest_warehouse_id, phi_ok, residue_test, weigh_ticket_id, created_by from harvests where farm_id=$1 and (season_id=$2 or (plot_id=$3 and ts::date between $4 and $5)) and status='ACTIVE' order by ts", [farm, sid, pid, f0, t0]));
            files[`${sn.code}/04_mau_lab.csv`] = csv(await q("select * from lab_samples where farm_id=$1 and subject_ref in ($2,$3)", [farm, sid, pid]));
          }
          return zipRes(`nhat-ky-san-xuat-${farm}-${season ?? "tat-ca"}.zip`, files);
        }
        case "harvest-log": return csvRes(`thu-hoach-${farm}.csv`, await q("select h.ts, h.plot_id, p.name as plot, h.crop, h.variety, h.qty_kg, h.moisture_pct, h.grade, h.harvest_lot, h.dest_warehouse_id, h.phi_ok, h.created_by from harvests h left join plots p on p.id=h.plot_id where h.farm_id=$1 and h.status='ACTIVE' and h.ts::date between $2 and $3 order by h.ts", [farm, from, to]));
        case "recon": return csvRes(''', 1)
rw("src/app/api/exports/[kind]/route.ts", exp)
# nav additions
def nav(s):
    s = s.replace('tech_head: [{ href: "/ktt", label: "KTT" }, { href: "/quan-tri", label: "Danh mục" },', 'tech_head: [{ href: "/ktt", label: "KTT" }, { href: "/canh-tac", label: "Canh tác" }, { href: "/to-chuc", label: "Quy trình" },')
    s = s.replace('director: [{ href: "/gd", label: "GĐ" }, { href: "/quan-tri", label: "Quản trị DL" },', 'director: [{ href: "/gd", label: "GĐ" }, { href: "/to-chuc", label: "Tổ chức" }, { href: "/doi-tuong", label: "Đối tượng" }, { href: "/canh-tac", label: "Canh tác" }, { href: "/du-lich", label: "Du lịch" }, { href: "/quan-tri", label: "Quản trị DL" },')
    s = s.replace('owner: [{ href: "/hq", label: "Công ty" }, { href: "/quan-tri", label: "Quản trị DL" },', 'owner: [{ href: "/hq", label: "Công ty" }, { href: "/to-chuc", label: "Tổ chức" }, { href: "/doi-tuong", label: "Đối tượng" }, { href: "/quan-tri", label: "Quản trị DL" },')
    s = s.replace('worker: [{ href: "/ca", label: "Ca của tôi" }, { href: "/dan", label: "Đàn" }, { href: "/kho", label: "Kho" }, { href: "/giay", label: "Phiếu giấy" }],', 'worker: [{ href: "/ca", label: "Ca của tôi" }, { href: "/dan", label: "Đàn" }, { href: "/canh-tac", label: "Canh tác" }, { href: "/kho", label: "Kho" }, { href: "/ban-hang", label: "Bán/DL" }, { href: "/giay", label: "Phiếu giấy" }],')
    return s
rw("src/components/Shell.tsx", nav)
