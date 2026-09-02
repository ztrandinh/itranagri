"use client";
import QrScan from "@/components/QrScan";
/** Component chuẩn "ghi 3 chạm": Bước 1 QUÉT/CHỌN đối tượng → Bước 2 CHỌN/NHẬP giá trị → Bước 3 XÁC NHẬN → enqueue (offline-first). */
import { useEffect, useMemo, useRef, useState } from "react";
import { enqueue, newClientRef, flush, pending } from "@/lib/offline";
import { noAccent } from "@/lib/client";
import { uxTask, uxFormError } from "@/lib/ux";

export type Option = { id: string; label: string; sub?: string; meta?: Record<string, unknown> };
export type Field =
  /** options tĩnh, hoặc HÀM theo đối tượng đã chọn ở Bước 1 — dùng khi lựa chọn ở bước 2 phải
   *  khớp đối tượng (vd công thức phải cùng loài với đàn nhận) thay vì lọc kiểu random rồi bị
   *  máy chủ từ chối ở bước 3: lọc NGAY khi vừa chọn xong Bước 1, không đợi tính sau. */
  | { key: string; label: string; type: "choice"; options: Option[] | ((target: Option | null) => Option[]); required?: boolean }
  | { key: string; label: string; type: "number"; unit?: string; min?: number; max?: number; step?: number; required?: boolean; default?: number }
  | { key: string; label: string; type: "text"; required?: boolean; placeholder?: string }
  | { key: string; label: string; type: "date"; required?: boolean }
  | { key: string; label: string; type: "photo"; required?: boolean }
  | { key: string; label: string; type: "bool"; required?: boolean }
  /** Danh sách BƯỚC của SOP đang chọn — tích ĐẠT/KHÔNG cho TỪNG bước.
   *  Các bước lấy từ `target.meta.steps` (phụ thuộc đối tượng đã chọn ở Bước 1),
   *  nên không khai cứng trong spec được. */
  | { key: string; label: string; type: "steps"; required?: boolean };
export type Step = { n: number; a: string; code?: string; ok?: boolean | null };

