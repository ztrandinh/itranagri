"use client";
import { useState } from "react";
import { useData, act, fmt } from "@/lib/client";
import type { Sess } from "@/components/Shell";
type R = Record<string, unknown>;

/** SỔ ĐỌC SỐ MÁY / CÔNG-TƠ — công nhân vận hành máy ghi số (điện·nước·biogas·sản lượng),
 *  đối chiếu SERI GIẤY (giấy bắt buộc = file cứng soát file mềm), tự bắt bất thường. */
export function MeterReadingPanel({ sess }: { sess: Sess }) {
  const latest = useData<R>("reading_latest"); const due = useData<R>("reading_due"); const metrics = useData<R>("reading_metrics"); const anomalies = useData<R>("reading_anomalies");
  const [f, setF] = useState<R | null>(null); const [msg, setMsg] = useState("");
  const rows = latest.rows ?? []; const dueRows = (due.rows ?? []).filter((d) => d.due);
  const anomRows = anomalies.rows ?? []; const anom = anomRows.length;
  const save = async () => {
    if (!f?.metric_id || f.value === "" || f.value == null) return;
    const j = await act("record_reading", { metric_id: f.metric_id, value: Number(f.value), paper_serial: f.paper_serial || null, note: f.note || null });
    if (j.error) { setMsg(String(j.error)); return; }
    setMsg(j.anomaly ? `⚠ Đã ghi — BẤT THƯỜNG: ${j.reason}. Đã tạo việc cho kỹ thuật.` : `✓ Đã ghi số. Chênh kỳ trước: ${fmt.n(j.delta)}`);
    setF(null); latest.reload(); due.reload();
  };
  return <div className="space-y-3">
    <div className="card flex items-center gap-2 flex-wrap text-sm"><b>🔌 Sổ đọc số máy / công-tơ</b>
      <span className="text-xs text-slate-500">Người vận hành ghi số điện/nước/biogas/sản lượng theo ca; ô SERI GIẤY để đối chiếu sổ tay (giấy) ↔ số. Nhảy vọt / số lùi → tự báo bất thường & tạo việc.</span>
      <button className="btn-primary !py-1 !text-xs ml-auto" onClick={() => setF({ metric_id: "", value: "", paper_serial: "", note: "" })}>＋ Ghi số đọc</button></div>

    <div className="grid grid-cols-2 md:grid-cols-4 gap-2">{[["Chỉ số theo dõi", (metrics.rows ?? []).length], ["Cần đọc (quá hạn)", dueRows.length], ["Bất thường (14 ngày)", anom], ["Nguồn giấy → số", "SERI ✓"]].map(([l, v]) => <div key={String(l)} className="card"><div className="text-xs text-slate-500">{l}</div><div className={`text-xl font-black ${l === "Bất thường (14 ngày)" && Number(v) > 0 ? "text-red-700" : l === "Cần đọc (quá hạn)" && Number(v) > 0 ? "text-amber-700" : ""}`}>{String(v)}</div></div>)}</div>

    {f && <div className="card grid sm:grid-cols-4 gap-2">
      <select className="input sm:col-span-2" value={String(f.metric_id)} onChange={(e) => setF({ ...f, metric_id: e.target.value })}><option value="">— chọn máy · chỉ số —</option>{(metrics.rows ?? []).map((m) => <option key={String(m.id)} value={String(m.id)}>{String(m.facility_name)} · {String(m.name)} ({String(m.unit)})</option>)}</select>
      <input className="input" type="number" placeholder="Số trên đồng hồ" value={String(f.value)} onChange={(e) => setF({ ...f, value: e.target.value })} />
      <input className="input" placeholder="Seri giấy (sổ tay)" value={String(f.paper_serial)} onChange={(e) => setF({ ...f, paper_serial: e.target.value })} />
      <input className="input sm:col-span-3" placeholder="Ghi chú (tùy chọn)" value={String(f.note)} onChange={(e) => setF({ ...f, note: e.target.value })} />
      <div className="sm:col-span-4 flex gap-2"><button className="btn-primary !py-1" disabled={!f.metric_id || f.value === ""} onClick={save}>Ghi số</button><button className="btn-secondary !py-1" onClick={() => setF(null)}>Hủy</button></div></div>}
    {msg && <div className={`text-sm ${msg.startsWith("⚠") ? "text-red-700" : "text-emerald-800"}`}>{msg}</div>}

    {dueRows.length > 0 && <div className="card"><div className="font-bold text-sm mb-1 text-amber-800">Cần đọc hôm nay ({dueRows.length})</div><div className="flex flex-wrap gap-2">{dueRows.map((d) => <button key={String(d.metric_id)} className="b-yel text-xs underline" onClick={() => setF({ metric_id: d.metric_id, value: "", paper_serial: "", note: "" })}>{String(d.facility_name)} · {String(d.metric_name)}</button>)}</div></div>}

    <div className="card p-0 overflow-auto"><table className="tbl text-sm"><thead><tr><th className="pl-3">Máy</th><th>Chỉ số</th><th className="text-right">Số đọc</th><th className="text-right">Chênh kỳ</th><th>Seri giấy</th><th>Lúc</th><th>Người</th><th></th></tr></thead><tbody>
      {rows.map((r) => <tr key={String(r.metric_id)} className={r.is_anomaly ? "bg-red-50" : ""}><td className="pl-3 text-xs font-semibold">{String(r.facility_name)}</td><td className="text-xs">{String(r.metric_name)}</td><td className="text-right">{fmt.n(r.value)} <span className="text-xs text-slate-400">{String(r.unit)}</span></td><td className="text-right">{fmt.n(r.delta)}</td><td className="text-xs font-mono">{String(r.paper_serial ?? "—")}</td><td className="text-xs">{fmt.d(r.ts)}</td><td className="text-xs">{String(r.reader_id ?? "")}</td><td>{r.is_anomaly ? <span className="b-red text-xs" title={String(r.anomaly_reason)}>⚠ bất thường</span> : <span className="text-emerald-600 text-xs">ổn</span>}</td></tr>)}
      {rows.length === 0 && <tr><td className="pl-3 text-sm text-slate-500 py-3" colSpan={8}>Chưa có số đọc — bấm "＋ Ghi số đọc". Cấu hình chỉ số ở Quản trị DL › reading_metrics.</td></tr>}</tbody></table></div>
    {anomRows.length > 0 && <div className="card p-0 overflow-auto"><div className="px-3 py-2 bg-red-100 rounded-t-xl font-bold text-red-800">⚠ Bất thường gần đây ({anomRows.length}) — đã tạo việc cho kỹ thuật</div><table className="tbl text-sm"><thead><tr><th className="pl-3">Lúc</th><th>Máy · chỉ số</th><th className="text-right">Số đọc</th><th className="text-right">Chênh</th><th>Nguyên nhân</th><th>Seri giấy</th></tr></thead><tbody>
      {anomRows.map((r) => <tr key={String(r.id)} className="bg-red-50"><td className="pl-3 text-xs">{fmt.d(r.ts)}</td><td className="text-xs">{String(r.facility_name)} · {String(r.metric_name)}</td><td className="text-right">{fmt.n(r.value)} {String(r.unit)}</td><td className="text-right font-bold text-red-700">{fmt.n(r.delta)}</td><td className="text-xs text-red-800">{String(r.anomaly_reason)}</td><td className="text-xs font-mono">{String(r.paper_serial ?? "—")}</td></tr>)}</tbody></table></div>}
    <div className="text-xs text-slate-500">Số đọc là bản ghi <b>append-only</b> (sửa = ghi bản mới). Sau này đầu đọc IoT/MQTT (chờ chủ đầu tư) ghi vào cùng bảng với nguồn IOT — schema không đổi.</div>
  </div>;
}

