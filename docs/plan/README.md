# ITRAN OS — BỘ KẾ HOẠCH PHÁT TRIỂN PHẦN MỀM (v1.0 · 18/08/2026)

Phần mềm quản trị chuỗi trang trại tuần hoàn ITRAN FARM — đứng ở góc nhìn **công ty mẹ quản nhiều trại, nhiều vùng, nhiều pháp nhân**; triển khai bằng **Claude Code** (đơn vị: phiên/ngày). Căn cứ nghiệp vụ: Bộ gốc 12 file (FILE-GỐC v3.1, Quyển 1–5, Phụ lục sổ tay & sổ cái). Căn cứ công nghệ: khảo sát 60+ phần mềm nông nghiệp/ERP thế giới + kiểm chứng phiên bản/giấy phép công nghệ ngày 18/08/2026.

| # | File | Đọc khi |
|---|---|---|
| 00 | [Tổng quan kế hoạch](00-TONG-QUAN-KE-HOACH.md) | Bắt đầu — tầm nhìn, 10 nguyên tắc, góc nhìn công ty mẹ, kiến trúc 1 trang, lộ trình tóm tắt, quyết định cần chốt, việc làm ngay |
| 01 | [Benchmark thế giới](01-BENCHMARK-PHAN-MEM-THE-GIOI.md) | Muốn biết học gì từ ai, chuẩn nào áp dụng, thêm gì so bộ gốc |
| 02 | [Kiến trúc hệ thống](02-KIEN-TRUC-HE-THONG.md) | Tech stack đã kiểm chứng, luồng dữ liệu, offline/edge/IoT, multi-tenant, ADR |
| 03 | [Danh mục module & tính năng](03-DANH-MUC-MODULE-TINH-NANG.md) | 20 module + cơ chế mở rộng, màn hình 14 vai, ma trận quyền, 12 SLA |
| 04 | [Mô hình dữ liệu](04-MO-HINH-DU-LIEU.md) | Bảng, ID, luật append-only/RLS, seed, import |
| 05 | [API & tích hợp](05-API-TICH-HOP.md) | REST/event/MQTT, import–export, connector VN & thế giới |
| 06 | [Engine thông minh](06-ENGINE-THONG-MINH.md) | KPI, alert, RC1–RC15, báo cáo, dự báo, gợi ý, AI, camera, thế số |
| 07 | [Lộ trình triển khai](07-LO-TRINH-TRIEN-KHAI.md) | Đợt A→F bằng Claude Code, DoD, thứ cần thời gian thật |
| 08 | [Chất lượng – bảo mật – vận hành](08-CHAT-LUONG-BAO-MAT-VAN-HANH.md) | NFR, test, DevOps, DR, ISO 27001 |
| 09 | [Cấu trúc repo & chuẩn code](09-CAU-TRUC-REPO-CHUAN-CODE.md) | Monorepo, chuẩn code, bắt đầu nhanh |
| 10 | [Phản hồi Góp ý ràng buộc v1.5](10-PHAN-HOI-GOP-Y-v1.5.md) | Đã áp gì, phản biện gì, 6 cầu nối Ray A→B, đề nghị SPEC-01 v1.1 |
| — | [CLAUDE.md mẫu cho repo](CLAUDE.md.template) | Ray B; Ray A dùng CLAUDE.md của starter (+ 6 cầu nối file 10) |

**Hai đường ray (theo Góp ý v1.5):** Ray A = `files/itran-os-starter` (Supabase + Next.js PWA) cho 90 ngày thực chiến; Ray B = bộ 10 file này làm bản đồ đích, mở khi ≥3 trại / ≥3 khách trả tiền / cần IoT thời gian thực. Bảng RC chuẩn duy nhất: file 06 §3 (RC11 = giấy–số).

**Luật thứ bậc:** Bộ gốc thắng về nghiệp vụ; bộ kế hoạch này thắng về công nghệ & cách làm; mâu thuẫn → INCIDENT "tài liệu", sửa trong 7 ngày, tăng phiên bản.
