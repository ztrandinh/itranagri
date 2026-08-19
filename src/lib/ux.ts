"use client";
/** ĐO TRẢI NGHIỆM (HEART) — đặt 3 mốc quanh mỗi tác vụ lõi để biết:
 *  bao nhiêu % làm xong · mất bao lâu · vấp ở đâu.
 *  Dùng:
 *    const t = uxTask("ghi_3_cham");   // khi bắt đầu
 *    t.done();                          // khi ghi thành công
 *    t.abandon();                       // khi thoát giữa chừng
 *    uxFormError("ghi_3_cham", "thieu_so_luong");
 *  Nguyên tắc: gửi kiểu "bắn và quên" (keepalive), lỗi đo KHÔNG được ảnh hưởng nghiệp vụ. */

type Payload = Record<string, unknown>;

function send(body: Payload) {
  try {
    const data = JSON.stringify({ ...body, path: typeof location !== "undefined" ? location.pathname : undefined });
    if (typeof navigator !== "undefined" && navigator.sendBeacon) {
      navigator.sendBeacon("/api/ux", new Blob([data], { type: "application/json" }));
      return;
    }
    void fetch("/api/ux", { method: "POST", headers: { "content-type": "application/json" }, body: data, keepalive: true }).catch(() => {});
  } catch { /* đo lường không bao giờ làm vỡ luồng người dùng */ }
}

export function uxTask(task: string) {
  const t0 = Date.now();
  let closed = false;
  send({ kind: "task_start", task });
  return {
    done(detail?: Payload) { if (closed) return; closed = true; send({ kind: "task_done", task, ms: Date.now() - t0, ok: true, detail }); },
    abandon(reason?: string) { if (closed) return; closed = true; send({ kind: "task_abandon", task, ms: Date.now() - t0, ok: false, detail: reason ? { reason } : undefined }); },
  };
}

export function uxFormError(task: string, code: string) { send({ kind: "form_error", task, ok: false, detail: { code } }); }
export function uxSearch(q: string, n: number) { send({ kind: "search", task: "tim_kiem", detail: { len: q.length, results: n } }); }
