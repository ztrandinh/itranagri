# 05 · API & TÍCH HỢP — "ĐẤU NỐI DỄ DÀNG, NHẬP–XUẤT DỄ DÀNG"

## 1. Nguyên tắc API
- **API-first / contract-first:** OpenAPI 3.1 viết trước (hoặc sinh từ Zod schema dùng chung), review như code; SDK TypeScript/Python sinh tự động (`packages/sdk`); Postman/Bruno collection kèm.
- **Phiên bản:** `/api/v1/…`; thay đổi phá vỡ → v2 song song ≥ 12 tháng; deprecation header.
- **Xác thực:** người dùng OIDC (Bearer JWT Keycloak); máy-máy OAuth2 client credentials; đối tác API key + HMAC ký body (như VNPay/Shopee); thiết bị mTLS/token MQTT.
- **Phân quyền tại API** giống UI (RBAC/ABAC + RLS), farm scope trong token/claim `farm_ids`.
- **Idempotency:** header `Idempotency-Key` / trường `client_ref` cho mọi POST sự kiện (bắt buộc cho offline).
- **Chuẩn phản hồi:** JSON:API-lite `{data, meta, errors[]}`; lỗi có `code` máy đọc + thông điệp vi/en; phân trang cursor; lọc `?filter[field]=`, sắp xếp, `fields=`; ETag.
- **Giới hạn:** rate limit theo client; payload ≤ 5 MB (ảnh qua pre-signed URL S3).
- **Sự kiện ra ngoài:** Webhook (HMAC-SHA256, retry lũy tiến, log), hoặc subscribe NATS/MQTT topic (đối tác nội bộ), hoặc SSE.
- **Đọc linh hoạt:** GraphQL read-only (dashboards, đối tác BI) trên cùng phân quyền; MCP server cho AI.
- **Tài liệu:** developer portal (Scalar/Redoc) `developers.itranfarm.vn`, sandbox tenant `F99` dữ liệu giả.

## 2. Nhóm tài nguyên REST (rút gọn — mỗi module 1 namespace)
| Namespace | Tài nguyên chính | Ghi chú |
|---|---|---|
| `/farms`, `/orgs` | farm, profile, settings, modules | HQ |
| `/master` | species, breeds, uom, products(sku), partners, cost-centers, locations, devices, norms, price-lists | import CSV endpoint |
| `/ids` | `POST /ids/allocate {type, n}` sinh mã, `GET /ids/resolve/{code}` | offline pre-allocate |
| `/animals`, `/animal-groups` | CRUD hồ sơ, `/events` (POST batch), `/lifecycle`, `/withdrawal`, `/pedigree`, `/weigh-sessions` | |
| `/feeding` | feed-logs, mixer-loads, feed-plans | |
| `/plots`, `/seasons`, `/crop-logs`, `/work-orders`, `/silage-pits`, `/ndvi`, `/pasture-rotations` | GeoJSON in/out | |
| `/batches` | batch (D5/bio/chế biến), inputs/outputs, qc-results, ccp-logs, material-balance | |
| `/recipes`, `/formulation/solve` | recipe versions, LP solve | |
| `/inventory` | warehouses, lots, moves, balances, adjustments, stocktakes, weigh-tickets, gate-logs, purchase-orders | |
| `/sales` | partners(crm), contracts, orders, sales, payments, receivables, adoptions, subscriptions, pos-sessions | |
| `/trace` | epcis/events (capture/query theo EPCIS 2.0 REST), passports, qr, recalls, audit-packs | |
| `/resort` | rooms, rate-plans, bookings, folios, fnb-orders, tours, nps, events(MICE) | |
| `/hr` | staff, positions, shifts, attendance, checklist-runs, certificates, trainings, kpi-results, payroll-runs, bonus-pools | |
| `/finance` | expense-requests, approvals, budgets, funds, transfer-prices, pl-snapshots, gates, module-dossiers, bank-statements | |
| `/risk` | risks, indicators, incidents, five-whys, capas, drills, audits, obligations, standards | |
| `/sops` | sops, versions, steps, signoffs, checklist-templates, acknowledgements | |
| `/iot` | devices, sensor-reads (query Timescale: `?metric&from&to&bucket=15m`), calibrations, states | ingest qua MQTT, không REST |
| `/brain` | kpis (defs/values), alerts (+ack), alert-rules, rc-rules, recon-results, forecasts, recommendations, reports | |
| `/hq` | farms compare, sop-distributions, cross-audits, franchises, benchmarks | |
| `/param` | farm-profiles, param-sets, `POST /param/compute` | |
| `/files` | pre-signed upload, evidence links | |
| `/exports` | `POST /exports {scope, format}` → job → tải ZIP; `/exports/schema` | mọi dữ liệu |
| `/imports` | `POST /imports {type, file}` → validate report → commit/rollback | Sheets/CSV/XLSX |
| `/webhooks` | đăng ký, sự kiện, log | |
| `/public/trace/{gtin}/{lot}` | trang QR (Digital Link resolver ở domain `id.itranfarm.vn`) | không auth |

