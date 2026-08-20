/* Chuẩn hoá mã ID toàn hệ + soát tuân thủ. Chạy SAU mỗi lần migrate/seed.
 * Dùng: pnpm db:codes
 * Có tham số --check thì chỉ soát, không đổi gì. */
import { adminPool } from "../src/lib/db";

async function main() {
  const chiSoat = process.argv.includes("--check");
  const c = adminPool();

  if (!chiSoat) {
    // Cấp tài khoản TRƯỚC: nhân sự do script gieo thêm chưa có chỗ ngồi
    // (migration 0103 chạy lúc `staff` mới chỉ có nhân sự nền — đo được 18 tài khoản / 67 nhân sự).
    const p = await c.query("select provision_accounts() as ket");
    console.log(p.rows[0].ket);
    const r = await c.query("select normalize_codes() as ket");
    console.log(r.rows[0].ket);
    // Gán việc + dọn quá hạn cũng phải chạy SAU seed: migration 0124/0125 chạy lúc migrate khi
    // `tasks` mới có ít việc; seed sinh hàng nghìn việc sau đó nên chúng chưa được gán. Chạy lại
    // ở đây để bản dựng-lại-từ-trắng có việc gán đúng chỗ ngồi ngay, không phải chờ mở app.
    for (const fn of ["assign_open_tasks()", "reassign_tasks_by_dept()", "assign_open_tasks()", "reschedule_overdue_tasks()"]) {
      try { const x = await c.query(`select ${fn} as ket`); console.log(x.rows[0].ket); } catch (e) { console.warn(fn, (e as Error).message); }
    }
  }

  const thieu = await c.query("select count(*)::int as n from v_staff_no_account");
  if (thieu.rows[0].n > 0) { console.error(`✗ ${thieu.rows[0].n} nhân sự có đăng nhập mà chưa có tài khoản.`); process.exit(1); }

  const q = await c.query<{ bang: string; loai: string; tong: string; dung_chuan: string; con_lech: string }>(
    "select * from check_code_compliance() order by con_lech desc, bang");
  const lech = q.rows.filter((r) => Number(r.con_lech) > 0);
  console.table(q.rows.map((r) => ({ bảng: r.bang, loại: r.loai, tổng: Number(r.tong), "đúng chuẩn": Number(r.dung_chuan), "còn lệch": Number(r.con_lech) })));

  if (lech.length) {
    console.error(`\n✗ ${lech.length} bảng còn mã lệch chuẩn — xem cột "còn lệch".`);
    process.exit(1);
  }
  console.log(`\n✓ ${q.rows.length}/${q.rows.length} bảng đúng chuẩn mã, không còn hệ mã cũ.`);
  await c.end();
}
main().catch((e) => { console.error(e); process.exit(1); });
