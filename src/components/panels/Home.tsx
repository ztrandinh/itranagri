"use client";
import type { Sess } from "@/components/Shell";
import { ZONES } from "@/components/Shell";
import { MODULES } from "@/lib/modules";
import { Search } from "@/components/Search";
/** TRANG CHỦ theo KHU VỰC: mỗi khu = 1 ô lớn, dễ bấm trên điện thoại; chỉ hiện khu vai được vào */
export default function Home({ sess }: { sess: Sess }) {
  const myDept = sess.dept ?? ""; const zones = ZONES.filter((z) => z.roles.includes(sess.role) || z.roles.includes("*")).sort((a, b) => ((a.key === "me" ? 0 : myDept && a.dept === myDept ? 1 : 2) - (b.key === "me" ? 0 : myDept && b.dept === myDept ? 1 : 2)));
  return (<div className="space-y-4">
    <div className="card"><div className="font-bold mb-1">Tìm mọi đối tượng — gõ tên/mã: con bò, ô ruộng, mặt hàng, người, khách, thiết bị…</div><Search big /></div>
    <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-3">{zones.map((z) => <div key={z.key} className={`card ${myDept && z.dept === myDept ? "ring-2 ring-emerald-500" : ""}`}><div className="text-lg font-black">{z.icon} {z.label}{myDept && z.dept === myDept ? <span className="ml-2 text-xs rounded bg-emerald-600 text-white px-2 py-0.5 align-middle">phòng của tôi</span> : null}</div><div className="text-xs text-stone-500 mb-2">{z.desc}</div><div className="flex flex-wrap gap-1">{z.items.filter((i) => !i.roles || i.roles.includes(sess.role)).map((i) => <a key={i.href} href={i.href} title={MODULES[i.href.split("?")[0]]?.purpose ?? ""} className="px-3 py-1.5 rounded-xl bg-stone-100 hover:bg-green-100 text-sm font-semibold">{i.label}</a>)}</div></div>)}</div>
  </div>);
}