## 3. Sự kiện (event bus) — chủ đề & payload chuẩn
- Chủ đề: `itran.{farm}.{domain}.{event}` (NATS) ↔ MQTT `itran/{farm}/{domain}/{event}`.
- Payload CloudEvents 1.0 (`id, source, type, time, datacontenttype, data`), `data` = bản ghi + `version`.
- Ví dụ: `itran.F01.animal.event.created`, `itran.F01.inventory.move.created`, `itran.F01.iot.sensor.read`, `itran.F01.brain.alert.raised`, `itran.F01.finance.gate.passed`.
- Consumer nội bộ: KPI, alert, EPCIS projector, notification, search index, HQ aggregator; đối tác qua webhook mapping.

## 4. IoT ingest
- MQTT topic thiết bị: `itran/{farm}/dev/{device_code}/{metric}` payload `{v, ts, q, meta}` hoặc Sparkplug B (gateway PLC).
- LoRaWAN: ChirpStack → MQTT `application/{id}/device/{eui}/event/up` → codec registry (JS decoder theo model) → chuẩn hóa.
- Serial: `edge-agent` driver plugin `{name, transport: serial|tcp|ble, parser}`; mẫu cân: regex ASCII → `{gross, net, stable}`; RFID: FDX-B 15 số.
- Camera: `itran/{farm}/cam/{cam_id}/detections` `{count, boxes, conf, snapshot_url}`.
- Đăng ký thiết bị: `POST /iot/devices` sinh cert/token; provisioning QR dán thiết bị.

## 5. Nhập dữ liệu (import) — "nhập dễ dàng"
| Nguồn | Cách | Ghi chú |
|---|---|---|
| Google Sheets GĐ1 (schema Phần IX) | Kết nối Sheets API hoặc upload CSV; map cột; validate; import theo lô; rollback 24h | G0–G1 |
| Excel/CSV bất kỳ | Trình hướng dẫn map cột → template; lưu mapping tái dùng | G1 |
| Phần mềm khác (Herdwatch/AgriWebb/CattleMax export, KiotViet, MISA) | Template import theo định dạng xuất của họ | G2+ |
| GeoJSON/KML/SHP/ISOXML | Ranh lô, zone | G1/G4 |
| Ảnh drone/NDVI (GeoTIFF/COG) | Upload → tile | G2 |
| Sao kê ngân hàng (CSV/Excel/API) | RC10 | G3 |
| Bản tin thú y/giá thị trường | RSS/nhập tay/API | G3 |
| Danh mục vaccine tỉnh, luật lương | Seed có phiên bản | G1/G3 |

## 6. Xuất dữ liệu (export) — "xuất dễ dàng, dữ liệu của công ty"
- Toàn bộ dữ liệu theo phạm vi/thời gian: CSV (UTF-8 BOM), Parquet, JSON Lines, kèm `schema.json` + data dictionary; ZIP có sha256; lịch xuất tự động (tuần) về S3 riêng của công ty.
- Theo chuẩn: EPCIS 2.0 JSON-LD; ICAR ADE (animal/events) ⏩; ISOXML (Rx) ⏩; GS1 Digital Link; PDF hồ sơ audit; mẫu báo cáo TT 66/2025 (chăn nuôi), VietGAP/GlobalG.A.P evidence pack; MISA (chứng từ CSV/API); Excel báo cáo bất kỳ màn hình (nút Export).
- Không có màn hình nào "chỉ xem không xuất được".

## 6b. LUẬT CONNECTOR (chống FOMO — Góp ý v1.5 mục 7.3)
Connector chỉ được xây khi **có nghiệp vụ thật đang chạy** và chỉ ra được dòng tiền/bản ghi nó phục vụ; mỗi connector = một khoản **nợ bảo trì vĩnh viễn** phải có người nhận (KS công nghệ). **Thứ tự năm 1: VietQR (đối chiếu tay/sao kê) → Zalo ZNS (đăng ký OA ngay ngày 0, lead time 2–4 tuần; SMS là kênh ĐỎ dự phòng bắt buộc) → xuất file MISA (không API) → import sao kê CSV (RC10). HẾT.** VNPay/MoMo/Shopee/TikTok/hóa đơn điện tử/cổng truy xuất: chỉ mở khi kênh tương ứng có doanh thu thật. Bảng mục 7 dưới đây là **bản đồ dài hạn để tra cứu**, không phải backlog.

