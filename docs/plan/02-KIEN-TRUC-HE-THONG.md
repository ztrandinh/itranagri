# 02 · KIẾN TRÚC HỆ THỐNG ITRAN AGRI
*Tech stack đã kiểm chứng phiên bản/giấy phép ngày 18/08/2026 (nguồn: trang phát hành chính thức). Nguyên tắc chọn: (1) hiện đại nhưng ổn định (GA, cộng đồng lớn), (2) giấy phép cho phép **tự host + bán SaaS đa tenant** (tránh AGPL/BSL/SSPL ở lõi), (3) chạy được **tại trại (edge) khi mất internet**, (4) TypeScript xuyên suốt để đội nhỏ làm được nhiều.*

## 1. KIẾN TRÚC TỔNG THỂ (C4 – Level 1/2)

```
                     ┌──────────────────────── NGƯỜI DÙNG ────────────────────────┐
                     │ Công nhân (mobile offline) · KTT/GĐ (web+mobile) · Chủ đầu tư/HQ (web) │
                     │ Khách QR truy xuất (web public) · Kiểm toán (read-only) · Đối tác (API)  │
                     └───────────────┬─────────────────────────────┬───────────────┘
                                     │                             │
   ┌───────────── CLOUD (VN region) ─┴───────────────┐   ┌─────────┴───── TẠI TRẠI (EDGE F0x) ─────────┐
   │ itran-web (Next.js 16)   itran-api (NestJS 11)   │   │ itran-edge box (x86/ARM, Docker Compose):    │
   │ itran-sync (PowerSync)   itran-brain (FastAPI)   │◄─►│  mosquitto (MQTT) · nats-leaf · chirpstack   │
   │ NATS JetStream (bus+MQTT) · pg-boss (jobs)       │   │  edge-agent (driver cân/RFID/OCR/AI)          │
   │ PostgreSQL 18 + Timescale + PostGIS (CNPG HA)    │   │  edge-rules (alert ĐỎ cục bộ, còi/đèn)        │
   │ SeaweedFS (S3) · Valkey · Meilisearch            │   │  garage (S3 cache ảnh) · sqlite buffer         │
   │ Keycloak 26 (OIDC) · OpenBao (secrets)           │   │  otel-collector (buffer log/metric)            │
   │ OTel → Grafana/Loki/Tempo · Argo CD · k3s        │   │  local dashboard TV (Grafana/Next static)      │
   └──────────────────────────────────────────────────┘   └───────────────────────────────────────────────┘
```

**Kiểu kiến trúc:** *Modular monolith* (`itran-api`) chia theo bounded context (file 04 mục 3) + vài dịch vụ tách vì lý do kỹ thuật (Python ML, sync engine, edge). Không micro-service từ đầu (đội 9 người); ranh giới module rõ để tách sau qua NATS.

## 2. TECH STACK (quyết định)

