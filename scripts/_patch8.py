import re, io
def rw(p, fn):
    s = io.open(p, encoding="utf-8").read(); n = fn(s); assert n != s, p; io.open(p, "w", encoding="utf-8", newline="\n").write(n); print("ok", p)
R = "F:/ITRAN FARM/itran-os/"
# Shell: chuông
def shell(s):
    s = s.replace('import { usePathname, useRouter } from "next/navigation";', 'import { usePathname, useRouter } from "next/navigation";\nimport { Bell } from "@/components/panels/Notify";', 1)
    s = s.replace('<div className="ml-auto flex items-center gap-2 text-sm">\n', '<div className="ml-auto flex items-center gap-2 text-sm">\n            <Bell />\n', 1)
    return s
rw(R + "src/components/Shell.tsx", shell)
# Kho: biểu đồ theo SKU (tab tồn: mở SKU → biểu đồ nhập/xuất; tab thẻ kho: biểu đồ)
def kho(s):
    s = s.replace('import { useMemo, useState } from "react";', 'import { useMemo, useState } from "react";\nimport AnyChart from "@/components/AnyChart";', 1)
    s = s.replace('...(open ? ls.map((r, i) =>', '...(open ? [<tr key={sku + "-chart"} className="bg-white"><td colSpan={6} className="p-2"><div className="grid md:grid-cols-2 gap-2"><AnyChart title="Nhập kho theo ngày" table="inventory_moves" col="qty" dim="reason" filters={{ sku, direction: "1" }} height={180} /><AnyChart title="Xuất kho theo ngày" table="inventory_moves" col="qty" dim="reason" filters={{ sku, direction: "-1" }} height={180} /></div></td></tr>, ...ls.map((r, i) =>', 1)
    s = s.replace('{sku && <div className="card p-0 overflow-auto"><div className="px-3 py-2 font-bold bg-stone-100 rounded-t-2xl">Thẻ kho {sku}</div>', '{sku && <div className="card"><AnyChart title={`Biến động ${sku} (nhập +, xuất −) theo kỳ`} table="inventory_moves" col="qty" dim="direction" filters={{ sku }} chart="bar" height={220} compare /></div>}\n        {sku && <div className="card p-0 overflow-auto"><div className="px-3 py-2 font-bold bg-stone-100 rounded-t-2xl">Thẻ kho {sku}</div>', 1)
    s = s.replace('[["ton", "Tồn kho"], ["ghi", "Nhập / Xuất"], ["kiemke", "Kiểm kê · Điều chỉnh"], ["so", "Ngày-tồn nguyên liệu"]]', '[["ton", "Tồn kho"], ["ghi", "Nhập / Xuất"], ["kiemke", "Kiểm kê · Điều chỉnh"], ["so", "Ngày-tồn nguyên liệu"], ["bieudo", "📈 Biểu đồ kho"]]')
    s = s.replace('useState<"ton" | "ghi" | "kiemke" | "so">("ton")', 'useState<"ton" | "ghi" | "kiemke" | "so" | "bieudo">("ton")')
    s = s.replace('      {tab === "so" && (<div className="space-y-3">', '''      {tab === "bieudo" && (<div className="space-y-3">
        <div className="card"><AnyChart title="Sản lượng NHẬP kho theo mặt hàng (thu hoạch cỏ/ngô, mua, sản xuất D5…)" table="inventory_moves" col="qty" dim="sku" filters={{ direction: "1" }} bucket="week" height={300} compare /></div>
        <div className="card"><AnyChart title="XUẤT kho theo mặt hàng (cho ăn, bán, hao hụt…)" table="inventory_moves" col="qty" dim="sku" filters={{ direction: "-1" }} bucket="week" height={300} compare /></div>
        <div className="grid md:grid-cols-2 gap-3"><div className="card"><AnyChart title="Giá trị nhập mua (đ)" table="inventory_moves" col="qty" agg="sum" dim="from_to" filters={{ reason: "NHAP_MUA" }} bucket="week" height={220} /></div><div className="card"><AnyChart title="Thu hoạch/cắt sinh khối theo giống (kg)" table="crop_logs" col="qty_kg" dim="variety" bucket="week" height={220} /></div></div>
        <div className="text-sm text-stone-600">Muốn biểu đồ cho bất kỳ trường nào khác → <a className="underline" href="/so-lieu?tab=any">Số liệu › Mọi trường</a>.</div>
      </div>)}
      {tab === "so" && (<div className="space-y-3">''', 1)
    return s