export type ThreeTapSpec = {
  table: string;
  title: string;
  record?: { code: string; name: string; std: string };
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
  const [msgErr, setMsgErr] = useState(false);
  const [busy, setBusy] = useState(false);
  const [photoUrls, setPhotoUrls] = useState<string[]>([]);
  const uxRef = useRef<ReturnType<typeof uxTask> | null>(null);
  // Đo HEART: bắt đầu tính giờ khi người dùng thật sự bắt tay ghi (đã chọn đối tượng)
  useEffect(() => { if (step === 2 && !uxRef.current) uxRef.current = uxTask(`ghi_${spec.table}`); }, [step, spec.table]);
  // Đặt giá trị mặc định cho ô số KHI ĐỔI SANG FORM KHÁC.
  // KHÔNG được phụ thuộc vào `spec.fields` (danh tính mảng): cha dựng lại mảng này mỗi lần
  // re-render (tải danh mục, sinh việc, đếm thông báo…), nên effect bắn hàng chục lần và
  // setVals(mặc định) XOÁ SẠCH thứ công nhân vừa nhập giữa chừng — đo được 9 lần reset
  // trong 0,3s ngay sau một cú chạm. Dùng chữ ký nội dung (bảng + khoá + mặc định) để
  // chỉ reset khi thật sự đổi form.
  const fieldSig = useMemo(() => spec.table + "|" + spec.fields.map((f) => `${f.key}:${f.type === "number" ? f.default ?? "" : ""}`).join(","), [spec.table, spec.fields]);
  // useMemo khoá theo chữ ký → trả về CÙNG một đối tượng khi form không đổi, nên effect dưới chỉ chạy khi đổi form.
  const soMacDinh = useMemo(() => { const d: Record<string, unknown> = {}; for (const f of spec.fields) if (f.type === "number" && f.default != null) d[f.key] = f.default; return d;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [fieldSig]);
  useEffect(() => { setVals(soMacDinh); }, [soMacDinh]);
  // Đàn/đối tượng đổi (Bước 1 → chọn lại) → xoá NGAY lựa chọn ở Bước 2 không còn hợp lệ với đối
  // tượng mới (vd công thức của loài khác) — trước đây chỉ máy chủ từ chối lúc XÁC NHẬN (Bước 3),
  // công nhân phải điền lại từ đầu. Không đụng options tĩnh (không phụ thuộc target) hay trường khác.
  useEffect(() => {
    for (const f of spec.fields) {
      if (f.type !== "choice" || typeof f.options !== "function") continue;
      const cur = vals[f.key];
      if (cur == null) continue;
      if (!f.options(target).some((o) => o.id === cur)) setVals((v0) => { const n = { ...v0 }; delete n[f.key]; return n; });
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [target]);

  const filtered = useMemo(() => {
    const s = noAccent(search.trim());
    return s ? spec.targets.filter((t) => noAccent(t.id + " " + t.label + " " + (t.sub ?? "")).includes(s)).slice(0, 40) : spec.targets.slice(0, 40);
  }, [search, spec.targets]);

  const buocSop = (target?.meta?.steps as Step[] | undefined) ?? [];
  const missing = spec.fields.filter((f) => {
    if (!f.required) return false;
    // Ô ẢNH: ảnh lưu ở state `photoUrls` RIÊNG (không phải trong `vals`). Trước đây kiểm
    // vals[f.key] nên ảnh bắt buộc KHÔNG BAO GIỜ thoả — mọi form bắt buộc ảnh (nộp phiếu giấy…)
    // không thể hoàn thành dù công nhân đã chụp và ảnh đã lên máy chủ. Kiểm đúng nguồn photoUrls.
    if (f.type === "photo") return photoUrls.length === 0;
    // Ô "steps": phải trả lời ĐỦ mọi bước, không được để sót bước nào.
    if (f.type === "steps") { const ds = (vals[f.key] as Step[] | undefined) ?? []; return buocSop.length > 0 && ds.filter((x) => x.ok != null).length < buocSop.length; }
    return vals[f.key] == null || vals[f.key] === "";
  }).map((f) => (f.type === "steps" ? `${f.label} (còn ${buocSop.length - (((vals[f.key] as Step[] | undefined) ?? []).filter((x) => x.ok != null).length)} bước chưa chấm)` : f.label));

  async function submit() {
    if (!target) return;
    setBusy(true);
    try {
      const base: Record<string, unknown> = { client_ref: newClientRef(), ts: new Date().toISOString(), [spec.targetKey]: target.id, ...vals };
      if (photoUrls.length) base.photo_urls = photoUrls;
      if (spec.paper?.serial) { base.source = "PAPER"; base.paper_serial = spec.paper.serial; base.is_backfill = true; }
      const ev = spec.build ? spec.build(target, base) : base;
      const q = await enqueue(spec.table, ev);

      // KHÔNG báo "Đã ghi" ngay sau khi xếp hàng. Trước đây làm vậy nên khi máy chủ TỪ CHỐI
      // bản ghi (đo được: khoá ngoại checklist_runs_sop_code_fkey chặn, CSDL 0 dòng) màn hình
      // vẫn hiện "Đã ghi …" — công nhân tưởng xong, thực tế mất trắng. Nay đợi gửi rồi mới kết luận.
      await flush().catch(() => {});
      const conNam = (await pending()).find((p) => p.key === q.key);

      // Còn kẹt trong hàng đợi VÀ máy chủ đã TỪ CHỐI vì dữ liệu (không phải lỗi mạng):
      // giữ nguyên bước 3, báo ĐỎ để công nhân sửa. Lỗi mạng thì rơi xuống nhánh "đã lưu, sẽ gửi".
      if (conNam && conNam.last_error && !conNam.net_error) {
        uxFormError(`ghi_${spec.table}`, conNam.last_error.slice(0, 40));
        setMsgErr(true);
        setMsg(`CHƯA GHI ĐƯỢC — máy chủ từ chối: ${conNam.last_error}. Bản ghi đang giữ trong máy, sửa lại rồi gửi tiếp; báo tổ trưởng nếu lặp lại.`);
        return;
      }

      setMsgErr(false);
      uxRef.current?.done(); uxRef.current = null;
      setMsg(conNam
        ? `Đã lưu trong máy (chưa có mạng) · ${spec.title} · ${target.label} — sẽ tự gửi khi có mạng.`
        : `Đã ghi ${spec.title} · ${target.label} · ${new Date().toLocaleTimeString("vi-VN")}`);
      setStep(1); setTarget(null); setSearch(""); setVals({}); setPhotoUrls([]);
      spec.onDone?.();
    } catch (e) {
      // Không để treo nút: validate (spec.build) hoặc enqueue có thể ném lỗi → báo rõ, giữ nguyên bước để sửa.
      uxFormError(`ghi_${spec.table}`, (e as Error)?.message?.slice(0, 40) || "unknown");
      setMsgErr(true);
      setMsg("Chưa ghi được: " + ((e as Error)?.message || "lỗi không xác định") + " — kiểm tra lại số liệu rồi thử lại.");
    } finally {
      setBusy(false);
    }
  }

  /** Đọc cân qua Web Bluetooth (Android Chrome): thiết bị phát số qua đặc tính notify (UART/GATT), parse số đầu tiên. Cấu hình service/characteristic ở settings ble.scale (mặc định Nordic UART). */
  async function readBleScale(key: string) {
    try {
      const nav = navigator as Navigator & { bluetooth?: { requestDevice: (o: unknown) => Promise<{ gatt?: { connect: () => Promise<{ getPrimaryService: (s: string) => Promise<{ getCharacteristic: (c: string) => Promise<{ startNotifications: () => Promise<void>; addEventListener: (e: string, f: (ev: Event) => void) => void; }> }> }> } }> } };
      if (!nav.bluetooth) { setMsg("Trình duyệt không hỗ trợ Bluetooth (dùng Android Chrome)"); return; }
      const svc = localStorage.getItem("ble.service") ?? "6e400001-b5a3-f393-e0a9-e50e24dcca9e", chr = localStorage.getItem("ble.char") ?? "6e400003-b5a3-f393-e0a9-e50e24dcca9e";
      const dev = await nav.bluetooth.requestDevice({ acceptAllDevices: true, optionalServices: [svc] });
      const server = await dev.gatt!.connect(); const ch = await (await server.getPrimaryService(svc)).getCharacteristic(chr);
      await ch.startNotifications(); setMsg("Đang đọc cân… (đứng yên 2 giây)");
      ch.addEventListener("characteristicvaluechanged", (ev: Event) => { const dv = (ev.target as unknown as { value: DataView }).value; const txt = new TextDecoder().decode(dv); const m = txt.match(/-?\d+(?:[.,]\d+)?/); if (m) { setVals((v0) => ({ ...v0, [key]: Number(m[0].replace(",", ".")) })); setMsg(`Cân: ${m[0]}`); } });
    } catch (e) { setMsg("BLE: " + (e as Error).message); }
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
        <div><h2 className="text-xl font-bold">{spec.title}</h2>{spec.record && <div className="text-xs text-brand mt-0.5" title={spec.record.std}>📋 Ghi vào hồ sơ: <b>{spec.record.name}</b> ({spec.record.code}) · {spec.record.std}</div>}</div>
        <div className="text-sm text-muted">Bước {step}/3</div>
      </div>
      {msg && <div role="status" aria-live="polite" className={`mb-2 rounded-xl border px-3 py-2 ${msgErr ? "bg-danger-soft-tok border-danger-tok text-danger-tok" : "bg-brand-soft border-brand-soft text-brand"}`}>{msg}</div>}
      {step === 1 && (
        <div>
          <label className="block text-sm text-muted mb-1">{spec.targetLabel}</label>
          <div className="flex gap-2"><QrScan onResult={(v) => setSearch(v)} /><input className="input" autoFocus placeholder="Quét QR/RFID hoặc gõ mã / tên (không dấu được)" aria-label="Quét QR/RFID hoặc gõ mã / tên (không dấu được)" value={search} onChange={(e) => setSearch(e.target.value)}
            onKeyDown={(e) => { if (e.key === "Enter") { const exact = spec.targets.find((t) => t.id.toLowerCase() === search.trim().toLowerCase() || t.meta?.rfid === search.trim() || t.meta?.visual_tag?.toString().toLowerCase() === search.trim().toLowerCase()); if (exact) { setTarget(exact); setStep(2); } else if (spec.allowScanInput && search.trim()) { setTarget({ id: search.trim(), label: search.trim() }); setStep(2); } } }} /></div>
          <div className="mt-2 grid grid-cols-2 sm:grid-cols-3 gap-2 max-h-[50vh] overflow-auto">
            {filtered.map((t) => (
              <button key={t.id} className="btn-secondary !py-3 !text-base flex-col items-start" onClick={() => { setTarget(t); setStep(2); }}>
                <span className="font-semibold">{t.label}</span>{t.sub && <span className="text-xs text-muted">{t.sub}</span>}
              </button>))}
            {!filtered.length && <div className="col-span-full text-muted py-6 text-center">{spec.allowScanInput ? (search.trim() ? "Chưa có trong danh sách — bấm nút xanh bên dưới để dùng mã vừa gõ." : `Quét mã, hoặc gõ ${spec.targetLabel.toLowerCase()} vào ô trên.`) : "Chưa có đối tượng nào để chọn — báo tổ trưởng."}</div>}
          </div>
          {/* Trước đây lối đi duy nhất khi danh sách rỗng (vd bảo vệ ghi "Nhật ký cổng", đối tượng là
              biển số xe nên không thể có sẵn danh sách) là bấm phím Enter — trên bàn phím điện thoại
              phím đó ghi "Xong"/"Go", công nhân gõ xong không thấy nút nào và tắc hẳn. Nay có nút rõ ràng. */}
          {spec.allowScanInput && search.trim() && !filtered.some((t) => t.id.toLowerCase() === search.trim().toLowerCase()) && (
            <button className="btn-primary w-full mt-2 !py-3" onClick={() => { setTarget({ id: search.trim(), label: search.trim() }); setStep(2); }}>Dùng “{search.trim()}” → Tiếp</button>)}
        </div>)}
      {step === 2 && target && (
        <div className="space-y-4">
          <div className="rounded-xl bg-surface-2 px-3 py-2 flex justify-between items-center"><span><b>{target.label}</b> {target.sub && <span className="text-muted text-sm">· {target.sub}</span>}</span><button className="underline text-sm" onClick={() => setStep(1)}>đổi</button></div>
          {spec.fields.map((f) => (
            <div key={f.key}>
              <label className="block text-sm text-muted mb-1">{f.label}{f.required && " *"}</label>
              {f.type === "choice" && (
                <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                  {(typeof f.options === "function" ? f.options(target) : f.options).map((o) => <button key={o.id} className={`btn !py-3 !text-base ${vals[f.key] === o.id ? "bg-brand-tok text-white" : "bg-surface border border-line"}`} onClick={() => setVals((v0) => ({ ...v0, [f.key]: o.id }))}>{o.label}</button>)}
                </div>)}
              {f.type === "number" && (
                <div className="flex items-center gap-2">
                  <button className="btn-secondary !px-4" onClick={() => setVals((v0) => ({ ...v0, [f.key]: Math.max(f.min ?? -1e9, Number(v0[f.key] ?? 0) - (f.step ?? 1)) }))}>−</button>
                  <input type="number" inputMode="decimal" className="input text-center text-2xl font-bold" value={(vals[f.key] as number) ?? ""} min={f.min} max={f.max} step={f.step ?? "any"} onChange={(e) => setVals((v0) => ({ ...v0, [f.key]: e.target.value === "" ? undefined : Number(e.target.value) }))} />
                  <button className="btn-secondary !px-4" onClick={() => setVals((v0) => ({ ...v0, [f.key]: Number(v0[f.key] ?? 0) + (f.step ?? 1) }))}>+</button>
                  {f.unit && <span className="text-muted w-16">{f.unit}</span>}
                  {f.unit === "kg" && <button type="button" className="btn-secondary !px-3 !py-2 !text-sm" title="Đọc từ cân Bluetooth" onClick={() => readBleScale(f.key)}>⚖ BLE</button>}
                </div>)}
              {f.type === "text" && <input className="input" placeholder={f.placeholder} value={(vals[f.key] as string) ?? ""} onChange={(e) => setVals((v0) => ({ ...v0, [f.key]: e.target.value }))} />}
              {f.type === "date" && <input type="date" className="input" value={(vals[f.key] as string) ?? ""} onChange={(e) => setVals((v0) => ({ ...v0, [f.key]: e.target.value }))} />}
              {f.type === "bool" && <button className={`btn !py-3 ${vals[f.key] ? "bg-brand-tok text-white" : "bg-surface border"}`} onClick={() => setVals((v0) => ({ ...v0, [f.key]: !v0[f.key] }))}>{vals[f.key] ? "✓ Có" : "Không"}</button>}
              {/* Checklist THẬT: từng bước SOP một dòng, chấm riêng. Trước đây cả quy trình
                  chỉ có MỘT công tắc "Tất cả bước ĐẠT" — một cú bấm như vậy không phải bằng
                  chứng tuân thủ, và không ai biết bước nào hỏng. */}
              {f.type === "steps" && (buocSop.length === 0
                ? <div className="rounded-xl border border-amber-300 bg-warning-soft-tok px-3 py-2 text-sm text-warning-tok">Quy trình này chưa khai bước nào — báo tổ trưởng bổ sung SOP trước khi ghi.</div>
                : <div className="space-y-1">
                    <div className="flex gap-2 mb-1">
                      <button className="btn-secondary !py-2 !text-sm flex-1" onClick={() => setVals((v0) => ({ ...v0, [f.key]: buocSop.map((b) => ({ ...b, ok: true })) }))}>Chấm tất cả ĐẠT</button>
                      <button className="btn-secondary !py-2 !text-sm" onClick={() => setVals((v0) => ({ ...v0, [f.key]: [] }))}>Xoá chấm</button>
                    </div>
                    {buocSop.map((b) => {
                      const ds = (vals[f.key] as Step[] | undefined) ?? [];
                      const cur = ds.find((x) => x.n === b.n)?.ok ?? null;
                      const dat = (ok: boolean) => setVals((v0) => {
                        const cu = ((v0[f.key] as Step[] | undefined) ?? []).filter((x) => x.n !== b.n);
                        return { ...v0, [f.key]: [...cu, { ...b, ok }].sort((x, y) => x.n - y.n) };
                      });
                      return (
                        <div key={b.n} className={`flex items-center gap-2 rounded-xl border px-2 py-1.5 ${cur === false ? "border-danger-tok bg-danger-soft-tok" : cur === true ? "border-green-300 bg-brand-soft" : "border-line"}`}>
                          <span className="text-sm text-muted w-6 shrink-0">{b.n}.</span>
                          <span className="flex-1 text-sm">{b.a}</span>
                          <button className={`btn !py-1.5 !px-3 !text-sm ${cur === true ? "bg-brand-tok text-white" : "bg-surface border border-line"}`} onClick={() => dat(true)} aria-label={`Bước ${b.n} đạt`}>Đạt</button>
                          <button className={`btn !py-1.5 !px-3 !text-sm ${cur === false ? "bg-red-700 text-white" : "bg-surface border border-line"}`} onClick={() => dat(false)} aria-label={`Bước ${b.n} không đạt`}>Không</button>
                        </div>);
                    })}
                  </div>)}
              {f.type === "photo" && (<div className="flex items-center gap-2"><input type="file" accept="image/*" capture="environment" onChange={(e) => e.target.files?.[0] && uploadPhoto(e.target.files[0])} />{photoUrls.map((u) => <img key={u} src={u} alt="" loading="lazy" className="h-12 w-12 object-cover rounded" />)}</div>)}
            </div>))}
          <div className="flex gap-2"><button className="btn-secondary flex-1" onClick={() => setStep(1)}>← Quay lại</button><button className="btn-primary flex-1" disabled={missing.length > 0} onClick={() => setStep(3)}>{missing.length ? `Thiếu: ${missing.join(", ")}` : "Tiếp →"}</button></div>
        </div>)}
      {step === 3 && target && (
        <div className="space-y-3">
          <div className="rounded-xl bg-brand-soft border border-brand-soft p-3">
            <div className="text-sm text-muted">Xác nhận ghi</div>
            <div className="text-lg font-bold">{spec.title} · {target.label}</div>
            <ul className="text-base mt-1">{spec.fields.filter((f) => vals[f.key] != null && vals[f.key] !== "").map((f) => <li key={f.key}>{f.label}: <b>{f.type === "choice" ? (typeof f.options === "function" ? f.options(target) : f.options).find((o) => o.id === vals[f.key])?.label : String(vals[f.key])}</b>{f.type === "number" && f.unit ? ` ${f.unit}` : ""}</li>)}{photoUrls.length > 0 && <li>Ảnh: {photoUrls.length}</li>}{spec.paper?.serial && <li>Từ phiếu giấy: <b>{spec.paper.serial}</b></li>}</ul>
          </div>
          <div className="flex gap-2"><button className="btn-secondary flex-1" onClick={() => setStep(2)}>← Sửa</button><button className="btn-primary flex-1 !text-xl" disabled={busy} onClick={submit}>✓ XÁC NHẬN</button></div>
        </div>)}
    </div>
  );
}
