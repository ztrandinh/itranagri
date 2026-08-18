import { redirect } from "next/navigation";
import { headers } from "next/headers";
import { canPage } from "@/lib/roles";
import ModuleIntro from "@/components/ModuleIntro";
import { getSession } from "@/lib/auth";
import Shell, { type Sess } from "@/components/Shell";
/** Server wrapper: lấy session, bọc Shell. */
export async function Page({ title, children }: { title?: string; children: (s: Sess) => React.ReactNode }) {
  const s = await getSession();
  if (!s) redirect("/login");
  const sess: Sess = { staffId: s.staffId, staffName: s.staffName, role: s.role, position: s.position, dept: s.dept ?? null, farmId: s.farmId, farmIds: s.farmIds, orgId: s.orgId };
  const path = (await headers()).get("x-pathname") ?? ""; if (path && !canPage(path, sess.role)) return <Shell sess={sess} title={title}><div className="card"><b>Không có quyền xem trang này</b><div className="text-sm text-slate-600 mt-1">Vai <b>{sess.role}</b> không thuộc phạm vi {path}. Liên hệ quản trị nếu cần cấp quyền.</div></div></Shell>;
  return <Shell sess={sess} title={title}><ModuleIntro path={path.split("?")[0]} />{children(sess)}</Shell>;
}
