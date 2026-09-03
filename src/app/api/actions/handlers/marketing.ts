import type { PoolClient } from "pg";
import type { Session } from "@/lib/auth";
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type B = any;
export type ActionHandler = (c: PoolClient, s: Session, b: B) => Promise<unknown>;

export const mktCampaign: ActionHandler = async (c, s, b) => {
  if (b.id) { const sets: string[] = []; const vals: unknown[] = [b.id, s.farmId]; for (const k of ["name","status","budget","ends_on","starts_on","objective","audience","kpi_target","channels","note"]) if (b[k] !== undefined) { vals.push(k === "kpi_target" ? JSON.stringify(b[k]) : b[k]); sets.push(`${k}=$${vals.length}`); } if (sets.length) await c.query(`update mkt_campaigns set ${sets.join(",")} where id=$1 and farm_id=$2`, vals); return { ok: true }; }
          const r = await c.query("insert into mkt_campaigns(farm_id,code,name,objective,channels,audience,starts_on,ends_on,budget,kpi_target,status,owner_id,utm_code,created_by) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$12) returning id", [s.farmId, b.code, b.name, b.objective ?? null, b.channels ?? [], b.audience ?? null, b.starts_on ?? null, b.ends_on ?? null, Number(b.budget ?? 0), JSON.stringify(b.kpi_target ?? {}), b.status ?? "NHAP", s.staffId, String(b.code ?? "").toLowerCase()]); return { ok: true, id: r.rows[0].id };
};

export const mktContent: ActionHandler = async (c, s, b) => {
  if (b.id) { const sets: string[] = []; const vals: unknown[] = [b.id, s.farmId]; for (const k of ["status","approved_by","url","metrics","title","brief","planned_at","channel","kind","campaign_id","cost","note"]) if (b[k] !== undefined) { vals.push(k === "metrics" ? JSON.stringify(b[k]) : b[k]); sets.push(`${k}=$${vals.length}`); } if (b.status === "DUYET") { vals.push(s.staffId); sets.push(`approved_by=$${vals.length}`, "approved_at=now()"); } if (sets.length) await c.query(`update mkt_contents set ${sets.join(",")} where id=$1 and farm_id=$2`, vals); return { ok: true }; }
          const r = await c.query("insert into mkt_contents(farm_id,campaign_id,planned_at,channel,kind,title,brief,author_id,created_by,status) values ($1,$2,$3,$4,$5,$6,$7,$8,$8,'Y_TUONG') returning id", [s.farmId, b.campaign_id ?? null, b.planned_at, b.channel, b.kind ?? "BAI_VIET", b.title, b.brief ?? null, s.staffId]); return { ok: true, id: r.rows[0].id };
};

export const mktAsset: ActionHandler = async (c, s, b) => {
  await c.query("insert into mkt_assets(farm_id,kind,title,url,tags,version,created_by) values ($1,$2,$3,$4,$5,$6,$7)", [s.farmId, b.kind, b.title, b.url ?? null, b.tags ?? [], b.version ?? null, s.staffId]); return { ok: true };
};

export const mktAssetApprove: ActionHandler = async (c, s, b) => {
  if (!["tech_head","team_lead","director","owner"].includes(s.role)) throw new Error("ERR_FORBIDDEN_ROLE"); await c.query("update mkt_assets set approved=true, approved_by=$3 where id=$1 and farm_id=$2 and created_by is distinct from $3", [b.id, s.farmId, s.staffId]); return { ok: true };
};

export const mktMention: ActionHandler = async (c, s, b) => {
  const r = await c.query("insert into mkt_mentions(farm_id,channel,source_url,author,summary,sentiment,severity,created_by) values ($1,$2,$3,$4,$5,$6,$7,$8) returning id", [s.farmId, b.channel, b.source_url ?? null, b.author ?? null, b.summary, b.sentiment ?? "TRUNG_TINH", b.severity ?? "THAP", s.staffId]); return { ok: true, id: r.rows[0].id };
};

export const mktMentionUpdate: ActionHandler = async (c, s, b) => {
  await c.query("update mkt_mentions set status=$3, response=coalesce($4,response), handler_id=$5, resolved_at=case when $3='DONG' then now() else resolved_at end where id=$1 and farm_id=$2", [b.id, s.farmId, b.status, b.response ?? null, s.staffId]); if (b.status === "DONG") await c.query("update tasks set status='XONG', done_by=$3, done_at=now() where farm_id=$1 and ref_table='mkt_mentions' and ref_id=$2 and status<>'XONG'", [s.farmId, b.id, s.staffId]); return { ok: true };
};

