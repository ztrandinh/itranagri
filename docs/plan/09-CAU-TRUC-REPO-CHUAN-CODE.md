# 09 · CẤU TRÚC REPO & CHUẨN CODE — "RÕ RÀNG, MỞ RỘNG ĐƯỢC"

## 1. Monorepo (pnpm 11 + Turborepo 2.10)
```
itran-agri/
├─ apps/
│  ├─ api/            # NestJS 11 (Fastify) — modular monolith
│  ├─ web/            # Next.js 16 — office/dashboard/HQ/public trace page
│  ├─ mobile/         # Expo SDK 57 — app 14 vai, offline (PowerSync)
│  ├─ edge-agent/     # Node (hoặc Go) — driver cân/RFID/serial/camera → MQTT
│  ├─ edge-rules/     # CEL rules cục bộ + còi/đèn + dashboard TV
│  ├─ brain/          # Python FastAPI — KPI nặng/RC/forecast/CV/LLM tools
│  └─ sync/           # cấu hình PowerSync (sync rules) + upload connector
├─ packages/
│  ├─ domain/         # kiểu & luật nghiệp vụ thuần (không phụ thuộc framework): ID, trạng thái, KPI DSL, RC, thế số
│  ├─ schemas/        # Zod schema dùng chung API/mobile/web + sinh OpenAPI/JSON Schema
│  ├─ db/             # Drizzle schema, migrations, seed, RLS policies, views (v_*, bi_*, hq_*)
│  ├─ sdk/            # client TS sinh từ OpenAPI (+ Python trong brain/)
│  ├─ ui/             # design system (shadcn base, token, icon, mobile kit)
│  ├─ i18n/           # vi/en/… ICU messages
│  ├─ rules/          # CEL helpers, thư viện rule mẫu (alert/RC/SLA)
│  ├─ reports/        # template Typst/HTML báo cáo, tem ZPL
│  ├─ epcis/          # map sự kiện → EPCIS 2.0, GS1 helper (bwip-js, syntax-engine)
│  ├─ drivers/        # parser thiết bị (cân/RFID/DO/silo) dùng chung mobile & edge
│  └─ config/         # eslint/biome/tsconfig/vitest preset
├─ infra/
│  ├─ compose/        # dev + edge stacks
│  ├─ k8s/            # helm/kustomize + Argo CD apps (staging/prod)
│  ├─ cnpg/           # cluster Postgres
│  └─ terraform/      # cloud VN
├─ docs/
│  ├─ adr/            # ADR-001…
│  ├─ data-dictionary/ (sinh từ packages/db)
│  ├─ api/            # OpenAPI + portal
│  └─ runbooks/
├─ tools/             # scripts: sinh dữ liệu giả F99, import Sheets, backtest KPI
├─ .github/workflows/
├─ turbo.json  pnpm-workspace.yaml  biome.json  tsconfig.base.json
```

## 2. Cấu trúc module trong `apps/api` (mỗi bounded context)
```
src/modules/livestock/
├─ livestock.module.ts
├─ domain/            # entity, value object, luật (import từ packages/domain khi dùng chung)
├─ application/       # use-case/command/query handlers (CQRS nhẹ), policies (quyền)
├─ infrastructure/    # repository (Drizzle/Kysely), event publisher (outbox), adapters
├─ interface/         # controllers (REST), resolvers (GraphQL), consumers (NATS), dto (Zod)
├─ livestock.events.ts   # tên sự kiện + schema payload
└─ __tests__/
```
Luật phụ thuộc: `interface → application → domain`; `infrastructure` chỉ implement port; module khác chỉ gọi qua **application service public** hoặc **sự kiện** (không import repository của nhau). Kiểm bằng `dependency-cruiser` trong CI.

## 3. Chuẩn code
- TypeScript `strict`, `noUncheckedIndexedAccess`, không `any` (trừ `// eslint-disable` có lý do); ESM.
- Đặt tên: bảng/cột `snake_case`; TS `camelCase`; hằng `UPPER_SNAKE`; sự kiện `domain.entity.action`; mã nghiệp vụ theo file 04.
- Tiếng Việt cho thuật ngữ nghiệp vụ trong tên miền có glossary (`docs/glossary.md`: nái = `dam`, vỗ béo = `fattening`, ủ chua = `silage`…); code tiếng Anh, UI tiếng Việt.
- Validation ở biên (Zod), lỗi có mã (`ERR_WITHDRAWAL_ACTIVE`), không throw string.
- Append-only: repository sự kiện chỉ có `insert`/`supersede`; lint rule cấm `update/delete` trên bảng `*_event`.
- Mọi truy vấn qua repository có `farmId` bắt buộc; test RLS.
- Không logic trong controller; không SQL trong service (qua repository).
- Cấu hình qua env + SETTING DB (không hằng số nghiệp vụ trong code).
- Log có cấu trúc, không log dữ liệu nhạy cảm; trace id xuyên suốt.
- Commit: Conventional Commits; PR template (mục đích, ảnh màn hình, test, migration, ADR?); ≥ 1 reviewer, tech lead cho `packages/db`, `domain`, `infra`.
- Biome format+lint; typescript-eslint rule có type; `pnpm check` = lint+typecheck+test trước push (lefthook).
- Tài liệu: mỗi module `README.md` (mục đích, sự kiện phát/nhận, bảng, quyền); ADR khi đổi quyết định kiến trúc; changelog tự sinh.

## 4. Mobile (`apps/mobile`)
- Expo Router; màn hình theo vai từ cấu hình quyền; component "ghi 3 chạm" chuẩn (Scan → Chọn → Xác nhận); form Zod; queue upload; PowerSync bucket theo vai/khu; BLE lớp trừu tượng (`packages/drivers`); chế độ ngoài trời (font lớn, tương phản); giọng nói; kiểm tra pin/dung lượng.
- Không Expo Go; dev build; EAS Update kênh theo trại; crash report (Sentry self-host tùy chọn).

## 5. Web (`apps/web`)
- App Router, RSC cho trang đọc; client component cho bản đồ/biểu đồ; TanStack Query; shadcn; MapLibre; Recharts/ECharts; i18n; kiosk mode `/tv/:farm` tự refresh; trang public trace tách route group, cache CDN.

## 6. Edge
- Compose stack phiên bản; `edge-agent` plugin driver `{transport, parser, mapper}` + simulator; healthcheck; buffer SQLite khi mất broker; cấu hình kéo từ cloud (thiết bị, codec) có ký.

## 7. Brain (Python)
- FastAPI, Pydantic v2, uv/poetry; nhận sự kiện NATS; ghi qua API SDK; mô hình có phiên bản (MLflow nhẹ hoặc bảng MODEL); tests golden; container GPU tùy chọn.

## 8. Chất lượng liên tục
- Coverage gate 80% domain/application; mutation test mẫu cho KPI/RC (Stryker) hằng quý.
- Dependabot/Renovate nhóm theo tuần; nâng major có ADR.
- Nợ kỹ thuật ghi issue nhãn `debt`, tối đa 10% sprint để trả.

## 9. Bắt đầu nhanh (S0)
```bash
pnpm i && pnpm dev:infra   # compose: pg18+timescale+postgis, nats, keycloak, seaweedfs, valkey, meili
pnpm db:migrate && pnpm db:seed   # seed 9 kho, 12 CC, 14 vai, KPI/alert/RC, SOP L2, chuẩn
pnpm dev                    # api + web + mobile (expo) + brain
```
