# 14 · ĐỐI CHIẾU SPEC-05 + QUYỂN 3 §15 ↔ APP (rà lại sau khi build) — 18/08/2026

## A. Thư viện quy trình chuẩn (Quyển 3 §15)
| Mục bộ gốc | Bộ gốc | App (DB) | Kết quả |
|---|---|---|---|
| L1 chuỗi giá trị | 8 | 8 (`processes.l1_chain`) | ✅ |
| L2 quy trình bộ phận | bảng §15.2 liệt kê 81 dòng (tiêu đề ghi "66") | 81 `processes` mã `SOP-XX-NN`, theo cơ quan: BO10 GA8 DE3 RAS6 TOM4 TT7 SH6 NAM3 CB6 KD5 RS6 HC5 CN6 AT6 | ✅ đủ từng dòng |
| L3 SOP thao tác | 67+30+12+30+18+45+36+10+30+25+34+29+28+28 = **422** | 422 `process_steps` (sop_code) = 422 `sops` | ✅ khớp từng L2 (`sop_count`) |
| SOP mẫu | SOP-BO-07.2 TMR vỗ béo · SOP-TR-01.3 nạp trùn | SOP-BO-07.2 ✓ · SOP-SH-01.2 (giữ mã cũ trong tiêu đề; SOP cũ đánh THAY_THE, 0045) | ✅ |
| Chuẩn 10+1 trường | mã·mục đích·người·công cụ·tần suất·bước·chuẩn ĐẠT·bằng chứng·an toàn·video + trường 11 điều khoản | cột `sops`: title, owner_role, tools, frequency, (bước = process_steps), pass_criteria, evidence, safety, video_url, std_clauses[], version/published_at/review_due, ccp/ccp_limit/ccp_action | ✅ |
| Trường 11 = dropdown (SPEC-05 §4.4) | chọn từ standard_clauses | /quan-tri?t=sops → ô `std_clauses` là danh sách tick từ `standard_requirements` (127 điều) | ✅ |
| 12 điểm giao nhận SLA | GN1–GN12 | 12 `dept_links` "GN…" (D5→chuồng, chuồng→trùn, ruộng→D5, rơm→nấm, nấm→trùn, RAS→wetland, chuồng→CB, CB→KD/RS, bếp→BSF, KD→CB, RS↔đàn, AT→*) | ✅ |
| Mỗi L2 có bước, có phòng, có visible_depts | — | 0 L2 thiếu bước · 0 bước thiếu dept · 0 L2 thiếu visible_depts | ✅ |
| CCP ghi giới hạn + hành động | HACCP | 5 SOP CCP (CB-01.3, CB-01.6, CB-03.3, CB-06.2, RS-03.4) hiện đỏ trong thư viện | ✅ |
| Rà hạn 12 tháng | §15.7 | `sops.review_due` = ban hành + 365 ngày | ✅ |
| Màn hình | — | /to-chuc?tab=sop (L1→L2→L3, tìm, CCP đỏ, [điều khoản]); mỗi L2 mở được trong Khai báo quy trình (thêm/xóa bước, xuất bản → thông báo bộ phận, chạy sinh việc) | ✅ |

## B. Tầng tuân thủ (SPEC-05)
| SPEC-05 | App | Kết quả |
|---|---|---|
| §0 chuẩn = metadata trên MỘT bộ quy trình | không có module chuẩn riêng; `clause_controls` trỏ vào vật thật | ✅ |
| §1 danh mục chuẩn 16 mã | 23 `standards` (đủ 16 của spec, mã: VIETGAP-TT/CN, VN-TT66, ORGANIC-VN, VN-ND13, VN-PHANBON, HACCP, ISO22000, ISO9001, GLOBALGAP, EU-ORGANIC, USDA-NOP, HALAL, JGAP, KR-MFDS + ISO14001/ASC/BRCGS/RAINFOREST/CN-GB/JAS/VIETGAP-TS/ITRAN-STD) + `spec_code`, `priority` (thứ tự kích §5) | ✅ |
| §2 schema | standards · standard_requirements(=standard_clauses, level=MAJOR/MINOR/KHUYEN_NGHI) · controls · clause_controls · compliance_gaps · sops.std_clauses[] | ✅ |
| §3 map lõi ~40 dòng | 34 controls, 247 map, **127/127 điều khoản có control, 114/114 MAJOR** | ✅ |
| §4.1 /compliance độ phủ + chạy evidence_query | /tuan-thu: pill từng chuẩn (x/y, MAJOR x/y), 34 nút control → `/api/compliance/evidence` chạy SQL bằng chứng sống, bảng gap đỏ | ✅ |
| §4.2 gói audit theo chuẩn ZIP | `/api/exports/audit-std?std=&from=&to=` (điều khoản↔control, controls, evidence/*.csv, data/* theo evidence_tables, checks, certifications, MANIFEST sha256) | ✅ |
| §4.3 audit nội bộ 2 lần/năm + diễn tập thu hồi | `gen_compliance_tasks(farm)` trong job tasks/all → tasks AUDIT_NOI_BO, DIEN_TAP_THU_HOI; findings → compliance_checks/compliance_gaps | ✅ |
| §4.4 trường 11 dropdown | như A | ✅ |
| §4.5 KPI % MAJOR có control | cột `major_with_control/major` trong `v_compliance_coverage` hiện trên pill | ✅ |
| §5 kích chuẩn = đổi `standards.status`, không sửa code | status/priority là dữ liệu (/quan-tri?t=standards) | ✅ |
| Giết mổ | không làm tại trại (chỉ đạo chủ) — control C-HALAL-SLAUGHTER = hợp đồng lò mổ chứng nhận, thuê ngoài | ✅ theo chỉ đạo |

## C. Ghi chú
- Số "66 L2 / ~410 L3" trong bộ gốc là trần ước lượng; bảng liệt kê thực tế trong §15.2 là 81 dòng / 422 SOP → app theo bảng liệt kê (thừa không thiếu).
- Bộ 65 quy trình kiểm kê cũ (QT-*) vẫn giữ (theo đối tượng); 81 SOP-* là thư viện theo cơ quan; hai bộ cùng chạy trên 1 engine.
