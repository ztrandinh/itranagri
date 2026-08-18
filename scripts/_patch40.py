import io, os, re
R="F:/ITRAN FARM/itran-os/"
def w(p, s): os.makedirs(os.path.dirname(R+p) or R, exist_ok=True); io.open(R+p,"w",encoding="utf-8",newline="\n").write(s); print("w",p)
def rw(p, fn): s=io.open(R+p,encoding="utf-8").read(); n=fn(s); assert n!=s, p; io.open(R+p,"w",encoding="utf-8",newline="\n").write(n); print("ok",p)
# 1) dept in session
rw("src/lib/auth.ts", lambda s: s.replace("export type Session = Ctx & { staffName: string; position: string | null; farmName?: string };","export type Session = Ctx & { staffName: string; position: string | null; dept?: string | null; farmName?: string };",1).replace("select s.id, s.org_id, s.farm_id, s.role, s.full_name, s.position, s.farm_ids,","select s.id, s.org_id, s.farm_id, s.role, s.full_name, s.position, s.dept, s.farm_ids,",1).replace("staffName: s.full_name, position: s.position };","staffName: s.full_name, position: s.position, dept: s.dept };",1))
rw("src/components/Shell.tsx", lambda s: s.replace("export type Sess = { staffId: string; staffName: string; role: string; position: string | null; farmId: string; farmIds: string[]; orgId: string };","export type Sess = { staffId: string; staffName: string; role: string; position: string | null; dept?: string | null; farmId: string; farmIds: string[]; orgId: string };",1))
rw("src/components/withSession.tsx", lambda s: s.replace("position: s.position, farmId: s.farmId","position: s.position, dept: s.dept ?? null, farmId: s.farmId",1))
# 2) ModuleIntro component
w("src/components/ModuleIntro.tsx", '''"use client";
import { useEffect, useState } from "react";
import { MODULES } from "@/lib/modules";
/** Giới thiệu chuẩn đầu mỗi trang: để làm gì · dành cho ai · quy trình · SOP · bắt đầu từ đâu — thu gọn được, nhớ theo người dùng (localStorage) */
export default function ModuleIntro({ path }: { path: string }) {
  const m = MODULES[path]; const [open, setOpen] = useState(true);
  useEffect(() => { try { setOpen(localStorage.getItem("intro:" + path) !== "0"); } catch { /* ignore */ } }, [path]);
  if (!m) return null;
  const toggle = () => { const v = !open; setOpen(v); try { localStorage.setItem("intro:" + path, v ? "1" : "0"); } catch { /* ignore */ } };
  return <div className="rounded-xl border border-emerald-200 bg-emerald-50/50 px-3 py-2 mb-3 text-sm">
    <div className="flex items-center gap-2 flex-wrap"><span className="font-bold text-emerald-900">ℹ {m.name}</span><span className="text-xs rounded-full bg-white border px-2 py-0.5">Phòng: {m.dept}</span><span className="text-xs text-slate-600">Dùng cho: {m.users}</span><button className="ml-auto text-xs underline text-slate-600" onClick={toggle}>{open ? "thu gọn" : "trang này để làm gì?"}</button></div>
    {open && <div className="mt-2 grid md:grid-cols-3 gap-3"><div><div className="text-xs font-bold text-slate-500 uppercase">Để làm gì</div><div>{m.purpose}</div>{m.kpis && <div className="text-xs text-slate-600 mt-1">KPI: {m.kpis.join(" · ")}</div>}</div><div><div className="text-xs font-bold text-slate-500 uppercase">Quy trình</div><ol className="list-decimal ml-4">{m.steps.map((s, i) => <li key={i}>{s}</li>)}</ol></div><div><div className="text-xs font-bold text-slate-500 uppercase">Bắt đầu từ đâu</div><div>{m.start}</div>{m.sops && <div className="text-xs mt-1">SOP/quy trình: {m.sops.map((c) => <a key={c} className="underline mr-1" href={`/to-chuc?tab=sop&q=${c}`}>{c}</a>)}</div>}</div></div>}
  </div>;
}
''')
# 3) Page renders intro
rw("src/components/withSession.tsx", lambda s: s.replace('import { canPage } from "@/lib/roles";','import { canPage } from "@/lib/roles";\nimport ModuleIntro from "@/components/ModuleIntro";',1).replace('  return <Shell sess={sess} title={title}>{children(sess)}</Shell>;\n}','  return <Shell sess={sess} title={title}><ModuleIntro path={path.split("?")[0]} />{children(sess)}</Shell>;\n}',1))
# 4) Shell: phòng của tôi lên đầu; item title tooltips; mobile nav theo dept
def sh(s):
    s=s.replace('  const zones = ZONES.filter((z) => z.roles.includes(sess.role) || z.roles.includes("*")).map((z) => ({ ...z, items: z.items.filter((i) => !i.roles || i.roles.includes(sess.role)) })).filter((z) =>',
                '  const myDept = sess.dept ?? ""; const zonesRaw = ZONES.filter((z) => z.roles.includes(sess.role) || z.roles.includes("*")).map((z) => ({ ...z, items: z.items.filter((i) => !i.roles || i.roles.includes(sess.role)) })).filter((z) =>',1)
    # find the end of that statement to append sorting: locate 'z.items.length);' following
    s=s.replace('.filter((z) => z.items.length);\n','.filter((z) => z.items.length);\n  const zones = [...zonesRaw].sort((a, b) => (a.dept === myDept && myDept ? -1 : 0) - (b.dept === myDept && myDept ? -1 : 0));\n',1)
    return s
rw("src/components/Shell.tsx", sh)
