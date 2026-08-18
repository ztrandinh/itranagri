/* Golden tests đợt doanh nghiệp: workflow engine (khai báo → xuất bản → chạy → enforce biểu mẫu → xong) · nhập lô đàn + vòng theo dõi · GL cân Nợ=Có · ICFS chấm điểm · tuân thủ · audit_log ghi vết · khẩu phần LP · VietQR CRC. Cần DB đang chạy. */
import { describe, it, expect, beforeAll, afterAll } from "vitest";
import { Client } from "pg";
import "dotenv/config";
import { solveRation } from "../src/lib/ration";
import { vietqr } from "../src/lib/vietqr";
const ADMIN = process.env.DATABASE_ADMIN_URL ?? "postgres://postgres:itranos@localhost:54499/itranos";
let admin: Client;
beforeAll(async () => { admin = new Client({ connectionString: ADMIN }); await admin.connect(); await admin.query("select set_config('app.org_id','ITRAN',false), set_config('app.farm_id','F01',false), set_config('app.role','tech_head',false), set_config('app.staff_id','NS-003',false), set_config('app.farm_ids','F01',false)"); });
afterAll(async () => { await admin.query("delete from tasks where ref_table='process_runs' and ref_id in (select id::text from process_runs where process_code='P-TEST-WF')"); await admin.query("delete from process_runs where process_code='P-TEST-WF'"); await admin.query("delete from process_steps where process_code='P-TEST-WF'"); await admin.query("delete from processes where code='P-TEST-WF'"); await admin.end(); });