| Lớp | Chọn | Phiên bản (8/2026) | Giấy phép | Lý do / thay thế |
|---|---|---|---|---|
| Ngôn ngữ | TypeScript (strict) toàn stack; Python cho ML | TS 5.x, Node 22 LTS, Python 3.12 | — | Một ngôn ngữ, chia sẻ schema (Zod) web/mobile/api |
| Backend API | **NestJS 11** trên **Fastify 5** adapter | 11.2.x / 5.12 | MIT | DI/module chuẩn doanh nghiệp, transport MQTT/NATS sẵn, OpenAPI. NestJS 12 (ESM) chưa GA → pin 11, kế hoạch nâng 2027. Thay thế: Hono cho BFF/edge nhẹ |
| ORM/DB access | **Drizzle ORM** (schema, migrate) + **Kysely** (truy vấn phức tạp) | Drizzle 1.0-rc (pin) / Kysely 0.29 | Apache-2 / MIT | SQL-first, hỗ trợ RLS; Prisma 8 rc thay đổi lớn → không |
| Validation | **Zod 4** (+ zod/mini cho mobile) | 4.4 | MIT | Sinh JSON Schema/OpenAPI |
| CSDL | **PostgreSQL 18.6** + **TimescaleDB 2.28** (Community/TSL) + **PostGIS 3.6** + pg_partman | | PostgreSQL / TSL / GPL(ext) | uuidv7 native, AIO, RLS, logical replication (cho sync); Timescale nén + continuous aggregate cho SENSOR_READ; TSL cấm bán Timescale-as-DBaaS — ta không bán DB nên OK. Vận hành: **CloudNativePG 1.29** trên k3s (HA, PITR) |
| Phân tích | Continuous aggregates + view; **DuckDB 1.5** cho báo cáo/edge; ClickHouse chỉ khi > 10⁹ hàng | | MIT/Apache | |
| Cache/queue nhẹ | **Valkey 9.1** | | BSD-3 | Redis 8 = AGPL/RSAL → tránh |
| Event bus | **NATS JetStream 2.14** (Apache-2, CNCF) — có **MQTT server tích hợp** + **leaf node** cho trại | | Apache-2 | Thay Kafka (nặng); NATS leaf tại edge tiếp tục nhận khi đứt mạng, đồng bộ khi nối lại |
| Outbox/jobs | **pg-boss 12** (outbox transactional trong Postgres) | | MIT | Không cần Debezium/Kafka |
| Workflow bền | **DBOS Transact** (thư viện trên Postgres, MIT) cho duyệt chi/cổng chặn/recall/SLA; **Temporal 1.31** (MIT) nếu cần đa ngôn ngữ/khối lượng lớn ở G4 | | MIT | Inngest (SSPL), Restate (BSL), n8n (SUL) → không nhúng |
| Object storage | **SeaweedFS 4.x** (cloud, Apache-2) + **Garage 2.3** (edge, AGPL-unmodified) | | Apache-2 / AGPL | **MinIO CE đã archive 4/2026 → không dùng**; RustFS theo dõi khi GA |
| Tìm kiếm | **Meilisearch 1.52** (tenant token) | | MIT | Typesense GPL, OpenSearch nặng |
| Identity | **Keycloak 26.7** (OIDC, MFA/passkey, Organizations = multi-tenant, CNCF) + **Ory Keto** (tùy chọn ReBAC) | | Apache-2 | Zitadel (AGPL) là phương án 2; Better-Auth chỉ nếu 1 app TS |
| Secrets | **OpenBao 2.6** | | MPL-2 | Vault 2.0 = BSL |
| Web | **Next.js 16.3** (App Router) + **React 19.2** + **Tailwind 4.3** + **shadcn/ui** (CLI v4) | | MIT | Vá bảo mật Next nhanh (nhiều CVE 2026); web office/dashboards; kiosk TV = trang tĩnh |
| GIS web | **MapLibre GL JS 5.24** (→6 khi wrapper ổn) + PMTiles offline; **deck.gl 9.3** chỉ khi overlay lớn | | BSD-3 / MIT | Không phí Mapbox; tile ảnh vệ tinh/drone dạng COG qua titiler |
| Biểu đồ | **Recharts 3.10** (KPI/ERP) + **Apache ECharts 6.1** (chuỗi cảm biến dày) | | MIT / Apache-2 | |
| Mobile | **Expo SDK 57 + React Native 0.87** (New Architecture), EAS build; **dev build từ ngày 1** (BLE/camera) | | MIT | Flutter là phương án 2 (mất chia sẻ code TS/sync) |
| Offline sync | **PowerSync** (Open Edition self-host, FSL; client Apache-2) — Postgres logical replication → SQLite thiết bị theo *sync rules* (bucket theo farm/vai) — ghi offline → upload queue → API | client 1.35 | FSL/Apache-2 | ElectricSQL 1.7 + TanStack DB (Apache-2) là phương án 2 (tự làm write path). Zero (không offline write), Replicache (archived), Couchbase (BSL) → loại |
| BLE/quét | **react-native-ble-manager 12.5** (đầu đọc EID, cân, cân xe trộn); **expo-camera** (QR/mã vạch); **vision-camera v5** khi cần OCR số tai/biển số | | Apache-2 / MIT | ble-plx 18 tháng không cập nhật → phương án 2 |
| RFID tai | Đầu đọc BLE **ISO 11784/85 LF 134,2 kHz** (Agrident AWR300 / Allflex RS420 / Gallagher HR5) — **NFC điện thoại chỉ 13,56 MHz, không đọc được** | | | Song song: RS-232 → ESP32 → MQTT tại chuồng cố định |
| Cân/thiết bị serial | Bộ chuyển RS-232/RS-485 → MQTT (USR-DR302/ESP32 Tasmota) → Mosquitto; Modbus RTU/TCP; OPC-UA (node-opcua) khi máy có | | | Driver trong `edge-agent` (Node/Go) |
| MQTT edge | **Mosquitto 2.1** (bridge → NATS/EMQX) | | EPL-2 | EMQX ≥5.9 = BSL (1 node free, cluster trả phí) → chỉ dùng nếu cần rule engine trung tâm; HiveMQ CE (Apache-2) phương án 2 |
| LoRaWAN | **ChirpStack v4.19** (MIT, có tenant) | | MIT | Cảm biến DO/nhiệt/ẩm đất/mực nước/silo pin |
| Edge runtime | **Docker Compose + Portainer Edge Agent** (hoặc balena) trên mini-PC/RPi5; k3s edge chỉ khi > 50 trại | | | Node-RED 5 (64-bit) chỉ để prototype glue |
| Camera AI | **RF-DETR / RT-DETR** (Apache-2) + **MegaDetector v1.3** (MIT) tiền lọc; **ONNX Runtime 1.29**; **Jetson Orin Nano (JetPack 6.2/TRT)** cho chuồng, **RPi5 + AI HAT+ 2 (Hailo-10H)** cho camera lẻ | | Apache/MIT | **Ultralytics YOLO = AGPL → không dùng trong SaaS đóng** (trừ mua Enterprise); Coral EOL |
| ML/dự báo | Python **FastAPI 0.136** + **Nixtla statsforecast 2.1 / mlforecast 1.1** + **LightGBM 4.7**; Prophet chỉ tham chiếu (maintenance mode) | | MIT/Apache | |
| LLM trợ lý | **Claude API — Sonnet 5** mặc định, Haiku 4.5 phân loại, Opus 5 phân tích sâu; **structured outputs / strict tools**; **MCP** (SDK 1.30) để lộ dữ liệu trại thành tool có phân quyền | | | Text-to-SQL chỉ trên view whitelist, role read-only, RLS `SET LOCAL app.farm_id` |
| Báo cáo/PDF | **Typst 0.15** (hồ sơ, chứng nhận, tem A4) + **Playwright 1.62/Gotenberg 8** (dashboard→PDF); **pdfme 6** cho template kéo-thả | | Apache/MIT | Carbone (CCL), Jasper (Java) → không |
| Mã vạch/GS1 | **bwip-js 4.11** (GS1-128/DataMatrix/QR) + **gs1-syntax-engine 1.4** (validate AI) + **zxing-wasm 3.1** (đọc); ZPL tự viết template + zpl-image; Labelary preview | | MIT/Apache | jszpl GPL → không |
| Observability | **OpenTelemetry** (JS SDK 2.10, Collector 0.159 tại edge buffer) → **Grafana 13 + Loki 3.7 + Tempo 3.0** (+Mimir tùy) | | Apache/AGPL(nội bộ) | SigNoz phương án 2 |
| Nền tảng | **k3s 1.36** (cloud nhỏ) · **Argo CD 3.5** (GitOps) · GitHub Actions · **Flux 2.9** nếu fleet edge k3s | | Apache-2 | |
| Toolchain | **pnpm 11 + Turborepo 2.10**, **Biome 2.5** (lint+format) + typescript-eslint cho rule có type, **Vitest 4.1**, **Playwright 1.62**, **k6 2.2**, **Pact-js 17** (contract) | | MIT… | Nx phương án 2 |

