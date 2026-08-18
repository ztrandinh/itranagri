# 08 · CHẤT LƯỢNG – BẢO MẬT – VẬN HÀNH (NFR, TEST, DEVOPS, SLO, DR)

## 1. YÊU CẦU PHI CHỨC NĂNG (ISO/IEC 25010)
| Nhóm | Yêu cầu đo được |
|---|---|
| Hiệu năng | API p95 < 300 ms (đọc), < 500 ms (ghi batch 50 sự kiện); dashboard 1 trang < 2 s; sync 1.000 sự kiện offline < 30 s trên 4G; ingest cảm biến ≥ 5.000 điểm/s/trại; RC đêm < 30'; alert ĐỎ edge < 10 s, cloud < 60 s |
| Khả dụng | Cloud SLO 99,5%/tháng (G1–G3) → 99,9% (SaaS); edge hoạt động độc lập ≥ 72 h mất internet; mobile offline vô hạn (giới hạn dung lượng) |
| Dữ liệu | RPO 15' (WAL streaming + PITR), RTO 4 h; backup 3-2-1: PITR + snapshot ngày (SeaweedFS vùng khác) + bản offline hằng tuần; lưu ≥ 5 năm; hash-chain kiểm chứng hằng ngày; không mất bản ghi (at-least-once + idempotent) |
| Bảo mật | OWASP ASVS L2; ISO 27001 Annex A áp dụng; MFA vai duyệt; RLS; mã hóa at-rest (LUKS + cột nhạy cảm pgcrypto); TLS 1.3; secrets OpenBao; SBOM; quét lỗ hổng mỗi build; pentest trước SaaS và hằng năm |
| Khả dụng người dùng | Công nhân: mỗi bản ghi ≤ 3 chạm, ≤ 20 s; chữ ≥ 16 pt ngoài trời, tương phản cao, găng tay/ướt (nút lớn); WCAG 2.2 AA web; tiếng Việt không dấu tìm được; giọng nói |
| Bảo trì | Module ranh giới rõ; test ≥ 80% domain; ADR; docs sinh từ code; nâng phiên bản nền tối đa trễ 1 major |
| Tương thích | Android 10+ (tầm trung 3 GB RAM), iOS 15+; Chrome/Edge/Safari 2 bản mới; máy in ZPL/TSPL; RS-232/BLE thiết bị theo danh mục |
| Mở rộng | 1 → 100 trại/tenant, 10⁹ hàng SENSOR_READ (nén Timescale), thêm trại không sửa code |
| Pháp lý | NĐ 13/2023 dữ liệu cá nhân; TCVN 12850; TT 66/2025; NĐ 70/2025 hóa đơn; lưu trữ hồ sơ chứng nhận ≥ 5 năm |

## 2. CHIẾN LƯỢC KIỂM THỬ
| Tầng | Công cụ | Phạm vi |
|---|---|---|
| Unit | Vitest 4 | domain logic, KPI/RC/alert formula (golden datasets), máy sinh mã, formulation |
| Integration | Vitest + Testcontainers (PG18+Timescale+PostGIS, NATS) | repository, RLS (test mỗi bảng: farm A không thấy farm B), migration lên/xuống, outbox |
| Contract | Pact 17 + OpenAPI diff | mobile ↔ API, đối tác ↔ API, edge ↔ cloud |
| E2E | Playwright 1.62 (web), Maestro/Detox (mobile), thiết bị thật Android | luồng theo vai A1–A14, offline→sync, quét BLE/QR (simulator + thật) |
| Hiệu năng | k6 2.2 | ingest, sync, dashboard, RC |
| Bảo mật | ZAP, Trivy/Grype (SBOM), Semgrep, dependency review; pentest ngoài | |
| Dữ liệu | dbt-style test trên view/KPI (không null, tổng khớp), backtest KPI khi đổi phiên bản | |
| Hiện trường | Checklist nghiệm thu mỗi sprint với 2 người dùng thật; "ngày mất mạng" giả lập hằng quý; drill DR | |
| Chấp nhận | UAT theo story với KTT/GĐ; sandbox F99 dữ liệu giả sinh (faker theo nghiệp vụ) | |

## 3. DEVOPS & MÔI TRƯỜNG
- Nhánh: trunk-based, PR nhỏ, preview env cho web; conventional commits; semantic release.
- CI (GitHub Actions): lint (Biome) → typecheck → unit → build → integration (containers) → contract → e2e smoke → SBOM/scan → publish image (ghcr) → Argo CD sync staging → e2e đầy đủ → phê duyệt → prod (blue/green). Mobile: EAS build/update, testflight/internal track.
- Migration DB: Drizzle, chạy job trước rollout, tương thích ngược 1 phiên bản (expand/contract).
- Feature flags theo farm/vai; kill switch tính năng.
- Edge: image đa kiến trúc (amd64/arm64), Portainer Edge stack, cập nhật theo đợt (canary 1 trại), rollback tự động nếu healthcheck fail.
- Quan sát: OTel trace end-to-end (mobile → API → DB → job), log cấu trúc JSON có `farm_id/staff_id/trace_id`, metric RED/USE, dashboard SLO, alert on-call (Grafana OnCall) — người trực A13 + dev.
- Cost: nhãn tài nguyên theo tenant; báo cáo chi phí tháng vs trần 4–6% DT.

