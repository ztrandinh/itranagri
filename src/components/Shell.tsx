"use client";
import { MODULES, DEPT_HOME } from "@/lib/modules";
import Link from "next/link";
import { useEffect, useState } from "react";
import { pending, onQueueChange, flush, type Queued, discard } from "@/lib/offline";
import { usePathname, useRouter } from "next/navigation";
import { Bell } from "@/components/panels/Notify";
import { Search } from "@/components/Search";
import { Toaster } from "@/components/ui/Toast";
import { ThemeToggle, ThemeBoot } from "@/components/ui/ThemeToggle";
import { BottomNav } from "@/components/ui/BottomNav";
import { SunToggle, SunBoot } from "@/components/ui/SunMode";
import { CommandPalette } from "@/components/ui/CommandPalette";

/** `account` = mã CHỖ NGỒI bất biến (job_accounts.code, vd KTCN-A-03); `positionCode` = mã NGHỀ
 *  trong danh mục (A1…A18, T01…, K01…). Bộ form và việc giao xuống bám hai mã này, không bám
 *  chức danh tự do (`position`) vốn mỗi người viết một kiểu. */
export type Sess = { staffId: string; staffName: string; role: string; position: string | null; dept?: string | null; farmId: string; farmIds: string[]; orgId: string; account?: string | null; positionCode?: string | null };


