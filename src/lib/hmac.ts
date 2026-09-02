import { createHmac, timingSafeEqual } from "node:crypto";
import { adminPool } from "./db";

const DEV_DEFAULT = "dev-api-key-enc-secret-change-me-32ch!!";

/** Passphrase mã hoá/giải mã `api_keys.hmac_secret_enc` (pgp_sym_encrypt/decrypt) — KHÔNG lưu trong DB,
 *  chỉ tồn tại phía app. Cùng pattern lazy-check với SESSION_SECRET (auth.ts): chặn khi thực sự dùng ở
 *  production, không chặn ở module top-level (tránh vỡ `next build`). */
function encSecret(): string {
  const v = process.env.API_KEY_ENC_SECRET;
  if (process.env.NODE_ENV === "production" && (!v || v === DEV_DEFAULT || v.length < 32)) {
    throw new Error("ERR_API_KEY_ENC_SECRET_UNSAFE: API_KEY_ENC_SECRET chưa set, dùng giá trị mặc định công khai, hoặc quá ngắn (<32 ký tự) — bắt buộc set giá trị ngẫu nhiên riêng ở production.");
  }
  return v ?? DEV_DEFAULT;
}

/** Sinh secret ký HMAC mới (hex, 32 byte) — trả về plaintext (hiện 1 lần cho người tạo key) +
 *  passphrase mã hoá (để caller tự INSERT `pgp_sym_encrypt($secret, $passphrase)` vào cột enc). */
export function newHmacSecret(): { secret: string; encPassphrase: string } {
  const secret = [...crypto.getRandomValues(new Uint8Array(32))].map((x) => x.toString(16).padStart(2, "0")).join("");
  return { secret, encPassphrase: encSecret() };
}

/** Giải mã secret ký của 1 api_key (null nếu key chưa cấu hình HMAC — chấp nhận bearer-only). */
export async function decryptHmacSecret(hmacSecretEnc: Buffer | null): Promise<string | null> {
  if (!hmacSecretEnc) return null;
  const r = await adminPool().query("select pgp_sym_decrypt($1, $2) as s", [hmacSecretEnc, encSecret()]);
  return r.rows[0]?.s ?? null;
}

/** Verify chữ ký HMAC-SHA256 (hex) của raw body theo secret đã giải mã — so sánh hằng thời gian. */
export function verifyHmac(rawBody: string, signatureHex: string | null, secret: string): boolean {
  if (!signatureHex) return false;
  const expected = createHmac("sha256", secret).update(rawBody).digest("hex");
  const a = Buffer.from(expected, "hex"); const b = Buffer.from(signatureHex.replace(/^sha256=/i, ""), "hex");
  return a.length === b.length && timingSafeEqual(a, b);
}
