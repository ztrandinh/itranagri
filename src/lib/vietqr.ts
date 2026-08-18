/** VietQR (NAPAS 247 · chuẩn EMVCo QR) — sinh chuỗi QR chuyển khoản có sẵn số tiền & nội dung, không cần dịch vụ ngoài. Ngân hàng nhận: farms.bank_bin (mã BIN 6 số NAPAS, vd 970436 Vietcombank), farms.bank_account. */
function tlv(id: string, v: string): string { return id + String(v.length).padStart(2, "0") + v; }
function crc16(s: string): string { let crc = 0xffff; for (let i = 0; i < s.length; i++) { crc ^= s.charCodeAt(i) << 8; for (let j = 0; j < 8; j++) crc = crc & 0x8000 ? ((crc << 1) ^ 0x1021) & 0xffff : (crc << 1) & 0xffff; } return crc.toString(16).toUpperCase().padStart(4, "0"); }
export function vietqr(bin: string, account: string, amount?: number, memo?: string): string {
  const acct = tlv("00", "A000000727") + tlv("01", tlv("00", bin) + tlv("01", account)) + tlv("02", "QRIBFTTA");
  let s = tlv("00", "01") + tlv("01", amount ? "12" : "11") + tlv("38", acct) + tlv("53", "704") + (amount ? tlv("54", String(Math.round(amount))) : "") + tlv("58", "VN") + (memo ? tlv("62", tlv("08", memo.normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/[^A-Za-z0-9 .-]/g, "").slice(0, 25))) : "");
  s += "6304"; return s + crc16(s);
}
/** QR SVG đơn giản (module hóa bằng thuật toán QR chuẩn là nặng) → dùng dịch vụ ảnh VietQR khi online (img.vietqr.io) và chuỗi EMV để in/copy. */
export function vietqrImage(bin: string, account: string, amount?: number, memo?: string, name?: string): string {
  const q = new URLSearchParams(); if (amount) q.set("amount", String(Math.round(amount))); if (memo) q.set("addInfo", memo); if (name) q.set("accountName", name);
  return `https://img.vietqr.io/image/${bin}-${account}-compact2.png?${q.toString()}`;
}
export const BANK_BINS: [string, string][] = [["970436", "Vietcombank"], ["970418", "BIDV"], ["970415", "VietinBank"], ["970405", "Agribank"], ["970407", "Techcombank"], ["970422", "MB Bank"], ["970416", "ACB"], ["970432", "VPBank"], ["970423", "TPBank"], ["970403", "Sacombank"], ["970441", "VIB"], ["970443", "SHB"], ["970426", "MSB"], ["970437", "HDBank"], ["970431", "Eximbank"], ["970448", "OCB"], ["970429", "SCB"], ["970454", "VietCapital"], ["970419", "NCB"]];