## 3. LUỒNG DỮ LIỆU CHÍNH

1. **Ghi từ mobile (offline):** app ghi vào SQLite (PowerSync) → khi có mạng: upload queue gọi `POST /events/*` (idempotent theo `client_ref`) → API validate (Zod), ghi bảng sự kiện (append-only), outbox → NATS `farm.F01.event.<type>` → consumer: KPI incremental, alert, EPCIS chiếu, thông báo. Server đổi mã tạm `TMP-` → mã chính thức, trả về; PowerSync đẩy bản chuẩn xuống thiết bị.
2. **Ghi từ thiết bị (edge):** cân/RFID/cảm biến → `edge-agent` chuẩn hóa JSON (SensorThings-like: `{device, metric, value, ts, quality}`) → Mosquitto → bridge NATS leaf → JetStream (lưu bền khi đứt mạng) → cloud consumer ghi SENSOR_READ (Timescale) / WEIGH_TICKET / GATE_LOG. `edge-rules` chạy CEL cho luật ĐỎ tại chỗ (DO<4, mất điện) → còi/đèn + push khi có mạng.
3. **Đọc:** web/mobile qua REST (OpenAPI) + GraphQL read-only (dashboards linh hoạt) + SSE/WebSocket (alert, live sensor); mobile đọc chủ yếu từ SQLite đã sync (bucket theo farm+vai+khu → công nhân chỉ tải phần mình).
4. **Job đêm:** pg-boss lịch: RC engine 01:00, KPI kỳ, báo cáo ngày 21:00, thứ 6 06:00, P&L ngày 5, backup, nhắc đến hạn.
5. **Não:** `itran-brain` (FastAPI) đăng ký NATS consumer + gọi API nội bộ; kết quả ghi FORECAST/RECOMMENDATION qua API (không ghi thẳng DB).
6. **HQ multi-farm:** cùng DB (RLS) hoặc DB riêng/tenant (SaaS lớn); HQ đọc view tổng hợp `hq_*`; đẩy SOP = tạo SOP_DISTRIBUTION → sự kiện → trại nhận/ký.

