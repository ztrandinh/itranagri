import { adminPool } from "./db";

/** Cửa sổ trượt 1 phút, đếm atomic bằng 1 câu UPSERT (không cần advisory lock — UPDATE trong
 *  ON CONFLICT đã tự khoá dòng). Thay Map trong process để đúng khi chạy nhiều instance. */
export async function rateLimited(bucket: string, maxPerMinute: number): Promise<boolean> {
  const r = await adminPool().query(
    `insert into rl_counters(bucket, window_start, count) values ($1, now(), 1)
     on conflict (bucket) do update set
       count = case when rl_counters.window_start > now() - interval '1 minute' then rl_counters.count + 1 else 1 end,
       window_start = case when rl_counters.window_start > now() - interval '1 minute' then rl_counters.window_start else now() end
     returning count`,
    [bucket],
  );
  // Dọn ngẫu nhiên (~1%/lượt gọi) thay vì job riêng — bucket theo IP nên số dòng tỉ lệ với IP khác
  // nhau đã thấy, không dọn sẽ phình vô hạn theo thời gian.
  if (Math.random() < 0.01) void adminPool().query("delete from rl_counters where window_start < now() - interval '10 minutes'").catch(() => {});
  return Number(r.rows[0].count) > maxPerMinute;
}
