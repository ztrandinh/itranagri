import pino from "pino";

/** Logging có cấu trúc (JSON 1 dòng/log) — trước đây chỉ vài `console.log/error` rải rác, không
 * gắn ngữ cảnh (farm/action/job), không nối được vào hệ thu thập log tập trung (Datadog/ELK/Loki)
 * nếu sau này gắn. Không phải APM đầy đủ (không có tracing/alerting) — chỉ format log đúng chuẩn để
 * SAU NÀY gắn APM không phải viết lại từ đầu. Dùng `logger.child({...})` để gắn ngữ cảnh cố định. */
export const logger = pino({
  level: process.env.LOG_LEVEL ?? "info",
  formatters: { level: (label) => ({ level: label }) },
  timestamp: pino.stdTimeFunctions.isoTime,
});
