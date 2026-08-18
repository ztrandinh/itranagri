import { redirect } from "next/navigation";
import { getSession } from "@/lib/auth";
import Shell, { type Sess } from "@/components/Shell";
/** Server wrapper: lấy session, bọc Shell. */
export async function Page({ title, children }: { title?: string; children: (s: Sess) => React.ReactNode }) {
  const s = await getSession();
  if (!s) redirect("/login");
  const sess: Sess = { staffId: s.staffId, staffName: s.staffName, role: s.role, position: s.position, farmId: s.farmId, farmIds: s.farmIds, orgId: s.orgId };
  return <Shell sess={sess} title={title}>{children(sess)}</Shell>;
}
