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
  { key: "ca", icon: "📝", label: "Ghi chép hàng ngày", desc: "Việc của tôi, 3 chạm theo vị trí, phiếu giấy", roles: ["*"], items: [{ href: "/ca", label: "Ca của tôi" }, { href: "/giay", label: "Phiếu giấy" }, { href: "/sop", label: "SOP" }] },
  { key: "sx", icon: "🐄", label: "Sản xuất: đàn · ruộng · khu D · D5", desc: "Vật nuôi, canh tác, thú y, kế hoạch, sức khỏe đàn", roles: ["*"], items: [{ href: "/dan", label: "Đàn" }, { href: "/canh-tac", label: "Canh tác" }, { href: "/thu-y", label: "Thú y" }, { href: "/ke-hoach", label: "Kế hoạch" }, { href: "/suc-khoe", label: "Sức khỏe" }, { href: "/ktt", label: "KTT" }] },
  { key: "kho", icon: "🏬", label: "Kho · vật tư · mua hàng", desc: "9 kho, FEFO, ngày-tồn, kiểm kê, PO", roles: ["*"], items: [{ href: "/kho", label: "Kho" }, { href: "/thiet-bi", label: "Thiết bị" }, { href: "/truy-xuat", label: "Truy xuất" }] },
  { key: "kd", icon: "💰", label: "Kinh doanh · du lịch · XNK", desc: "Bán hàng, CRM, POS, nhận nuôi, lưu trú, tiệc, tour", roles: ["worker", "team_lead", "director", "owner", "accountant"], items: [{ href: "/ban-hang", label: "Bán hàng" }, { href: "/du-lich", label: "Du lịch" }, { href: "/quan-tri?t=trade_contracts", label: "XNK", roles: ["director", "owner"] }] },
  { key: "tc", icon: "📒", label: "Tài chính · nhân sự", desc: "Kế toán, P&L, KPI→lương, nhân sự", roles: ["director", "owner", "accountant", "auditor"], items: [{ href: "/ke-toan", label: "Kế toán" }, { href: "/nhan-su", label: "Nhân sự" }, { href: "/audit", label: "Xuất dữ liệu" }] },
  { key: "gs", icon: "📊", label: "Giám sát · số liệu · cảnh báo", desc: "Dashboard, biểu đồ mọi trường, đối soát, cảnh báo", roles: ["*"], items: [{ href: "/gd", label: "Dashboard GĐ", roles: ["director", "owner", "tech_head", "accountant"] }, { href: "/so-lieu", label: "Số liệu · biểu đồ" }, { href: "/canh-bao", label: "Cảnh báo" }, { href: "/doi-soat", label: "Đối soát" }] },
  { key: "qt", icon: "🏢", label: "Công ty · tổ chức · quy trình", desc: "Trại, phòng ban, quy trình, đối tượng, quản trị dữ liệu", roles: ["director", "owner", "it_engineer", "tech_head", "accountant", "auditor"], items: [{ href: "/hq", label: "Công ty · trại" }, { href: "/to-chuc", label: "Tổ chức · quy trình" }, { href: "/doi-tuong", label: "Đối tượng" }, { href: "/quan-tri", label: "Quản trị dữ liệu" }] },
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
  return (
    <div className="min-h-screen flex flex-col">
      <header className="sticky top-0 z-20 bg-green-800 text-white shadow">
        <div className="max-w-5xl mx-auto px-3 py-2 flex items-center gap-3">
          <Link href="/trang-chu" className="font-bold text-lg tracking-tight">ITRAN OS</Link>
          <span className="text-green-200 text-sm">{sess.farmId}</span>
          {sess.farmIds.length > 1 && (
            <select className="bg-green-900 text-white text-sm rounded px-2 py-1" value={sess.farmId}
              onChange={async (e) => { await fetch("/api/auth/switch-farm", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ farm_id: e.target.value }) }); router.refresh(); window.location.reload(); }}>
              {sess.farmIds.map((f) => <option key={f} value={f}>{f}</option>)}
            </select>)}
          <div className="ml-auto flex items-center gap-2 text-sm">
            <Search />
            <Bell />
            <button onClick={() => setShowQ(!showQ)} className={`rounded-full px-2.5 py-0.5 font-semibold ${!online ? "bg-amber-400 text-black" : q.length ? "bg-amber-300 text-black" : "bg-green-600"}`} title="Hàng đợi đồng bộ">
              {online ? (q.length ? `⏳ ${q.length}` : "✓ đồng bộ") : `📴 offline ${q.length}`}
            </button>
            <span className="hidden sm:inline">{sess.staffName} · {sess.position ?? sess.role}</span>
            <Link href="/tai-khoan" className="underline">Tài khoản</Link>
            <button className="underline" onClick={async () => { await fetch("/api/auth/logout", { method: "POST" }); window.location.href = "/login"; }}>Thoát</button>
          </div>
        </div>
        <nav className="max-w-5xl mx-auto px-2 flex gap-1 overflow-x-auto pb-1">
          <Link href="/trang-chu" className={`px-3 py-1.5 rounded-lg text-sm whitespace-nowrap ${path === "/trang-chu" ? "bg-white text-green-900 font-semibold" : "text-green-100 hover:bg-green-700"}`}>🏠 Khu vực</Link>{nav.map((n) => <Link key={n.href} href={n.href} className={`px-3 py-1.5 rounded-lg text-sm whitespace-nowrap ${path.startsWith(n.href) ? "bg-white text-green-900 font-semibold" : "text-green-100 hover:bg-green-700"}`}>{n.label}</Link>)}
        </nav>
      </header>
      {showQ && (
        <div className="bg-amber-50 border-b border-amber-200 text-sm">
          <div className="max-w-5xl mx-auto px-3 py-2">
            <div className="flex items-center gap-3"><b>Hàng đợi: {q.length}</b> <button className="underline" onClick={() => void flush()}>Đồng bộ ngay</button> {failed.length > 0 && <span className="text-red-700">{failed.length} bản ghi bị từ chối — cần sửa</span>}</div>
            <ul className="mt-1 max-h-48 overflow-auto">{q.map((x) => <li key={x.key} className="flex gap-2 py-0.5 border-t border-amber-100"><span className="font-mono text-xs">{x.table}</span><span className="truncate flex-1">{JSON.stringify(x.event).slice(0, 90)}</span>{x.last_error && <span className="text-red-700 text-xs">{x.last_error.slice(0, 60)}</span>}{x.last_error && <button className="text-xs underline" onClick={() => discard(x.key)}>bỏ</button>}</li>)}</ul>
          </div>
        </div>)}
      <main className="flex-1 max-w-5xl w-full mx-auto px-3 py-4">
        {title && <h1 className="text-2xl font-bold mb-3">{title}</h1>}
        {children}
      </main>
      <footer className="text-center text-xs text-stone-500 py-3">ITRAN FARM · "Một vòng tròn — không gì bị bỏ đi" · người tạo bản ghi, máy viết báo cáo</footer>
    </div>
  );
}
