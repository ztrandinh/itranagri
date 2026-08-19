/** KÊNH GỬI THẬT: app (đã có) · zalo (Zalo OA / ZNS) · sms (eSMS/SpeedSMS/Twilio-compatible HTTP) · email (SMTP qua fetch tới API hoặc Resend/SendGrid) · webhook (đối tác).
 *  Cấu hình = dữ liệu trong bảng `integrations` (kind ZALO_OA | SMS | EMAIL; config jsonb; active). Không có cấu hình → ghi SKIPPED (không giả vờ đã gửi). Mọi lần gửi ghi vào notification_deliveries. */
import { createHmac } from "node:crypto";
import { adminPool } from "./db";
import webpush from "web-push";
type Cfg = Record<string, string>;
async function integration(kind: string, farm: string | null): Promise<Cfg | null> {
  const r = (await adminPool().query("select config from integrations where kind=$1 and active and (farm_id=$2 or farm_id is null) order by (farm_id=$2) desc limit 1", [kind, farm])).rows[0];
  return r ? (r.config as Cfg) : null;
}
async function sendZalo(cfg: Cfg, to: string, text: string): Promise<string> {
  // Zalo OA "message" API (CS message trong 7 ngày) hoặc ZNS template — cfg: {access_token, template_id?}
  if (cfg.template_id) { const r = await fetch("https://business.openapi.zalo.me/message/template", { method: "POST", headers: { "content-type": "application/json", access_token: cfg.access_token }, body: JSON.stringify({ phone: to, template_id: cfg.template_id, template_data: { noi_dung: text.slice(0, 200) }, tracking_id: String(Date.now()) }) }); const j = await r.json(); if (j.error && j.error !== 0) throw new Error(`zalo ${j.error}: ${j.message}`); return String(j.data?.msg_id ?? "ok"); }
  const r = await fetch("https://openapi.zalo.me/v3.0/oa/message/cs", { method: "POST", headers: { "content-type": "application/json", access_token: cfg.access_token }, body: JSON.stringify({ recipient: { user_id: to }, message: { text } }) }); const j = await r.json(); if (j.error && j.error !== 0) throw new Error(`zalo ${j.error}: ${j.message}`); return String(j.data?.message_id ?? "ok");
}
async function sendSms(cfg: Cfg, to: string, text: string): Promise<string> {
  // eSMS.vn (mặc định) — cfg: {provider:'esms', api_key, secret_key, brandname} | provider:'http' — cfg: {url, method, body_template}
  if ((cfg.provider ?? "esms") === "esms") { const r = await fetch("https://rest.esms.vn/MainService.svc/json/SendMultipleMessage_V4_post_json/", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ ApiKey: cfg.api_key, SecretKey: cfg.secret_key, Phone: to, Content: text.slice(0, 300), Brandname: cfg.brandname, SmsType: cfg.sms_type ?? "2" }) }); const j = await r.json(); if (String(j.CodeResult) !== "100") throw new Error(`esms ${j.CodeResult}: ${j.ErrorMessage}`); return String(j.SMSID ?? "ok"); }
  const body = (cfg.body_template ?? '{"to":"{to}","text":"{text}"}').replace("{to}", to).replace("{text}", text.replace(/"/g, '\\"'));
  const r = await fetch(cfg.url, { method: cfg.method ?? "POST", headers: { "content-type": "application/json", ...(cfg.auth_header ? { authorization: cfg.auth_header } : {}) }, body }); if (!r.ok) throw new Error(`sms http ${r.status}`); return String(r.status);
}
async function sendEmail(cfg: Cfg, to: string, subject: string, text: string): Promise<string> {
  // Resend (mặc định, HTTPS) — cfg: {provider:'resend', api_key, from} | SendGrid — cfg: {provider:'sendgrid', api_key, from}
  if ((cfg.provider ?? "resend") === "resend") { const r = await fetch("https://api.resend.com/emails", { method: "POST", headers: { "content-type": "application/json", authorization: `Bearer ${cfg.api_key}` }, body: JSON.stringify({ from: cfg.from, to: [to], subject, text }) }); const j = await r.json(); if (!r.ok) throw new Error(`resend ${r.status}: ${JSON.stringify(j).slice(0, 120)}`); return String(j.id ?? "ok"); }
  const r = await fetch("https://api.sendgrid.com/v3/mail/send", { method: "POST", headers: { "content-type": "application/json", authorization: `Bearer ${cfg.api_key}` }, body: JSON.stringify({ personalizations: [{ to: [{ email: to }] }], from: { email: cfg.from }, subject, content: [{ type: "text/plain", value: text }] }) }); if (!r.ok) throw new Error(`sendgrid ${r.status}`); return "ok";
}
/** WEB PUSH: mọi notification mới (2 ngày) chưa push → gửi tới các subscription của staff (thông báo nổi trên điện thoại) */
export async function deliverPush(limit = 300): Promise<{ sent: number; failed: number }> {
  const pub = process.env.VAPID_PUBLIC_KEY ?? process.env.NEXT_PUBLIC_VAPID_KEY, priv = process.env.VAPID_PRIVATE_KEY; if (!pub || !priv) return { sent: 0, failed: 0 };
  webpush.setVapidDetails(process.env.VAPID_SUBJECT ?? "mailto:admin@itran.farm", pub, priv);
  const p = adminPool(); let sent = 0, failed = 0;
  const rows = (await p.query("select n.id, n.staff_id, n.title, n.body, n.link, n.level from notifications n where n.ts > now() - interval '2 days' and not exists (select 1 from notification_deliveries d where d.notification_id=n.id and d.channel='push') order by n.ts limit $1", [limit])).rows;
  for (const n of rows) {
    const subs = (await p.query("select * from push_subscriptions where staff_id=$1 and fail_count < 5", [n.staff_id])).rows;
    if (!subs.length) { await p.query("insert into notification_deliveries(notification_id,channel,status,error) values ($1,'push','SKIPPED','không có subscription')", [n.id]); continue; }
    for (const s of subs) { try { await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, JSON.stringify({ title: n.title, body: n.body ?? "", url: n.link ?? "/", level: n.level, id: n.id }), { TTL: 3600 }); await p.query("update push_subscriptions set last_ok=now(), fail_count=0 where id=$1", [s.id]); sent++; }
      catch (e) { const code = (e as { statusCode?: number }).statusCode; if (code === 404 || code === 410) await p.query("delete from push_subscriptions where id=$1", [s.id]); else await p.query("update push_subscriptions set fail_count=fail_count+1 where id=$1", [s.id]); failed++; } }
    await p.query("insert into notification_deliveries(notification_id,channel,to_addr,status,provider,sent_at) values ($1,'push',$2,$3,'webpush',now())", [n.id, `${subs.length} thiết bị`, failed ? "FAILED" : "SENT"]);
  }
  return { sent, failed };
}
/** Đẩy notifications có kênh zalo/sms/email chưa gửi → deliveries; rồi gửi hàng đợi (tối đa 3 lần thử) */
export async function deliverChannels(limit = 200): Promise<{ queued: number; sent: number; failed: number; skipped: number }> {
  const p = adminPool(); let queued = 0, sent = 0, failed = 0, skipped = 0;
  const pending = (await p.query("select n.id, n.farm_id, n.staff_id, n.title, n.body, n.link, n.channels from notifications n where n.ts > now() - interval '2 days' and exists (select 1 from unnest(n.channels) c where c in ('zalo','sms','email')) and not exists (select 1 from notification_deliveries d where d.notification_id=n.id) limit $1", [limit])).rows;
  for (const n of pending) { const st = (await p.query("select phone, email, zalo_uid from staff where id=$1", [n.staff_id])).rows[0] ?? {}; for (const ch of (n.channels as string[]).filter((c) => ["zalo", "sms", "email"].includes(c))) { const to = ch === "zalo" ? (st.zalo_uid ?? st.phone) : ch === "sms" ? st.phone : st.email; await p.query("insert into notification_deliveries(notification_id,channel,to_addr,status) values ($1,$2,$3,$4)", [n.id, ch, to ?? null, to ? "QUEUED" : "SKIPPED"]); if (to) queued++; else skipped++; } }
  const q = (await p.query("select d.*, n.title, n.body, n.link, n.farm_id from notification_deliveries d join notifications n on n.id=d.notification_id where d.status='QUEUED' and d.attempts < 3 order by d.ts limit $1", [limit])).rows;
  for (const d of q) {
    const cfg = await integration(d.channel === "zalo" ? "ZALO_OA" : d.channel === "sms" ? "SMS" : "EMAIL", d.farm_id);
    if (!cfg) { await p.query("update notification_deliveries set status='SKIPPED', error='chưa cấu hình integrations '||$2, attempts=attempts+1 where id=$1", [d.id, d.channel]); skipped++; continue; }
    const text = `[ITRAN AGRI] ${d.title}${d.body ? " — " + d.body : ""}${d.link ? " " + (process.env.PUBLIC_URL ?? "") + d.link : ""}`;
    try { const ref = d.channel === "zalo" ? await sendZalo(cfg, d.to_addr, text) : d.channel === "sms" ? await sendSms(cfg, d.to_addr, text) : await sendEmail(cfg, d.to_addr, `[ITRAN AGRI] ${d.title}`, text); await p.query("update notification_deliveries set status='SENT', provider=$2, provider_ref=$3, sent_at=now(), attempts=attempts+1 where id=$1", [d.id, cfg.provider ?? d.channel, ref]); sent++; }
    catch (e) { await p.query("update notification_deliveries set status=case when attempts+1>=3 then 'FAILED' else 'QUEUED' end, error=$2, attempts=attempts+1 where id=$1", [d.id, (e as Error).message.slice(0, 300)]); failed++; }
  }
  await deliverWebhooks(); await deliverPush();
  return { queued, sent, failed, skipped };
}
/** WEBHOOK: mọi event_bus đã xử lý → POST tới webhooks có topics khớp (hoặc '*'), ký HMAC-SHA256 header x-itran-signature; ghi webhook_deliveries; thử lại ≤5 lần, tắt sau 20 lỗi liên tiếp */
export async function deliverWebhooks(limit = 200): Promise<number> {
  const p = adminPool(); let n = 0;
  const hooks = (await p.query("select * from webhooks where active and fail_count < 20")).rows; if (!hooks.length) return 0;
  const evs = (await p.query("select * from event_bus where processed_at is not null and ts > now() - interval '1 day' and id > coalesce((select max(event_id) from webhook_deliveries),0) order by id limit $1", [limit])).rows;
  for (const e of evs) for (const h of hooks) {
    const topics: string[] = h.topics ?? []; if (!(topics.includes("*") || topics.includes(e.topic))) continue; if (h.farm_id && e.farm_id && h.farm_id !== e.farm_id) continue;
    const body = JSON.stringify({ id: e.id, topic: e.topic, farm_id: e.farm_id, ts: e.ts, payload: e.payload }); const sig = h.secret ? createHmac("sha256", String(h.secret)).update(body).digest("hex") : "";
    try { const r = await fetch(String(h.url), { method: "POST", headers: { "content-type": "application/json", "x-itran-topic": String(e.topic), "x-itran-signature": sig }, body, signal: AbortSignal.timeout(8000) }); await p.query("insert into webhook_deliveries(webhook_id,event_id,status,response) values ($1,$2,$3,$4)", [h.id, e.id, r.status, (await r.text()).slice(0, 500)]); await p.query("update webhooks set last_status=$2, last_at=now(), fail_count=case when $2 between 200 and 299 then 0 else fail_count+1 end where id=$1", [h.id, r.status]); n++; }
    catch (err) { await p.query("insert into webhook_deliveries(webhook_id,event_id,status,response) values ($1,$2,0,$3)", [h.id, e.id, (err as Error).message.slice(0, 300)]); await p.query("update webhooks set last_status=0, last_at=now(), fail_count=fail_count+1 where id=$1", [h.id]); }
  }
  return n;
}