rw(R + "src/components/panels/KhoPanel.tsx", kho)
# Số liệu: tab
def sl(s):
    s = s.replace('import { fmt } from "@/lib/client";', 'import { fmt } from "@/lib/client";\nimport { AnyExplorer } from "@/components/AnyChart";', 1)
    s = s.replace('export default function SoLieuPanel({ sess, initialMetric }: { sess: Sess; initialMetric?: string }) {', '''export default function SoLieuPanel({ sess, initialMetric, initialTab }: { sess: Sess; initialMetric?: string; initialTab?: string }) {
  const [top, setTop] = useState<"kpi" | "any">(initialTab === "any" ? "any" : "kpi");
  return (<div className="space-y-3">
    <div className="flex gap-2">{[["kpi", "Chỉ số nghiệp vụ (catalog)"], ["any", "📈 Mọi trường dữ liệu (tự động)"]].map(([k, l]) => <button key={k} className={`px-4 py-2 rounded-xl font-semibold ${top === k ? "bg-green-700 text-white" : "bg-white border"}`} onClick={() => setTop(k as typeof top)}>{l}</button>)}</div>
    {top === "any" ? <AnyExplorer /> : <MetricExplorer sess={sess} initialMetric={initialMetric} />}
  </div>);
}
function MetricExplorer({ sess, initialMetric }: { sess: Sess; initialMetric?: string }) {''', 1)
    return s
rw(R + "src/components/panels/SoLieuPanel.tsx", sl)
rw(R + "src/app/so-lieu/page.tsx", lambda s: s.replace('searchParams: Promise<{ m?: string }> }) { const { m } = await searchParams; return <Page title="Số liệu — mọi chỉ số đều vẽ được">{(s) => <SoLieuPanel sess={s} initialMetric={m} />}', 'searchParams: Promise<{ m?: string; tab?: string }> }) { const { m, tab } = await searchParams; return <Page title="Số liệu — mọi chỉ số, mọi trường đều vẽ được">{(s) => <SoLieuPanel sess={s} initialMetric={m} initialTab={tab} />}'))
# Cảnh báo: tab cài đặt
def cb(s):
    s = s.replace('useData("alerts_grouped"); const [tab, setTab] = useState<"open" | "all" | "group">("group");', 'useData("alerts_grouped"); const [tab, setTab] = useState<"open" | "all" | "group" | "caidat">(typeof window !== "undefined" && new URLSearchParams(window.location.search).get("tab") === "caidat" ? "caidat" : "group");', 1)
    s = s.replace('[["group", "Theo luật (30 ngày)"], ["open", `Chưa xử lý (${open.rows?.length ?? 0})`], ["all", "Tất cả"]]', '[["group", "Theo luật (30 ngày)"], ["open", `Chưa xử lý (${open.rows?.length ?? 0})`], ["all", "Tất cả"], ["caidat", "⚙ Cài đặt cảnh báo · Hộp thư"]]', 1)
    return s
rw(R + "src/components/panels/Ops.tsx", cb)
s = io.open(R + "src/components/panels/Ops.tsx", encoding="utf-8").read()
# tìm chỗ render body của CanhBaoPanel: chèn nhánh caidat ngay sau div tabs
i = s.index('export function CanhBaoPanel'); j = s.index('</div>\n', s.index('▶ Quét cảnh báo ngay', i)) + len('</div>\n')
s = s[:j] + '      {tab === "caidat" && <AlertSettings sess={sess} />}\n' + s[j:]
s = s.replace('"use client";', '"use client";\nimport { AlertSettings } from "@/components/panels/Notify";', 1)
io.open(R + "src/components/panels/Ops.tsx", "w", encoding="utf-8", newline="\n").write(s); print("ok Ops2")
# HQ page: tabs
io.open(R + "src/app/hq/page.tsx", "w", encoding="utf-8", newline="\n").write('''import { Page } from "@/components/withSession"; import { HqPanel } from "@/components/panels/Dashboards"; import { CompanyPanel } from "@/components/panels/Company";
export default async function P({ searchParams }: { searchParams: Promise<{ tab?: string }> }) { const { tab } = await searchParams; return <Page title="Công ty mẹ ITRAN FARM — nhiều trại, nhiều vùng, nhiều pháp nhân">{(s) => <div className="space-y-3"><div className="flex gap-2"><a href="/hq" className={`px-4 py-2 rounded-xl font-semibold ${!tab ? "bg-green-700 text-white" : "bg-white border"}`}>So sánh trại</a><a href="/hq?tab=cty" className={`px-4 py-2 rounded-xl font-semibold ${tab === "cty" ? "bg-green-700 text-white" : "bg-white border"}`}>🏢 Quản trị công ty · Khai báo trại</a></div>{tab === "cty" ? <CompanyPanel sess={s} /> : <HqPanel />}</div>}</Page>; }
''')
print("ok hq")
