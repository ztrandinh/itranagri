"use client";
import { useState } from "react";
import { useData, act } from "@/lib/client";
import type { Sess } from "@/components/Shell";
export default function TaiKhoan({ sess }: { sess: Sess }) {
  const staff = useData("staff"); const [o, setO] = useState(""); const [n, setN] = useState(""); const [msg, setMsg] = useState("");
  return (<div className="space-y-3">
    <div className="card"><h3 className="font-bold">Đổi PIN ({sess.staffName})</h3><div className="flex gap-2 flex-wrap mt-2"><input className="input !w-40" type="password" placeholder="PIN cũ" value={o} onChange={(e) => setO(e.target.value)} /><input className="input !w-40" type="password" placeholder="PIN mới (4–8 số)" value={n} onChange={(e) => setN(e.target.value)} /><button className="btn-primary !py-2" onClick={async () => { const j = await act("change_pin", { old_pin: o, new_pin: n }); setMsg(j.ok ? "Đã đổi PIN" : j.error); setO(""); setN(""); }}>Đổi</button></div>{msg && <div className="text-sm mt-1">{msg}</div>}</div>
    <div className="card p-0 overflow-auto"><div className="px-3 py-2 font-bold bg-stone-100 rounded-t-2xl">Nhân sự & thiết bị (mất máy → thu hồi phiên ≤1h)</div><table className="tbl"><thead><tr><th className="pl-3">Mã</th><th>Tên</th><th>Vai</th><th>Vị trí</th><th>SĐT</th><th></th></tr></thead><tbody>{(staff.rows ?? []).map((s) => <tr key={String(s.id)}><td className="pl-3 font-mono">{String(s.id)}</td><td>{String(s.full_name)}</td><td>{String(s.role)}</td><td>{String(s.position ?? "")}</td><td>{String(s.phone ?? "")}</td><td>{["director","owner","it_engineer"].includes(sess.role) && <button className="btn-secondary !py-1 !px-2 !text-sm" onClick={async () => { await act("revoke_sessions", { staff_id: s.id }); alert("Đã thu hồi phiên của " + s.id); }}>Thu hồi phiên</button>}</td></tr>)}</tbody></table></div>
  </div>);
}
