"use client";
import { useState } from "react";
import { useData, act, maskPhone } from "@/lib/client";
import { toast } from "@/components/ui/Toast";
import type { Sess } from "@/components/Shell";
import { AttendancePanel } from "@/components/panels/More";
import { MyPath } from "@/components/panels/Career";
function Whistle() {
  const [open, setOpen] = useState(false); const [cat, setCat] = useState("BAO_CHE"); const [dept, setDept] = useState(""); const [txt, setTxt] = useState(""); const [m, setM] = useState("");
  if (!open) return <div className="text-xs text-slate-500">🛡 Thấy bao che, gian dối, lười biếng, mất an toàn? <button className="underline" onClick={() => setOpen(true)}>Phản ánh ẩn danh tới Chủ tịch/TGĐ</button> — hệ thống KHÔNG lưu người gửi.</div>;
  return <div className="card text-sm space-y-2"><b>🛡 Phản ánh ẩn danh</b> <span className="text-xs text-slate-500">— chỉ Chủ tịch/TGĐ/GĐ đọc; không lưu tên/ID người gửi (chỉ băm chống spam, tối đa 5 lượt/tuần)</span>
    <div className="flex gap-2 flex-wrap"><select className="input !py-1" value={cat} onChange={(e) => setCat(e.target.value)}>{[["BAO_CHE", "Bao che / bỏ qua lỗi"], ["GIAN_DOI", "Gian dối số liệu"], ["LUOI", "Lười / bỏ việc"], ["AN_TOAN", "Mất an toàn / dịch bệnh"], ["THAM_NHUNG", "Ăn chặn / thông đồng NCC"], ["KHAC", "Khác"]].map(([k, l]) => <option key={k} value={k}>{l}</option>)}</select><input className="input !py-1" placeholder="Phòng liên quan (tùy chọn)" aria-label="Phòng liên quan (tùy chọn)" value={dept} onChange={(e) => setDept(e.target.value)} /></div>
    <textarea className="input w-full" rows={3} placeholder="Chuyện gì, ở đâu, khi nào, ai — càng cụ thể càng dễ xác minh" aria-label="Chuyện gì, ở đâu, khi nào, ai — càng cụ thể càng dễ xác minh" value={txt} onChange={(e) => setTxt(e.target.value)} />
    <div className="flex gap-2 items-center"><button className="btn-primary !py-1" disabled={txt.length < 10} onClick={async () => { const j = await act("whistle", { category: cat, target_dept: dept || null, content: txt }); setM(j.error ? String(j.error) : "Đã gửi ẩn danh. Cảm ơn bạn."); setTxt(""); }}>Gửi ẩn danh</button><button className="btn-secondary !py-1" onClick={() => setOpen(false)}>Đóng</button><span className="text-xs">{m}</span></div></div>;
}
export default function TaiKhoan({ sess }: { sess: Sess }) {
  const staff = useData("staff"); const [o, setO] = useState(""); const [n, setN] = useState(""); const [msg, setMsg] = useState("");
  return (<div className="space-y-3">
    <MyPath sess={sess} />
    <Whistle />
    <div className="card"><div className="font-black mb-2">⏱ Chấm công · xin nghỉ · người thay khi nghỉ</div><AttendancePanel sess={sess} /></div>
    <div className="card"><h3 className="font-bold">Đổi PIN ({sess.staffName})</h3><div className="flex gap-2 flex-wrap mt-2"><input className="input !w-40" type="password" placeholder="PIN cũ" aria-label="PIN cũ" value={o} onChange={(e) => setO(e.target.value)} /><input className="input !w-40" type="password" placeholder="PIN mới (4–8 số)" aria-label="PIN mới (4–8 số)" value={n} onChange={(e) => setN(e.target.value)} /><button className="btn-primary !py-2" onClick={async () => { const j = await act("change_pin", { old_pin: o, new_pin: n }); setMsg(j.ok ? "Đã đổi PIN" : j.error); setO(""); setN(""); }}>Đổi</button></div>{msg && <div className="text-sm mt-1">{msg}</div>}</div>
    <div className="card p-0 overflow-auto"><div className="px-3 py-2 font-bold bg-stone-100 rounded-t-2xl">Nhân sự & thiết bị (mất máy → thu hồi phiên ≤1h)</div><table className="tbl"><thead><tr><th className="pl-3">Mã</th><th>Tên</th><th>Vai</th><th>Vị trí</th><th>SĐT</th><th></th></tr></thead><tbody>{(staff.rows ?? []).map((s) => <tr key={String(s.id)}><td className="pl-3 font-mono">{String(s.id)}</td><td>{String(s.full_name)}</td><td>{String(s.role)}</td><td>{String(s.position ?? "")}</td><td>{maskPhone(s.phone)}</td><td>{["director","owner","it_engineer"].includes(sess.role) && <button className="btn-secondary !py-1 !px-2 !text-sm" onClick={async () => { await act("revoke_sessions", { staff_id: s.id }); toast.ok("Đã thu hồi phiên của " + s.id); }}>Thu hồi phiên</button>}</td></tr>)}</tbody></table></div>
  </div>);
}
