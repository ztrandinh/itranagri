import { NextResponse } from "next/server";
import { adminPool } from "@/lib/db";
/** CÔNG KHAI: ITRAN Circular Farm Standard — điều khoản + căn cứ + cách đo + điểm từng trại (minh bạch cho hộ liên kết, khách, nhà nhập khẩu, cơ quan) */
export async function GET(req: Request) {
  const p = adminPool(); const u = new URL(req.url); const farm = u.searchParams.get("farm");
  const std = (await p.query("select code,name,issuer,version,description,pillars,levels,url from standards where code='ITRAN-STD'")).rows[0];
  const reqs = (await p.query("select clause,title,requirement,level,evidence_tables,basis,threshold,points,frequency,owner_dept from standard_requirements where standard_code='ITRAN-STD' and public order by clause")).rows;
  const farms = (await p.query("select farm_id, name, pct, level, critical_fail from v_icfs_summary" + (farm ? " where farm_id=$1" : ""), farm ? [farm] : [])).rows;
  const detail = farm ? (await p.query("select * from icfs_score($1)", [farm])).rows : [];
  const changes = (await p.query("select ts, action, pk, by_staff from audit_log where table_name in ('standards','standard_requirements') and (pk like 'ITRAN-STD%' or (after->>'standard_code')='ITRAN-STD' or (before->>'standard_code')='ITRAN-STD') order by ts desc limit 50")).rows;
  return NextResponse.json({ standard: std, requirements: reqs, farms, detail, changes, generated_at: new Date().toISOString() });
}
