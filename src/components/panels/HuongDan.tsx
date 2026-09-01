"use client";
import { useState } from "react";
import type { Sess } from "@/components/Shell";
const G: Record<string, { title: string; steps: string[] }[]> = {
  worker: [
    { title: "Mỗi ca 3 việc", steps: ["Mở app → 🏠 Trang chủ → «Ca của tôi» (hoặc chấm công ▶ Vào ca ở Nhân sự nếu tổ yêu cầu).", "Làm việc trong danh sách «Việc của tôi» (việc do quy trình/vòng theo dõi tự sinh): bấm việc → ghi bằng form 3 chạm (chọn đối tượng → nhập số → Lưu). Mất mạng vẫn ghi được, tự đồng bộ khi có sóng (xem ⏳ góc phải).", "Cuối ca: giao ca (ghi chú) và ■ Ra ca."] },
    { title: "Ghi đúng đối tượng", steps: ["Gõ mã/tên vào ô 🔍 (bò B004, ô R3, mặt hàng…) → mở trang 360 → xem/ghi.", "Bò/dê: quét/gõ RFID hoặc thẻ; bê chưa có tai vẫn ghi (chờ gắn tai).", "Sai trong 72h: tự sửa (bản mới); sau 72h: báo tổ trưởng lập phiếu điều chỉnh."] },
    { title: "Phiếu giấy", steps: ["Khi không có máy: ghi BM01–BM10 (in ở In ấn), số hóa vào «Phiếu giấy» trong 24h, ghi số phiếu."] },
  ],
  team_lead: [
    { title: "Đầu ca", steps: ["Xem «Đàn › 🔄 Vòng theo dõi» (cân/vaccine/tẩy KST/khám thai đến hạn) và «Phê duyệt» (checklist tổ).", "Phân việc: Ca của tôi → tạo việc → gán người."] },
    { title: "Nhập lô đàn", steps: ["Đàn › ⬆ Nhập lô đàn: nhập nguồn/giấy kiểm dịch/giá → dán danh sách RFID|thẻ|giới|ngày sinh|kg từ Excel/máy đọc (hoặc chỉ số con) → hệ thống sinh mã cá thể, cách ly 21 ngày, sổ đàn K8, việc theo dõi."] },
    { title: "Kho", steps: ["Kho › Nhập/Xuất theo lô (FEFO), Kiểm kê tuần/tháng, chênh lệch → phiếu điều chỉnh (KTT duyệt).", "Mỗi dòng có 📈 để xem biến động so kỳ trước."] },
  ],
  tech_head: [
    { title: "Kỹ thuật", steps: ["KTT: duyệt điều chỉnh/checklist, kế hoạch khẩu phần (Kế hoạch), Thú y (điều trị – ngưng thuốc – vaccine).", "Canh tác: mở mùa vụ → vật tư có PHI → thu hoạch (bị chặn khi còn cách ly) → xuất Nhật ký sản xuất.", "Khẩu phần: /khau-phan tính khẩu phần rẻ nhất theo giá kho.", "Đối tượng: định nghĩa loài/lớp/cây/biến đầu vào–ra; Vòng theo dõi: sửa tham số theo loài/lớp."] },
    { title: "Quy trình & chuẩn", steps: ["Tổ chức › Khai báo quy trình: thêm/xóa bước, bộ phận, công cụ, vật tư, đầu vào/ra, biểu mẫu bắt buộc → Xuất bản (phòng ban nhận thông báo) → ▶ Chạy.", "Tuân thủ: tự đánh giá điều khoản (đạt/NC/N/A), đóng NC, sổ chứng nhận; ICFS tự chấm ở /chuan."] },
  ],
  director: [
    { title: "Mỗi sáng 5 phút", steps: ["Dashboard GĐ → cảnh báo ĐỎ → Phê duyệt (chi 2 chữ ký, PO, nghỉ phép) → Đối soát đêm (lệch >5%).", "Số liệu › Mọi trường: bất kỳ cột số nào cũng vẽ được, so kỳ trước, bấm cột ra bản ghi gốc."] },
    { title: "Công ty · trại", steps: ["Công ty › Khai báo trại (9 kho/12 CC/khu tự sinh) → Hồ sơ trại (diện tích, hạ tầng, nhân sự, giấy phép).", "Quản trị DL: thêm/sửa/gỡ/nhập CSV/xuất/lịch sử mọi bảng — admin được báo mọi thay đổi.", "Kế toán: cân đối phát sinh (GL tự hạch toán), P&L phân hệ, VietQR thu tiền, xuất CSV cho MISA/Fast; In ấn: hóa đơn, phiếu cân, HĐ, nhãn QR, báo cáo tuần."] },
  ],
  owner: [
    { title: "Chủ đầu tư", steps: ["Trang chủ → Công ty (so sánh trại, ICFS, P&L) → Cảnh báo ĐỎ → Phê duyệt chi >50tr.", "/chuan công khai cho đối tác/cơ quan; portal khách nhận nuôi /khach/{token}; portal đối tác /doi-tac/{token} (link trong Đối tác).", "Sao lưu tự động 01:15 (pg_dump + ZIP CSV → BACKUP_DIR); job đêm; thông báo Zalo/SMS/Email cấu hình ở Quản trị DL › integrations."] },
  ],
  accountant: [{ title: "Kế toán", steps: ["Đề nghị chi (đính kèm chứng từ) → Phê duyệt → chi & ghi paid → GL tự sinh bút toán.", "Đối chiếu ngân hàng (nhập sao kê), khóa kỳ, bảng kê thuế (sales-tax), TT66, gói audit sha256.", "Kênh/POS: hóa đơn POS → sales; công nợ theo đối tác; VietQR in trên hóa đơn."] }],
  it_engineer: [{ title: "Hệ thống", steps: ["Thiết bị/cảm biến: IoT ingest bằng API key (Quản trị DL › api_keys), MQTT bridge POST /api/ingest/sensor.", "Cảnh báo: luật cấu hình; kênh Zalo/SMS/Email trong integrations; webhook đối tác.", "Docker/compose/CI có sẵn; migrate `pnpm db:migrate`; backup ở BACKUP_DIR; khóa/mở khóa tài khoản, reset PIN.", "Thêm bảng/cột → tự có biểu đồ, quản trị, CSV; thêm đối tượng 360 = 1 dòng cấu hình."] }],
  auditor: [{ title: "Kiểm toán / QA", steps: ["Audit › gói audit sha256; Đối soát RC1–RC16; Tuân thủ: 19 chuẩn, ma trận yêu cầu → bằng chứng; ICFS; lịch sử thay đổi danh mục (audit_log)."] }],
};
export default function HuongDan({ sess }: { sess: Sess }) {
  const [role, setRole] = useState(sess.role in G ? sess.role : "worker");
  return (<div className="space-y-3"><div className="flex gap-2 flex-wrap">{Object.keys(G).map((r) => <button key={r} className={`px-3 py-1.5 rounded-xl text-sm font-semibold ${role === r ? "bg-brand-tok text-white" : "bg-white border"}`} onClick={() => setRole(r)}>{r}</button>)}<a className="ml-auto underline text-sm self-center" href="/to-chuc">quy trình đầy đủ</a></div>
    {G[role].map((sec) => <div key={sec.title} className="card"><b>{sec.title}</b><ol className="list-decimal pl-5 mt-1 space-y-1 text-sm">{sec.steps.map((s, i) => <li key={i}>{s}</li>)}</ol></div>)}
    <div className="text-xs text-muted">Điện thoại: mở trình duyệt Chrome → «Thêm vào màn hình chính» để dùng như app (PWA), ghi được khi mất mạng.</div></div>);
}
