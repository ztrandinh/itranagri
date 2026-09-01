"use client";
import { useEffect, useRef, useState } from "react";
/** QUÉT QR/BARCODE bằng camera điện thoại (BarcodeDetector native — Android Chrome; fallback: nhập tay). Trả về chuỗi quét được (mã cá thể/lô/SKU/URL trace → lấy phần cuối). */
export default function QrScan({ onResult, className }: { onResult: (v: string) => void; className?: string }) {
  const [open, setOpen] = useState(false); const [err, setErr] = useState(""); const videoRef = useRef<HTMLVideoElement | null>(null); const stopRef = useRef<() => void>(() => {});
  useEffect(() => {
    if (!open) return; let alive = true;
    (async () => {
      try {
        const w = window as unknown as { BarcodeDetector?: new (o?: { formats?: string[] }) => { detect: (v: HTMLVideoElement) => Promise<{ rawValue: string }[]> } };
        if (!w.BarcodeDetector) { setErr("Trình duyệt chưa hỗ trợ quét camera (dùng Chrome Android). Gõ mã tay bên dưới."); return; }
        const det = new w.BarcodeDetector({ formats: ["qr_code", "code_128", "ean_13", "code_39", "data_matrix"] });
        const stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: "environment" } }); const v = videoRef.current!; v.srcObject = stream; await v.play();
        stopRef.current = () => stream.getTracks().forEach((t) => t.stop());
        const loop = async () => { if (!alive) return; try { const codes = await det.detect(v); if (codes.length) { const raw = codes[0].rawValue; const val = raw.includes("/trace/") ? raw.split("/trace/")[1].split(/[?#]/)[0] : raw.includes("/xem/") ? decodeURIComponent(raw.split("/").pop() ?? raw) : raw; if (navigator.vibrate) navigator.vibrate(60); onResult(val); setOpen(false); return; } } catch { /* frame lỗi */ } requestAnimationFrame(loop); };
        loop();
      } catch (e) { setErr("Không mở được camera: " + (e as Error).message); }
    })();
    return () => { alive = false; stopRef.current(); };
  }, [open, onResult]);
  return (<>
    <button type="button" className={className ?? "btn-secondary !py-2 !px-3"} title="Quét QR/mã vạch bằng camera" onClick={() => { setErr(""); setOpen(true); }}>📷 Quét</button>
    {open && <div className="fixed inset-0 z-[60] bg-black/80 flex flex-col items-center justify-center p-4" onClick={() => setOpen(false)}>
      <div className="bg-surface rounded-2xl p-3 w-full max-w-md" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center mb-2"><b>Quét QR / mã vạch</b><button className="ml-auto text-xl" onClick={() => setOpen(false)}>✕</button></div>
        <video ref={videoRef} className="w-full rounded-xl bg-black aspect-square object-cover" muted playsInline />
        {err && <div className="text-sm text-danger-tok mt-2">{err}</div>}
        <input className="input mt-2" placeholder="hoặc gõ mã rồi Enter" aria-label="hoặc gõ mã rồi Enter" onKeyDown={(e) => { if (e.key === "Enter") { onResult((e.target as HTMLInputElement).value.trim()); setOpen(false); } }} />
        <div className="text-xs text-muted mt-1">Đưa QR trên thẻ tai / nhãn lô / bao bì vào khung; hỗ trợ QR, Code128, EAN-13, DataMatrix.</div>
      </div></div>}
  </>);
}
