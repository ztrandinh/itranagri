"use client";
import Link from "next/link";
import { useEffect, useState } from "react";
import { pending, onQueueChange, flush, type Queued, discard } from "@/lib/offline";
import { usePathname, useRouter } from "next/navigation";
import { Bell } from "@/components/panels/Notify";
import { Search } from "@/components/Search";

export type Sess = { staffId: string; staffName: string; role: string; position: string | null; farmId: string; farmIds: string[]; orgId: string };


/** KHU VỰC (phân khu UI cho dễ dùng): mỗi khu gom các màn liên quan; vai nào thấy khu nào */
export const ZONES: { key: string; icon: string; label: string; desc: string; roles: string[]; items: { href: string; label: string; roles?: string[] }[] }[] = [
  { key: "ca", icon: "📝", label: "Ghi chép hàng ngày", desc: "Việc của tôi, 3 chạm theo vị trí, phiếu giấy, phê duyệt", roles: ["*"], items: [{ href: "/ca", label: "Ca của tôi" }, { href: "/phe-duyet", label: "Phê duyệt", roles: ["team_lead", "tech_head", "director", "owner", "accountant"] }, { href: "/giay", label: "Phiếu giấy" }, { href: "/sop", label: "SOP" }] },
  { key: "sx", icon: "🐄", label: "Sản xuất: đàn · ruộng · khu D · D5", desc: "Vật nuôi, canh tác, thú y, kế hoạch, sức khỏe đàn", roles: ["*"], items: [{ href: "/dan", label: "Đàn" }, { href: "/canh-tac", label: "Canh tác" }, { href: "/che-bien", label: "Chế biến" }, { href: "/thu-y", label: "Thú y" }, { href: "/ke-hoach", label: "Kế hoạch" }, { href: "/suc-khoe", label: "Sức khỏe" }, { href: "/ktt", label: "KTT" }] },
  { key: "kho", icon: "🏬", label: "Kho · vật tư · mua hàng", desc: "9 kho, FEFO, ngày-tồn, kiểm kê, PO", roles: ["*"], items: [{ href: "/du-tru", label: "Dự trữ (dashboard)" }, { href: "/kho", label: "Kho" }, { href: "/khau-phan", label: "Khẩu phần tối ưu", roles: ["tech_head", "director", "owner"] }, { href: "/thiet-bi", label: "Thiết bị" }, { href: "/truy-xuat", label: "Truy xuất" }, { href: "/ban-do", label: "Bản đồ" }, { href: "/in-an", label: "In ấn" }] },
  { key: "kd", icon: "💰", label: "Kinh doanh · du lịch · XNK", desc: "Bán hàng, CRM, POS, nhận nuôi, lưu trú, tiệc, tour", roles: ["worker", "team_lead", "director", "owner", "accountant"], items: [{ href: "/ban-hang", label: "Bán hàng" }, { href: "/du-lich", label: "Du lịch" }, { href: "/xnk", label: "Xuất nhập khẩu", roles: ["director", "owner", "accountant"] }] },
  { key: "tc", icon: "📒", label: "Tài chính · nhân sự", desc: "Kế toán, P&L, KPI→lương, nhân sự", roles: ["director", "owner", "accountant", "auditor"], items: [{ href: "/ke-toan", label: "Kế toán" }, { href: "/nhan-su", label: "Nhân sự" }, { href: "/audit", label: "Xuất dữ liệu" }] },
  { key: "gs", icon: "📊", label: "Giám sát · số liệu · cảnh báo", desc: "Dashboard, biểu đồ mọi trường, đối soát, cảnh báo", roles: ["*"], items: [{ href: "/gd", label: "Dashboard GĐ", roles: ["director", "owner", "tech_head", "accountant"] }, { href: "/so-lieu", label: "Số liệu · biểu đồ" }, { href: "/canh-bao", label: "Cảnh báo" }, { href: "/doi-soat", label: "Đối soát" }, { href: "/tuan-thu", label: "Tuân thủ · chứng nhận", roles: ["director", "owner", "tech_head", "auditor", "it_engineer", "accountant"] }, { href: "/co2e", label: "CO2e", roles: ["director", "owner", "tech_head", "auditor"] }] },
  { key: "qt", icon: "🏢", label: "Công ty · tổ chức · quy trình", desc: "Trại, phòng ban, quy trình, đối tượng, quản trị dữ liệu", roles: ["director", "owner", "it_engineer", "tech_head", "accountant", "auditor"], items: [{ href: "/hq", label: "Công ty · trại" }, { href: "/to-chuc", label: "Tổ chức · quy trình" }, { href: "/doi-tuong", label: "Đối tượng" }, { href: "/rd", label: "R&D", roles: ["director", "owner", "tech_head"] }, { href: "/nhan-rong", label: "Nhân rộng", roles: ["director", "owner"] }, { href: "/quan-tri", label: "Quản trị dữ liệu" }, { href: "/huong-dan", label: "Hướng dẫn" }] },
];

