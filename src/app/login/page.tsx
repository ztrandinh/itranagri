"use client";
import { useState } from "react";
export default function Login() {
  const [login, setLogin] = useState(""); const [pin, setPin] = useState(""); const [err, setErr] = useState<string | null>(null); const [busy, setBusy] = useState(false);
  async function go(e: React.FormEvent) {
    e.preventDefault(); setBusy(true); setErr(null);
    const r = await fetch("/api/auth/login", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ login, pin, device_id: localStorage.getItem("device_id") ?? (() => { const d = "dev-" + Math.random().toString(36).slice(2, 10); localStorage.setItem("device_id", d); return d; })() }) });
    const j = await r.json(); setBusy(false);
    if (!r.ok) { setErr(j.error === "ERR_BAD_CREDENTIALS" ? "Sai tài khoản hoặc PIN" : j.error); return; }
    const next = new URLSearchParams(location.search).get("next"); location.href = next && next.startsWith("/") ? next : j.home;
  }
  return (
    <div className="min-h-screen flex items-center justify-center bg-green-900 p-4">
      <form onSubmit={go} className="card w-full max-w-sm space-y-4">
        <div className="text-center"><div className="text-3xl font-black text-green-800">ITRAN OS</div><div className="text-stone-500 text-sm">Hệ điều hành số trang trại tuần hoàn</div></div>
        <div><label className="text-sm text-stone-600">Tài khoản (mã đăng nhập / SĐT)</label><input className="input" autoFocus autoComplete="username" value={login} onChange={(e) => setLogin(e.target.value)} placeholder="a1, gd, owner…" /></div>
        <div><label className="text-sm text-stone-600">PIN</label><input className="input text-center tracking-[0.5em] text-2xl" type="password" inputMode="numeric" autoComplete="current-password" value={pin} onChange={(e) => setPin(e.target.value)} placeholder="••••" /></div>
        {err && <div className="text-red-700 text-sm">{err}</div>}
        <button className="btn-primary w-full" disabled={busy}>Đăng nhập</button>
        <div className="text-xs text-stone-500 text-center">Dev: owner / gd / ktt-cn / a1…a11 / audit · PIN 1234</div>
      </form>
    </div>);
}
