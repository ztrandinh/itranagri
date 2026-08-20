/* Nhóm 2 (audit code) — cưỡng chế ATTP/phúc lợi bằng cách TREO LÔ / SINH VIỆC (không hard-guard chặn ghi).
 * T2.4 lab chặn lô · T2.1 CCP engine · T2.2 welfare. Mỗi test bọc BEGIN/ROLLBACK → 0 residue (DB dùng chung).
 * Cần DB đang chạy. */
import { describe, it, expect, beforeAll, afterAll } from "vitest";
import { Client } from "pg";
import "dotenv/config";
const ADMIN = process.env.DATABASE_ADMIN_URL ?? "postgres://postgres:itranagri@localhost:54499/itranagri";
let db: Client;
beforeAll(async () => { db = new Client({ connectionString: ADMIN }); await db.connect(); });
afterAll(async () => { await db.end(); });

describe("T2.4 — lab KHÔNG ĐẠT → treo lô", () => {
  it("verdict=KHONG_DAT trên lô → GIU_QC + task LAB_FAIL; DAT → không treo", async () => {
    await db.query("begin");
    try {
      const lot = (await db.query("select id, farm_id from lots where status='KHA_DUNG' limit 1")).rows[0];
      await db.query("insert into lab_samples(id,farm_id,code,kind,subject_ref,verdict) values('T-2160',$1,'MYCO-T','TA',$2,'KHONG_DAT')", [lot.farm_id, lot.id]);
      const st = (await db.query("select status from lots where id=$1", [lot.id])).rows[0].status;
      expect(st).toBe("GIU_QC");
      const nHold = Number((await db.query("select count(*) from qc_holds where lot_id=$1 and status='GIU'", [lot.id])).rows[0].count);
      expect(nHold).toBe(1);
      const nTask = Number((await db.query("select count(*) from tasks where kind='LAB_FAIL' and ref_id='T-2160'")).rows[0].count);
      expect(nTask).toBe(1);
      // ca DAT (lô khác) → không treo
      const lot2 = (await db.query("select id, farm_id from lots where status='KHA_DUNG' limit 1 offset 5")).rows[0];
      await db.query("insert into lab_samples(id,farm_id,code,kind,subject_ref,verdict) values('T-2160b',$1,'MYCO-T','TA',$2,'DAT')", [lot2.farm_id, lot2.id]);
      expect((await db.query("select status from lots where id=$1", [lot2.id])).rows[0].status).toBe("KHA_DUNG");
    } finally { await db.query("rollback"); }
  });
});

describe("T2.1 — CCP vượt ngưỡng mẻ D5 → treo lô đầu ra", () => {
  it("ccp value>limit → lô đầu ra GIU_QC + task CCP_FAIL + v_ccp_breach; đạt → không", async () => {
    await db.query("begin");
    try {
      await db.query("insert into batch_logs(farm_id,line,batch_code,outputs,ccp_readings,source) values('F01','D5-T','T-2161-A','[{\"kg\":50,\"sku\":\"SKU-PTR-25\"}]'::jsonb,'[{\"ccp\":\"AM_SAY\",\"value\":15,\"limit\":12}]'::jsonb,'APP')");
      const held = Number((await db.query("select count(*) from lots where status='GIU_QC' and id in (select im.lot_id from inventory_moves im join batch_logs b on im.ref_id=b.id::text where b.batch_code='T-2161-A' and im.ref_type='batch_logs' and im.reason='NHAP_SX')")).rows[0].count);
      expect(held).toBeGreaterThan(0);
      expect(Number((await db.query("select count(*) from tasks where kind='CCP_FAIL' and detail->>'batch'='T-2161-A'")).rows[0].count)).toBe(1);
      expect(Number((await db.query("select count(*) from v_ccp_breach where batch_code='T-2161-A'")).rows[0].count)).toBe(1);
      // ca đạt
      await db.query("insert into batch_logs(farm_id,line,batch_code,outputs,ccp_readings,source) values('F01','D5-T','T-2161-B','[{\"kg\":50,\"sku\":\"SKU-PTR-25\"}]'::jsonb,'[{\"ccp\":\"AM_SAY\",\"value\":10,\"limit\":12,\"ok\":true}]'::jsonb,'APP')");
      expect(Number((await db.query("select count(*) from tasks where kind='CCP_FAIL' and detail->>'batch'='T-2161-B'")).rows[0].count)).toBe(0);
    } finally { await db.query("rollback"); }
  });
});

describe("T2.2 — phúc lợi: lameness param + giảm đau thủ thuật", () => {
  it("param LAME30 có cho BO+DE", async () => {
    expect(Number((await db.query("select count(*) from monitoring_params where code='LAME30'")).rows[0].count)).toBe(2);
  });
  it("khử sừng/thiến thiếu giảm đau → task; có giảm đau/IMPORT → không", async () => {
    await db.query("begin");
    try {
      const an = (await db.query("select id, farm_id from animals where farm_id='F01' limit 1")).rows[0];
      await db.query("insert into animal_events(farm_id,animal_id,event_type,detail,source) values($1,$2,'DIEU_TRI','{\"thu_thuat\":\"KHU_SUNG\"}'::jsonb,'APP')", [an.farm_id, an.id]);
      expect(Number((await db.query("select count(*) from tasks where kind='WELFARE_PAINREL' and detail->>'animal'=$1", [an.id])).rows[0].count)).toBe(1);
      await db.query("rollback"); await db.query("begin");
      await db.query("insert into animal_events(farm_id,animal_id,event_type,detail,source) values($1,$2,'DIEU_TRI','{\"thu_thuat\":\"KHU_SUNG\",\"giam_dau\":\"lidocaine\"}'::jsonb,'APP')", [an.farm_id, an.id]);
      expect(Number((await db.query("select count(*) from tasks where kind='WELFARE_PAINREL' and detail->>'animal'=$1", [an.id])).rows[0].count)).toBe(0);
      await db.query("rollback"); await db.query("begin");
      await db.query("insert into animal_events(farm_id,animal_id,event_type,detail,source,is_backfill) values($1,$2,'DIEU_TRI','{\"thu_thuat\":\"THIEN\"}'::jsonb,'IMPORT',true)", [an.farm_id, an.id]);
      expect(Number((await db.query("select count(*) from tasks where kind='WELFARE_PAINREL' and detail->>'animal'=$1", [an.id])).rows[0].count)).toBe(0);
    } finally { await db.query("rollback"); }
  });
});
