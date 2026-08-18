"use client";
/** Component chuẩn "ghi 3 chạm": Bước 1 QUÉT/CHỌN đối tượng → Bước 2 CHỌN/NHẬP giá trị → Bước 3 XÁC NHẬN → enqueue (offline-first). */
import { useEffect, useMemo, useState } from "react";
import { enqueue, newClientRef } from "@/lib/offline";
import { noAccent } from "@/lib/client";

export type Option = { id: string; label: string; sub?: string; meta?: Record<string, unknown> };
export type Field =
  | { key: string; label: string; type: "choice"; options: Option[]; required?: boolean }
  | { key: string; label: string; type: "number"; unit?: string; min?: number; max?: number; step?: number; required?: boolean; default?: number }
  | { key: string; label: string; type: "text"; required?: boolean; placeholder?: string }
  | { key: string; label: string; type: "date"; required?: boolean }
  | { key: string; label: string; type: "photo"; required?: boolean }
  | { key: string; label: string; type: "bool"; required?: boolean };

export type ThreeTapSpec = {
  table: string;
  title: string;
  targetLabel: string;               // "Quét/chọn con bò", "Chọn kho"…
  targetKey: string;                 // tên trường nhận id đối tượng (animal_id, warehouse_id…)
  targets: Option[];                 // danh sách chọn (đã tải)
  allowScanInput?: boolean;          // cho nhập mã tay/quét
  fields: Field[];                   // bước 2 (tối đa 3–4 trường; ưu tiên choice)
  build?: (target: Option, values: Record<string, unknown>) => Record<string, unknown>; // biến đổi thành event
  onDone?: () => void;
  paper?: { serial?: string } | null; // nếu nhập từ phiếu giấy
};

