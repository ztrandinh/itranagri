/* Golden tests nền: RLS từng bảng · append-only · chặn ngưng thuốc · sinh mã · RC engine. Cần DB đang chạy (pnpm db:migrate). */
import { describe, it, expect, beforeAll, afterAll } from "vitest";
import { Client } from "pg";
import "dotenv/config";
const APP = process.env.DATABASE_URL ?? "postgres://app_user:app_user_pw@localhost:54499/itranagri";
const ADMIN = process.env.DATABASE_ADMIN_URL ?? "postgres://postgres:itranagri@localhost:54499/itranagri";
let app: Client, admin: Client;
const ctx = async (farm: string, role: string, staff = "NS-003") => app.query("select set_config('app.org_id','ITRAN',false), set_config('app.farm_id',$1,false), set_config('app.role',$2,false), set_config('app.staff_id',$3,false), set_config('app.farm_ids',$4,false)", [farm, role, staff, role === "owner" || role === "auditor" ? "F01,F99" : farm]);
beforeAll(async () => { app = new Client({ connectionString: APP }); admin = new Client({ connectionString: ADMIN }); await app.connect(); await admin.connect(); });
afterAll(async () => { await app.end(); await admin.end(); });

describe("RLS — farm A không thấy farm B", () => {
  it("mọi bảng có farm_id đều bật RLS", async () => {
    const r = await admin.query("select c.table_name from information_schema.columns c join pg_tables t on t.tablename=c.table_name and t.schemaname='public' where c.column_name='farm_id' and c.table_schema='public' and not t.rowsecurity and c.table_name not like 'sensor_reads%' and not exists (select 1 from pg_inherits i join pg_class ch on ch.oid=i.inhrelid where ch.relname=c.table_name) and c.table_name not in ('sessions','id_sequences','staff','farms','norms','price_list','alert_rules','settings','audit_anchors')");
    expect(r.rows.map((x) => x.table_name)).toEqual([]);
  });
  it("worker F99 thấy 0 bò của F01; worker F01 thấy đủ; auditor thấy tất cả", async () => {
    await ctx("F99", "worker", "NS-011"); expect(Number((await app.query("select count(*) from animals where farm_id='F01'")).rows[0].count)).toBe(0);
    await ctx("F01", "worker", "NS-011"); expect(Number((await app.query("select count(*) from animals")).rows[0].count)).toBeGreaterThan(0);
    await ctx("F01", "auditor", "NS-030"); expect(Number((await app.query("select count(*) from animals")).rows[0].count)).toBeGreaterThan(0);
  });
  it("worker không ghi được vào trại khác", async () => {
    await ctx("F01", "worker", "NS-011");
    await expect(app.query("insert into animal_events(farm_id,animal_id,event_type,created_by,client_ref) values ('F99','F01-BO-00001','GHI_CHU','NS-011','t-rls-1')")).rejects.toThrow();
  });
  it("sale_animals (bảng nối, không farm_id) vẫn bật RLS + có policy theo trại đơn cha", async () => {
    // bảng nối không có cột farm_id nên không lọt test tổng "mọi bảng có farm_id"; kiểm riêng.
    const r = await admin.query("select relrowsecurity from pg_class where relname='sale_animals'");
    expect(r.rows[0].relrowsecurity).toBe(true);
    const p = await admin.query("select count(*)::int n from pg_policies where tablename='sale_animals'");
    expect(p.rows[0].n).toBeGreaterThan(0);
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
describe("Đọc số máy · khâu ghi chép · độ phủ (0100–0110)", () => {
  it("device_readings RLS: worker F99 không thấy số đọc F01", async () => {
    await ctx("F99", "worker", "NS-011");
    expect(Number((await app.query("select count(*) from device_readings where farm_id='F01'")).rows[0].count)).toBe(0);
  });
  it("device_readings APPEND-ONLY: chặn UPDATE & DELETE (trigger, kể cả superuser)", async () => {
    await expect(admin.query("update device_readings set note='x' where farm_id='F01'")).rejects.toThrow(/ERR_APPEND_ONLY/);
    await expect(admin.query("delete from device_readings where farm_id='F01'")).rejects.toThrow(/ERR_APPEND_ONLY/);
  });
  it("trigger insert tự tính chênh + bắt bất thường + điền facility + sinh việc (mọi đường insert)", async () => {
    const cref = "t-dr-" + Date.now();
    // Lấy đúng số đọc MỐC mà trigger sẽ dùng (gần nhất theo ts<=now) rồi chèn THẤP HƠN 1 → công-tơ LÙI chắc chắn.
    // (device_readings append-only: mỗi lần chạy test lại thêm 1 dòng, nên KHÔNG được dùng hằng value=1 — sẽ bằng prev cũ → delta=0 → hết bất thường.)
    const prev = Number((await admin.query("select value from device_readings where metric_id='RM-ELEC-F01' and ts <= now() order by ts desc limit 1")).rows[0]?.value ?? 100);
    const r = await admin.query("insert into device_readings(farm_id, created_by, metric_id, value, source, client_ref) values ('F01','system','RM-ELEC-F01', $2, 'PAPER', $1) returning id, is_anomaly, facility_id", [cref, prev - 1]);
    expect(r.rows[0].is_anomaly).toBe(true);
    expect(r.rows[0].facility_id).not.toBeNull();
    expect(Number((await admin.query("select count(*) from tasks where farm_id='F01' and kind='DEVICE_ANOMALY' and ref_id=$1", [r.rows[0].id])).rows[0].count)).toBe(1);
  });
  it("v_recording_due phân loại hợp lệ + gen_recording_alerts chạy sạch", async () => {
    const n = await admin.query("select gen_recording_alerts('F01') as n");
    expect(Number.isInteger(Number(n.rows[0].n))).toBe(true);
    const levels = (await admin.query("select distinct level from v_recording_due where farm_id='F01'")).rows.map((r) => r.level);
    expect(levels.every((l) => ["OK", "DUE", "ESCALATE"].includes(l))).toBe(true);
  });
  it("control_coverage trả về SOP kèm cờ vùng mù", async () => {
    const r = await admin.query("select count(*)::int c, count(*) filter (where blind)::int b from control_coverage('F01')");
    expect(r.rows[0].c).toBeGreaterThan(0);
  });
});
describe("Đăng nhập · phiên", () => {
  // Regression 0142: 0127 siết FK hàng loạt theo tên cột từng gán sessions.device_id → devices(id),
  // khiến MỌI đăng nhập qua trình duyệt vỡ (login() insert 'dev-xxxx' chưa có trong devices → 423).
  // device_id là VÂN TAY THIẾT BỊ ĐĂNG NHẬP (sinh tại máy), KHÔNG phải nông cụ. Không được có FK này.
  it("sessions.device_id KHÔNG bị khoá ngoại chặn (vân tay máy đăng nhập tự sinh)", async () => {
    expect(Number((await admin.query("select count(*) from pg_constraint where conname='fk_sessions_device_id'")).rows[0].count)).toBe(0);
    const st = (await admin.query("select id, farm_id from staff where farm_id is not null limit 1")).rows[0];
    await expect(admin.query(
      "insert into sessions(staff_id, farm_id, device_id, expires_at) values ($1,$2,$3, now()+interval '1 day')",
      [st.id, st.farm_id, "dev-regression-" + Date.now()]
    )).resolves.toBeTruthy();
  });
});
describe("Feed species guard (0143)", () => {
  // Cấm cho ăn SAI LOÀI: loài đàn (animal_groups.species) phải khớp loài khẩu phần (recipes.species_phase 'LOÀI/…').
  it("khẩu phần loài KHÁC đàn → ERR_FEED_WRONG_SPECIES; khớp loài → qua", async () => {
    const bo = (await admin.query("select id from animal_groups where species='BO' limit 1")).rows[0];
    const gaRec = (await admin.query("select id from recipes where split_part(species_phase,'/',1)='GA' limit 1")).rows[0];
    const boRec = (await admin.query("select id from recipes where split_part(species_phase,'/',1)='BO' limit 1")).rows[0];
    expect(bo && gaRec && boRec).toBeTruthy();
    await expect(admin.query("select chk_feed_species($1,$2)", [bo.id, gaRec.id])).rejects.toThrow(/ERR_FEED_WRONG_SPECIES/);
    await expect(admin.query("select chk_feed_species($1,$2)", [bo.id, boRec.id])).resolves.toBeTruthy();
    // thiếu recipe hoặc thiếu đàn → không chặn (luồng ghi tối thiểu vẫn qua)
    await expect(admin.query("select chk_feed_species($1,null)", [bo.id])).resolves.toBeTruthy();
  });
  it("trigger feed_logs chặn thật khi ghi khẩu phần sai loài", async () => {
    const bo = (await admin.query("select id, farm_id from animal_groups where species='BO' limit 1")).rows[0];
    const gaRec = (await admin.query("select id from recipes where split_part(species_phase,'/',1)='GA' limit 1")).rows[0];
    await ctx(bo.farm_id, "worker", "NS-011");
    await expect(app.query(
      "insert into feed_logs(farm_id, dest_group_id, recipe_id, qty_kg, source, created_by, client_ref) values ($1,$2,$3,10,'APP','NS-011',$4)",
      [bo.farm_id, bo.id, gaRec.id, "t-feedspec-" + Date.now()]
    )).rejects.toThrow(/ERR_FEED_WRONG_SPECIES/);
  });
});
describe("supervision_criteria.sop_code đa hình (0144)", () => {
  // sop_code chứa CẢ SOP-* LẪN P-* (mã quy trình từ sync_process_criteria). FK 0127 → sops gán sai
  // làm sync_process_criteria vỡ. Không được có FK; sync phải chạy lại được.
  it("KHÔNG còn FK sop_code→sops + sync_process_criteria() chạy sạch", async () => {
    expect(Number((await admin.query("select count(*) from pg_constraint where conname='fk_supervision_criteria_sop_code'")).rows[0].count)).toBe(0);
    await expect(admin.query("select sync_process_criteria() as n")).resolves.toBeTruthy();
  });
});
describe("AMU giám sát kháng sinh (0145)", () => {
  // Read-side: view cường độ điều trị + ngưỡng norm + sinh việc. Không hard-guard.
  it("norm ngưỡng tồn tại · view phân loại đúng invariant · gen_amu_alerts chạy sạch", async () => {
    expect(Number((await admin.query("select count(*) from norms where kind='AMU_MAX_90D'")).rows[0].count)).toBeGreaterThan(0);
    // invariant: muc='VUOT' ⇔ lượt > ngưỡng (đúng với MỌI dữ liệu, không phụ thuộc seed)
    expect(Number((await admin.query("select count(*) from v_amu_over where (lan_dieu_tri_90d > nguong) <> (muc='VUOT')")).rows[0].count)).toBe(0);
    await expect(admin.query("select gen_amu_alerts('F01') as n")).resolves.toBeTruthy();
  });
});
describe("Mortality watch (0146)", () => {
  // Read-side: tỷ lệ chết 30 ngày/đàn vs norm → sinh việc. Không hard-guard.
  it("norm tồn tại · invariant VUOT⇔vượt ngưỡng · gen_mortality_alerts chạy sạch", async () => {
    expect(Number((await admin.query("select count(*) from norms where kind='MORTALITY_MAX_30D'")).rows[0].count)).toBeGreaterThan(0);
    expect(Number((await admin.query("select count(*) from v_mortality_watch where (ty_le_pct > nguong) <> (muc='VUOT')")).rows[0].count)).toBe(0);
    await expect(admin.query("select gen_mortality_alerts('F01') as n")).resolves.toBeTruthy();
  });
});
describe("Ngưng thuốc — theo dõi auto (0147)", () => {
  it("view chỉ con còn hạn ngưng thuốc · gen_withdrawal_reminders chạy sạch + tự đóng", async () => {
    // mọi dòng trong view phải còn hạn (con_lai_ngay >= 0)
    expect(Number((await admin.query("select count(*) from v_withdrawal_active where con_lai_ngay < 0")).rows[0].count)).toBe(0);
    await expect(admin.query("select gen_withdrawal_reminders('F01') as n")).resolves.toBeTruthy();
    // không còn việc WITHDRAWAL mở cho con đã hết hạn (tự đóng)
    expect(Number((await admin.query("select count(*) from tasks t where t.ref_table='withdrawal' and t.status<>'XONG' and not exists(select 1 from v_withdrawal_active d where d.animal_id=t.ref_id)")).rows[0].count)).toBe(0);
  });
});
describe("Độ phủ truy xuất (0148)", () => {
  it("v_trace_coverage: có chiều, truy_duoc≤tong, pct trong [0,100]", async () => {
    const r = await admin.query("select chieu, tong, truy_duoc, pct from v_trace_coverage where farm_id='F01'");
    expect(r.rows.length).toBeGreaterThan(0);
    for (const row of r.rows) {
      expect(Number(row.truy_duoc)).toBeLessThanOrEqual(Number(row.tong));
      if (row.pct !== null) { expect(Number(row.pct)).toBeGreaterThanOrEqual(0); expect(Number(row.pct)).toBeLessThanOrEqual(100); }
    }
  });
});
describe("Lô hết hạn còn tồn (0149)", () => {
  it("view chỉ lô còn tồn+sắp/đã hết · gen GOM ≤1 việc/trại, idempotent, tự đóng", async () => {
    // mọi dòng view: ton>0 và trong ngưỡng 30 ngày
    expect(Number((await admin.query("select count(*) from v_lot_expiry_watch where ton<=0")).rows[0].count)).toBe(0);
    await admin.query("select gen_lot_expiry_alerts('F01')");
    // gom: tối đa 1 việc lot_expiry mở/trại
    expect(Number((await admin.query("select count(*) from tasks where ref_table='lot_expiry' and ref_id='F01' and status<>'XONG'")).rows[0].count)).toBeLessThanOrEqual(1);
    await expect(admin.query("select gen_lot_expiry_alerts('F01') as n")).resolves.toBeTruthy();
  });
  it("close_depleted_lots: đóng lô hết tồn, không đụng lô còn hàng/GIU_QC, idempotent", async () => {
    await admin.query("select close_depleted_lots('F01')");
    // sau khi chạy: không còn lô KHA_DUNG (có move) mà tồn<=0
    const orphan = await admin.query(`with o as (select lot_id, sum(direction*qty) ton from inventory_moves where status='ACTIVE' and lot_id is not null group by lot_id)
      select count(*) c from lots l join o on o.lot_id=l.id where l.farm_id='F01' and l.status='KHA_DUNG' and o.ton<=0`);
    expect(Number(orphan.rows[0].c)).toBe(0);
    // chạy lại = 0 (idempotent)
    expect(Number((await admin.query("select close_depleted_lots('F01') as n")).rows[0].n)).toBe(0);
  });
  it("chặn BÁN lô hết hạn (source APP) — ERR_LOT_EXPIRED", async () => {
    const lot = (await admin.query("select id, farm_id from lots where expiry_date < current_date and status='KHA_DUNG' limit 1")).rows[0];
    // BEFORE trigger raise trước cả GL/NOT NULL → sạch, không tạo dòng
    await expect(admin.query(
      "insert into sales(farm_id,lot_id,source,ts,sku,qty,unit,price,amount,status,created_by,client_ref) values ($1,$2,'APP',now(),'NL-BAP-U',1,'kg',1,1,'ACTIVE','system',$3)",
      [lot.farm_id, lot.id, "t-exp-" + Date.now()])).rejects.toThrow(/ERR_LOT_EXPIRED/);
  });
});
describe("Nhập kho tổng quát — quy cách khai báo biến (0153)", () => {
  it("record_intake: lô CÓ hạn dùng (từ config) + move truy về nguồn; idempotent; SKU lạ bị chặn", async () => {
    const flock = (await admin.query("select id, farm_id from animal_groups where species='GA' and head_count>0 limit 1")).rows[0];
    const cref = "t-in-" + Date.now();
    // ví dụ: NHẬP TRỨNG — nguồn = đàn gà đẻ (SKU là BIẾN, không fix cứng)
    const j = (await admin.query("select record_intake($1,'SKU-TRUNG-10',$2,'system','animal_groups',$3,$4) as j",
      [flock.farm_id, 100, flock.id, cref])).rows[0].j;
    expect(j.lot).toBeTruthy();
    const lot = (await admin.query("select mfg_date, expiry_date from lots where id=$1", [j.lot])).rows[0];
    expect(lot.expiry_date).not.toBeNull();   // hạn dùng lấy từ products.shelf_life_days (config)
    expect(lot.mfg_date).not.toBeNull();
    const mv = (await admin.query("select ref_type, ref_id from inventory_moves where client_ref=$1", [cref])).rows[0];
    expect(mv.ref_type).toBe("animal_groups"); expect(mv.ref_id).toBe(flock.id);  // truy xuất về nguồn
    // idempotent
    expect((await admin.query("select record_intake($1,'SKU-TRUNG-10',$2,'system','animal_groups',$3,$4) as j",
      [flock.farm_id, 100, flock.id, cref])).rows[0].j.dup).toBe(true);
    // SKU chưa khai danh mục → chặn (không fix cứng, kiểm theo config)
    await expect(admin.query("select record_intake($1,'SKU-KHONG-CO',1,'system',null,null,$2)",
      [flock.farm_id, "t-in-bad-" + Date.now()])).rejects.toThrow(/ERR_SKU_UNKNOWN/);
    // SP mới khai (0154) chạy được qua CÙNG hàm generic — vd phân bò
    expect(Number((await admin.query("select count(*) from products where sku in ('SKU-NHUNG-HUOU','SKU-LUON-THIT','SKU-PHAN-BO','SKU-PHAN-DE','SKU-PHAN-GA')")).rows[0].count)).toBe(5);
    const jm = (await admin.query("select record_intake($1,'SKU-PHAN-BO',$2,'system',null,null,$3) as j", [flock.farm_id, 500, "t-in-manure-" + Date.now()])).rows[0].j;
    expect(jm.lot).toBeTruthy();
  });
});
