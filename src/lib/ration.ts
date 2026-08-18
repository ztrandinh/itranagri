/** TỐI ƯU KHẨU PHẦN GIÁ RẺ NHẤT (least-cost ration) — LP đơn hình (simplex 2 pha, dense) đủ cho ≤30 nguyên liệu × ≤12 ràng buộc.
 *  min Σ price_i·x_i  s.t. Σ nutrient_ij·x_i ≥ min_j, ≤ max_j; Σ x_i = DM mục tiêu (kg DM/ngày); lo_i ≤ x_i ≤ hi_i.  x = kg DM mỗi nguyên liệu. */
export type Ingredient = { sku: string; name: string; price_per_kg_dm: number; dm_pct?: number; nutrients: Record<string, number>; min_kg?: number; max_kg?: number };
export type Constraint = { nutrient: string; min?: number; max?: number; per: "total" | "pct" }; // pct: nutrient là % (hoặc đơn vị/kg DM) → ràng buộc trung bình có trọng số: Σ n_i·x_i ≥ min·DM
export type RationResult = { ok: boolean; cost: number; kg: Record<string, number>; nutrients: Record<string, number>; message?: string };
export function solveRation(ings: Ingredient[], dmTarget: number, cons: Constraint[]): RationResult {
  const n = ings.length; if (!n) return { ok: false, cost: 0, kg: {}, nutrients: {}, message: "không có nguyên liệu" };
  // Ràng buộc dạng a·x (≤|≥|=) b
  const rows: { a: number[]; op: "<=" | ">=" | "="; b: number }[] = [];
  rows.push({ a: ings.map(() => 1), op: "=", b: dmTarget });
  for (const c of cons) { const a = ings.map((g) => g.nutrients[c.nutrient] ?? 0); if (c.min != null) rows.push({ a, op: ">=", b: c.per === "pct" ? c.min * dmTarget : c.min }); if (c.max != null) rows.push({ a, op: "<=", b: c.per === "pct" ? c.max * dmTarget : c.max }); }
  ings.forEach((g, i) => { if (g.min_kg) rows.push({ a: ings.map((_, j) => (j === i ? 1 : 0)), op: ">=", b: g.min_kg }); if (g.max_kg != null) rows.push({ a: ings.map((_, j) => (j === i ? 1 : 0)), op: "<=", b: g.max_kg }); });
  const c = ings.map((g) => g.price_per_kg_dm);
  const x = simplex(c, rows); if (!x) return { ok: false, cost: 0, kg: {}, nutrients: {}, message: "Không có lời giải khả thi — nới ràng buộc hoặc thêm nguyên liệu" };
  const kg: Record<string, number> = {}; ings.forEach((g, i) => { if (x[i] > 1e-6) kg[g.sku] = Math.round(x[i] * 100) / 100; });
  const nutrients: Record<string, number> = {}; for (const key of new Set(ings.flatMap((g) => Object.keys(g.nutrients)))) nutrients[key] = Math.round(ings.reduce((s, g, i) => s + (g.nutrients[key] ?? 0) * x[i], 0) * 100) / 100;
  return { ok: true, cost: Math.round(ings.reduce((s, g, i) => s + g.price_per_kg_dm * x[i], 0)), kg, nutrients };
}
/** Simplex 2 pha (Big-M) minimize c·x, x ≥ 0 */
function simplex(c: number[], rows: { a: number[]; op: "<=" | ">=" | "="; b: number }[]): number[] | null {
  const n = c.length; const m = rows.length; const M = 1e6;
  // biến: x(n) + slack/surplus (một cho mỗi hàng ≤ hoặc ≥) + artificial (cho ≥ và =)
  let nSlack = 0, nArt = 0; rows.forEach((r) => { if (r.op !== "=") nSlack++; if (r.op !== "<=") nArt++; });
  const N = n + nSlack + nArt; const T: number[][] = []; const basis: number[] = [];
  let si = n, ai = n + nSlack; const artCols: number[] = [];
  for (const r of rows) { const row = new Array(N + 1).fill(0); const sign = r.b < 0 ? -1 : 1; for (let j = 0; j < n; j++) row[j] = r.a[j] * sign; const b = r.b * sign; const op = sign < 0 ? (r.op === "<=" ? ">=" : r.op === ">=" ? "<=" : "=") : r.op;
    if (op === "<=") { row[si] = 1; basis.push(si); si++; } else if (op === ">=") { row[si] = -1; si++; row[ai] = 1; basis.push(ai); artCols.push(ai); ai++; } else { row[ai] = 1; basis.push(ai); artCols.push(ai); ai++; }
    row[N] = b; T.push(row); }
  const cost = new Array(N).fill(0); for (let j = 0; j < n; j++) cost[j] = c[j]; for (const a of artCols) cost[a] = M;
  // reduced costs
  const z = new Array(N + 1).fill(0); for (let j = 0; j <= N; j++) { let s = 0; for (let i = 0; i < m; i++) s += cost[basis[i]] * T[i][j]; z[j] = (j < N ? cost[j] : 0) - s; }
  for (let it = 0; it < 500; it++) {
    let piv = -1, best = -1e-9; for (let j = 0; j < N; j++) if (z[j] < best) { best = z[j]; piv = j; } if (piv < 0) break;
    let r = -1, minR = Infinity; for (let i = 0; i < m; i++) if (T[i][piv] > 1e-9) { const q = T[i][N] / T[i][piv]; if (q < minR) { minR = q; r = i; } } if (r < 0) return null;
    const p = T[r][piv]; for (let j = 0; j <= N; j++) T[r][j] /= p; for (let i = 0; i < m; i++) if (i !== r && Math.abs(T[i][piv]) > 1e-12) { const f = T[i][piv]; for (let j = 0; j <= N; j++) T[i][j] -= f * T[r][j]; }
    const f = z[piv]; for (let j = 0; j <= N; j++) z[j] -= f * T[r][j]; basis[r] = piv;
  }
  const x = new Array(n).fill(0); for (let i = 0; i < m; i++) if (basis[i] < n) x[basis[i]] = T[i][N]; else if (artCols.includes(basis[i]) && T[i][N] > 1e-6) return null;
  return x;
}
