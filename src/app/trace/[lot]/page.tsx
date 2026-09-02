import { headers } from "next/headers";
type Ev = { ts: string; event_type: string; value: number | null; unit: string | null };
type Chain = {
  ancestors?: string[]; descendants?: string[];
  batches?: { batch_code: string; input_lot: string; output_lot: string; ts: string }[];
  origins_harvest?: { lot_id: string; plot_id: string; crop: string; variety: string | null; ts: string; phi_ok: boolean | null; harvest_lot: string | null }[];
  origins_purchase?: { lot_id: string; ts: string; from: string | null; qty: number; unit: string }[];
  exits_sale?: { lot_id: string; ts: string; qty: number; unit: string; partner: string | null; channel: number }[];
  exits_feeding?: { lot_id: string; ts: string; dest: string | null; qty: number; unit: string }[];
};
export default async function Trace({ params }: { params: Promise<{ lot: string }> }) {
  const { lot } = await params; const h = await headers(); const host = h.get("host") ?? "localhost:3111";
  const r = await fetch(`http://${host}/api/public/trace/${lot}`, { cache: "no-store" }); const j = await r.json();
  return (
    <div className="min-h-screen bg-brand-soft p-4"><div className="max-w-xl mx-auto space-y-3">
      <div className="text-center"><div className="text-2xl font-black text-brand">ITRAN FARM</div><div className="text-sm text-muted">Quét mã xem hành trình sản phẩm · &quot;{j.story ?? "Một vòng tròn — không gì bị bỏ đi."}&quot;</div></div>
      {j.kind === "LOT" && (<div className="card"><h1 className="text-xl font-bold">{j.lot.product}</h1><div className="text-sm">Lô <b>{j.lot.lot_no}</b> · SX {j.lot.mfg_date ?? "—"} · HSD {j.lot.expiry_date ?? "—"} · <span className={j.lot.status === "KHA_DUNG" ? "b-grn" : "b-red"}>{j.lot.status === "KHA_DUNG" ? "Đang lưu hành" : j.lot.status}</span></div><div className="text-sm mt-1">Trại: {j.lot.farm} ({j.lot.province})</div>
        {(() => { const c = (j.chain ?? {}) as Chain; const harvest = c.origins_harvest ?? []; const purchase = c.origins_purchase ?? []; const batches = c.batches ?? []; const sale = c.exits_sale ?? []; const feed = c.exits_feeding ?? [];
          return (<>
            <h2 className="font-semibold mt-3">Nguồn gốc</h2><ul className="text-sm list-disc pl-5">
              {harvest.map((h, k) => <li key={"h" + k}>Thu hoạch <b>{h.crop}</b>{h.variety ? ` (${h.variety})` : ""} tại ruộng {h.plot_id} ({new Date(h.ts).toLocaleDateString("vi-VN")}){h.phi_ok === false ? " — ⚠ chưa đủ thời gian cách ly PHI" : ""}</li>)}
              {purchase.map((pu, k) => <li key={"p" + k}>Nhập mua {pu.qty} {pu.unit}{pu.from ? ` từ ${pu.from}` : ""} ({new Date(pu.ts).toLocaleDateString("vi-VN")})</li>)}
              {!harvest.length && !purchase.length && <li>Sản phẩm sơ cấp từ trại (chưa có bản ghi thu hoạch/mua liên kết).</li>}
            </ul>
            {batches.length > 0 && <><h2 className="font-semibold mt-3">Chế biến</h2><ul className="text-sm list-disc pl-5">{batches.map((b, k) => <li key={k}>Nguyên liệu <b>{b.input_lot}</b> → mẻ {b.batch_code} → <b>{b.output_lot}</b> ({new Date(b.ts).toLocaleDateString("vi-VN")})</li>)}</ul></>}
            {(sale.length > 0 || feed.length > 0) && <><h2 className="font-semibold mt-3">Đi đâu</h2><ul className="text-sm list-disc pl-5">
              {sale.map((s, k) => <li key={"s" + k}>Bán {s.qty} {s.unit}{s.partner ? ` cho ${s.partner}` : ""} ({new Date(s.ts).toLocaleDateString("vi-VN")})</li>)}
              {feed.map((f, k) => <li key={"f" + k}>Dùng làm thức ăn {f.qty} {f.unit}{f.dest ? ` tại ${f.dest}` : ""} ({new Date(f.ts).toLocaleDateString("vi-VN")})</li>)}
            </ul></>}
          </>); })()}
        {(j.batches ?? []).length > 0 && <div className="text-sm mt-2">Kiểm soát an toàn (CCP): {(j.batches as { ccp_ok: boolean }[]).every((b) => b.ccp_ok) ? <span className="b-grn">đạt</span> : <span className="b-red">có điểm không đạt</span>}</div>}</div>)}
      {j.kind === "ANIMAL" && (<div className="card"><h1 className="text-xl font-bold">{j.animal.species === "BO" ? "Bò" : j.animal.species} {j.animal.visual_tag} <span className="text-sm font-normal text-muted">{j.animal.breed}</span></h1><div className="text-sm">Sinh {j.animal.birth_date ?? "—"} · {j.animal.sex === "F" ? "cái" : "đực"} · {j.animal.group_name ?? ""} · trại {j.animal.farm}</div><div className="text-sm">Cân gần nhất: <b>{j.animal.last_weight_kg ?? "—"} kg</b> ({j.animal.last_weight_at ?? ""})</div>
        <h2 className="font-semibold mt-3">Nhật ký chăm sóc (công khai)</h2><ul className="text-sm list-disc pl-5">{(j.events as Ev[] ?? []).map((e, k) => <li key={k}>{new Date(e.ts).toLocaleDateString("vi-VN")} · {e.event_type}{e.value != null ? ` ${e.value} ${e.unit ?? ""}` : ""}</li>)}</ul>
        <div className="text-xs text-muted mt-3">Chương trình &quot;chăm sóc hộ – xem live&quot;: liên hệ ITRAN FARM.</div></div>)}
      {j.error && <div className="card text-danger-tok">Không tìm thấy mã này.</div>}
      <div className="text-xs text-center text-muted">Dữ liệu từ ITRAN AGRI — bản ghi gốc không thể sửa xóa.</div>
    </div></div>);
}
