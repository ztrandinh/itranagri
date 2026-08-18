import io, os
R = "F:/ITRAN FARM/itran-os/"
def w(p, s): os.makedirs(os.path.dirname(R + p), exist_ok=True); io.open(R + p, "w", encoding="utf-8", newline="\n").write(s); print("w", p)
def rw(p, fn): s = io.open(R + p, encoding="utf-8").read(); n = fn(s); assert n != s, p; io.open(R + p, "w", encoding="utf-8", newline="\n").write(n); print("ok", p)
rw("src/proxy.ts", lambda s: s.replace('pathname.startsWith("/trace") ||', 'pathname.startsWith("/trace") || pathname.startsWith("/chuan") ||'))
# public API for standard
w("src/app/api/public/standard/route.ts", '''import { NextResponse } from "next/server";
import { adminPool } from "@/lib/db";
/** CÔNG KHAI: ITRAN Circular Farm Standard — điều khoản + căn cứ + cách đo + điểm từng trại (minh bạch cho hộ liên kết, khách, nhà nhập khẩu, cơ quan) */
export async function GET(req: Request) {
  const p = adminPool(); const u = new URL(req.url); const farm = u.searchParams.get("farm");
  const std = (await p.query("select code,name,issuer,version,description,pillars,levels,url from standards where code='ITRAN-STD'")).rows[0];
  const reqs = (await p.query("select clause,title,requirement,level,evidence_tables,basis,threshold,points,frequency,owner_dept from standard_requirements where standard_code='ITRAN-STD' and public order by clause")).rows;
  const farms = (await p.query("select farm_id, name, pct, level, critical_fail from v_icfs_summary" + (farm ? " where farm_id=$1" : ""), farm ? [farm] : [])).rows;
  const detail = farm ? (await p.query("select * from icfs_score($1)", [farm])).rows : [];
  const changes = (await p.query("select ts, action, pk, by_staff from audit_log where table_name in ('standards','standard_requirements') and (pk like 'ITRAN-STD%' or (after->>'standard_code')='ITRAN-STD' or (before->>'standard_code')='ITRAN-STD') order by ts desc limit 50")).rows;
  return NextResponse.json({ standard: std, requirements: reqs, farms, detail, changes, generated_at: new Date().toISOString() });
}
''')
w("src/app/chuan/page.tsx", '''import { adminPool } from "@/lib/db";
type R = Record<string, unknown>;
export const dynamic = "force-dynamic";
/** Trang CÔNG KHAI (không cần đăng nhập): ITRAN Circular Farm Standard — minh bạch điều khoản, cách đo, điểm từng trại/hộ */
export default async function P({ searchParams }: { searchParams: Promise<{ farm?: string }> }) {
  const { farm } = await searchParams; const p = adminPool();
  const std = (await p.query("select * from standards where code='ITRAN-STD'")).rows[0] as R | undefined;
  const reqs = (await p.query("select * from standard_requirements where standard_code='ITRAN-STD' and public order by clause")).rows as R[];
  const farms = (await p.query("select * from v_icfs_summary order by farm_id")).rows as R[];
  const detail = farm ? ((await p.query("select * from icfs_score($1)", [farm])).rows as R[]) : [];
  const pillars = ["1 An toàn & truy xuất", "2 Tuần hoàn tài nguyên", "3 Định danh & phúc lợi vật nuôi", "4 Đất – nước – đa dạng sinh học", "5 Con người & cộng đồng", "6 Dữ liệu minh bạch", "7 Quản trị & cải tiến"];
  const arr = (v: unknown) => (Array.isArray(v) ? (v as string[]) : []);
  return (<main className="min-h-screen bg-slate-50 text-slate-900"><div className="max-w-5xl mx-auto px-4 py-8 space-y-6">
    <div><div className="text-xs uppercase tracking-widest text-emerald-700 font-bold">ITRAN FARM · công khai</div><h1 className="text-3xl font-black">{String(std?.name ?? "ITRAN Circular Farm Standard")}</h1><p className="mt-2 text-slate-700">{String(std?.description ?? "")}</p><div className="text-xs text-slate-500 mt-1">Phiên bản {String(std?.version ?? "")} · Chủ sở hữu: ITRAN FARM · Mọi điều khoản đo bằng dữ liệu vận hành (không tự khai) · Lịch sử sửa đổi công khai · API: <code>/api/public/standard</code></div></div>
    <div className="grid sm:grid-cols-3 gap-3">{arr(std?.levels ? (std.levels as R[]).map((l) => JSON.stringify(l)) : []).map((l) => { const o = JSON.parse(l) as R; return <div key={String(o.level)} className={`rounded-xl border p-4 ${o.level === "VÀNG" ? "bg-amber-50 border-amber-300" : o.level === "BẠC" ? "bg-slate-100 border-slate-300" : "bg-orange-50 border-orange-300"}`}><div className="text-xl font-black">{String(o.level)}</div><div className="text-sm">≥ {String(o.min_pct)}% điểm · {String(o.desc)}</div></div>; })}</div>
    <div className="rounded-xl bg-white border p-4"><h2 className="font-bold text-lg mb-2">Trại / hộ đang áp dụng</h2><table className="w-full text-sm"><thead><tr className="text-left text-xs uppercase text-slate-500"><th>Mã</th><th>Tên</th><th className="text-right">Điểm</th><th>Hạng</th><th>Vi phạm CRITICAL</th><th></th></tr></thead><tbody>{farms.map((f) => <tr key={String(f.farm_id)} className="border-t"><td className="font-mono py-1">{String(f.farm_id)}</td><td>{String(f.name)}</td><td className="text-right font-bold">{String(f.pct)}%</td><td><span className={`rounded-full px-2 py-0.5 text-xs font-bold ${f.level === "VÀNG" ? "bg-amber-200" : f.level === "BẠC" ? "bg-slate-200" : f.level === "ĐỒNG" ? "bg-orange-200" : "bg-red-100 text-red-800"}`}>{String(f.level)}</span></td><td>{String(f.critical_fail)}</td><td><a className="underline text-emerald-700" href={`/chuan?farm=${f.farm_id}`}>chi tiết</a></td></tr>)}</tbody></table></div>
    {farm && <div className="rounded-xl bg-white border p-4"><h2 className="font-bold text-lg mb-2">Kết quả đo theo điều khoản — {farm} (thời gian thực)</h2><table className="w-full text-sm"><thead><tr className="text-left text-xs uppercase text-slate-500"><th>Điều</th><th>Yêu cầu</th><th>Mức</th><th>Ngưỡng</th><th className="text-right">Đo được</th><th>Kết quả</th></tr></thead><tbody>{detail.map((d) => <tr key={String(d.clause)} className="border-t"><td className="font-mono py-1">{String(d.clause)}</td><td>{String(d.title)}</td><td className="text-xs">{String(d.level)}</td><td>{String(d.threshold ?? "")}</td><td className="text-right font-bold">{String(d.value ?? "—")}</td><td>{d.pass === true ? <span className="text-emerald-700 font-bold">ĐẠT</span> : d.pass === false ? <span className="text-red-700 font-bold">CHƯA</span> : <span className="text-slate-400">n/a</span>}</td></tr>)}</tbody></table></div>}
    <div className="rounded-xl bg-white border p-4"><h2 className="font-bold text-lg mb-2">Điều khoản ({reqs.length}) theo 7 trụ cột</h2>{pillars.map((pl, i) => <div key={pl} className="mt-3"><div className="font-bold text-emerald-800">{pl}</div><table className="w-full text-sm mt-1"><tbody>{reqs.filter((r) => String(r.clause).startsWith(`${i + 1}.`)).map((r) => <tr key={String(r.clause)} className="border-t align-top"><td className="font-mono py-1 w-12">{String(r.clause)}</td><td><b>{String(r.title)}</b><div className="text-xs text-slate-600">{String(r.requirement ?? "")}</div><div className="text-xs text-slate-500">Đo bằng: {arr(r.evidence_tables).join(", ")} · Ngưỡng {String(r.threshold ?? "")} · {String(r.points)} điểm · Kế thừa: {arr(r.basis).join(", ") || "riêng ITRAN"}</div></td><td className="text-xs w-20">{String(r.level)}</td></tr>)}</tbody></table></div>)}</div>
    <div className="text-xs text-slate-500">Cách sinh chuẩn: kế thừa điều khoản mạnh nhất của VietGAP · GlobalG.A.P. · EU Organic · ISO 22000/HACCP · Halal · ASC (cột "Kế thừa"), bổ sung 4 điều ITRAN riêng (tuần hoàn đo được, định danh cá thể suốt đời, dữ liệu append-only + đối soát đêm, công khai). Hộ liên kết dùng cùng ITRAN OS → cùng biểu mẫu, cùng cách đo, audit chéo. Nguồn mở: github.com/ztrandinh/itranagri</div>
  </div></main>);
}
''')
# TuanThu: ICFS tab
def tt(s):
    s = s.replace('  const [sel, setSel] = useState<string | null>(null);', '  const icfs = useData("icfs_score"); const icfsSum = useData("icfs_summary");\n  const [sel, setSel] = useState<string | null>(null);', 1)
    s = s.replace('      <div className="text-sm text-slate-600">Số điều khoản là bản tóm tắt', '''      <div className="card border-2 border-emerald-500"><div className="flex items-center gap-3 flex-wrap"><div><div className="text-xs uppercase tracking-widest text-emerald-700 font-bold">Tiêu chuẩn của riêng ITRAN</div><b className="text-lg">ITRAN Circular Farm Standard (ICFS) v1.0</b></div>{(icfsSum.rows ?? []).map((f) => <div key={String(f.farm_id)} className="kpi !p-2"><div className="l">{String(f.farm_id)}</div><div className="text-xl font-black">{String(f.pct)}% · {String(f.level)}</div><div className="text-xs">CRITICAL lỗi: {String(f.critical_fail)}</div></div>)}<a className="ml-auto underline text-sm" href="/chuan" target="_blank">Trang công khai /chuan ↗</a><a className="underline text-sm" href="/api/public/standard" target="_blank">API</a></div>
        <div className="overflow-auto mt-2"><table className="tbl text-sm"><thead><tr><th className="pl-2">Điều</th><th>Yêu cầu</th><th>Mức</th><th>Ngưỡng</th><th className="text-right">Đo được (realtime)</th><th>KQ</th></tr></thead><tbody>{(icfs.rows ?? []).map((d) => <tr key={String(d.clause)}><td className="pl-2 font-mono">{String(d.clause)}</td><td>{String(d.title)}</td><td><span className={d.level === "CRITICAL" ? "b-red" : d.level === "MAJOR" ? "b-yel" : "b-gray"}>{String(d.level)}</span></td><td>{String(d.threshold ?? "")}</td><td className="text-right font-bold">{String(d.value ?? "—")}</td><td>{d.pass === true ? <span className="b-grn">ĐẠT</span> : d.pass === false ? <span className="b-red">CHƯA</span> : <span className="b-gray">n/a</span>}</td></tr>)}</tbody></table></div>
        <div className="text-xs text-slate-600 mt-1">Điểm tính tự động từ dữ liệu vận hành (không tự khai). Sửa điều khoản/ngưỡng/công thức đo: <a className="underline" href="/quan-tri?t=standard_requirements">Quản trị DL</a> (có lịch sử công khai).</div></div>
      <div className="text-sm text-slate-600">Số điều khoản là bản tóm tắt''', 1)
    return s
rw("src/components/panels/TuanThu.tsx", tt)
rw("src/lib/queries.ts", lambda s: s.replace("  compliance: {", '  icfs_score: { sql: "select * from icfs_score($1)" }, icfs_summary: { sql: "select * from v_icfs_summary order by farm_id" },\n  compliance: {', 1))
