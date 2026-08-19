/** TỪ ĐIỂN THUẬT NGỮ — giải nghĩa mọi viết tắt nội bộ bằng tiếng Việt đời thường.
 *  Vì sao: màn hình đang đầy mã kỹ thuật (RC1, FEFO, PHI, D5, K3, ROP…) — người mới
 *  không hiểu, phải đi hỏi. Dùng <Term k="FEFO" /> để gạch chân + hiện giải thích khi chạm.
 *  Nguồn: bộ gốc nghiệp vụ ITRAN + SPEC-01/05. Thêm từ mới ở đây, không viết rải rác. */
export type TermDef = { short: string; long?: string };

export const GLOSSARY: Record<string, TermDef> = {
  // Đối soát (RC = Reconciliation — soát đầu vào vs đầu ra)
  RC: { short: "Đối soát", long: "So khớp hai vế: cái ghi vào vs cái thực tế ra, để phát hiện thất thoát." },
  RC1: { short: "Đối soát thức ăn", long: "Thức ăn xuất kho vs thức ăn thực sự cho ăn." },
  RC2: { short: "Đối soát tăng trọng", long: "Thức ăn tiêu thụ vs tăng trọng (FCR) so chuẩn." },
  RC4: { short: "Đối soát phân", long: "Phân sinh ra vs phân đưa vào xử lý (trùn/biogas/compost)." },
  RC7: { short: "Đối soát nhiên liệu", long: "Dầu xuất kho vs giờ máy chạy × định mức." },
  RC10: { short: "Đối soát tiền–hàng", long: "Tiền đã thu vs sao kê ngân hàng + két." },
  RC11: { short: "Đối soát giấy–số", long: "Phiếu giấy đã chụp vs bản ghi số hoá (seri liên tục, ≤24h)." },
  RC12: { short: "Đối soát tem", long: "Tem truy xuất in ra vs tem đã dán/bán." },
  // Kho
  FEFO: { short: "Hết hạn trước – xuất trước", long: "Xuất lô sắp hết hạn trước, tránh hàng quá date (First Expired, First Out)." },
  ROP: { short: "Điểm đặt hàng lại", long: "Mức tồn chạm ngưỡng này thì phải đặt mua ngay, kẻo đứt hàng." },
  "NGAY-TON": { short: "Ngày-tồn", long: "Tồn kho hiện tại đủ dùng bao nhiêu ngày nữa theo tốc độ tiêu thụ." },
  ABC: { short: "Phân hạng ABC", long: "Xếp hàng hoá theo giá trị: A quan trọng nhất, kiểm kê dày hơn." },
  // Khu / kho vật lý
  K1: { short: "Kho vật tư – thuốc – vaccine" }, K2: { short: "Kho nguyên liệu thô mua" },
  K3: { short: "Kho bán thành phẩm thức ăn", long: "Hào ủ, cỏ, silo — nơi để thức ăn ủ chua." },
  K4: { short: "Kho thức ăn thành phẩm" }, K5: { short: "Kho thành phẩm bán (SKU)" },
  K7: { short: "Kho nhiên liệu" }, K8: { short: "Sổ đàn (kho vật nuôi)" }, K9: { short: "Kho bao bì – tem" },
  D5: { short: "Xưởng thức ăn D5", long: "Xưởng trộn/ép viên thức ăn cho đàn." },
  "KHU D": { short: "Khu sinh học tuần hoàn", long: "Trùn quế, ruồi lính đen (BSF), biogas, compost — biến chất thải thành tài nguyên." },
  // Thú y / an toàn thực phẩm
  PHI: { short: "Thời gian cách ly", long: "Số ngày phải chờ sau khi phun thuốc mới được thu hoạch (Pre-Harvest Interval)." },
  "NGUNG THUOC": { short: "Ngưng thuốc", long: "Sau khi dùng thuốc thú y, phải chờ đủ ngày mới được bán/giết mổ." },
  BCS: { short: "Điểm thể trạng", long: "Chấm độ béo/gầy của con vật theo thang điểm (Body Condition Score)." },
  ADG: { short: "Tăng trọng ngày", long: "Số kg tăng trung bình mỗi ngày." },
  FCR: { short: "Hệ số chuyển hoá thức ăn", long: "Tốn bao nhiêu kg thức ăn để tăng 1 kg thịt — càng thấp càng tốt." },
  TMR: { short: "Khẩu phần trộn sẵn", long: "Trộn đều mọi nguyên liệu thành một khẩu phần (Total Mixed Ration)." },
  // Chất lượng / tuân thủ
  SOP: { short: "Quy trình chuẩn", long: "Bản hướng dẫn từng bước cho một công việc." },
  NC: { short: "Điểm không phù hợp", long: "Chỗ làm sai chuẩn, phát hiện khi đánh giá — phải khắc phục." },
  CAPA: { short: "Khắc phục – phòng ngừa", long: "Sửa lỗi đã xảy ra và ngăn nó lặp lại." },
  HACCP: { short: "Kiểm soát điểm tới hạn", long: "Hệ thống an toàn thực phẩm: xác định công đoạn nguy cơ và chốt chặn." },
  ICFS: { short: "Chuẩn trang trại tuần hoàn ITRAN", long: "Bộ tiêu chuẩn riêng của ITRAN, tự chấm điểm bằng dữ liệu thật." },
  EPCIS: { short: "Chuẩn truy xuất quốc tế", long: "Định dạng dữ liệu chuẩn để truy xuất nguồn gốc xuyên chuỗi." },
  TT66: { short: "Thông tư 66", long: "Mẫu báo cáo theo quy định của cơ quan quản lý." },
  // Kế hoạch / tài chính
  "S&OP": { short: "Kế hoạch cung – cầu", long: "Cân đối đàn ↔ thức ăn ↔ đất trồng ↔ tiền theo từng tháng." },
  GL: { short: "Sổ cái kế toán", long: "Ghi kép mọi phát sinh tiền (General Ledger)." },
  AR: { short: "Công nợ phải thu" }, AP: { short: "Công nợ phải trả" },
  COGS: { short: "Giá vốn hàng bán" }, PIT: { short: "Thuế thu nhập cá nhân" },
  BOM: { short: "Định mức nguyên liệu", long: "Làm 1 đơn vị thành phẩm cần những gì, bao nhiêu." },
  MRP: { short: "Tính nhu cầu nguyên liệu", long: "Từ kế hoạch sản xuất suy ra cần mua/chuẩn bị bao nhiêu." },
  // Vận hành
  KPI: { short: "Chỉ số đánh giá" },
  GS: { short: "Giám sát", long: "Người/tổ đi kiểm tra công việc theo tiêu chí, chấm điểm tuần." },
  POD: { short: "Bằng chứng giao hàng", long: "Ký nhận/ảnh chứng minh đã giao tới nơi." },
  "3 CHAM": { short: "Ghi 3 chạm", long: "Ghi xong 1 bản ghi chỉ với 3 lần chạm: chọn đối tượng → nhập số → xác nhận." },
};

/** Tra 1 thuật ngữ (không phân biệt hoa thường, bỏ dấu cách thừa). */
export function lookup(key: string): TermDef | null {
  const k = key.trim().toUpperCase();
  return GLOSSARY[k] ?? null;
}
