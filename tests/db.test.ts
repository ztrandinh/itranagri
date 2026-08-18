/* Golden tests nền: RLS từng bảng · append-only · chặn ngưng thuốc · sinh mã · RC engine. Cần DB đang chạy (pnpm db:migrate). */
import { describe, it, expect, beforeAll, afterAll } from "vitest";
import { Client } from "pg";
import "dotenv/config";
const APP = process.env.DATABASE_URL ?? "postgres://app_user:app_user_pw@localhost:54499/itranos";
const ADMIN = process.env.DATABASE_ADMIN_URL ?? "postgres://postgres:itranos@localhost:54499/itranos";
let app: Client, admin: Client;
const ctx = async (farm: string, role: string, staff = "NS-003") => app.query("select set_config('app.org_id','ITRAN',false), set_config('app.farm_id',$1,false), set_config('app.role',$2,false), set_config('app.staff_id',$3,false), set_config('app.farm_ids',$4,false)", [farm, role, staff, role === "owner" || role === "auditor" ? "F01,F99" : farm]);
beforeAll(async () => { app = new Client({ connectionString: APP }); admin = new Client({ connectionString: ADMIN }); await app.connect(); await admin.connect(); });
afterAll(async () => { await app.end(); await admin.end(); });

describe("RLS — farm A không thấy farm B", () => {
  it("mọi bảng có farm_id đều bật RLS", async () => {
    const r = await admin.query("select c.table_name from information_schema.columns c join pg_tables t on t.tablename=c.table_name and t.schemaname='public' where c.column_name='farm_id' and c.table_schema='public' and not t.rowsecurity and c.table_name not like 'sensor_reads%' and c.table_name not in ('sessions','id_sequences','staff','farms','norms','price_list','alert_rules','settings','audit_anchors')");
    expect(r.rows.map((x) => x.table_name)).toEqual([]);
  });
  it("worker F99 thấy 0 bò của F01; worker F01 thấy đủ; auditor thấy tất cả", async () => {
    await ctx("F99", "worker", "NS-011"); expect(Number((await app.query("select count(*) from animals")).rows[0].count)).toBe(0);
    await ctx("F01", "worker", "NS-011"); expect(Number((await app.query("select count(*) from animals")).rows[0].count)).toBeGreaterThan(0);
    await ctx("F01", "auditor", "NS-030"); expect(Number((await app.query("select count(*) from animals")).rows[0].count)).toBeGreaterThan(0);
  });
  it("worker không ghi được vào trại khác", async () => {
    await ctx("F01", "worker", "NS-011");
    await expect(app.query("insert into animal_events(farm_id,animal_id,event_type,created_by,client_ref) values ('F99','F01-BO-00001','GHI_CHU','NS-011','t-rls-1')")).rejects.toThrow();
  });
});
describe("Append-only", () => {
  it("app_user không UPDATE được bảng sự kiện", async () => { await ctx("F01", "tech_head"); await expect(app.query("update animal_events set value=1 where farm_id='F01'")).rejects.toThrow(/permission denied/); });
  it("kể cả superuser không DELETE được (trigger)", async () => { await expect(admin.query("delete from animal_events where farm_id='F01' and event_type='CAN'")).rejects.toThrow(/ERR_APPEND_ONLY/); });
  it("supersede: bản mới đánh dấu bản cũ SUPERSEDED", async () => {
    await ctx("F01", "tech_head");
    const a = await app.query("insert into animal_events(farm_id,animal_id,event_type,value,created_by,client_ref) values ('F01','F01-BO-00005','CAN',350,'NS-003',$1) returning id", ["t-sup-" + Date.now()]);
    await app.query("insert into animal_events(farm_id,animal_id,event_type,value,created_by,client_ref,supersedes_id) values ('F01','F01-BO-00005','CAN',355,'NS-003',$1,$2)", ["t-sup2-" + Date.now(), a.rows[0].id]);
    expect((await app.query("select status from animal_events where id=$1", [a.rows[0].id])).rows[0].status).toBe("SUPERSEDED");
  });
});
describe("Luật nghiệp vụ", () => {
  it("chặn XUẤT khi đang ngưng thuốc (ERR_WITHDRAWAL_ACTIVE)", async () => {
    await ctx("F01", "tech_head");
    await app.query("insert into animal_events(farm_id,animal_id,event_type,withdrawal_until,created_by,client_ref) values ('F01','F01-BO-00006','DIEU_TRI',current_date+21,'NS-003',$1)", ["t-wd-" + Date.now()]);
    await expect(app.query("insert into animal_events(farm_id,animal_id,event_type,created_by,client_ref) values ('F01','F01-BO-00006','XUAT','NS-003',$1)", ["t-wd2-" + Date.now()])).rejects.toThrow(/ERR_WITHDRAWAL_ACTIVE/);
  });
  it("phiếu giấy bắt buộc paper_serial khi source=PAPER", async () => {
    await ctx("F01", "worker", "NS-011");
    await expect(app.query("insert into feed_logs(farm_id,qty_kg,source,created_by,client_ref) values ('F01',10,'PAPER','NS-011',$1)", ["t-pp-" + Date.now()])).rejects.toThrow(/ERR_PAPER_SERIAL_REQUIRED/);
  });
  it("máy sinh mã theo trại", async () => { const r = await admin.query("select next_code('F99','BO',5) as c"); expect(r.rows[0].c).toMatch(/^F99-BO-\d{5}$/); });
  it("thêm trại mới = 1 dòng farms (không sửa code)", async () => {
    await admin.query("insert into farms(id,org_id,region_id,kind,name,s_ha,k_factor) values ('F98','ITRAN','TRUNG-DU','VE_TINH','Test F98',2.5,17) on conflict do nothing");
    expect((await admin.query("select count(*) from farms where id='F98'")).rows[0].count).toBe("1");
    await admin.query("delete from farms where id='F98'");
  });
});
describe("RC engine", () => {
  it("mọi rc_rules chạy được không lỗi cú pháp", async () => {
    await ctx("F01", "it_engineer", "NS-005");
    const rules = (await app.query("select code, side_a_sql, side_b_sql from rc_rules where active")).rows;
    for (const r of rules) for (const sql of [r.side_a_sql, r.side_b_sql]) {
      const params = sql.includes("$2") ? ["F01", "2026-08-10"] : sql.includes("$1") ? ["F01"] : [];
      await expect(app.query(sql, params), r.code).resolves.toBeTruthy();
    }
  });
});
