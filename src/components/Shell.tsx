"use client";
import Link from "next/link";
import { useEffect, useState } from "react";
import { pending, onQueueChange, flush, type Queued, discard } from "@/lib/offline";
import { usePathname, useRouter } from "next/navigation";

export type Sess = { staffId: string; staffName: string; role: string; position: string | null; farmId: string; farmIds: string[]; orgId: string };

const NAV: Record<string, { href: string; label: string }[]> = {
  worker: [{ href: "/ca", label: "Ca của tôi" }, { href: "/dan", label: "Đàn" }, { href: "/kho", label: "Kho" }, { href: "/giay", label: "Phiếu giấy" }],
  team_lead: [{ href: "/ca", label: "Ca" }, { href: "/dan", label: "Đàn" }, { href: "/kho", label: "Kho" }, { href: "/giay", label: "Giấy" }, { href: "/canh-bao", label: "Cảnh báo" }],
  tech_head: [{ href: "/ktt", label: "KTT" }, { href: "/dan", label: "Đàn" }, { href: "/kho", label: "Kho" }, { href: "/doi-soat", label: "Đối soát" }, { href: "/canh-bao", label: "Cảnh báo" }, { href: "/sop", label: "SOP" }, { href: "/so-lieu", label: "Số liệu" }, { href: "/ca", label: "Ghi" }],
  director: [{ href: "/gd", label: "GĐ" }, { href: "/dan", label: "Đàn" }, { href: "/kho", label: "Kho" }, { href: "/ban-hang", label: "Bán hàng" }, { href: "/doi-soat", label: "Đối soát" }, { href: "/canh-bao", label: "Cảnh báo" }, { href: "/so-lieu", label: "Số liệu" }, { href: "/sop", label: "SOP" }, { href: "/suc-khoe", label: "Sức khỏe" }, { href: "/audit", label: "Xuất DL" }],
  owner: [{ href: "/hq", label: "Công ty" }, { href: "/gd", label: "Trại" }, { href: "/dan", label: "Đàn" }, { href: "/kho", label: "Kho" }, { href: "/doi-soat", label: "Đối soát" }, { href: "/canh-bao", label: "Cảnh báo" }, { href: "/so-lieu", label: "Số liệu" }, { href: "/suc-khoe", label: "Sức khỏe" }, { href: "/audit", label: "Xuất DL" }],
  auditor: [{ href: "/audit", label: "Audit" }, { href: "/dan", label: "Đàn" }, { href: "/kho", label: "Kho" }, { href: "/doi-soat", label: "Đối soát" }, { href: "/giay", label: "Giấy" }, { href: "/so-lieu", label: "Số liệu" }, { href: "/suc-khoe", label: "Sức khỏe" }],
  accountant: [{ href: "/kho", label: "Kho" }, { href: "/ban-hang", label: "Bán hàng" }, { href: "/doi-soat", label: "Đối soát" }, { href: "/so-lieu", label: "Số liệu" }, { href: "/audit", label: "Xuất DL" }, { href: "/suc-khoe", label: "Sức khỏe" }],
  it_engineer: [{ href: "/ktt", label: "Hệ thống" }, { href: "/canh-bao", label: "Cảnh báo" }, { href: "/doi-soat", label: "Đối soát" }, { href: "/sop", label: "SOP" }, { href: "/ca", label: "Ghi" }],
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
          <Link href="/" className="font-bold text-lg tracking-tight">ITRAN OS</Link>
          <span className="text-green-200 text-sm">{sess.farmId}</span>
          {sess.farmIds.length > 1 && (
            <select className="bg-green-900 text-white text-sm rounded px-2 py-1" value={sess.farmId}
              onChange={async (e) => { await fetch("/api/auth/switch-farm", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ farm_id: e.target.value }) }); router.refresh(); window.location.reload(); }}>
              {sess.farmIds.map((f) => <option key={f} value={f}>{f}</option>)}
            </select>)}
          <div className="ml-auto flex items-center gap-2 text-sm">
            <button onClick={() => setShowQ(!showQ)} className={`rounded-full px-2.5 py-0.5 font-semibold ${!online ? "bg-amber-400 text-black" : q.length ? "bg-amber-300 text-black" : "bg-green-600"}`} title="Hàng đợi đồng bộ">
              {online ? (q.length ? `⏳ ${q.length}` : "✓ đồng bộ") : `📴 offline ${q.length}`}
            </button>
            <span className="hidden sm:inline">{sess.staffName} · {sess.position ?? sess.role}</span>
            <Link href="/tai-khoan" className="underline">Tài khoản</Link>
            <button className="underline" onClick={async () => { await fetch("/api/auth/logout", { method: "POST" }); window.location.href = "/login"; }}>Thoát</button>
          </div>
        </div>
        <nav className="max-w-5xl mx-auto px-2 flex gap-1 overflow-x-auto pb-1">
          {nav.map((n) => <Link key={n.href} href={n.href} className={`px-3 py-1.5 rounded-lg text-sm whitespace-nowrap ${path.startsWith(n.href) ? "bg-white text-green-900 font-semibold" : "text-green-100 hover:bg-green-700"}`}>{n.label}</Link>)}
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
