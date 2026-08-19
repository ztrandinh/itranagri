import { headers } from "next/headers";
type Inp = { input_lot: string; batch_code: string; ts: string }; type Ev = { ts: string; event_type: string; value: number | null; unit: string | null };
export default async function Trace({ params }: { params: Promise<{ lot: string }> }) {
  const { lot } = await params; const h = await headers(); const host = h.get("host") ?? "localhost:3111";
  const r = await fetch(`http://${host}/api/public/trace/${lot}`, { cache: "no-store" }); const j = await r.json();
  return (
    <div className="min-h-screen bg-green-50 p-4"><div className="max-w-xl mx-auto space-y-3">
      <div className="text-center"><div className="text-2xl font-black text-green-800">ITRAN FARM</div><div className="text-sm text-stone-600">Quét mã xem hành trình sản phẩm · &quot;{j.story ?? "Một vòng tròn — không gì bị bỏ đi."}&quot;</div></div>
      {j.kind === "LOT" && (<div className="card"><h1 className="text-xl font-bold">{j.lot.product}</h1><div className="text-sm">Lô <b>{j.lot.lot_no}</b> · SX {j.lot.mfg_date ?? "—"} · HSD {j.lot.expiry_date ?? "—"} · <span className={j.lot.status === "KHA_DUNG" ? "b-grn" : "b-red"}>{j.lot.status === "KHA_DUNG" ? "Đang lưu hành" : j.lot.status}</span></div><div className="text-sm mt-1">Trại: {j.lot.farm} ({j.lot.province})</div>
        <h2 className="font-semibold mt-3">Hành trình</h2><ul className="text-sm list-disc pl-5">{(j.inputs as Inp[] ?? []).map((i, k) => <li key={k}>Từ nguyên liệu <b>{i.input_lot}</b> qua mẻ {i.batch_code} ({new Date(i.ts).toLocaleDateString("vi-VN")})</li>)}{!(j.inputs ?? []).length && <li>Sản phẩm sơ cấp từ trại.</li>}</ul>
        {(j.batches ?? []).length > 0 && <div className="text-sm mt-2">Kiểm soát an toàn (CCP): {(j.batches as { ccp_ok: boolean }[]).every((b) => b.ccp_ok) ? <span className="b-grn">đạt</span> : <span className="b-red">có điểm không đạt</span>}</div>}</div>)}
      {j.kind === "ANIMAL" && (<div className="card"><h1 className="text-xl font-bold">{j.animal.species === "BO" ? "Bò" : j.animal.species} {j.animal.visual_tag} <span className="text-sm font-normal text-stone-500">{j.animal.breed}</span></h1><div className="text-sm">Sinh {j.animal.birth_date ?? "—"} · {j.animal.sex === "F" ? "cái" : "đực"} · {j.animal.group_name ?? ""} · trại {j.animal.farm}</div><div className="text-sm">Cân gần nhất: <b>{j.animal.last_weight_kg ?? "—"} kg</b> ({j.animal.last_weight_at ?? ""})</div>
        <h2 className="font-semibold mt-3">Nhật ký chăm sóc (công khai)</h2><ul className="text-sm list-disc pl-5">{(j.events as Ev[] ?? []).map((e, k) => <li key={k}>{new Date(e.ts).toLocaleDateString("vi-VN")} · {e.event_type}{e.value != null ? ` ${e.value} ${e.unit ?? ""}` : ""}</li>)}</ul>
        <div className="text-xs text-stone-500 mt-3">Chương trình &quot;chăm sóc hộ – xem live&quot;: liên hệ ITRAN FARM.</div></div>)}
      {j.error && <div className="card text-red-700">Không tìm thấy mã này.</div>}
      <div className="text-xs text-center text-stone-500">Dữ liệu từ ITRAN AGRI — bản ghi gốc không thể sửa xóa.</div>
    </div></div>);
}