export default function ThreeTap({ spec }: { spec: ThreeTapSpec }) {
  const [step, setStep] = useState<1 | 2 | 3>(1);
  const [target, setTarget] = useState<Option | null>(null);
  const [vals, setVals] = useState<Record<string, unknown>>({});
  const [search, setSearch] = useState("");
  const [msg, setMsg] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [photoUrls, setPhotoUrls] = useState<string[]>([]);
  useEffect(() => { const d: Record<string, unknown> = {}; for (const f of spec.fields) if (f.type === "number" && f.default != null) d[f.key] = f.default; setVals(d); }, [spec.fields]);

  const filtered = useMemo(() => {
    const s = noAccent(search.trim());
    return s ? spec.targets.filter((t) => noAccent(t.id + " " + t.label + " " + (t.sub ?? "")).includes(s)).slice(0, 40) : spec.targets.slice(0, 40);
  }, [search, spec.targets]);

  const missing = spec.fields.filter((f) => f.required && (vals[f.key] == null || vals[f.key] === "")).map((f) => f.label);

  async function submit() {
    if (!target) return;
    setBusy(true);
    const base: Record<string, unknown> = { client_ref: newClientRef(), ts: new Date().toISOString(), [spec.targetKey]: target.id, ...vals };
    if (photoUrls.length) base.photo_urls = photoUrls;
    if (spec.paper?.serial) { base.source = "PAPER"; base.paper_serial = spec.paper.serial; base.is_backfill = true; }
    const ev = spec.build ? spec.build(target, base) : base;
    await enqueue(spec.table, ev);
    setBusy(false);
    setMsg(`Đã ghi ${spec.title} · ${target.label} · ${new Date().toLocaleTimeString("vi-VN")}`);
    setStep(1); setTarget(null); setSearch(""); setVals({}); setPhotoUrls([]);
    spec.onDone?.();
  }

  async function compress(file: File): Promise<Blob> {
    // nén ảnh phía máy (≤1280px, JPEG 0.8) — mạng trại yếu, ảnh ≤300KB
    try { const bmp = await createImageBitmap(file); const k = Math.min(1, 1280 / Math.max(bmp.width, bmp.height)); const cv = document.createElement("canvas"); cv.width = Math.round(bmp.width * k); cv.height = Math.round(bmp.height * k); cv.getContext("2d")!.drawImage(bmp, 0, 0, cv.width, cv.height); return await new Promise<Blob>((res) => cv.toBlob((b) => res(b ?? file), "image/jpeg", 0.8)); } catch { return file; }
  }
  async function uploadPhoto(file: File) {
    const fd = new FormData(); fd.append("file", await compress(file), file.name.replace(/\.[^.]+$/, "") + ".jpg");
    try { const r = await fetch("/api/upload", { method: "POST", body: fd }); const j = await r.json(); if (j.url) setPhotoUrls((p) => [...p, j.url]); }
    catch { setMsg("Không tải được ảnh (offline) — bản ghi vẫn được lưu, chụp lại sau."); }
  }

  return (
    <div className="card">
      <div className="flex items-center justify-between mb-2">
        <h2 className="text-xl font-bold">{spec.title}</h2>
        <div className="text-sm text-stone-500">Bước {step}/3</div>
      </div>
      {msg && <div className="mb-2 rounded-xl bg-green-50 border border-green-200 text-green-900 px-3 py-2">{msg}</div>}
      {step === 1 && (
        <div>
          <label className="block text-sm text-stone-600 mb-1">{spec.targetLabel}</label>
          <input className="input" autoFocus placeholder="Quét QR/RFID hoặc gõ mã / tên (không dấu được)" value={search} onChange={(e) => setSearch(e.target.value)}
            onKeyDown={(e) => { if (e.key === "Enter") { const exact = spec.targets.find((t) => t.id.toLowerCase() === search.trim().toLowerCase() || t.meta?.rfid === search.trim() || t.meta?.visual_tag?.toString().toLowerCase() === search.trim().toLowerCase()); if (exact) { setTarget(exact); setStep(2); } else if (spec.allowScanInput && search.trim()) { setTarget({ id: search.trim(), label: search.trim() }); setStep(2); } } }} />
          <div className="mt-2 grid grid-cols-2 sm:grid-cols-3 gap-2 max-h-[50vh] overflow-auto">
            {filtered.map((t) => (
              <button key={t.id} className="btn-secondary !py-3 !text-base flex-col items-start" onClick={() => { setTarget(t); setStep(2); }}>
                <span className="font-semibold">{t.label}</span>{t.sub && <span className="text-xs text-stone-500">{t.sub}</span>}
              </button>))}
            {!filtered.length && <div className="col-span-full text-stone-500 py-6 text-center">Không thấy — kiểm tra mã{spec.allowScanInput ? " hoặc Enter để dùng mã vừa nhập" : ""}</div>}
          </div>
        </div>)}
      {step === 2 && target && (
        <div className="space-y-4">
          <div className="rounded-xl bg-stone-100 px-3 py-2 flex justify-between items-center"><span><b>{target.label}</b> {target.sub && <span className="text-stone-500 text-sm">· {target.sub}</span>}</span><button className="underline text-sm" onClick={() => setStep(1)}>đổi</button></div>
          {spec.fields.map((f) => (
            <div key={f.key}>
              <label className="block text-sm text-stone-600 mb-1">{f.label}{f.required && " *"}</label>
              {f.type === "choice" && (
                <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                  {f.options.map((o) => <button key={o.id} className={`btn !py-3 !text-base ${vals[f.key] === o.id ? "bg-green-700 text-white" : "bg-white border border-stone-300"}`} onClick={() => setVals({ ...vals, [f.key]: o.id })}>{o.label}</button>)}
                </div>)}
              {f.type === "number" && (
                <div className="flex items-center gap-2">
                  <button className="btn-secondary !px-4" onClick={() => setVals({ ...vals, [f.key]: Math.max(f.min ?? -1e9, Number(vals[f.key] ?? 0) - (f.step ?? 1)) })}>−</button>
                  <input type="number" inputMode="decimal" className="input text-center text-2xl font-bold" value={(vals[f.key] as number) ?? ""} min={f.min} max={f.max} step={f.step ?? "any"} onChange={(e) => setVals({ ...vals, [f.key]: e.target.value === "" ? undefined : Number(e.target.value) })} />
                  <button className="btn-secondary !px-4" onClick={() => setVals({ ...vals, [f.key]: Number(vals[f.key] ?? 0) + (f.step ?? 1) })}>+</button>
                  {f.unit && <span className="text-stone-600 w-16">{f.unit}</span>}
                </div>)}
              {f.type === "text" && <input className="input" placeholder={f.placeholder} value={(vals[f.key] as string) ?? ""} onChange={(e) => setVals({ ...vals, [f.key]: e.target.value })} />}
              {f.type === "date" && <input type="date" className="input" value={(vals[f.key] as string) ?? ""} onChange={(e) => setVals({ ...vals, [f.key]: e.target.value })} />}
              {f.type === "bool" && <button className={`btn !py-3 ${vals[f.key] ? "bg-green-700 text-white" : "bg-white border"}`} onClick={() => setVals({ ...vals, [f.key]: !vals[f.key] })}>{vals[f.key] ? "✓ Có" : "Không"}</button>}
              {f.type === "photo" && (<div className="flex items-center gap-2"><input type="file" accept="image/*" capture="environment" onChange={(e) => e.target.files?.[0] && uploadPhoto(e.target.files[0])} />{photoUrls.map((u) => <img key={u} src={u} alt="" className="h-12 w-12 object-cover rounded" />)}</div>)}
            </div>))}
          <div className="flex gap-2"><button className="btn-secondary flex-1" onClick={() => setStep(1)}>← Quay lại</button><button className="btn-primary flex-1" disabled={missing.length > 0} onClick={() => setStep(3)}>{missing.length ? `Thiếu: ${missing.join(", ")}` : "Tiếp →"}</button></div>
        </div>)}
      {step === 3 && target && (
        <div className="space-y-3">
          <div className="rounded-xl bg-green-50 border border-green-200 p-3">
            <div className="text-sm text-stone-600">Xác nhận ghi</div>
            <div className="text-lg font-bold">{spec.title} · {target.label}</div>
            <ul className="text-base mt-1">{spec.fields.filter((f) => vals[f.key] != null && vals[f.key] !== "").map((f) => <li key={f.key}>{f.label}: <b>{f.type === "choice" ? f.options.find((o) => o.id === vals[f.key])?.label : String(vals[f.key])}</b>{f.type === "number" && f.unit ? ` ${f.unit}` : ""}</li>)}{photoUrls.length > 0 && <li>Ảnh: {photoUrls.length}</li>}{spec.paper?.serial && <li>Từ phiếu giấy: <b>{spec.paper.serial}</b></li>}</ul>
          </div>
          <div className="flex gap-2"><button className="btn-secondary flex-1" onClick={() => setStep(2)}>← Sửa</button><button className="btn-primary flex-1 !text-xl" disabled={busy} onClick={submit}>✓ XÁC NHẬN</button></div>
        </div>)}
    </div>
  );
}
