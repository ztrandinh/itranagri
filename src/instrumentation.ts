/** Lịch chạy nội bộ (không cần cron ngoài): bật bằng SCHEDULER=1. Mỗi phút: dispatch thông báo + kênh gửi + webhook; 01:15 hằng đêm: jobs/all + backup; 06:00: tasks. Chạy 1 lần/process (Node runtime). */
export async function register() {
  if (process.env.NEXT_RUNTIME !== "nodejs" || process.env.SCHEDULER !== "1") return;
  const g = globalThis as unknown as { __itranSched?: boolean }; if (g.__itranSched) return; g.__itranSched = true;
  const { dispatchEvents } = await import("@/lib/notify"); const { deliverChannels } = await import("@/lib/channels"); const { adminPool } = await import("@/lib/db");
  const port = process.env.PORT ?? "3000"; const key = process.env.JOB_KEY ?? "dev-job-key";
  const farms = async () => (await adminPool().query("select id from farms where status='ACTIVE'")).rows.map((r) => String(r.id));
  const call = async (job: string, farm: string) => { try { await fetch(`http://127.0.0.1:${port}/api/jobs/${job}?farm=${farm}`, { method: "POST", headers: { "x-job-key": key } }); } catch (e) { console.error("sched", job, farm, (e as Error).message); } };
  setInterval(async () => { try { await dispatchEvents(); await deliverChannels(); } catch (e) { console.error("sched:dispatch", (e as Error).message); } }, 60e3);
  let lastNight = "", lastMorning = "";
  setInterval(async () => { const now = new Date(); const hm = now.toTimeString().slice(0, 5); const day = now.toISOString().slice(0, 10);
    if (hm === "01:15" && lastNight !== day) { lastNight = day; for (const f of await farms()) { await call("all", f); await call("backup", f); } }
    if (hm === "06:00" && lastMorning !== day) { lastMorning = day; for (const f of await farms()) await call("tasks", f); }
    if (now.getMinutes() % 5 === 0 && now.getSeconds() < 30) { for (const f of await farms()) await call("cache", f); }
    if (hm === "02:30" && now.getDay() === 0 && lastMorning !== "maint" + day) { for (const f of await farms()) { await call("maint", f); break; } }
  }, 30e3);
  console.log("[ITRAN OS] scheduler on: dispatch mỗi phút · jobs/all+backup 01:15 · tasks 06:00");
}