## 4. MULTI-TENANT & PHÂN QUYỀN
- **Tenant = công ty mẹ (ORG)**; **FARM** thuộc ORG; mọi bảng có `farm_id` (+ `org_id` ở bảng chung). RLS bật mặc định; API set `SET LOCAL app.org_id/app.farm_id/app.staff_id/app.roles` mỗi request (connection pool an toàn).
- **RBAC** 14 vai chuẩn + vai hệ thống (chủ đầu tư, HQ, kiểm toán read-only, đối tác API) + **ABAC** theo phòng/CC/khu (công nhân A3 khối đẻ không thấy khối thịt). Quyền ghi ≠ quyền duyệt (P7) kiểm ở API + DB (trigger cấm self-approve).
- Keycloak: realm ITRAN, Organizations = ORG; login mobile OIDC PKCE + **PIN offline** (token cache mã hóa, hết hạn 7 ngày offline); MFA bắt buộc vai duyệt/chi tiền/HQ.
- Khách QR: endpoint public read-only qua resolver riêng, rate-limit, không lộ dữ liệu nội bộ.

## 5. OFFLINE-FIRST CHI TIẾT
| Tình huống | Hành vi |
|---|---|
| Điện thoại mất mạng | Ghi bình thường; badge "chưa đồng bộ n"; checklist/alert cache; ảnh nén xếp hàng; sync khi có Wi-Fi/4G (foreground + background task cơ hội) |
| Trại mất internet (edge còn điện) | Mosquitto/NATS leaf/edge-rules/dashboard TV chạy; cảnh báo ĐỎ cục bộ; điện thoại trong Wi-Fi trại vẫn đẩy về edge? → **Có**: PowerSync có thể trỏ về endpoint edge (chế độ "edge sync") ở G3; G1–G2: chỉ queue trên máy |
| Mất điện | UPS edge ≥ 4h; thiết bị pin LoRa; giấy in sẵn (mẫu từ hệ, có QR để nhập bù nhanh) |
| Xung đột | Sự kiện append-only nên hầu như không xung đột; master data: last-write-wins + lịch sử; số lượng đàn nhóm: gộp delta |
| Nhập bù | `backfilled=true`, `occurred_at` ≠ `recorded_at`, báo cáo tách riêng; khóa backdate > 72h nếu không có quyền KTT |