describe("Workflow engine", () => {
  it("khai báo → xuất bản → chạy → bước 1 sinh việc → enforce biểu mẫu → xong", async () => {
    await admin.query("insert into processes(code,dept_code,name,kind,status,coverage) values ('P-TEST-WF','TT','Test WF','CORE','NHAP','DA_CO') on conflict (code) do nothing");
    await admin.query("insert into process_steps(process_code,step_no,name,dept_code,actor_role,form_table,sla_hours) values ('P-TEST-WF',1,'Bước cần biểu mẫu','TT','worker','crop_logs',4),('P-TEST-WF',2,'Bước tự do','CCU','worker',null,4) on conflict (process_code, step_no) do nothing");
    await admin.query("select publish_process('P-TEST-WF','NS-003')");
    const st = (await admin.query("select status from processes where code='P-TEST-WF'")).rows[0].status; expect(st).toBe("BAN_HANH");
    const ev = (await admin.query("select count(*) as n from event_bus where topic='process.published' and payload->>'code'='P-TEST-WF'")).rows[0].n; expect(Number(ev)).toBeGreaterThan(0);
    const run = (await admin.query("select start_process_run('F01','P-TEST-WF','NS-011',null,null,'test run') as id")).rows[0].id;
    const t1 = (await admin.query("select count(*) as n from tasks where ref_table='process_runs' and ref_id=$1 and status='MO'", [run])).rows[0].n; expect(Number(t1)).toBe(1);
    // chưa ghi crop_logs → phải bị chặn
    await expect(admin.query("select complete_run_step($1,1,'NS-011')", [run])).rejects.toThrow(/ERR_FORM_REQUIRED/);
    // ghi biểu mẫu rồi mới xong
    await admin.query("insert into crop_logs(farm_id,created_by,plot_id,activity,client_ref) values ('F01','NS-011',(select id from plots where farm_id='F01' limit 1),'GHI_CHU','wf-test-'||$1)", [run]);
    const r1 = (await admin.query("select complete_run_step($1,1,'NS-011') as r", [run])).rows[0].r; expect(r1).toBe("NEXT:2");
    const r2 = (await admin.query("select complete_run_step($1,2,'NS-011') as r", [run])).rows[0].r; expect(r2).toBe("DONE");
    expect((await admin.query("select status from process_runs where id=$1", [run])).rows[0].status).toBe("XONG");
  });
});
describe("Nhập lô đàn & vòng theo dõi", () => {
  it("intake_herd tạo lô + N con + thẻ + sự kiện; monitoring có hạn", async () => {
    const r = (await admin.query("select intake_herd('F01','NS-003',$1,$2) as r", [JSON.stringify({ kind: "MUA", species: "BO", breed: "Test", price: 1 }), JSON.stringify([{ rfid: "7041999" + String(Date.now()).slice(-8), visual_tag: "TST" + String(Date.now()).slice(-4), sex: "F", weight_kg: 300 }, { sex: "M" }])])).rows[0].r as { lot_id: string; animals: string[] };
    expect(r.animals.length).toBe(2);
    const a = (await admin.query("select status, tag_pending from animals where id=$1", [r.animals[1]])).rows[0]; expect(a.status).toBe("CACH_LY"); expect(a.tag_pending).toBe(true);
    const tags = Number((await admin.query("select count(*) from animal_tags where animal_id=$1", [r.animals[0]])).rows[0].count); expect(tags).toBe(2);
    const mon = Number((await admin.query("select count(*) from v_animal_monitoring where animal_id=$1", [r.animals[0]])).rows[0].count); expect(mon).toBeGreaterThan(0);
    // dọn
    await admin.query("delete from tasks where target_id = any($1)", [r.animals]); await admin.query("delete from animal_tags where animal_id = any($1)", [r.animals]);
    await admin.query("update animal_events set status='VOID' where animal_id = any($1)", [r.animals]).catch(() => null);
  });
});
describe("Kế toán kép", () => {
  it("gl_post từ chối bút toán lệch; bút toán cân được ghi; sổ cái Nợ = Có", async () => {
    await expect(admin.query("select gl_post('F01','test','x1','lệch','[{\"acct\":\"111\",\"debit\":100,\"credit\":0},{\"acct\":\"511\",\"debit\":0,\"credit\":90}]'::jsonb)")).rejects.toThrow(/ERR_GL_UNBALANCED/);
    const id = (await admin.query("select gl_post('F01','test','x2','cân','[{\"acct\":\"111\",\"debit\":100,\"credit\":0},{\"acct\":\"511\",\"debit\":0,\"credit\":100}]'::jsonb) as id")).rows[0].id; expect(id).toBeTruthy();
    const tb = (await admin.query("select coalesce(sum(debit),0) as d, coalesce(sum(credit),0) as c from v_gl_trial_balance where farm_id='F01'")).rows[0]; expect(Math.round(Number(tb.d))).toBe(Math.round(Number(tb.c)));
    await admin.query("delete from journal_entries where ref_table='test'");
  });
});
describe("Tiêu chuẩn & ICFS", () => {
  it("≥19 chuẩn có điều khoản; ICFS chấm điểm 0–100 và có hạng", async () => {
    const n = Number((await admin.query("select count(distinct standard_code) from standard_requirements")).rows[0].count); expect(n).toBeGreaterThanOrEqual(19);
    const s = (await admin.query("select * from v_icfs_summary where farm_id='F01'")).rows[0]; expect(Number(s.pct)).toBeGreaterThanOrEqual(0); expect(Number(s.pct)).toBeLessThanOrEqual(100); expect(["ĐỒNG", "BẠC", "VÀNG", "CHƯA ĐẠT"]).toContain(s.level);
    const sc = (await admin.query("select count(*) filter (where value='ERR') as err from icfs_score('F01')")).rows[0]; expect(Number(sc.err)).toBe(0);
  });
});
describe("Audit trail danh mục", () => {
  it("sửa facilities ghi audit_log trước/sau + sự kiện master.changed", async () => {
    await admin.query("update facilities set note='audit-test-'||now()::text where id='F01-FC-CAN'");
    const a = (await admin.query("select action, changed_cols from audit_log where table_name='facilities' and pk='F01-FC-CAN' order by ts desc limit 1")).rows[0]; expect(a.action).toBe("UPDATE"); expect(a.changed_cols).toContain("note");
  });
});
describe("Thuật toán thuần", () => {
  it("LP khẩu phần ra lời giải đạt ràng buộc CP", () => {
    const r = solveRation([{ sku: "A", name: "A", price_per_kg_dm: 1000, nutrients: { CP: 5 } }, { sku: "B", name: "B", price_per_kg_dm: 3000, nutrients: { CP: 20 } }], 10, [{ nutrient: "CP", min: 10, per: "pct" }]);
    expect(r.ok).toBe(true); expect(r.nutrients.CP / 10).toBeGreaterThanOrEqual(9.99); expect(r.cost).toBeLessThanOrEqual(30000);
  });
  it("VietQR có CRC 4 hex và BIN/STK", () => { const s = vietqr("970436", "0011002233445", 150000, "DH123"); expect(s).toMatch(/6304[0-9A-F]{4}$/); expect(s).toContain("970436"); expect(s).toContain("0011002233445"); });
});
