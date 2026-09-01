"use client";
import { useMemo, useState } from "react";
type R = Record<string, unknown>;
type IO = { from?: string; to?: string; what?: string; via?: string };
const COLORS: Record<string, string> = { DIEU_HANH: "#334155", SAN_XUAT: "#059669", CHUOI_CUNG_UNG: "#d97706", KINH_DOANH: "#2563eb", HO_TRO: "#64748b", CHIEN_LUOC: "#7c3aed" };
const BLOCK_LABEL: Record<string, string> = { DIEU_HANH: "Điều hành", SAN_XUAT: "Sản xuất", CHUOI_CUNG_UNG: "Chuỗi cung ứng", KINH_DOANH: "Kinh doanh", HO_TRO: "Hỗ trợ", CHIEN_LUOC: "Chiến lược" };
const short = (s: unknown, n = 26) => { const t = String(s ?? ""); return t.length > n ? t.slice(0, n - 1) + "…" : t; };
const wrap = (s: string, n: number) => { const w = s.split(" "); const out: string[] = []; let cur = ""; for (const x of w) { if ((cur + " " + x).trim().length > n) { out.push(cur.trim()); cur = x; } else cur += " " + x; } if (cur.trim()) out.push(cur.trim()); return out.slice(0, 3); };

/** SƠ ĐỒ 1 QUY TRÌNH: [phòng nguồn] ⇒ bước 1 → bước 2 → … (bơi theo phòng) ⇒ [phòng nhận 1..n]. Đường link có mũi tên; 1 quy trình có thể ra 2–3 phòng. */
export function ProcessFlow({ process, steps, depts, onStep }: { process: R; steps: R[]; depts: R[]; onStep?: (s: R) => void }) {
  const inputs = (process.inputs as IO[]) ?? []; const outputs = (process.outputs as IO[]) ?? [];
  const S = [...steps].sort((a, b) => Number(a.step_no) - Number(b.step_no));
  const dname = (c?: string) => String(depts.find((d) => d.code === c)?.short ?? c ?? "?");
  const dcolor = (c?: string) => COLORS[String(depts.find((d) => d.code === c)?.block ?? "")] ?? "#64748b";
  const bw = 170, bh = 64, gap = 40, left = 200, right = 220; const n = Math.max(S.length, 1);
  const width = left + n * (bw + gap) + right; const rowsIn = Math.max(inputs.length, 1), rowsOut = Math.max(outputs.length, 1); const height = Math.max(rowsIn, rowsOut, 1) * 56 + 120;
  const cy = height / 2;
  const stepX = (i: number) => left + i * (bw + gap); const firstX = stepX(0), lastX = stepX(n - 1) + bw;
  return (
    <div className="overflow-x-auto"><svg width={Math.max(width, 700)} height={height} className="text-[12px]" style={{ fontFamily: "ui-sans-serif, system-ui" }}>
      <defs><marker id="arr" markerWidth="10" markerHeight="10" refX="9" refY="5" orient="auto"><path d="M0,0 L10,5 L0,10 z" fill="#475569" /></marker><marker id="arrg" markerWidth="10" markerHeight="10" refX="9" refY="5" orient="auto"><path d="M0,0 L10,5 L0,10 z" fill="#059669" /></marker><marker id="arrb" markerWidth="10" markerHeight="10" refX="9" refY="5" orient="auto"><path d="M0,0 L10,5 L0,10 z" fill="#2563eb" /></marker></defs>
      {/* Đầu vào */}
      {inputs.map((i, k) => { const y = cy + (k - (inputs.length - 1) / 2) * 56; return <g key={"in" + k}><rect x={8} y={y - 22} width={160} height={44} rx={8} fill="#fff7ed" stroke="#f59e0b" /><text x={16} y={y - 6} fontWeight={700} fill="#92400e">{dname(i.from)}</text><text x={16} y={y + 10} fill="#78350f">{short(i.what, 24)}</text><text x={16} y={y + 22} fill="#a16207" fontSize={10}>{short(i.via, 26)}</text><path d={`M168,${y} C ${(168 + firstX) / 2},${y} ${(168 + firstX) / 2},${cy} ${firstX - 2},${cy}`} fill="none" stroke="#475569" strokeWidth={1.5} markerEnd="url(#arr)" /></g>; })}
      {!inputs.length && <text x={16} y={cy} fill="#94a3b8">(chưa khai báo đầu vào)</text>}
      {/* Bước */}
      {S.map((s, i) => { const x = stepX(i); return <g key={String(s.id ?? i)} className="cursor-pointer" onClick={() => onStep?.(s)}>
        <rect x={x} y={cy - bh / 2} width={bw} height={bh} rx={10} fill="#ffffff" stroke={dcolor(String(s.dept_code))} strokeWidth={2} />
        <rect x={x} y={cy - bh / 2} width={bw} height={16} rx={10} fill={dcolor(String(s.dept_code))} /><text x={x + 8} y={cy - bh / 2 + 12} fill="#fff" fontSize={10} fontWeight={700}>{String(s.step_no)}. {dname(String(s.dept_code))} · {String(s.actor_role ?? "")}</text>
        {wrap(String(s.name), 26).map((l, j) => <text key={j} x={x + 8} y={cy - 4 + j * 13} fill="#0f172a" fontWeight={600}>{l}</text>)}
        {(s.tools as string[] | undefined)?.length ? <text x={x + 8} y={cy + bh / 2 - 6} fill="#64748b" fontSize={10}>🛠 {short((s.tools as string[]).join(", "), 24)}</text> : null}
        {i < n - 1 && <path d={`M${x + bw},${cy} L${x + bw + gap - 2},${cy}`} stroke="#475569" strokeWidth={1.5} markerEnd="url(#arr)" />}
        {s.parallel_group ? <text x={x + bw - 14} y={cy - bh / 2 - 4} fill="#7c3aed" fontSize={10}>∥{String(s.parallel_group)}</text> : null}
      </g>; })}
      {!S.length && <text x={left} y={cy} fill="#94a3b8">(chưa có bước — thêm ở Khai báo)</text>}
      {/* Đầu ra: 1 → n phòng */}
      {outputs.map((o, k) => { const y = cy + (k - (outputs.length - 1) / 2) * 56; const x0 = lastX + 4, x1 = width - right + 24; return <g key={"out" + k}><path d={`M${x0},${cy} C ${(x0 + x1) / 2},${cy} ${(x0 + x1) / 2},${y} ${x1 - 2},${y}`} fill="none" stroke="#059669" strokeWidth={1.5} markerEnd="url(#arrg)" /><rect x={x1} y={y - 22} width={180} height={44} rx={8} fill="#ecfdf5" stroke="#059669" /><text x={x1 + 8} y={y - 6} fontWeight={700} fill="#065f46">→ {dname(o.to)}</text><text x={x1 + 8} y={y + 10} fill="#064e3b">{short(o.what, 26)}</text><text x={x1 + 8} y={y + 22} fill="#047857" fontSize={10}>{short(o.via, 28)}</text></g>; })}
      {!outputs.length && <text x={width - right + 24} y={cy} fill="#94a3b8">(chưa khai báo đầu ra)</text>}
    </svg></div>);
}