/** KHU VỰC (phân khu UI cho dễ dùng): mỗi khu gom các màn liên quan; vai nào thấy khu nào */
export const ZONES: { key: string; icon: string; label: string; desc: string; dept?: string; roles: string[]; items: { href: string; label: string; roles?: string[] }[] }[] = [
  { key: "me", icon: "📝", label: "Của tôi", desc: "Việc trong ca, ghi 3 chạm theo vị trí, phê duyệt, phiếu giấy, in biểu mẫu", roles: ["*"], items: [{ href: "/ca", label: "Ca của tôi" }, { href: "/phe-duyet", label: "Phê duyệt", roles: ["team_lead", "tech_head", "director", "owner", "accountant"] }, { href: "/giay", label: "Phiếu giấy ↔ số" }, { href: "/in-an", label: "In biểu mẫu · nhãn · báo cáo" }, { href: "/huong-dan", label: "Hướng dẫn theo vai" }, { href: "/tai-khoan", label: "Tài khoản & thiết bị" }] },
  { key: "dh", icon: "🎯", label: "Điều hành & Kế hoạch", desc: "HĐQT · Ban GĐ · GĐ trại: kế hoạch S&OP, bảng điều hành, điều hành ca, giám sát (tuyến 2, công ty mẹ), cảnh báo, đa trại", dept: "BGD", roles: ["*"], items: [{ href: "/trang-chu", label: "Trang chủ khu vực" }, { href: "/ke-hoach", label: "Kế hoạch (Năm → S&OP tháng)", roles: ["team_lead", "tech_head", "director", "owner", "accountant", "auditor", "it_engineer"] }, { href: "/gd", label: "Bảng điều hành GĐ trại", roles: ["director", "owner", "tech_head", "accountant"] }, { href: "/ktt", label: "Điều hành ca (KTT)", roles: ["team_lead", "tech_head", "director", "owner"] }, { href: "/giam-sat", label: "Giám sát & kế thừa (tổ GS công ty mẹ)", roles: ["team_lead", "tech_head", "director", "owner", "auditor", "it_engineer", "accountant"] }, { href: "/canh-bao", label: "Cảnh báo & luật" }, { href: "/hq", label: "Công ty mẹ · đa trại", roles: ["owner", "director", "auditor", "it_engineer", "accountant"] }] },
  { key: "cn", icon: "🐄", label: "Chăn nuôi – Thú y", desc: "Đàn bò/dê/gà/thủy sản: định danh, sinh sản, cân, việc đàn; thú y, vaccine, ngưng thuốc, dịch tễ", dept: "KTCN", roles: ["*"], items: [{ href: "/dan", label: "Đàn (cá thể · lô · nhóm · việc đàn)" }, { href: "/thu-y", label: "Thú y & sức khỏe đàn" }] },
  { key: "tt", icon: "🌾", label: "Trồng trọt – Sinh khối", desc: "Cỏ, bắp, lúa, rau: mùa vụ, vật tư PHI, tưới, đất, IPM, luân canh, giá thành ô", dept: "TT", roles: ["*"], items: [{ href: "/canh-tac", label: "Canh tác" }, { href: "/ban-do", label: "Bản đồ ô thửa" }] },
  { key: "sh", icon: "♻", label: "Sinh học tuần hoàn (khu D)", desc: "Trùn, BSF, biogas, compost/biochar, IMO/EM, anolyte, phát thải", dept: "SH", roles: ["*"], items: [{ href: "/sinh-hoc", label: "Sinh học tuần hoàn" }, { href: "/co2e", label: "Phát thải & tuần hoàn (CO2e)", roles: ["director", "owner", "tech_head", "auditor", "team_lead"] }] },
  { key: "d5", icon: "🏭", label: "Xưởng thức ăn D5 & Chế biến", desc: "TMR/viên cho đàn (D5); sơ chế – sấy – đóng gói – nhãn – tem QR (chế biến thực phẩm)", dept: "D5", roles: ["*"], items: [{ href: "/che-bien", label: "D5 & Chế biến" }, { href: "/khau-phan", label: "Khẩu phần tối ưu (LP)", roles: ["tech_head", "director", "owner", "team_lead"] }] },
  { key: "ccu", icon: "🏬", label: "Chuỗi cung ứng – Kho – Mua hàng", desc: "Dự trữ, 9 kho + kho công cụ, bin, kiểm kê, vận tải, mua hàng/PO/NCC", dept: "CCU", roles: ["*"], items: [{ href: "/du-tru", label: "Dự trữ (dashboard)" }, { href: "/kho", label: "Kho & vận tải" }, { href: "/mua-hang", label: "Mua hàng" }] },
  { key: "kdm", icon: "💰", label: "Kinh doanh – Marketing – CSKH", desc: "Bán 5 kênh, báo giá, hợp đồng, khách, điểm, công nợ, POS · marketing, lịch nội dung, thương hiệu, khủng hoảng truyền thông", dept: "KDM", roles: ["worker", "team_lead", "director", "owner", "accountant", "tech_head"], items: [{ href: "/ban-hang", label: "Kinh doanh (bán hàng · CRM · POS · công nợ)" }, { href: "/marketing", label: "Marketing – Truyền thông" }] },
  { key: "dl", icon: "🏨", label: "Du lịch – Lưu trú – Ẩm thực", desc: "Booking, phòng, tiệc/MICE, tour, dịch vụ, công suất", dept: "DL", roles: ["worker", "team_lead", "director", "owner", "accountant"], items: [{ href: "/du-lich", label: "Du lịch" }] },
  { key: "xnk", icon: "🌏", label: "Xuất nhập khẩu", desc: "Thị trường, hợp đồng ngoại, chứng từ, hải quan, landed cost", dept: "XNK", roles: ["director", "owner", "accountant", "tech_head"], items: [{ href: "/xnk", label: "Xuất nhập khẩu" }] },
  { key: "tckt", icon: "📒", label: "Tài chính – Kế toán", desc: "GL kép, chi, lương, TSCĐ, AP/AR, vay, bảo hiểm, GTGT, dòng tiền, hợp nhất", dept: "TCKT", roles: ["director", "owner", "accountant", "auditor"], items: [{ href: "/ke-toan", label: "Kế toán" }, { href: "/audit", label: "Kiểm toán · xuất dữ liệu" }] },
  { key: "hcns", icon: "👥", label: "Hành chính – Nhân sự – Đào tạo", desc: "Hồ sơ, chấm công, đào tạo tuần, năng lực, thưởng gắn lương", dept: "HCNS", roles: ["team_lead", "tech_head", "director", "owner", "accountant", "it_engineer"], items: [{ href: "/nhan-su", label: "Nhân sự & đào tạo & thưởng" }] },
  { key: "qa", icon: "✅", label: "Chất lượng – Tuân thủ", desc: "Tuân thủ tiêu chuẩn/chứng nhận (tuyến 3), truy xuất & thu hồi, đối soát dữ liệu", dept: "QA", roles: ["team_lead", "tech_head", "director", "owner", "auditor", "it_engineer", "accountant"], items: [{ href: "/tuan-thu", label: "Tuân thủ & chứng nhận" }, { href: "/truy-xuat", label: "Truy xuất & thu hồi" }, { href: "/doi-soat", label: "Đối soát dữ liệu (RC)" }] },
  { key: "cntb", icon: "🔧", label: "Công nghệ – Thiết bị – Dữ liệu", desc: "Thiết bị/IoT, số liệu & biểu đồ, chất lượng dữ liệu, sơ đồ, quản trị dữ liệu", dept: "CNTB", roles: ["*"], items: [{ href: "/thiet-bi", label: "Thiết bị & IoT" }, { href: "/so-lieu", label: "Số liệu & biểu đồ mọi trường" }, { href: "/suc-khoe", label: "Chất lượng dữ liệu (7 bộ chất vấn)", roles: ["tech_head", "director", "owner", "auditor", "it_engineer", "accountant"] }, { href: "/so-do", label: "Sơ đồ khu · chuồng · vị trí" }, { href: "/quan-tri", label: "Quản trị dữ liệu", roles: ["director", "owner", "it_engineer", "tech_head", "accountant", "auditor", "team_lead"] }] },
  { key: "rd", icon: "🧪", label: "R&D · Nhân rộng – Nhượng quyền", desc: "Đề tài, đối chứng, tri thức; gói mẫu trại, chuyển giao", dept: "RD", roles: ["director", "owner", "tech_head", "it_engineer"], items: [{ href: "/rd", label: "R&D" }, { href: "/nhan-rong", label: "Nhân rộng · nhượng quyền", roles: ["director", "owner"] }] },
  { key: "tc", icon: "🏢", label: "Tổ chức – Quy trình – Danh mục", desc: "Phòng ban, quy trình A–Z, thư viện SOP, event bus, định nghĩa đối tượng", dept: "HCNS", roles: ["*"], items: [{ href: "/to-chuc", label: "Tổ chức · quy trình · SOP" }, { href: "/doi-tuong", label: "Danh mục đối tượng (định nghĩa)" }] },
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
  const nav = [...(sess.dept && DEPT_HOME[sess.dept] ? [{ href: DEPT_HOME[sess.dept], label: "Phòng tôi" }] : []), ...(NAV[sess.role] ?? NAV.worker)].filter((v, i, a) => a.findIndex((x) => x.href === v.href) === i).slice(0, 6);
  const failed = q.filter((x) => x.last_error && x.tries > 0);
  const [side, setSide] = useState(false); const [collapsed, setCollapsed] = useState(false);
  useEffect(() => { setSide(false); }, [path]);
  useEffect(() => { try { setCollapsed(localStorage.getItem("itran.side") === "1"); } catch { /* */ } }, []);
  const myDept = sess.dept ?? ""; const zonesRaw = ZONES.filter((z) => z.roles.includes(sess.role) || z.roles.includes("*")).map((z) => ({ ...z, items: z.items.filter((i) => !i.roles || i.roles.includes(sess.role)) })).filter((z) => z.items.length);
  const rank = (z: (typeof zonesRaw)[number]) => z.key === "me" ? 0 : (myDept && z.dept === myDept ? 1 : 2);
  const zonesSorted = [...zonesRaw].sort((a, b) => rank(a) - rank(b));
  // CÔNG NHÂN chỉ thấy khu của MÌNH. Trước đây menu bày trọn mọi khu cho mọi vai, nên công nhân
  // trộn TMR mở máy ra thấy cả "Canh tác", "Bản đồ ô thửa", "Thú y", "Cảnh báo & luật" — thứ họ
  // không có quyền lẫn việc gì để làm. Menu dài thì họ ngừng đọc menu.
  // KHÔNG xoá khu nào: gói phần còn lại sau nút "Xem thêm", bấm là hiện đủ như cũ.
  const [xemHet, setXemHet] = useState(false);
  const chiKhuCuaToi = sess.role === "worker" && !!myDept;
  const zones = chiKhuCuaToi && !xemHet ? zonesSorted.filter((z) => z.key === "me" || z.dept === myDept || !z.dept) : zonesSorted;
  const soKhuAn = zonesSorted.length - zones.length;
  const isActive = (href: string) => { const h = href.split("?")[0]; return path === h || path.startsWith(h + "/"); };
  const SideNav = (
    <nav className="flex-1 overflow-y-auto py-2 text-[15px]">
      <Link href="/trang-chu" className={`mx-2 mb-1 flex items-center gap-2 rounded-lg px-3 py-2 ${path === "/trang-chu" ? "bg-emerald-600 text-white" : "text-slate-200 hover:bg-slate-800"}`}><span>🏠</span>{!collapsed && <span>Trang chủ · khu vực</span>}</Link>
      {zones.map((z) => <div key={z.key} className="mt-2">
        {!collapsed && <div className="px-4 pt-2 pb-1 text-[11px] font-bold uppercase tracking-wider text-slate-400" title={z.desc}>{z.icon} {z.label}{myDept && z.dept === myDept ? <span className="ml-1 rounded bg-emerald-700 text-white px-1 normal-case">phòng tôi</span> : null}</div>}
        {z.items.map((i) => <Link key={i.href} href={i.href} title={MODULES[i.href.split("?")[0]]?.purpose ?? i.label} className={`mx-2 flex items-center gap-2 rounded-lg px-3 py-1.5 ${isActive(i.href) ? "bg-emerald-600 text-white font-semibold" : "text-slate-200 hover:bg-slate-800"}`}>{collapsed ? <span className="text-xs">{i.label.slice(0, 2)}</span> : <span>{i.label}</span>}</Link>)}
      </div>)}
      {chiKhuCuaToi && !collapsed && (soKhuAn > 0 || xemHet) && (
        <button className="mx-2 mt-2 w-[calc(100%-1rem)] rounded-lg px-3 py-1.5 text-left text-xs text-slate-400 hover:bg-slate-800"
          onClick={() => setXemHet(!xemHet)}>
          {xemHet ? "▾ Thu gọn — chỉ hiện phòng tôi" : `▸ Xem thêm ${soKhuAn} khu khác của trại`}
        </button>)}
      <div className="mt-3 border-t border-slate-800 pt-2">{nav.filter((n) => !zones.some((z) => z.items.some((i) => i.href.split("?")[0] === n.href))).map((n) => <Link key={n.href} href={n.href} className={`mx-2 flex items-center rounded-lg px-3 py-1.5 ${isActive(n.href) ? "bg-emerald-600 text-white" : "text-slate-300 hover:bg-slate-800"}`}>{collapsed ? n.label.slice(0, 2) : n.label}</Link>)}</div>
    </nav>);
  return (
    <div className="min-h-screen flex bg-slate-50 text-slate-900">
      <Toaster />
      <ThemeBoot />
      <SunBoot />
      <CommandPalette />
      <a href="#main" className="ui-skip">Tới nội dung chính</a>
      <aside className={`hidden md:flex flex-col sticky top-0 h-screen bg-slate-900 text-slate-100 shrink-0 transition-all ${collapsed ? "w-16" : "w-60"}`}>
        <div className="flex items-center gap-2 px-3 h-14 border-b border-slate-800"><Link href="/trang-chu" className="font-black text-lg tracking-tight text-emerald-400">{collapsed ? "IT" : "ITRAN AGRI"}</Link><button className="ml-auto text-slate-400 hover:text-white" title="Thu gọn" onClick={() => { const v = !collapsed; setCollapsed(v); try { localStorage.setItem("itran.side", v ? "1" : "0"); } catch { /* */ } }}>{collapsed ? "»" : "«"}</button></div>
        {SideNav}
        <div className="border-t border-slate-800 p-3 text-xs text-slate-400">{!collapsed && <><div className="font-semibold text-slate-200 truncate">{sess.staffName}</div><div className="truncate">{sess.position ?? sess.role} · {sess.farmId}</div><div className="mt-1 flex gap-3"><Link href="/tai-khoan" className="hover:text-white">Tài khoản</Link><button className="hover:text-white" onClick={async () => { await fetch("/api/auth/logout", { method: "POST" }); window.location.href = "/login"; }}>Thoát</button></div></>}</div>
      </aside>
      {side && <div className="fixed inset-0 z-40 md:hidden" onClick={() => setSide(false)}><div className="absolute inset-0 bg-black/40" /><aside className="absolute left-0 top-0 h-full w-72 bg-slate-900 text-slate-100 flex flex-col" onClick={(e) => e.stopPropagation()}><div className="flex items-center px-4 h-14 border-b border-slate-800 font-black text-emerald-400">ITRAN AGRI<button className="ml-auto text-slate-400" onClick={() => setSide(false)}>✕</button></div>{SideNav}</aside></div>}
      <div className="flex-1 flex flex-col min-w-0">
        <header className="sticky top-0 z-20 h-14 bg-white/90 backdrop-blur border-b border-slate-200 flex items-center gap-3 px-3">
          <button className="md:hidden text-2xl" onClick={() => setSide(true)} aria-label="Menu">☰</button>
          <span className="md:hidden font-black text-emerald-700">ITRAN AGRI</span>
          {sess.farmIds.length > 1 ? (
            <select className="rounded-lg border border-slate-300 bg-white text-sm px-2 py-1 font-semibold" value={sess.farmId}
              onChange={async (e) => { await fetch("/api/auth/switch-farm", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ farm_id: e.target.value }) }); router.refresh(); window.location.reload(); }}>
              {sess.farmIds.map((f) => <option key={f} value={f}>Trại {f}</option>)}
            </select>) : <span className="hidden sm:inline text-sm font-semibold text-slate-600">Trại {sess.farmId}</span>}
          <div className="ml-auto flex items-center gap-2 text-sm">
            <Search />
            <SunToggle compact />
            <span className="hidden md:inline-flex"><ThemeToggle compact /></span>
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
        <main id="main" className="flex-1 w-full max-w-[1800px] mx-auto px-3 md:px-5 py-4">
          {title && <h1 className="text-xl md:text-2xl font-bold mb-3 text-slate-800">{title}</h1>}
          {children}
        </main>
        <footer className="text-center text-xs text-slate-400 py-3">ITRAN FARM · "Một vòng tròn — không gì bị bỏ đi" · người tạo bản ghi, máy viết báo cáo</footer>
        <BottomNav role={sess.role} />
      </div>
    </div>
  );
}
