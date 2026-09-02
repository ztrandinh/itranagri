-- 0200 · HMAC-of-body cho webhook/ingest (đã xác nhận với chủ đầu tư: chưa có đối tác live, đổi an toàn).
-- `key_hash` (sha256, 1 chiều) giữ nguyên làm định danh bearer-token — đúng chuẩn, không đổi.
-- Thêm secret KÝ RIÊNG, mã hoá 2 chiều (pgp_sym_encrypt, passphrase truyền từ app qua API_KEY_ENC_SECRET,
-- KHÔNG lưu trong DB) — vì HMAC cần server tính lại chữ ký từ nội dung thật, khác hẳn model bearer-token
-- chỉ cần so khớp hash. Tách secret ký riêng khỏi khóa API (2 bí mật độc lập, đúng pattern Stripe webhook
-- signing secret khác API key) — lộ 1 cái không tự động lộ cái kia.
alter table api_keys add column if not exists hmac_secret_enc bytea;
comment on column api_keys.hmac_secret_enc is 'pgp_sym_encrypt(signing_secret, API_KEY_ENC_SECRET) — giải mã bằng pgp_sym_decrypt khi verify HMAC-SHA256 body. NULL = key này chưa cấu hình HMAC (chấp nhận bearer-only, chỉ dùng cho key nội bộ/dev).';
