import io, os, re
R="F:/ITRAN FARM/itran-os/"
def w(p, s): os.makedirs(os.path.dirname(R+p) or R, exist_ok=True); io.open(R+p,"w",encoding="utf-8",newline="\n").write(s); print("w",p)
def rw(p, fn): s=io.open(R+p,encoding="utf-8").read(); n=fn(s); assert n!=s, p; io.open(R+p,"w",encoding="utf-8",newline="\n").write(n); print("ok",p)
# 1) ZONES = phòng ban
def shell(s):
    i=s.index("export const ZONES"); j=s.index("];", i)+2
    new='''export const ZONES: { key: string; icon: string; label: string; desc: string; dept?: string; roles: string[]; items: { href: string; label: string; roles?: string[] }[] }[] = [
  { key: "me", icon: "📝", label: "Của tôi", desc: "Việc trong ca, ghi 3 chạm theo vị trí, phê duyệt, phiếu giấy, in biểu mẫu", roles: ["*"], items: [{ href: "/ca", label: "Ca của tôi" }, { href: "/phe-duyet", label: "Phê duyệt", roles: ["team_lead", "tech_head", "director", "owner", "accountant"] }, { href: "/giay", label: "Phiếu giấy ↔ số" }, { href: "/in-an", label: "In biểu mẫu · nhãn · báo cáo" }, { href: "/huong-dan", label: "Hướng dẫn theo vai" }, { href: "/tai-khoan", label: "Tài khoản & thiết bị" }] },
  { key: "dh", icon: "🎯", label: "Điều hành & Kế hoạch", desc: "HĐQT · Ban GĐ · GĐ trại: kế hoạch S&OP, bảng điều hành, điều hành ca, cảnh báo, đa trại", dept: "BGD", roles: ["*"], items: [{ href: "/trang-chu", label: "Trang chủ khu vực" }, { href: "/ke-hoach", label: "Kế hoạch (Năm → S&OP tháng)", roles: ["team_lead", "tech_head", "director", "owner", "accountant", "auditor", "it_engineer"] }, { href: "/gd", label: "Bảng điều hành GĐ trại", roles: ["director", "owner", "tech_head", "accountant"] }, { href: "/ktt", label: "Điều hành ca (KTT)", roles: ["team_lead", "tech_head", "director", "owner"] }, { href: "/canh-bao", label: "Cảnh báo & luật" }, { href: "/hq", label: "Công ty mẹ · đa trại", roles: ["owner", "director", "auditor", "it_engineer", "accountant"] }] },
  { key: "cn", icon: "🐄", label: "Chăn nuôi – Thú y", desc: "Đàn bò/dê/gà/thủy sản: định danh, sinh sản, cân, việc đàn; thú y, vaccine, ngưng thuốc, dịch tễ", dept: "KTCN", roles: ["*"], items: [{ href: "/dan", label: "Đàn (cá thể · lô · nhóm · việc đàn)" }, { href: "/thu-y", label: "Thú y & sức khỏe đàn" }] },
  { key: "tt", icon: "🌾", label: "Trồng trọt – Sinh khối", desc: "Cỏ, bắp, lúa, rau: mùa vụ, vật tư PHI, tưới, đất, IPM, luân canh, giá thành ô", dept: "TT", roles: ["*"], items: [{ href: "/canh-tac", label: "Canh tác" }, { href: "/ban-do", label: "Bản đồ ô thửa" }] },
  { key: "sh", icon: "♻", label: "Sinh học tuần hoàn (khu D)", desc: "Trùn, BSF, biogas, compost/biochar, IMO/EM, anolyte, phát thải", dept: "SH", roles: ["*"], items: [{ href: "/sinh-hoc", label: "Sinh học tuần hoàn" }, { href: "/co2e", label: "Phát thải & tuần hoàn (CO2e)", roles: ["director", "owner", "tech_head", "auditor", "team_lead"] }] },
  { key: "d5", icon: "🏭", label: "Xưởng thức ăn D5 & Chế biến", desc: "TMR/viên cho đàn (D5); sơ chế – sấy – đóng gói – nhãn – tem QR (chế biến thực phẩm)", dept: "D5", roles: ["*"], items: [{ href: "/che-bien", label: "D5 & Chế biến" }, { href: "/khau-phan", label: "Khẩu phần tối ưu (LP)", roles: ["tech_head", "director", "owner", "team_lead"] }] },
  { key: "ccu", icon: "🏬", label: "Chuỗi cung ứng – Kho – Mua hàng", desc: "Dự trữ, 9 kho + kho công cụ, bin, kiểm kê, vận tải, mua hàng/PO/NCC", dept: "CCU", roles: ["*"], items: [{ href: "/du-tru", label: "Dự trữ (dashboard)" }, { href: "/kho", label: "Kho & vận tải" }, { href: "/mua-hang", label: "Mua hàng" }] },
  { key: "kdm", icon: "💰", label: "Kinh doanh – Marketing – CSKH", desc: "Bán 5 kênh, báo giá, hợp đồng, khách, điểm, công nợ, POS", dept: "KDM", roles: ["worker", "team_lead", "director", "owner", "accountant", "tech_head"], items: [{ href: "/ban-hang", label: "Kinh doanh" }] },
  { key: "dl", icon: "🏨", label: "Du lịch – Lưu trú – Ẩm thực", desc: "Booking, phòng, tiệc/MICE, tour, dịch vụ, công suất", dept: "DL", roles: ["worker", "team_lead", "director", "owner", "accountant"], items: [{ href: "/du-lich", label: "Du lịch" }] },
  { key: "xnk", icon: "🌏", label: "Xuất nhập khẩu", desc: "Thị trường, hợp đồng ngoại, chứng từ, hải quan, landed cost", dept: "XNK", roles: ["director", "owner", "accountant", "tech_head"], items: [{ href: "/xnk", label: "Xuất nhập khẩu" }] },
  { key: "tckt", icon: "📒", label: "Tài chính – Kế toán", desc: "GL kép, chi, lương, TSCĐ, AP/AR, vay, bảo hiểm, GTGT, dòng tiền, hợp nhất", dept: "TCKT", roles: ["director", "owner", "accountant", "auditor"], items: [{ href: "/ke-toan", label: "Kế toán" }, { href: "/audit", label: "Kiểm toán · xuất dữ liệu" }] },
  { key: "hcns", icon: "👥", label: "Hành chính – Nhân sự – Đào tạo", desc: "Hồ sơ, chấm công, đào tạo tuần, năng lực, thưởng gắn lương", dept: "HCNS", roles: ["team_lead", "tech_head", "director", "owner", "accountant", "it_engineer"], items: [{ href: "/nhan-su", label: "Nhân sự & đào tạo & thưởng" }] },
  { key: "qa", icon: "✅", label: "Chất lượng – Tuân thủ", desc: "Giám sát & chấm điểm, tiêu chuẩn/chứng nhận, truy xuất & thu hồi, đối soát dữ liệu", dept: "QA", roles: ["team_lead", "tech_head", "director", "owner", "auditor", "it_engineer", "accountant"], items: [{ href: "/giam-sat", label: "Giám sát & chấm điểm" }, { href: "/tuan-thu", label: "Tuân thủ & chứng nhận" }, { href: "/truy-xuat", label: "Truy xuất & thu hồi" }, { href: "/doi-soat", label: "Đối soát dữ liệu (RC)" }] },
  { key: "cntb", icon: "🔧", label: "Công nghệ – Thiết bị – Dữ liệu", desc: "Thiết bị/IoT, số liệu & biểu đồ, chất lượng dữ liệu, sơ đồ, quản trị dữ liệu", dept: "CNTB", roles: ["*"], items: [{ href: "/thiet-bi", label: "Thiết bị & IoT" }, { href: "/so-lieu", label: "Số liệu & biểu đồ mọi trường" }, { href: "/suc-khoe", label: "Chất lượng dữ liệu (7 bộ chất vấn)", roles: ["tech_head", "director", "owner", "auditor", "it_engineer", "accountant"] }, { href: "/so-do", label: "Sơ đồ khu · chuồng · vị trí" }, { href: "/quan-tri", label: "Quản trị dữ liệu", roles: ["director", "owner", "it_engineer", "tech_head", "accountant", "auditor", "team_lead"] }] },
  { key: "rd", icon: "🧪", label: "R&D · Nhân rộng – Nhượng quyền", desc: "Đề tài, đối chứng, tri thức; gói mẫu trại, chuyển giao", dept: "RD", roles: ["director", "owner", "tech_head", "it_engineer"], items: [{ href: "/rd", label: "R&D" }, { href: "/nhan-rong", label: "Nhân rộng · nhượng quyền", roles: ["director", "owner"] }] },
  { key: "tc", icon: "🏢", label: "Tổ chức – Quy trình – Danh mục", desc: "Phòng ban, quy trình A–Z, thư viện SOP, event bus, định nghĩa đối tượng", dept: "HCNS", roles: ["*"], items: [{ href: "/to-chuc", label: "Tổ chức · quy trình · SOP" }, { href: "/doi-tuong", label: "Danh mục đối tượng (định nghĩa)" }] },
];'''
    return s[:i]+new+s[j:]