/** SƠ ĐỒ LIÊN KẾT PHÒNG BAN: nút = phòng (theo khối), cạnh có mũi tên = luồng dữ liệu (đầu ra của quy trình A → phòng B); độ dày = số luồng; bấm phòng để lọc; hover xem chi tiết. */
export function DeptGraph({ depts, io, processes, focus, onFocus }: { depts: R[]; io: R[]; processes: R[]; focus?: string | null; onFocus?: (code: string | null) => void }) {
  const [hover, setHover] = useState<string | null>(null);
  const cols = ["DIEU_HANH", "CHIEN_LUOC", "SAN_XUAT", "CHUOI_CUNG_UNG", "KINH_DOANH", "HO_TRO"];
  const pos = useMemo(() => { const m = new Map<string, { x: number; y: number }>(); const colW = 190, top = 40; cols.forEach((b, ci) => { const list = depts.filter((d) => d.block === b); list.forEach((d, ri) => m.set(String(d.code), { x: 20 + ci * colW, y: top + ri * 74 })); }); return m; }, [depts]); // eslint-disable-line react-hooks/exhaustive-deps
  const edges = useMemo(() => { const m = new Map<string, { from: string; to: string; items: R[] }>(); for (const r of io) { const f = String(r.from_dept), t = String(r.to_dept); if (f === t || f === "*" || t === "*" || !pos.has(f) || !pos.has(t)) continue; const k = `${f}>${t}`; const e = m.get(k) ?? { from: f, to: t, items: [] }; e.items.push(r); m.set(k, e); } return [...m.values()]; }, [io, pos]);
  const height = Math.max(...[...pos.values()].map((p) => p.y)) + 90; const width = 20 + cols.length * 190 + 40;
  const active = (e: { from: string; to: string }) => !focus || e.from === focus || e.to === focus;
  const dname = (c: string) => String(depts.find((d) => d.code === c)?.short ?? c);
  return (<div className="overflow-x-auto"><svg width={Math.max(width, 900)} height={height} style={{ fontFamily: "ui-sans-serif, system-ui" }}>
    <defs><marker id="ga" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="#475569" /></marker><marker id="gaf" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="#059669" /></marker></defs>
    {cols.map((b, ci) => <text key={b} x={20 + ci * 190} y={22} fontSize={11} fontWeight={700} fill={COLORS[b]}>{BLOCK_LABEL[b] ?? b}</text>)}
    {edges.map((e) => { const a = pos.get(e.from)!, b = pos.get(e.to)!; const x0 = a.x + 160, y0 = a.y + 28, x1 = b.x, y1 = b.y + 28; const back = x1 <= x0; const path = back ? `M${a.x + 80},${a.y + 56} C ${a.x + 80},${a.y + 56 + 40} ${b.x + 80},${b.y + 56 + 40} ${b.x + 80},${b.y + 58}` : `M${x0},${y0} C ${(x0 + x1) / 2},${y0} ${(x0 + x1) / 2},${y1} ${x1 - 2},${y1}`; const on = active(e); const isH = hover === `${e.from}>${e.to}`; return <g key={e.from + e.to} onMouseEnter={() => setHover(`${e.from}>${e.to}`)} onMouseLeave={() => setHover(null)}><path d={path} fill="none" stroke={on ? (isH ? "#059669" : "#475569") : "#e2e8f0"} strokeWidth={Math.min(1 + e.items.length * 0.6, 5)} opacity={on ? 0.9 : 0.4} markerEnd={on ? (isH ? "url(#gaf)" : "url(#ga)") : undefined}><title>{`${dname(e.from)} → ${dname(e.to)} (${e.items.length} luồng)\n` + e.items.map((i) => `• ${i.what} [${i.via}] (${i.process_code})`).join("\n")}</title></path></g>; })}
    {depts.map((d) => { const p = pos.get(String(d.code)); if (!p) return null; const c = COLORS[String(d.block)] ?? "#64748b"; const on = !focus || focus === d.code || edges.some((e) => (e.from === focus && e.to === d.code) || (e.to === focus && e.from === d.code)); const nIn = edges.filter((e) => e.to === d.code).reduce((a, e) => a + e.items.length, 0), nOut = edges.filter((e) => e.from === d.code).reduce((a, e) => a + e.items.length, 0); return <g key={String(d.code)} className="cursor-pointer" onClick={() => onFocus?.(focus === d.code ? null : String(d.code))} opacity={on ? 1 : 0.35}><rect x={p.x} y={p.y} width={160} height={56} rx={10} fill={focus === d.code ? c : "#fff"} stroke={c} strokeWidth={2} /><text x={p.x + 8} y={p.y + 20} fontSize={12} fontWeight={700} fill={focus === d.code ? "#fff" : "#0f172a"}>{short(d.short ?? d.name, 22)}</text><text x={p.x + 8} y={p.y + 36} fontSize={10} fill={focus === d.code ? "#e2e8f0" : "#64748b"}>{String(d.code)} · {processes.filter((q) => q.dept_code === d.code).length} QT</text><text x={p.x + 8} y={p.y + 49} fontSize={10} fill={focus === d.code ? "#e2e8f0" : "#475569"}>vào {nIn} · ra {nOut}</text></g>; })}
  </svg>
  {hover && (() => { const e = edges.find((x) => `${x.from}>${x.to}` === hover); return e ? <div className="text-xs bg-white border rounded-lg p-2 mt-1 inline-block"><b>{dname(e.from)} → {dname(e.to)}</b>: {e.items.map((i, k) => <span key={k} className="ml-2">• {String(i.what)} <span className="text-muted">[{String(i.via)} · {String(i.process_code)}]</span></span>)}</div> : null; })()}
  </div>);
}