const LV: Record<string, string> = { OK: "b-grn", DUE: "b-yel", ESCALATE: "b-red" };
const LVTXT: Record<string, string> = { OK: "đúng hạn", DUE: "QUÁ HẠN", ESCALATE: "⛔ LEO THANG" };
/** CẢNH BÁO NGHIÊM NGẶT KHI KHÂU GHI CHÉP BỊ QUÊN — tab trong Giám sát */
export function RecordingCompliancePanel({ sess }: { sess: Sess }) {
  void sess; const due = useData<R>("recording_due"); const comp = useData<R>("recording_compliance"); const cov = useData<R>("control_coverage");
  const rows = due.rows ?? []; const overdue = rows.filter((r) => r.level !== "OK"); const esc = rows.filter((r) => r.level === "ESCALATE");
  const miss30 = (comp.rows ?? []).reduce((a, r) => a + Number(r.misses_30d ?? 0), 0);
  const covRows = cov.rows ?? []; const blind = covRows.filter((r) => r.blind);
  return <div className="space-y-3">
    <div className="card text-sm"><b>🚨 Khâu ghi chép bắt buộc — quên cập nhật là báo NGHIÊM NGẶT</b>
      <div className="text-xs text-slate-500 mt-0.5">Mỗi khâu (theo bảng mẫu quy trình) có tần suất ngày/tuần/tháng/đợt. Quá hạn → việc CAO cho người phụ trách; quá mức → <b>LEO THANG lên GĐ (KHẨN)</b>. Bỏ sót được ghi nhật ký để đo tỷ lệ đúng hạn — bảo vệ chất lượng dữ liệu cho phân tích/dự báo.</div></div>
    <div className="grid grid-cols-2 md:grid-cols-4 gap-2">{[["Khâu theo dõi", rows.length], ["Đang quá hạn", overdue.length], ["Đã leo thang", esc.length], ["Bỏ sót (30 ngày)", miss30]].map(([l, v]) => <div key={String(l)} className="card"><div className="text-xs text-slate-500">{l}</div><div className={`text-xl font-black ${(l === "Đang quá hạn" || l === "Bỏ sót (30 ngày)") && Number(v) > 0 ? "text-amber-700" : l === "Đã leo thang" && Number(v) > 0 ? "text-red-700" : ""}`}>{String(v)}</div></div>)}</div>
    <div className="card p-0 overflow-auto"><table className="tbl text-sm"><thead><tr><th className="pl-3">Khâu ghi chép</th><th>Phòng</th><th>Tần suất</th><th>Ghi cuối</th><th>Trạng thái</th><th className="text-right">Trễ (h)</th><th>Phụ trách</th></tr></thead><tbody>
      {rows.map((r) => <tr key={String(r.code)} className={r.level === "ESCALATE" ? "bg-red-50" : r.level === "DUE" ? "bg-amber-50" : ""}><td className="pl-3 text-xs font-semibold">{String(r.name)}</td><td className="text-xs">{String(r.dept ?? "")}</td><td className="text-xs">{({ CA: "mỗi ca", NGAY: "hằng ngày", TUAN: "hằng tuần", THANG: "hằng tháng", DOT: "theo đợt" } as Record<string, string>)[String(r.freq)] ?? String(r.freq)}</td><td className="text-xs">{r.last_ts ? fmt.d(r.last_ts) : <span className="text-red-600">chưa có</span>}</td><td><span className={`${LV[String(r.level)]} text-xs`}>{LVTXT[String(r.level)]}</span></td><td className="text-right text-xs">{Number(r.hours_late) > 0 ? fmt.n(r.hours_late) : "—"}</td><td className="text-xs">{String(r.role_hint ?? "")}</td></tr>)}
      {rows.length === 0 && <tr><td className="pl-3 py-3 text-sm text-slate-500" colSpan={7}>Chưa khai báo khâu bắt buộc — thêm ở Quản trị DL › recording_obligations.</td></tr>}</tbody></table></div>
    <div className="card p-0 overflow-auto"><div className="px-3 py-2 bg-slate-100 rounded-t-xl font-bold">Tỷ lệ đúng hạn 30 ngày (bỏ sót theo khâu)</div><table className="tbl text-sm"><thead><tr><th className="pl-3">Khâu</th><th>Phòng</th><th className="text-right">Bỏ sót 30d</th><th className="text-right">Leo thang 30d</th><th>Bỏ sót gần nhất</th></tr></thead><tbody>
      {(comp.rows ?? []).map((r) => <tr key={String(r.code)} className={Number(r.misses_30d) > 0 ? "bg-amber-50" : ""}><td className="pl-3 text-xs">{String(r.name)}</td><td className="text-xs">{String(r.dept ?? "")}</td><td className="text-right font-bold">{String(r.misses_30d)}</td><td className="text-right text-red-700">{String(r.escalated_30d)}</td><td className="text-xs">{r.last_miss ? fmt.d(r.last_miss) : "—"}</td></tr>)}</tbody></table></div>

    <div className="card text-sm"><b>🗺 Độ phủ kiểm soát — vùng mù cần chĩa kiểm ngẫu nhiên</b>
      <div className="text-xs text-slate-500 mt-0.5">Mỗi khâu đều có SOP (thực hành SX·an toàn·vệ sinh) = checklist bắt buộc. Bảng dưới soi mỗi SOP đã được <b>tick checklist / spot-check / đi ca</b> lần cuối khi nào — <b>{blind.length} SOP "mù" &gt;14 ngày</b> chưa ai kiểm (kể cả việc không sinh số) → quản lý chĩa kiểm vào đó.</div></div>
    <div className="card p-0 overflow-auto"><table className="tbl text-sm"><thead><tr><th className="pl-3">SOP (khâu)</th><th>Phòng</th><th>Tick checklist</th><th>Spot-check</th><th>Đi ca</th><th className="text-right">Lâu nhất chưa kiểm</th></tr></thead><tbody>
      {covRows.filter((r) => r.blind).slice(0, 30).map((r) => <tr key={String(r.sop)} className="bg-red-50"><td className="pl-3 text-xs font-semibold">{String(r.sop)} · {String(r.name)}</td><td className="text-xs">{String(r.dept ?? "")}</td><td className="text-xs">{r.last_checklist ? fmt.d(r.last_checklist) : <span className="text-red-600">chưa</span>}</td><td className="text-xs">{r.last_spotcheck ? fmt.d(r.last_spotcheck) : <span className="text-red-600">chưa</span>}</td><td className="text-xs">{r.last_fieldday ? fmt.d(r.last_fieldday) : <span className="text-red-600">chưa</span>}</td><td className="text-right text-xs font-bold text-red-700">{Number(r.days_since) > 3000 ? "chưa bao giờ" : fmt.n(r.days_since) + " ngày"}</td></tr>)}
      {blind.length === 0 && <tr><td className="pl-3 py-3 text-sm text-emerald-700" colSpan={6}>✓ Không có SOP nào bị bỏ quên kiểm &gt;14 ngày.</td></tr>}</tbody></table></div>
  </div>;
}