const NAV: Record<string, { href: string; label: string }[]> = {
  worker: [{ href: "/ca", label: "Ca của tôi" }, { href: "/dan", label: "Đàn" }, { href: "/canh-tac", label: "Canh tác" }, { href: "/kho", label: "Kho" }, { href: "/ban-hang", label: "Bán/DL" }, { href: "/giay", label: "Phiếu giấy" }],
  team_lead: [{ href: "/ca", label: "Ca" }, { href: "/dan", label: "Đàn" }, { href: "/kho", label: "Kho" }, { href: "/giay", label: "Giấy" }, { href: "/canh-bao", label: "Cảnh báo" }],
  tech_head: [{ href: "/ktt", label: "KTT" }, { href: "/canh-tac", label: "Canh tác" }, { href: "/to-chuc", label: "Quy trình" }, { href: "/thu-y", label: "Thú y" }, { href: "/ke-hoach", label: "Kế hoạch" }, { href: "/dan", label: "Đàn" }, { href: "/kho", label: "Kho" }, { href: "/doi-soat", label: "Đối soát" }, { href: "/canh-bao", label: "Cảnh báo" }, { href: "/sop", label: "SOP" }, { href: "/so-lieu", label: "Số liệu" }, { href: "/ca", label: "Ghi" }],
  director: [{ href: "/gd", label: "GĐ" }, { href: "/to-chuc", label: "Tổ chức" }, { href: "/doi-tuong", label: "Đối tượng" }, { href: "/canh-tac", label: "Canh tác" }, { href: "/du-lich", label: "Du lịch" }, { href: "/quan-tri", label: "Quản trị DL" }, { href: "/ke-hoach", label: "Kế hoạch" }, { href: "/thu-y", label: "Thú y" }, { href: "/nhan-su", label: "Nhân sự" }, { href: "/thiet-bi", label: "Thiết bị" }, { href: "/ke-toan", label: "Kế toán" }, { href: "/dan", label: "Đàn" }, { href: "/kho", label: "Kho" }, { href: "/ban-hang", label: "Bán hàng" }, { href: "/doi-soat", label: "Đối soát" }, { href: "/canh-bao", label: "Cảnh báo" }, { href: "/so-lieu", label: "Số liệu" }, { href: "/sop", label: "SOP" }, { href: "/suc-khoe", label: "Sức khỏe" }, { href: "/audit", label: "Xuất DL" }],
  owner: [{ href: "/hq", label: "Công ty" }, { href: "/to-chuc", label: "Tổ chức" }, { href: "/doi-tuong", label: "Đối tượng" }, { href: "/quan-tri", label: "Quản trị DL" }, { href: "/gd", label: "Trại" }, { href: "/ke-toan", label: "Kế toán" }, { href: "/nhan-su", label: "Nhân sự" }, { href: "/dan", label: "Đàn" }, { href: "/kho", label: "Kho" }, { href: "/doi-soat", label: "Đối soát" }, { href: "/canh-bao", label: "Cảnh báo" }, { href: "/so-lieu", label: "Số liệu" }, { href: "/suc-khoe", label: "Sức khỏe" }, { href: "/audit", label: "Xuất DL" }],
  auditor: [{ href: "/audit", label: "Audit" }, { href: "/dan", label: "Đàn" }, { href: "/kho", label: "Kho" }, { href: "/doi-soat", label: "Đối soát" }, { href: "/giay", label: "Giấy" }, { href: "/so-lieu", label: "Số liệu" }, { href: "/suc-khoe", label: "Sức khỏe" }],
  accountant: [{ href: "/ke-toan", label: "Kế toán" }, { href: "/quan-tri", label: "Quản trị DL" }, { href: "/kho", label: "Kho" }, { href: "/ban-hang", label: "Bán hàng" }, { href: "/doi-soat", label: "Đối soát" }, { href: "/so-lieu", label: "Số liệu" }, { href: "/audit", label: "Xuất DL" }, { href: "/suc-khoe", label: "Sức khỏe" }],
  it_engineer: [{ href: "/quan-tri", label: "Quản trị DL" }, { href: "/hq", label: "Công ty" }, { href: "/thiet-bi", label: "Thiết bị" }, { href: "/ktt", label: "Hệ thống" }, { href: "/canh-bao", label: "Cảnh báo" }, { href: "/doi-soat", label: "Đối soát" }, { href: "/sop", label: "SOP" }, { href: "/ca", label: "Ghi" }],
};

