import io, os, re
R="F:/ITRAN FARM/itran-os/"
def w(p, s): os.makedirs(os.path.dirname(R+p) or R, exist_ok=True); io.open(R+p,"w",encoding="utf-8",newline="\n").write(s); print("w",p)
def rw(p, fn): s=io.open(R+p,encoding="utf-8").read(); n=fn(s); assert n!=s, p; io.open(R+p,"w",encoding="utf-8",newline="\n").write(n); print("ok",p)
# 1) Tabs component: desktop = wrap nhiều hàng, không kéo ngang; mobile = thanh sổ xuống; hỗ trợ nhóm ("Nhóm · Tên")
w("src/components/Tabs.tsx", '''"use client";
/** Thanh tab dùng chung: desktop bọc xuống nhiều hàng (không kéo ngang), mobile = select sổ xuống. Nhãn dạng "Nhóm · Tên" tự gom nhóm trong select. */
export default function Tabs({ items, value, onChange, right }: { items: (readonly [string, string])[] | [string, string][]; value: string; onChange: (k: string) => void; right?: React.ReactNode }) {
  const groups = new Map<string, [string, string][]>();
  for (const [k, l] of items) { const i = l.indexOf(" · "); const g = i > 0 && items.length > 6 ? l.slice(0, i) : ""; if (!groups.has(g)) groups.set(g, []); groups.get(g)!.push([k, l]); }
  return (
    <div className="flex items-start gap-2">
      <select className="input sm:hidden flex-1 font-semibold" value={value} onChange={(e) => onChange(e.target.value)}>
        {[...groups.entries()].map(([g, arr]) => g ? <optgroup key={g} label={g}>{arr.map(([k, l]) => <option key={k} value={k}>{l}</option>)}</optgroup> : arr.map(([k, l]) => <option key={k} value={k}>{l}</option>))}
      </select>
      <div className="hidden sm:flex flex-wrap gap-1.5 flex-1">{items.map(([k, l]) => <button key={k} type="button" className={`px-3 py-1.5 rounded-lg text-sm font-semibold whitespace-nowrap border ${value === k ? "bg-emerald-700 text-white border-emerald-700" : "bg-white text-slate-700 border-slate-200 hover:bg-emerald-50"}`} onClick={() => onChange(k)}>{l}</button>)}</div>
      {right && <div className="shrink-0">{right}</div>}
    </div>
  );
}
''')
# 2) Thay mọi thanh tab kéo ngang bằng <Tabs>
pat = re.compile(r'<div className="flex gap-2 overflow-x-auto">\{(\[\[.*?\]\])\.map\(\(\[k, l\]\) => <button key=\{k\} className=\{`[^`]*`\} onClick=\{\(\) => (setTab\w*)\(k as typeof (\w+)\)\}>\{l\}</button>\)\}(.*?)</div>', re.S)
files = ["src/components/CaPanel.tsx","src/components/ModulePanel.tsx","src/components/panels/CanhTac.tsx","src/components/panels/CheBien.tsx","src/components/panels/Company.tsx","src/components/panels/DanPanel.tsx","src/components/panels/DuLich.tsx","src/components/panels/FinanceMore.tsx","src/components/panels/KhoPanel.tsx","src/components/panels/Ops.tsx","src/components/panels/ToChuc.tsx"]
for f in files:
    s = io.open(R+f, encoding="utf-8").read(); n = 0
    def rep(m):
        global n; n += 1
        items, setter, tabvar, rest = m.group(1), m.group(2), m.group(3), m.group(4).strip()
        right = f" right={{<>{rest}</>}}" if rest else ""
        return f'<Tabs items={{{items}}} value={{{tabvar}}} onChange={{(k) => {setter}(k as typeof {tabvar})}}{right} />'
    s2 = pat.sub(rep, s)
    if n and 'import Tabs from "@/components/Tabs";' not in s2:
        s2 = s2.replace('"use client";\n', '"use client";\nimport Tabs from "@/components/Tabs";\n', 1)
    io.open(R+f, "w", encoding="utf-8", newline="\n").write(s2); print(f, "tabs replaced:", n)