## 7. Danh mục tích hợp bên ngoài (connector) & giai đoạn
| Nhóm | Đối tác/chuẩn | Xác thực | GĐ |
|---|---|---|---|
| Thông báo | Zalo OA/ZNS (template duyệt, OAuth v4, ZCA), SMS brandname (Viettel/VNPT), email (SES/SMTP), Telegram nội bộ | OAuth/API key | G2 |
| Thanh toán | VNPay (HMAC-SHA512, IPN, sandbox), MoMo v2 (HMAC-SHA256), VietQR/NAPAS, cổng ngân hàng (BIDV/MB/ACB open API khi có) | HMAC | G2–G3 |
| Hóa đơn điện tử | MISA meInvoice (Open API), Viettel S-Invoice (REST v2), VNPT Invoice (SOAP) — chế độ hóa đơn máy tính tiền NĐ 70/2025 | app id/token, user+MST | G4 |
| Kế toán | MISA AMIS/ASP API (đẩy chứng từ, kéo sổ), 1Office | API token | G3–G4 |
| Bán lẻ/TMĐT | KiotViet (OAuth2 CC + header Retailer), Sapo (private app), Haravan (OAuth2), Shopee Open Platform v2 (partner_id/key HMAC-SHA256, token 4h), TikTok Shop Partner Center (OAuth), Lazada | | G4 |
| Vận chuyển | GHN, GHTK, Viettel Post, Ahamove | API key | ⏩ |
| Truy xuất | Cổng truy xuất quốc gia (qua đơn vị chỉ định), iCheck Trace, TraceVerified, TE-FOOD (Đồng Nai) | hợp đồng | G4 |
| Chăn nuôi–thú y | Hệ thống báo cáo TT 66/2025 (mẫu), bản tin dịch tỉnh (RSS/nhập), thú y hợp đồng ký số | | G2–G3 |
| Thiết bị vật nuôi | SenseHub/Allflex API, smaXtec API, Moocall; đầu đọc Agrident/Allflex/Gallagher (BLE/RS-232); Tru-Test/Gallagher weigh head | BLE/API | G2–G3 |
| Máy nông nghiệp | Deere Ops Center, CNH FieldOps (ISO 15143-3), Trimble, Leaf/agrirouter (aggregator), ISOXML USB | OAuth | ⏩ |
| Thời tiết | Davis WeatherLink v2, Sencrop, Open-Meteo/KTTV, mực nước trạm thủy văn (KTTV API/scrape có phép) | key | G2 |
| Viễn thám | Sentinel-2 (Copernicus Data Space/STAC), Planet ⏩ | OAuth | G2 |
| Resort | Channel manager (ezCloud ezCms/SiteMinder) → OTA; khóa thông minh (TTLock/Tuya API); đăng ký lưu trú | API | G3–G4 |
| Nhân sự | BHXH điện tử (file XML qua nhà cung cấp), ngân hàng file lương | file | G3 |
| Bản đồ | MapTiler/OSM tiles + PMTiles offline; ảnh vệ tinh nền | key | G1 |
| AI | Claude API (Sonnet 5), MCP; ASR tiếng Việt on-device (Whisper nhỏ/Vosk) | key | G3 |
| Định danh sản phẩm | GS1 Vietnam (GTIN/GLN), Cục SHTT (nhãn hiệu — hồ sơ) | | G2 |
| BI ngoài | Metabase/Superset/Power BI đọc view `bi_*` (read replica) | DB user read | G2 |

## 8. Ví dụ hợp đồng API (trích)
```http
POST /api/v1/animals/events   Idempotency-Key: 8f1c…
{
  "farm": "F01",
  "events": [{
    "client_ref": "018f3d…-uuidv7",
    "animal_code": "F01-BO-00123",
    "type": "TREATMENT",
    "occurred_at": "2026-08-18T07:42:00+07:00",
    "recorded_by": "NS-014",
    "data": {"drug_sku":"SKU-OXY-100","lot":"L2406-77","dose_ml":15,"route":"IM","withdrawal_days":21,"protocol_id":"TP-017"},
    "evidence": [{"file_id":"…","kind":"PHOTO"}]
  }]
}
→ 207 Multi-Status {results:[{client_ref, id, code, status:"CREATED"|"DUPLICATE"|"REJECTED", errors}]}
```
```http
GET /api/v1/iot/sensor-reads?device=F01-SS-0042&metric=DO&from=…&to=…&bucket=5m
GET /api/v1/trace/lots/F01-ME-260315-02/tree?direction=both
POST /api/v1/exports {"scope":"farm:F01","from":"2026-01-01","to":"2026-06-30","format":"parquet"}
```

## 9. Chính sách dữ liệu & pháp lý tích hợp
- Hợp đồng vendor bắt buộc: dữ liệu thuộc công ty; xuất định dạng mở bất kỳ lúc nào; không khóa.
- NĐ 13/2023 bảo vệ dữ liệu cá nhân: khách/nhân sự có hồ sơ xử lý; ẩn danh hóa; đồng ý; log truy cập.
- Webhook/API đối tác qua staging trước; khóa API bị lộ trong 1 giờ; audit truy cập API.