export default function Shell({ sess, title, children }: { sess: Sess; title?: string; children: React.ReactNode }) {
  const [q, setQ] = useState<Queued[]>([]);
  const [online, setOnline] = useState(true);
  const [showQ, setShowQ] = useState(false);
  const path = usePathname();
  const router = useRouter();
  useEffect(() => {
    const upd = () => void pending().then(setQ);
    upd(); const off = onQueueChange(upd);
    setOnline(navigator.onLine);
    const on = () => setOnline(true), of = () => setOnline(false);
    window.addEventListener("online", on); window.addEventListener("offline", of);
    if ("serviceWorker" in navigator) navigator.serviceWorker.register("/sw.js").catch(() => {});
    return () => { off(); window.removeEventListener("online", on); window.removeEventListener("offline", of); };
  }, []);
  const nav = NAV[sess.role] ?? NAV.worker;
  const failed = q.filter((x) => x.last_error && x.tries > 0);
  const [side, setSide] = useState(false); const [collapsed, setCollapsed] = useState(false);
  useEffect(() => { setSide(false); }, [path]);
  useEffect(() => { try { setCollapsed(localStorage.getItem("itran.side") === "1"); } catch { /* */ } }, []);
  const zones = ZONES.filter((z) => z.roles.includes(sess.role) || z.roles.includes("*")).map((z) => ({ ...z, items: z.items.filter((i) => !i.roles || i.roles.includes(sess.role)) })).filter((z) => z.items.length);
  const isActive = (href: string) => { const h = href.split("?")[0]; return path === h || path.startsWith(h + "/"); };
  const SideNav = (
    <nav className="flex-1 overflow-y-auto py-2 text-[15px]">
      <Link href="/trang-chu" className={`mx-2 mb-1 flex items-center gap-2 rounded-lg px-3 py-2 ${path === "/trang-chu" ? "bg-emerald-600 text-white" : "text-slate-200 hover:bg-slate-800"}`}><span>🏠</span>{!collapsed && <span>Trang chủ · khu vực</span>}</Link>
      {zones.map((z) => <div key={z.key} className="mt-2">
        {!collapsed && <div className="px-4 pt-2 pb-1 text-[11px] font-bold uppercase tracking-wider text-slate-400">{z.icon} {z.label}</div>}
        {z.items.map((i) => <Link key={i.href} href={i.href} title={i.label} className={`mx-2 flex items-center gap-2 rounded-lg px-3 py-1.5 ${isActive(i.href) ? "bg-emerald-600 text-white font-semibold" : "text-slate-200 hover:bg-slate-800"}`}>{collapsed ? <span className="text-xs">{i.label.slice(0, 2)}</span> : <span>{i.label}</span>}</Link>)}
      </div>)}
      <div className="mt-3 border-t border-slate-800 pt-2">{nav.filter((n) => !zones.some((z) => z.items.some((i) => i.href.split("?")[0] === n.href))).map((n) => <Link key={n.href} href={n.href} className={`mx-2 flex items-center rounded-lg px-3 py-1.5 ${isActive(n.href) ? "bg-emerald-600 text-white" : "text-slate-300 hover:bg-slate-800"}`}>{collapsed ? n.label.slice(0, 2) : n.label}</Link>)}</div>
    </nav>);
  return (
    <div className="min-h-screen flex bg-slate-50 text-slate-900">
      <aside className={`hidden md:flex flex-col sticky top-0 h-screen bg-slate-900 text-slate-100 shrink-0 transition-all ${collapsed ? "w-16" : "w-60"}`}>
        <div className="flex items-center gap-2 px-3 h-14 border-b border-slate-800"><Link href="/trang-chu" className="font-black text-lg tracking-tight text-emerald-400">{collapsed ? "IT" : "ITRAN OS"}</Link><button className="ml-auto text-slate-400 hover:text-white" title="Thu gọn" onClick={() => { const v = !collapsed; setCollapsed(v); try { localStorage.setItem("itran.side", v ? "1" : "0"); } catch { /* */ } }}>{collapsed ? "»" : "«"}</button></div>
        {SideNav}
        <div className="border-t border-slate-800 p-3 text-xs text-slate-400">{!collapsed && <><div className="font-semibold text-slate-200 truncate">{sess.staffName}</div><div className="truncate">{sess.position ?? sess.role} · {sess.farmId}</div><div className="mt-1 flex gap-3"><Link href="/tai-khoan" className="hover:text-white">Tài khoản</Link><button className="hover:text-white" onClick={async () => { await fetch("/api/auth/logout", { method: "POST" }); window.location.href = "/login"; }}>Thoát</button></div></>}</div>
      </aside>
      {side && <div className="fixed inset-0 z-40 md:hidden" onClick={() => setSide(false)}><div className="absolute inset-0 bg-black/40" /><aside className="absolute left-0 top-0 h-full w-72 bg-slate-900 text-slate-100 flex flex-col" onClick={(e) => e.stopPropagation()}><div className="flex items-center px-4 h-14 border-b border-slate-800 font-black text-emerald-400">ITRAN OS<button className="ml-auto text-slate-400" onClick={() => setSide(false)}>✕</button></div>{SideNav}</aside></div>}
      <div className="flex-1 flex flex-col min-w-0">
        <header className="sticky top-0 z-20 h-14 bg-white/90 backdrop-blur border-b border-slate-200 flex items-center gap-3 px-3">
          <button className="md:hidden text-2xl" onClick={() => setSide(true)} aria-label="Menu">☰</button>
          <span className="md:hidden font-black text-emerald-700">ITRAN OS</span>
          {sess.farmIds.length > 1 ? (
            <select className="rounded-lg border border-slate-300 bg-white text-sm px-2 py-1 font-semibold" value={sess.farmId}
              onChange={async (e) => { await fetch("/api/auth/switch-farm", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ farm_id: e.target.value }) }); router.refresh(); window.location.reload(); }}>
              {sess.farmIds.map((f) => <option key={f} value={f}>Trại {f}</option>)}
            </select>) : <span className="hidden sm:inline text-sm font-semibold text-slate-600">Trại {sess.farmId}</span>}
          <div className="ml-auto flex items-center gap-2 text-sm">
            <Search />
            <Bell />
            <button onClick={() => setShowQ(!showQ)} className={`rounded-full px-2.5 py-1 text-xs font-semibold ${!online ? "bg-amber-400 text-black" : q.length ? "bg-amber-200 text-amber-900" : "bg-emerald-100 text-emerald-800"}`} title="Hàng đợi đồng bộ">
              {online ? (q.length ? `⏳ ${q.length}` : "✓ đồng bộ") : `📴 offline ${q.length}`}
            </button>
            <span className="hidden lg:inline text-slate-600">{sess.staffName}</span>
          </div>
        </header>
      {showQ && (
        <div className="bg-amber-50 border-b border-amber-200 text-sm">
          <div className="max-w-[1400px] mx-auto px-3 py-2">
            <div className="flex items-center gap-3"><b>Hàng đợi: {q.length}</b> <button className="underline" onClick={() => void flush()}>Đồng bộ ngay</button> {failed.length > 0 && <span className="text-red-700">{failed.length} bản ghi bị từ chối — cần sửa</span>}</div>
            <ul className="mt-1 max-h-48 overflow-auto">{q.map((x) => <li key={x.key} className="flex gap-2 py-0.5 border-t border-amber-100"><span className="font-mono text-xs">{x.table}</span><span className="truncate flex-1">{JSON.stringify(x.event).slice(0, 90)}</span>{x.last_error && <span className="text-red-700 text-xs">{x.last_error.slice(0, 60)}</span>}{x.last_error && <button className="text-xs underline" onClick={() => discard(x.key)}>bỏ</button>}</li>)}</ul>
          </div>
        </div>)}
        <main className="flex-1 w-full max-w-[1400px] mx-auto px-3 md:px-6 py-4">
          {title && <h1 className="text-xl md:text-2xl font-bold mb-3 text-slate-800">{title}</h1>}
          {children}
        </main>
        <footer className="text-center text-xs text-slate-400 py-3">ITRAN FARM · "Một vòng tròn — không gì bị bỏ đi" · người tạo bản ghi, máy viết báo cáo</footer>
      </div>
    </div>
  );
}
