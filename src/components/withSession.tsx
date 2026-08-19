import { redirect } from "next/navigation";
import { headers } from "next/headers";
import { canPage } from "@/lib/roles";
import ModuleIntro from "@/components/ModuleIntro";
import TodayBar from "@/components/TodayBar";
import PageNav from "@/components/PageNav";
import { getSession } from "@/lib/auth";
import Shell, { type Sess } from "@/components/Shell";
/** Server wrapper: lấy session, bọc Shell. */
export async function Page({ title, children }: { title?: string; children: (s: Sess) => React.ReactNode }) {
  const s = await getSession();
  if (!s) redirect("/login");
  // Chép TỪNG TRƯỜNG nên hễ thêm trường mới vào Session mà quên ở đây là nó biến mất im lặng
  // (đã dính: account + positionCode rơi mất, khiến màn Ca vẫn phải dò chữ để chọn bộ form).
  const sess: Sess = { staffId: s.staffId, staffName: s.staffName, role: s.role, position: s.position, dept: s.dept ?? null, farmId: s.farmId, farmIds: s.farmIds, orgId: s.orgId, account: s.account ?? null, positionCode: s.positionCode ?? null };
  const path = (await headers()).get("x-pathname") ?? ""; if (path && !canPage(path, sess.role)) return <Shell sess={sess} title={title}><div className="card"><b>Không có quyền xem trang này</b><div className="text-sm text-slate-600 mt-1">Vai <b>{sess.role}</b> không thuộc phạm vi {path}. Liên hệ quản trị nếu cần cấp quyền.</div></div></Shell>;
  return <Shell sess={sess} title={title}><PageNav dept={sess.dept} title={title} /><TodayBar /><ModuleIntro path={path.split("?")[0]} />{children(sess)}</Shell>;
}
