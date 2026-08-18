import io
R = "F:/ITRAN FARM/itran-os/"
p = R + "src/components/Shell.tsx"; s = io.open(p, encoding="utf-8").read()
start = s.index("  const nav = NAV[sess.role] ?? NAV.worker;")
end = s.index("      {showQ && (")
new = '''  const nav = NAV[sess.role] ?? NAV.worker;
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
'''
s = s[:start] + new + s[end:]
old_main = '''      <main className="flex-1 max-w-5xl w-full mx-auto px-3 py-4">
        {title && <h1 className="text-2xl font-bold mb-3">{title}</h1>}
        {children}
      </main>
      <footer className="text-center text-xs text-stone-500 py-3">ITRAN FARM · "Một vòng tròn — không gì bị bỏ đi" · người tạo bản ghi, máy viết báo cáo</footer>
    </div>'''
assert old_main in s
s = s.replace(old_main, '''        <main className="flex-1 w-full max-w-[1400px] mx-auto px-3 md:px-6 py-4">
          {title && <h1 className="text-xl md:text-2xl font-bold mb-3 text-slate-800">{title}</h1>}
          {children}
        </main>
        <footer className="text-center text-xs text-slate-400 py-3">ITRAN FARM · "Một vòng tròn — không gì bị bỏ đi" · người tạo bản ghi, máy viết báo cáo</footer>
      </div>
    </div>''')
s = s.replace('<div className="max-w-5xl mx-auto px-3 py-2">\n            <div className="flex items-center gap-3"><b>Hàng đợi', '<div className="max-w-[1400px] mx-auto px-3 py-2">\n            <div className="flex items-center gap-3"><b>Hàng đợi')
io.open(p, "w", encoding="utf-8", newline="\n").write(s)

p = R + "src/components/Search.tsx"; s = io.open(p, encoding="utf-8").read()
s = s.replace('"bg-green-900 text-white placeholder:text-green-300 rounded-lg px-3 py-1 text-sm w-48 lg:w-64"', '"rounded-lg border border-slate-300 bg-slate-50 px-3 py-1.5 text-sm w-48 lg:w-72 focus:outline-none focus:ring-2 focus:ring-emerald-500"')
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
p = R + "src/components/panels/Notify.tsx"; s = io.open(p, encoding="utf-8").read()
s = s.replace('className={`rounded-full px-2.5 py-0.5 text-sm font-semibold ${n ? "bg-red-500 text-white" : "bg-green-600"}`}', 'className={`rounded-full px-2.5 py-1 text-xs font-semibold ${n ? "bg-red-500 text-white" : "bg-slate-100 text-slate-700"}`}')
io.open(p, "w", encoding="utf-8", newline="\n").write(s)

p = R + "src/app/globals.css"
css = '''@import "tailwindcss";
html { -webkit-tap-highlight-color: transparent; }
body { background: #f8fafc; color: #0f172a; -webkit-font-smoothing: antialiased; }
@layer components {
  .btn { @apply inline-flex items-center justify-center rounded-xl px-5 py-3.5 text-lg font-semibold shadow-sm active:scale-[0.98] transition min-h-[52px] disabled:opacity-50; }
  .btn-primary { @apply inline-flex items-center justify-center rounded-xl px-5 py-3.5 text-lg font-semibold shadow-sm active:scale-[0.98] transition min-h-[52px] disabled:opacity-50 bg-emerald-600 text-white hover:bg-emerald-700; }
  .btn-secondary { @apply inline-flex items-center justify-center rounded-xl px-5 py-3.5 text-lg font-semibold shadow-sm active:scale-[0.98] transition min-h-[52px] disabled:opacity-50 bg-white text-slate-800 border border-slate-300 hover:bg-slate-50; }
  .btn-danger { @apply inline-flex items-center justify-center rounded-xl px-5 py-3.5 text-lg font-semibold shadow-sm active:scale-[0.98] transition min-h-[52px] bg-red-600 text-white; }
  .card { @apply rounded-xl bg-white shadow-sm border border-slate-200 p-4; }
  .tile { @apply rounded-xl bg-white shadow-sm border border-slate-200 p-4 flex flex-col gap-1 min-h-[96px] justify-center hover:bg-emerald-50 active:bg-emerald-100 cursor-pointer text-left; }
  .input { @apply w-full rounded-lg border border-slate-300 px-3 py-2.5 text-base bg-white focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500; }
  .badge { @apply inline-block rounded-full px-2.5 py-0.5 text-sm font-semibold; }
  .b-red { @apply inline-block rounded-full px-2.5 py-0.5 text-sm font-semibold bg-red-100 text-red-800; }
  .b-yel { @apply inline-block rounded-full px-2.5 py-0.5 text-sm font-semibold bg-amber-100 text-amber-800; }
  .b-grn { @apply inline-block rounded-full px-2.5 py-0.5 text-sm font-semibold bg-emerald-100 text-emerald-800; }
  .b-gray { @apply inline-block rounded-full px-2.5 py-0.5 text-sm font-semibold bg-slate-200 text-slate-700; }
  .kpi { @apply rounded-xl bg-white shadow-sm border border-slate-200 p-4; }
  .kpi .v { @apply text-3xl font-bold text-slate-800; } .kpi .l { @apply text-xs uppercase tracking-wide text-slate-500; }
  table.tbl { @apply w-full text-[15px]; } table.tbl th { @apply text-left text-xs uppercase tracking-wide text-slate-500 font-semibold py-2 border-b border-slate-200 bg-slate-50; } table.tbl td { @apply py-2 border-b border-slate-100 align-top; } table.tbl tbody tr:hover td { @apply bg-slate-50; }
}
/* Ánh xạ palette cũ (green/stone) sang hệ màu chuyên nghiệp (emerald/slate) để toàn bộ màn hình đồng bộ */
.bg-green-700 { background-color: #059669 !important; } .bg-green-800 { background-color: #047857 !important; } .hover\\:bg-green-800:hover { background-color: #047857 !important; } .hover\\:bg-green-700:hover { background-color: #059669 !important; }
.bg-green-50 { background-color: #ecfdf5 !important; } .bg-green-100 { background-color: #d1fae5 !important; } .hover\\:bg-green-50:hover { background-color: #ecfdf5 !important; }
.text-green-700 { color: #047857 !important; } .text-green-800 { color: #065f46 !important; } .text-green-900 { color: #064e3b !important; } .border-green-600 { border-color: #059669 !important; } .border-green-200 { border-color: #a7f3d0 !important; } .ring-green-600 { --tw-ring-color: #059669 !important; }
.bg-stone-100 { background-color: #f1f5f9 !important; } .bg-stone-50 { background-color: #f8fafc !important; } .text-stone-500 { color: #64748b !important; } .text-stone-600 { color: #475569 !important; } .border-stone-200 { border-color: #e2e8f0 !important; }
'''
io.open(p, "w", encoding="utf-8", newline="\n").write(css)
print("ok")
