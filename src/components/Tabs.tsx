"use client";
/** Thanh tab dùng chung: desktop bọc xuống nhiều hàng (không kéo ngang), mobile = select sổ xuống. Nhãn dạng "Nhóm · Tên" tự gom nhóm trong select. */
export default function Tabs({ items, value, onChange, right }: { items: (readonly [string, string])[] | [string, string][]; value: string; onChange: (k: string) => void; right?: React.ReactNode }) {
  const groups = new Map<string, [string, string][]>();
  for (const [k, l] of items) { const i = l.indexOf(" · "); const g = i > 0 && items.length > 6 ? l.slice(0, i) : ""; if (!groups.has(g)) groups.set(g, []); groups.get(g)!.push([k, l]); }
  const idx = items.findIndex(([k]) => k === value); const go = (d: number) => { const n = items[(idx + d + items.length) % items.length]; if (n) onChange(n[0]); };
  return (
    <div className="flex items-start gap-2">
      <button type="button" className="px-2 py-1.5 rounded-lg border bg-white text-slate-600 hover:bg-emerald-50 shrink-0" title="Tab trước" onClick={() => go(-1)}>‹</button>
      <select className="input sm:hidden flex-1 font-semibold" value={value} onChange={(e) => onChange(e.target.value)}>
        {[...groups.entries()].map(([g, arr]) => g ? <optgroup key={g} label={g}>{arr.map(([k, l]) => <option key={k} value={k}>{l}</option>)}</optgroup> : arr.map(([k, l]) => <option key={k} value={k}>{l}</option>))}
      </select>
      <div className="hidden sm:flex flex-wrap gap-1.5 flex-1">{items.map(([k, l]) => <button key={k} type="button" className={`px-3 py-1.5 rounded-lg text-sm font-semibold whitespace-nowrap border ${value === k ? "bg-emerald-700 text-white border-emerald-700" : "bg-white text-slate-700 border-slate-200 hover:bg-emerald-50"}`} onClick={() => onChange(k)}>{l}</button>)}</div>
      <button type="button" className="px-2 py-1.5 rounded-lg border bg-white text-slate-600 hover:bg-emerald-50 shrink-0" title="Tab tiếp" onClick={() => go(1)}>›</button>
      {right && <div className="shrink-0">{right}</div>}
    </div>
  );
}