## 4. BẢO MẬT CHI TIẾT
- Xác thực: Keycloak (OIDC PKCE, refresh rotation), MFA TOTP/passkey cho GĐ/KTT/HQ/chủ/KS CN; PIN offline (Argon2, khóa sau 5 lần); thiết bị đăng ký (device binding), xóa từ xa.
- Phân quyền: RBAC/ABAC + RLS; kiểm tra "self-approve" cấm; nhật ký quyền thay đổi; review quyền quý.
- Dữ liệu: phân loại (công khai/nội bộ/nhạy cảm: lương, giá vốn, sức khỏe NS, khách); mã hóa cột nhạy cảm; che dữ liệu trong log; export nhạy cảm cần vai + lý do + log.
- Ứng dụng: OWASP top 10; CSP; rate limit; input Zod; SQL tham số hóa; upload quét malware; ký webhook; API key xoay 90 ngày.
- Hạ tầng: k3s hardened (CIS), network policy, mTLS nội bộ (Linkerd tùy chọn), OpenBao, không SSH mật khẩu, bastion, WAF/CDN cho public (Cloudflare/VN CDN).
- Edge: disk mã hóa, không cổng mở ra ngoài, tunnel ngược, cert thiết bị MQTT, cập nhật ký số.
- Vận hành: incident response playbook (phát hiện → cô lập → thông báo ≤ 72h theo NĐ 13 → khắc phục → 5-Why); backup thử khôi phục hằng tháng; kiểm tra hash-chain hằng ngày; SoA ISO 27001; đào tạo an toàn thông tin nhân sự trại (phishing, mật khẩu, thiết bị).
- Riêng tư: camera chỉ khu sản xuất/vành đai; thông báo trong HĐLĐ; khách resort ẩn danh sau 5 năm; quyền xóa/xuất dữ liệu cá nhân.

## 5. SAO LƯU & KHÔI PHỤC THẢM HỌA
| Thành phần | Cơ chế | Kiểm tra |
|---|---|---|
| PostgreSQL | CNPG: WAL streaming → S3 (SeaweedFS vùng B), base backup ngày, PITR 30 ngày; replica standby | restore drill tháng; DR drill quý (RTO 4h) |
| Object storage | Replication SeaweedFS 2 vùng + Garage edge; bucket versioning | checksum job |
| NATS JetStream | replica 3; retention 7 ngày; edge leaf lưu tới khi đồng bộ | mô phỏng đứt mạng |
| Keycloak/OpenBao | export cấu hình + backup DB; unseal keys chia 3/5 | drill |
| Cấu hình | GitOps (mọi thứ trong git) | rebuild từ 0 hằng năm |
| Edge | ảnh đĩa chuẩn + cấu hình từ cloud; thay máy trong 4h | drill |
| Bản offline | Xuất Parquet toàn bộ hằng tuần vào ổ cứng tại trại/công ty (P4 dữ liệu công ty) | mở đọc thử |

## 5b. QUY TẮC THỰC ĐỊA CÓ HIỆU LỰC NGAY (Ray A — theo Góp ý v1.5 mục 13)
Luật UX công nhân (≤3 chạm VÀ ≤20 s, chữ ≥16 pt, nút lớn tay găng/ướt, tương phản ngoài nắng, tìm không dấu) · test RLS mỗi bảng chặn CI · backup 3-2-1 bản rẻ (backup ngày + CSV tuần về ổ cứng công ty + **diễn tập restore QUÝ**) · "ngày mất mạng" giả lập quý · NFR bổ sung: **0 tờ phiếu giấy mất dấu (seri liền mạch 100%)** ngang hàng "0 mất bản ghi" · MFA TOTP vai duyệt, secrets trong env, API key xoay 90 ngày · SLA hỗ trợ đội 1 người: lỗi chặn ghi chép sửa trong ngày (giấy BM gánh), lỗi cao 1 tuần, còn lại backlog; alert hạ tầng đổ về Zalo chủ đầu tư khi chưa có A13 · điện thoại cấp phát: tài khoản riêng từng máy, khóa màn hình, thu hồi phiên ≤1h, danh sách máy trong `devices` · runbook tối thiểu 5 mục (sync, thiết bị offline, RC lệch lớn, backup/restore, thu hồi phiên) · **bàn giao đội trại sau 90 ngày**: A13 nhận vận hành (bài kiểm tra: dựng lại hệ từ backup trong 1 buổi), MKT nhận trang QR/ZNS/nhận nuôi.

## 6. VẬN HÀNH SẢN PHẨM
- Kênh hỗ trợ: trong app (chụp màn hình + log tự đính), Zalo nhóm trại, hotline giờ hành chính; SLA lỗi: chặn công việc 2h, cao 1 ngày, thường 1 tuần.
- Analytics sản phẩm (PostHog self-host hoặc tự log): tính năng dùng, thời gian/bản ghi, lỗi.
- Runbook: sự cố sync, thiết bị offline, RC lệch lớn, backup lỗi, khôi phục edge, xoay khóa.
- Quản lý thay đổi: mọi thay đổi ngưỡng/rule/quyền có vết + thông báo GĐ; release note tiếng Việt cho người dùng.