rw("src/components/Shell.tsx", shell)
# 2) titles
T={
 "ke-hoach":"Kế hoạch — Năm · S&OP 12 tháng · đàn theo lứa · lịch vụ · ban hành việc · KH–TT",
 "kho":"Kho & vận tải — 9 kho + kho công cụ · bin · FEFO · kiểm kê · ROP · kho lạnh · chuyến xe · NCC",
 "ban-hang":"Kinh doanh — bán 5 kênh · báo giá · hợp đồng · khách · điểm · công nợ · POS",
 "nhan-su":"Nhân sự — đào tạo tuần · năng lực · thưởng gắn lương · hồ sơ · chấm công",
 "che-bien":"Xưởng thức ăn D5 & Chế biến — KHSX · MRP · BOM · mẻ · bao bì · nhãn · tem QR",
 "suc-khoe":"Chất lượng dữ liệu & sức khỏe hệ thống — 7 bộ câu chất vấn",
 "doi-tuong":"Danh mục đối tượng (định nghĩa) — con người · vật nuôi · cây trồng · sản phẩm/vật tư",
 "so-do":"Sơ đồ khu · chuồng · vị trí — trạng thái",
 "ban-do":"Bản đồ ô thửa ruộng — cây trồng · mùa vụ · trạng thái",
 "ktt":"Điều hành ca (Kỹ thuật trưởng) — duyệt · đối chiếu chéo · PO",
 "gd":"Bảng điều hành Giám đốc trại — 15 phút sáng · 1 trang thứ 6",
 "hq":"Công ty mẹ · đa trại — nhiều trại, nhiều vùng, nhiều pháp nhân",
 "audit":"Kiểm toán · xuất dữ liệu chuẩn",
 "co2e":"Phát thải & tuần hoàn — CO2e (IPCC Tier 1) · vòng dinh dưỡng khu D",
 "so-lieu":"Số liệu & biểu đồ — mọi chỉ số, mọi trường đều vẽ được",
 "in-an":"In biểu mẫu — hóa đơn · phiếu cân · hợp đồng · nhãn/tem QR · biểu mẫu · báo cáo",
 "thu-y":"Thú y & sức khỏe đàn — theo dõi · ngưng thuốc · vaccine · phác đồ · dịch tễ",
 "dan":"Chăn nuôi — Đàn: định danh 3 cấp · vòng theo dõi · lịch sinh sản · việc đàn",
 "canh-tac":"Trồng trọt — mùa vụ · vật tư PHI · thu hoạch · tưới/ET0 · đất/IPM · luân canh · giá thành ô",
 "truy-xuat":"Truy xuất & thu hồi — 1 lùi 1 tiến · mock recall",
 "thiet-bi":"Thiết bị – máy móc – IoT — giờ máy · bảo dưỡng · hiệu chuẩn · cảm biến",
}
for k,t in T.items():
    p=R+f"src/app/{k}/page.tsx"; s=io.open(p,encoding="utf-8").read(); s2=re.sub(r'title="[^"]*"', f'title="{t}"', s, count=1)
    if s2!=s: io.open(p,"w",encoding="utf-8",newline="\n").write(s2); print("title",k)