## 6. IoT / EDGE — DANH MỤC THIẾT BỊ & GIAO THỨC
| Thiết bị | Giao thức | Driver |
|---|---|---|
| Cân cầu khu D, cân cổng lõi | RS-232/RS-485 (ASCII hãng) → serial-MQTT | `edge-agent/scale-*` + camera biển số |
| Cân xe trộn TMR | Bluetooth SPP/BLE hoặc RS-232 | mobile BLE / edge |
| Cân lối đi bò (weigh head Tru-Test/Gallagher) | BLE/RS-232 | mobile BLE / edge |
| Đầu đọc RFID tai | BLE stick (FDX-B/HDX) hoặc cố định (RS-232/TCP) | mobile / edge |
| Vòng cổ bò | Cloud hãng (API) hoặc gateway LoRa/BLE | connector API hãng (SenseHub/smaXtec) hoặc LoRa |
| DO/pH/nhiệt RAS, NH₃, nhiệt-ẩm chuồng, ẩm đất, mực nước sông, silo | LoRaWAN (ChirpStack) / Modbus RTU / 4-20mA qua module | codec registry |
| Đồng hồ điện/nước khu | Modbus/pulse → LoRa | |
| Camera | RTSP → edge AI (Jetson/RPi+Hailo) | kết quả JSON MQTT |
| Máy in tem | ZPL/TSPL qua mạng/USB | print service edge |
| POS/két | API/tệp | connector |
| Trạm thời tiết | LoRa hoặc API (Davis WeatherLink v2/Sencrop) | connector |
| Máy nông nghiệp | tracker GPS (MQTT) · ISOXML USB · API OEM (Deere/CNH) ⏩ | connector |
Mọi thiết bị có DEVICE_STATE (online/pin/rssi/fw), heartbeat, hiệu chuẩn (CALIBRATION), OTA (ChirpStack/Portainer).

## 7. BẢO MẬT (tóm tắt — chi tiết file 08)
TLS mọi nơi (mTLS edge↔cloud, cert cho thiết bị MQTT), OIDC + MFA, RLS, mã hóa at-rest (disk + cột nhạy cảm lương/giá), audit hash-chain, backup 3-2-1 (SeaweedFS khác vùng + offline định kỳ), secrets OpenBao, SBOM + quét lỗ hổng CI, pentest trước SaaS.

## 8. TRIỂN KHAI & MÔI TRƯỜNG
- Môi trường: `dev` (docker compose local), `staging`, `prod` (k3s HA 3 node cloud VN), `edge-F01` (compose). GitOps Argo CD; DB migration qua Drizzle trong job trước deploy; blue/green cho API; feature flag (Unleash OSS hoặc bảng SETTING).
- Dữ liệu ở VN (yêu cầu bảo vệ dữ liệu cá nhân NĐ 13/2023); bản sao DR vùng khác.
- Chi phí hạ tầng cloud ước ~8–15 tr/tháng cho F01 (3 node nhỏ + storage), tăng theo tenant.

## 9. QUYẾT ĐỊNH KIẾN TRÚC (ADR) — danh sách ban đầu
ADR-001 Modular monolith NestJS · ADR-002 Postgres+Timescale+PostGIS một DB · ADR-003 PowerSync offline · ADR-004 NATS JetStream + MQTT bridge · ADR-005 Append-only + hash-chain · ADR-006 Keycloak Organizations · ADR-007 SeaweedFS/Garage thay MinIO · ADR-008 Edge Compose không k3s · ADR-009 RF-DETR thay YOLO (AGPL) · ADR-010 EPCIS 2.0 làm chuẩn truy xuất · ADR-011 DBOS Transact cho workflow, Temporal khi cần · ADR-012 CEL cho rule alert.