# 3) /sop → redirect
w("src/app/sop/page.tsx",'''import { redirect } from "next/navigation";
export default function P() { redirect("/to-chuc?tab=sop"); }
''')
# 4) CheBien tab regroup labels
rw("src/components/panels/CheBien.tsx", lambda s: s.replace('[["khsx", "Sản xuất · Kế hoạch tuần"], ["mrp", `Sản xuất · MRP thiếu hụt (${short.length})`], ["bom", "Sản xuất · BOM đa cấp"], ["me", "Sản xuất · Mẻ sơ chế/sấy/đóng gói"], ["baobi", "Đóng gói · Bao bì 3 cấp"], ["nhan", "Đóng gói · Nhãn sản phẩm"], ["tem", "Đóng gói · Tem QR mẻ"]]','[["khsx", "D5 & Chế biến · Kế hoạch SX tuần"], ["mrp", `D5 & Chế biến · MRP thiếu hụt (${short.length})`], ["bom", "D5 & Chế biến · BOM/định mức"], ["me", "Chế biến thực phẩm · Mẻ sơ chế/sấy/đóng gói + CCP"], ["baobi", "Chế biến thực phẩm · Bao bì 3 cấp"], ["nhan", "Chế biến thực phẩm · Nhãn (NĐ43/EU1169)"], ["tem", "Chế biến thực phẩm · Tem QR mẻ"]]',1))
# 5) /sinh-hoc page + panel
w("src/app/sinh-hoc/page.tsx",'''import { Page } from "@/components/withSession"; import SinhHoc from "@/components/panels/SinhHoc";
export default function P() { return <Page title="Sinh học tuần hoàn (khu D) — trùn · BSF · biogas · compost/biochar · IMO/EM · anolyte">{(s) => <SinhHoc sess={s} />}</Page>; }
''')
w("src/components/panels/SinhHoc.tsx", r'''"use client";
import { useState } from "react";
import { useData, fmt } from "@/lib/client";
import type { Sess } from "@/components/Shell";
import AnyChart from "@/components/AnyChart";
import Tabs from "@/components/Tabs";
type R = Record<string, unknown>;
const LINES: [string, string, string][] = [["TRUN_NAP", "Trùn: nạp phân", "kg phân ủ sơ nạp luống"], ["TRUN_THU", "Trùn: thu phân trùn", "kg phân trùn / trùn tươi"], ["BSF", "BSF ấu trùng", "kg rác hữu cơ vào → ấu trùng + compost"], ["BIOGAS", "Biogas", "kg phân vào → kWh điện / m³ khí"], ["COMPOST", "Compost – biochar – giấm gỗ", "mẻ ủ hiếu khí, than sinh học"], ["IMO_EM", "Nhân men IMO/EM", "lít men vi sinh"], ["ANOLYTE", "Trạm anolyte", "lít nước điện hóa · ppm"]];
/** SINH HỌC TUẦN HOÀN (khu D): mỗi dây chuyền có mẻ (batch_logs.line), đầu vào phân/rác → đầu ra phân trùn/BSF/điện/compost/men/anolyte; KPI 30 ngày; luống trùn; nối kho (K5 phân trùn) và CO2e */
export default function SinhHoc({ sess }: { sess: Sess }) {
  const [tab, setTab] = useState<string>("tong");
  const pb = useData("bio_batches"); const luong = useData("bio_beds");
  const B = pb.rows ?? []; const last30 = (line: string) => B.filter((b) => b.line === line && new Date(String(b.ts)) > new Date(Date.now() - 30 * 864e5));
  const sumIn = (rows: R[]) => rows.reduce((a, b) => a + ((b.inputs as R[]) ?? []).reduce((x, i) => x + Number(i.kg ?? 0), 0), 0); const sumOut = (rows: R[]) => rows.reduce((a, b) => a + ((b.outputs as R[]) ?? []).reduce((x, o) => x + Number(o.kg ?? 0), 0), 0);
  const canW = ["worker", "team_lead", "tech_head", "director", "owner"].includes(sess.role);
  return <div className="space-y-3">
    <div className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-7 gap-2">{LINES.map(([l, n]) => { const r = last30(l); return <div key={l} className="kpi !p-2"><div className="l">{n} · 30 ngày</div><div className="text-lg font-black">{fmt.n(sumOut(r) || sumIn(r))} <span className="text-xs font-normal">{sumOut(r) ? "ra" : "vào"} kg</span></div><div className="text-[10px] text-slate-500">{r.length} mẻ · vào {fmt.n(sumIn(r))} kg</div></div>; })}</div>
    <Tabs items={[["tong", "Tổng quan · vòng tuần hoàn"], ...LINES.map(([l, n]) => [l, n] as [string, string]), ["luong", `Luống trùn (${(luong.rows ?? []).length})`]]} value={tab} onChange={setTab} right={canW ? <a className="btn-primary !py-1.5 !px-3 text-sm" href="/ca">＋ Ghi mẻ (Ca của tôi › Mẻ khu D)</a> : undefined} />
    {tab === "tong" && <div className="space-y-3"><div className="card text-sm"><b>Vòng tuần hoàn khu D</b>: phân chuồng/RAS + rác bếp/BSF → <b>trùn</b> (phân trùn K5 · trùn tươi cho gà/lươn) · <b>BSF</b> (ấu trùng đạm · compost) · <b>biogas</b> (điện, đuốc dư khí) · <b>compost/biochar/giấm gỗ</b> (ruộng) · <b>IMO/EM</b> (men) · <b>anolyte</b> (khử trùng chuồng/trứng). Đầu ra ghi vào kho (K5 phân trùn, TH-ANOLYTE, NL-MEN-VS) qua mẻ; phát thải xem <a className="underline" href="/co2e">CO2e</a>; SOP-SH-01…06.</div>
      <div className="grid md:grid-cols-2 gap-3"><div className="card"><AnyChart title="Số mẻ khu D theo dây chuyền (tuần)" table="batch_logs" col="id" agg="count" dim="line" bucket="week" filters={{ location_id: `${sess.farmId}-KHU-D` }} height={240} /></div><div className="card"><AnyChart title="Nhiệt độ luống/mẻ (°C) theo dây chuyền" table="batch_logs" col="temp_c" agg="avg" dim="line" bucket="week" height={240} /></div><div className="card"><AnyChart title="Phân trùn nhập kho K5 (bao)" table="inventory_moves" col="qty" dim="reason" bucket="month" filters={{ sku: "SKU-PTR-25", direction: "1" }} height={240} /></div><div className="card"><AnyChart title="Anolyte sản xuất (lít)" table="batch_logs" col="id" agg="count" bucket="week" filters={{ line: "ANOLYTE" }} height={240} /></div></div></div>}
    {LINES.some(([l]) => l === tab) && <div className="card p-0 overflow-auto"><div className="px-3 py-2 bg-slate-100 rounded-t-xl font-bold">{LINES.find(([l]) => l === tab)?.[1]} — {LINES.find(([l]) => l === tab)?.[2]}</div><table className="tbl text-sm"><thead><tr><th className="pl-3">Lúc</th><th>Mã mẻ</th><th>Vị trí</th><th>Đầu vào</th><th>Đầu ra</th><th className="text-right">°C</th><th className="text-right">Ẩm %</th><th>QC/CCP</th><th>Người</th></tr></thead><tbody>{B.filter((b) => b.line === tab).slice(0, 120).map((b) => <tr key={String(b.id)}><td className="pl-3 text-xs">{fmt.dt(String(b.ts))}</td><td className="font-mono text-xs">{String(b.batch_code)}</td><td className="text-xs">{String(b.location_id ?? "")}</td><td className="text-xs">{((b.inputs as R[]) ?? []).map((i) => `${i.sku} ${fmt.n(Number(i.kg))}`).join(", ")}</td><td className="text-xs">{((b.outputs as R[]) ?? []).map((o) => `${o.sku} ${fmt.n(Number(o.kg))}`).join(", ")}</td><td className="text-right">{String(b.temp_c ?? "")}</td><td className="text-right">{String(b.moisture_pct ?? "")}</td><td className="text-xs">{JSON.stringify(b.qc ?? {}).slice(0, 50)}</td><td className="text-xs">{String(b.created_by ?? "")}</td></tr>)}</tbody></table>{!B.filter((b) => b.line === tab).length && <div className="p-3 text-sm text-slate-500">Chưa có mẻ.</div>}</div>}
    {tab === "luong" && <div className="card p-0 overflow-auto"><div className="px-3 py-2 bg-slate-100 rounded-t-xl font-bold">Luống trùn / ô khu D — lần nạp, lần thu gần nhất, nhiệt độ</div><table className="tbl text-sm"><thead><tr><th className="pl-3">Luống</th><th>Nạp gần nhất</th><th>Thu gần nhất</th><th className="text-right">°C gần nhất</th><th className="text-right">Mẻ 30 ngày</th></tr></thead><tbody>{(luong.rows ?? []).map((l) => <tr key={String(l.id)}><td className="pl-3">{String(l.name)}</td><td className="text-xs">{l.last_nap ? fmt.dt(String(l.last_nap)) : "—"}</td><td className="text-xs">{l.last_thu ? fmt.dt(String(l.last_thu)) : "—"}</td><td className={`text-right ${Number(l.temp_c) > 35 ? "text-red-700 font-bold" : ""}`}>{String(l.temp_c ?? "")}</td><td className="text-right">{String(l.n30)}</td></tr>)}</tbody></table></div>}
  </div>;
}
''')
rw("src/lib/queries.ts", lambda s: s.replace("  herd_actions: {", '''  bio_batches: { sql: "select b.* from batch_logs b where b.farm_id=$1 and b.status='ACTIVE' and b.line in ('TRUN_NAP','TRUN_THU','BSF','BIOGAS','COMPOST','IMO_EM','ANOLYTE') order by b.ts desc limit 600" },
  bio_beds: { sql: "select l.id, l.name, (select max(ts) from batch_logs b where b.location_id=l.id and b.line='TRUN_NAP') as last_nap, (select max(ts) from batch_logs b where b.location_id=l.id and b.line='TRUN_THU') as last_thu, (select temp_c from batch_logs b where b.location_id=l.id and b.temp_c is not null order by ts desc limit 1) as temp_c, (select count(*) from batch_logs b where b.location_id=l.id and b.ts>now()-interval '30 days') as n30 from locations l where l.farm_id=$1 and (l.kind='O' or l.id like '%-TR-%' or l.id like '%-KHU-D') and l.active order by l.id" },
  herd_actions: {''',1))
# NAV mobile: add sinh-hoc for SH workers? keep. roles for /sinh-hoc none.
