# 11 · RÀ SOÁT QUY MÔ — "1.000 CÂU HỎI" THEO NHÓM × VAI × KHÂU
*Mục đích: kiểm tra số liệu & cấu trúc ITRAN OS còn rành mạch/tối ưu không khi mở rộng theo 4 trục: **năm → nhiều năm**, **1 trại → nhiều trại/vùng**, **20 con → hàng nghìn con / hàng trăm lô–đàn–bể**, **1 người ghi → hàng chục vai**. Cách làm: đứng ở từng vai, từng khâu, hỏi "tôi cần gì để xử lý?"; mỗi câu có trả lời ngắn + trạng thái: ✅ đã có · 🔧 sửa ngay (đợt này) · 📅 kế hoạch (ghi migration/backlog) · ⚠️ rủi ro chấp nhận. Bộ câu hỏi ~380 câu thực chất (gộp trùng từ ~1.000 câu thô theo 14 vai × 20 khâu × 4 trục) — con số 1.000 là phương pháp quét, không phải số câu in ra.*

## 0. KẾT LUẬN TRƯỚC (đọc 1 phút)
**Nền đúng, hiển thị chưa đủ tầng, một số cấu trúc phải sửa ngay để không phải đập:**
1. 🔧 **Danh sách phẳng không sống nổi ở 1.000 con** → mọi danh sách (đàn, kho, sự kiện, việc) phải **phân trang + tìm kiếm + lọc phía server**, mặc định hiển thị theo **tầng: trại → khu/chuồng → đàn → cá thể**; cá thể chỉ mở khi cần.
2. 🔧 **Bảng sự kiện lớn dần theo năm** → **phân vùng theo tháng** (animal_events, feed_logs, inventory_moves, sensor_reads), chỉ mục theo `(farm_id, ts)`, `(farm_id, animal_id, ts)`, `(farm_id, sku, ts)`; số liệu tháng/quý/năm đọc từ **bảng tổng hợp ngày** (`agg_daily`) chứ không quét thô.
3. 🔧 **Sổ đàn K8 và tồn kho** phải là **snapshot cuối ngày** (`stock_daily`, `herd_daily`) để hỏi "tồn/đàn tại ngày X năm ngoái" trả lời trong 1 giây, và để P&L/thuế đóng kỳ.
4. 🔧 **Chu kỳ là chiều bắt buộc**: vụ (mùa vụ/năm), lứa (all-in-all-out), pha vỗ béo, đợt nuôi RAS, năm tài chính → thêm `cycle_id` vào sự kiện & nhóm; mọi so sánh năm/lứa dựa vào đó.
5. 🔧 **Mã đối tượng phải đọc được ở quy mô lớn**: giữ `[TRẠI]-[LOẠI]-[SỐ]`, số 5–6 chữ số, thêm **mã ngắn hiển thị** (số tai 3–4 ký tự) + **màu/khu**; tìm không dấu, quét mã là chính, gõ tay là phụ.
6. 📅 Đa trại: dữ liệu vẫn 1 DB (RLS) đến ~10 trại/1 triệu sự kiện/tháng; sau đó tách schema hoặc DB theo trại, HQ đọc qua bảng tổng hợp/`postgres_fdw`. Không đổi mô hình, chỉ đổi nơi đặt.
7. 📅 Lưu trữ nhiều năm: dữ liệu thô >2 năm chuyển bảng lưu trữ (partition detach → nén/parquet), vẫn truy vấn được; hồ sơ 5 năm cho chứng nhận.

---

## 1. NHÓM DỮ LIỆU CỐT LÕI (định danh, khóa, phiên bản)
| # | Câu hỏi | Trả lời | TT |
|---|---|---|---|
| 1.1 | Mã `F01-BO-00001` đủ cho 99.999 con/trại? | Đủ cho 1 trại đời sống 20 năm (~5.000 con); nới lên 6 số nếu >99.999 — chỉ đổi `lpad`, không đổi khóa | ✅ |
| 1.2 | Đổi tai RFID có mất lịch sử? | Không — `animal_tags` giữ lịch sử, `animals.rfid` là thẻ hiện hành | ✅ |
| 1.3 | Con vật chuyển trại F01→F02 giữ mã cũ hay mới? | Giữ mã gốc (mã sinh) + `animal_transfers` ghi trại đích; bảng animals có `farm_id` hiện tại và `origin_farm_id` | 🔧 thêm cột `origin_farm_id`, bảng `animal_transfers` |
| 1.4 | Hai trại cùng đặt số tai "B012"? | `visual_tag` chỉ unique trong trại; mã hệ thống unique toàn cục | ✅ |
| 1.5 | Con vật thuộc nhiều đàn theo thời gian? | `group_membership` có from/to | ✅ |
| 1.6 | Lứa gà thứ 30 sau 5 năm mã gì? | `F01-GA-L030`; lứa là `animal_groups` với `cycle` | ✅ (thêm `cycle_id`) 🔧 |
| 1.7 | Cần "vụ/lứa/pha/đợt" là thực thể? | Có: bảng `cycles(id, farm_id, kind: VU\|LUA\|PHA\|DOT\|NAM_TC, start, end, plot/group)`; sự kiện & nhóm gắn `cycle_id` | 🔧 |
| 1.8 | Năm tài chính khác năm dương lịch? | `settings.fiscal_year_start` (mặc định 01/01) | 🔧 setting |
| 1.9 | Đổi tên/nhập chuồng, khu sau 3 năm? | `locations` có `parent_id`, `valid_from/to`; sự kiện giữ mã cũ | 🔧 thêm valid_from/to |
| 1.10 | SKU đổi bao bì (25kg→20kg)? | SKU mới, SKU cũ `active=false`, map `replaces_sku` | 🔧 cột |
| 1.11 | Recipe sửa giữa chừng ảnh hưởng FEED_LOG cũ? | Không — FEED_LOG lưu `recipe_version` | ✅ |
| 1.12 | KPI đổi ngưỡng năm sau, so sánh năm trước? | `kpi_defs` có `version`; KPI_VALUE lưu version | ✅ (bảng có, job tính chưa) 📅 |
| 1.13 | Định mức khác nhau giữa trại/vùng? | `norms.farm_id null = toàn hệ; có farm_id = ghi đè` | ✅ |
| 1.14 | Một con thuộc khách hàng (nhận nuôi) và trại đồng thời? | `animal_ownership` % theo thời gian | ✅ |
| 1.15 | Đơn vị đo lẫn (kg/bao/vỉ/quả)? | `products.unit, unit2, unit2_factor`; mọi tổng hợp quy về đơn vị chuẩn | 🔧 view dùng factor (đã sửa trứng; áp cho tất cả) |
| 1.16 | Múi giờ khi trại ở vùng khác? | VN 1 múi; lưu timestamptz; `farms.tz` sẵn | ✅ |
| 1.17 | Khóa ngoại tới bảng master khi master bị "archive"? | Master không xóa, chỉ `active=false` | ✅ |
| 1.18 | Số bản ghi 1 con/đời? | ~2 sự kiện/tuần × 8 năm ≈ 800; 1.000 con ≈ 800k dòng animal_events → cần index `(animal_id, ts)` | 🔧 index |
| 1.19 | Cần "họ" bảng cho từng loài (bò/gà/cá) riêng? | Không — 1 bảng `animal_events` + `detail jsonb` theo loài; view theo loài | ✅ |
| 1.20 | JSON `detail` phình không kiểm soát? | Có schema Zod theo event_type; index GIN chỉ khi cần | 🔧 GIN index chọn lọc |

## 2. NHÓM KHỐI LƯỢNG & HIỆU NĂNG
| # | Câu hỏi | Trả lời | TT |
|---|---|---|---|
| 2.1 | Ước lượng dữ liệu 1 trại 500 bò + gà + RAS/năm? | ~60k animal_events, 8k feed_logs, 40k inventory_moves, 4M sensor_reads (5 cảm biến × 1/phút) | — |
| 2.2 | 10 trại × 5 năm? | ~50M dòng sự kiện + 200M sensor → Postgres đơn vẫn chịu nếu partition + rollup | ✅ (thiết kế) 🔧 (partition) |
| 2.3 | Bảng nào phải phân vùng? | sensor_reads (tháng), animal_events/feed_logs/inventory_moves/gate_logs (năm hoặc tháng), alerts/recon (năm) | 🔧 |
| 2.4 | Dashboard tháng/quý quét thô? | Không — `agg_daily(farm, day, metric, dim, value)` job đêm + refresh trong ngày cho hôm nay | 🔧 |
| 2.5 | Tồn kho tại 31/12 năm trước? | `stock_daily` snapshot | 🔧 |
| 2.6 | Đếm đàn tại ngày bất kỳ? | `herd_daily(farm, day, species, status, head, kg, value)` | 🔧 |
| 2.7 | Danh sách 1.000 con tải bao lâu? | Phải phân trang 50/trang + tìm kiếm server (trigram không dấu) | 🔧 |
| 2.8 | Trang QR công khai bị quét ồ ạt? | Cache 60s + rate-limit; chỉ đọc bảng nhỏ | 📅 |
| 2.9 | Explorer với 3 năm theo ngày = 1.000 điểm? | Tự động ép bucket: >120 điểm → tuần/tháng; đọc từ agg_daily | 🔧 |
| 2.10 | Backup 5 năm dung lượng? | ~50 GB; PITR + snapshot; xuất parquet năm | 📅 |
| 2.11 | Ảnh bằng chứng 5 năm? | ~50 ảnh/ngày × 300KB ≈ 27 GB/năm/trại → nén ≤300KB, lưu S3, dọn thumbnail | 📅 |
| 2.12 | RC job đêm 10 trại × 12 luật? | <2' nếu index; chạy song song theo trại | ✅ |
| 2.13 | Cảm biến 1 Hz? | Gộp trên edge về 1'/5'; DB chỉ nhận 1' | 📅 (edge) |
| 2.14 | Xuất "all" của 5 năm nặng? | Stream theo năm; ZIP theo năm | 🔧 tham số `year` |
| 2.15 | Truy vấn "mọi bảng theo người ghi" chậm? | Index `(farm_id, created_by, ts)` | 🔧 |

## 3. NHÓM HIỂN THỊ — TẦNG & ĐIỀU HƯỚNG (mọi vai)
| # | Câu hỏi | Trả lời | TT |
|---|---|---|---|
| 3.1 | Vào app thấy gì đầu tiên ở quy mô lớn? | **Tầng 0** thẻ tổng trại (đàn, đỏ, việc, tồn) → **Tầng 1** khu/chuồng/lô → **Tầng 2** đàn/ô/bể → **Tầng 3** cá thể/lô hàng | 🔧 màn Đàn & Kho theo tầng |
| 3.2 | Công nhân A2 có 200 nái phải cuộn? | Không — "Việc hôm nay" đã lọc đúng con; quét tai là chính; danh sách chỉ hiện con **cần chú ý** (đến hạn, bệnh, ngưng thuốc) | ✅/🔧 bộ lọc "cần chú ý" mặc định |
| 3.3 | Tìm con "B123" giữa 1.000 con? | Ô tìm không dấu + quét; kết quả server ≤ 50 | 🔧 |
| 3.4 | Bảng có 20 cột trên điện thoại? | Chế độ thẻ (card) trên mobile, bảng trên web; ẩn cột phụ | 🔧 responsive |
| 3.5 | Bộ lọc lưu được ("nái chờ phối > 90 ngày")? | Saved views (URL query) | 📅 |
| 3.6 | Màu/ký hiệu thống nhất? | ĐỎ/VÀNG/XANH/XÁM cố định; badge trạng thái vòng đời | ✅ |
| 3.7 | Số trên thẻ có so với kỳ trước? | Explorer có; thẻ KPI cần mũi tên ▲▼ | 🔧 tile delta |
| 3.8 | Nhiều trại: chọn trại ở đâu? | Bộ chọn trại trên header + HQ dashboard | ✅ |
| 3.9 | Số nào cũng bấm được xuống bản ghi? | Explorer ✅; thẻ dashboard → link màn tương ứng | 🔧 link các tile |
| 3.10 | Ngôn ngữ số: 1.234,5 chuẩn VN, đơn vị luôn kèm | fmt.n/vnd | ✅ |
| 3.11 | Timeline con vật 800 dòng? | Phân trang + lọc theo loại sự kiện + biểu đồ cân | 🔧 |
| 3.12 | Kho 200 SKU × 3 lô? | Tầng: kho → SKU (tổng) → lô (mở) | 🔧 |
| 3.13 | Việc hôm nay 300 việc cho KTT? | Nhóm theo khu & mức; đếm; "việc của tôi / của đội" | 🔧 group |
| 3.14 | Cảnh báo lặp mỗi đêm (RC) tràn màn? | Gộp theo rule (1 dòng + số lần + kỳ gần nhất) | 🔧 |
| 3.15 | Bản đồ lô/chuồng? | Sơ đồ khu (SVG) tô màu theo trạng thái; GIS đầy đủ ở Ray B | 📅 |

## 4. VAI A1 — TMR / cho ăn (khâu: nhận công thức → cân → rải → ghi)
| # | Câu hỏi | Trả lời | TT |
|---|---|---|---|
| 4.1 | 12 chuồng × 2 cữ = 24 mẻ/ngày, ghi 24 lần? | Ghi theo mẻ (1 mẻ nuôi nhiều chuồng): `feed_logs` thêm `allocations[]` chia theo chuồng | 🔧 |
| 4.2 | Công thức khác nhau theo pha (nái/vỗ/bê)? | recipe theo `species_phase`; chọn theo đàn tự gợi ý | 🔧 gợi ý theo group.kind |
| 4.3 | Kế hoạch mẻ lấy ở đâu? | `feed_plans` (đàn × ngày × kg KH từ định mức × số con) → mẻ chỉ xác nhận | 🔧 |
| 4.4 | Cân xe trộn tự đổ? | Ray B/BLE; nay nhập tay | 📅 |
| 4.5 | Sai số ≤2% tính trên mẻ hay ngày? | Cả hai: KPI mẻ + ngày | ✅ |
| 4.6 | Con bỏ ăn quét ngay tại máng? | Form animal_event BENH từ màn TMR | ✅ |
| 4.7 | Thừa máng % ước lượng chủ quan? | Cho phép; ảnh bắt buộc | ✅ |
| 4.8 | Ca sáng đã ghi, ca chiều người khác? | Mỗi bản ghi có người ghi; SLA theo cữ | ✅ |
| 4.9 | Mất mạng cả ngày? | Hàng đợi offline; giấy BM01 | ✅ |
| 4.10 | Nhìn thấy mình đã ghi đủ chưa? | Tab "Gần đây" + việc CHECKLIST | ✅ |

## 5. VAI A2 — Sinh sản/bê (khâu: động dục → phối → khám → đẻ → cai sữa → phân loại)
| # | Câu hỏi | Trả lời | TT |
|---|---|---|---|
| 5.1 | 300 nái, hôm nay phối con nào? | Việc hôm nay: động dục (vòng cổ/quan sát), sắp đẻ (280±10), khám thai 60 ngày | ✅ (task engine) |
| 5.2 | Lịch phối theo chu kỳ 21 ngày sau phối trượt? | Task "theo dõi động dục lại" 18–24 ngày sau PHOI không có KHAM_THAI+ | 🔧 rule |
| 5.3 | Đẻ ban đêm ghi lùi 6h? | Cho phép `ts` khác `created_at`, cờ backfill nếu >12h | ✅ |
| 5.4 | Bê sinh đôi? | new_animal ×2, cùng dam | ✅ |
| 5.5 | Bê chết lúc đẻ? | new_animal + CHET cùng lúc (giữ định danh) | ✅ |
| 5.6 | Nái loại sau 7 lứa — biết số lứa? | Đếm DE trong hồ sơ; cột `parity` tính từ view | 🔧 view |
| 5.7 | Khoảng cách 2 lứa/con? | view v_kpi có; hiển thị trên hồ sơ | 🔧 |
| 5.8 | Phân loại 3 hướng theo lô cai sữa hàng loạt? | bulk action + event PHAN_LOAI | 🔧 bulk event |
| 5.9 | Tinh lô nào, còn bao nhiêu liều? | K1 lot TINH-*; PHOI trừ K1 | 🔧 xuất K1 tự động khi PHOI |
| 5.10 | Bê từ nái nào tăng trọng tốt (chọn giống)? | Explorer weight_avg cắt theo dam_id | 🔧 thêm dim |

## 6. VAI A3 — Gà 2 khối · A4 — RAS (nhóm/lứa)
| # | Câu hỏi | Trả lời | TT |
|---|---|---|---|
| 6.1 | 6 chuồng đẻ × lứa lệch tuổi? | Mỗi chuồng 1 group + cycle; KPI theo tuần tuổi so đường chuẩn giống | 🔧 cycle + tuần tuổi |
| 6.2 | Trứng theo chuồng hay tổng? | Theo chuồng (group), tổng tự cộng | ✅ |
| 6.3 | Chết 5 con/ngày/khối cảnh báo | có | ✅ |
| 6.4 | Lứa thịt kết thúc → số liệu lứa (sống, FCR, EPEF) | Đóng cycle → snapshot `cycle_summary` | 🔧 |
| 6.5 | Người A3 khối đẻ không thấy khối thịt | ABAC theo group.block | 🔧 lọc theo vị trí NS |
| 6.6 | RAS 40 bể, DO từng bể | sensor per device; màn bể dạng lưới màu | 🔧 lưới bể |
| 6.7 | Phân cỡ tách bể → 2 group | event PHAN_LOAI + group_split | 🔧 |
| 6.8 | Sinh khối ước theo cân mẫu | SO_LUONG biomass_kg | ✅ |
| 6.9 | Thu 1 phần bể | XUAT với value con/kg | ✅ |
| 6.10 | FCR bể theo đợt nuôi | cycle_summary | 🔧 |

## 7. VAI A5 — Trồng trọt · A6 — Khu D · A7 — D5/chế biến
| # | Câu hỏi | Trả lời | TT |
|---|---|---|---|
| 7.1 | 40 lô, 3 vụ/năm, 5 năm = 600 vụ-lô | `cycles` kind VU gắn plot; năng suất/vụ/lô từ agg | 🔧 |
| 7.2 | Năng suất năm nay vs năm trước cùng lô | Explorer harvest_kg cắt plot + so kỳ trước | ✅ |
| 7.3 | Giờ máy theo lô để phân bổ chi phí | crop_logs.machine_hours; agg theo plot | ✅ |
| 7.4 | Nhiên liệu định mức từng máy | devices.fuel_l_per_h; RC7 | ✅ |
| 7.5 | Bón phân trùn: bao nhiêu/lô/năm | crop_logs BON input_lots; agg | ✅ (chưa có metric riêng) 🔧 metric |
| 7.6 | 6.000 m² luống trùn = 60 ô | locations O; batch theo ô; màn lưới ô | 🔧 lưới |
| 7.7 | Cân bằng vật chất tuần đúng khi nhiều khu | view theo farm; thêm theo khu | 📅 |
| 7.8 | Mẻ D5 100 mẻ/tháng, truy nguyên liệu | batch inputs lot_id | ✅ |
| 7.9 | CCP vượt → cô lập lô | lots.status CO_LAP + action | 🔧 action |
| 7.10 | Tem: số thứ tự theo cuộn | K9 lot + labels; RC12 | ✅ |

## 8. VAI A8 — Kho · A9 — Bán hàng · A11 — Cổng
| # | Câu hỏi | Trả lời | TT |
|---|---|---|---|
| 8.1 | 200 SKU, tìm nhanh | server search + quét mã | 🔧 |
| 8.2 | FEFO gợi ý lô khi xuất | list lô theo hạn | 🔧 |
| 8.3 | Kiểm kê 1 kho lớn 1 người 1 ngày | phiếu đếm theo vị trí bin | 📅 bin |
| 8.4 | Giá vốn BQ theo lô hay SKU | theo lô (view) | ✅ |
| 8.5 | Nhập không PO chặn không? | cảnh báo (không chặn) | ✅ |
| 8.6 | Bán 100 đơn/ngày | orders + sales dòng; POS | 🔧 orders |
| 8.7 | Khách 500 người, tìm nhanh | server search | 🔧 |
| 8.8 | Công nợ theo tuổi nợ (0–15/15–30/>30) | view aging | 🔧 |
| 8.9 | Cổng 50 xe/ngày, OCR | ảnh + gõ tay; OCR Ray B | ✅/📅 |
| 8.10 | Xe không cân cảnh báo | AL-GATE (rule seed) | 🔧 job |

## 9. VAI A12 KTT · A13 KS CN · A14 GĐ · Chủ · Kiểm toán · Kế toán
| # | Câu hỏi | Trả lời | TT |
|---|---|---|---|
| 9.1 | KTT quản 500 con, sáng xem gì? | Đỏ đêm, việc quá hạn theo khu, RC lệch, con cần chú ý | ✅ |
| 9.2 | Duyệt 40 checklist/ngày? | Duyệt hàng loạt (chỉ xem không xanh) | 🔧 bulk approve |
| 9.3 | Sửa RECIPE có phiên bản | UI recipe versioning | 📅 |
| 9.4 | KS CN: thiết bị 200 cái, hiệu chuẩn | tasks BAO_DUONG/hiệu chuẩn | ✅/🔧 calib task |
| 9.5 | GĐ: 3 trại so sánh | HQ | ✅ |
| 9.6 | GĐ: P&L phân hệ | chưa — cần cost allocation | 📅 (D) |
| 9.7 | Chủ: xem từ điện thoại 1 trang | /gd, /hq mobile | ✅ |
| 9.8 | Kiểm toán: mọi số → bản ghi + người | explorer/drill; audit pack | ✅ |
| 9.9 | Kế toán: bảng kê tháng, đóng kỳ | export sales-tax/purchases; khóa kỳ | 🔧 period lock |
| 9.10 | Khóa kỳ: sau ngày 5 không được ghi lùi vào tháng trước | `period_locks` + trigger chặn ts < lock (trừ adjustments có duyệt) | 🔧 |

## 10. NHÓM ĐA TRẠI / ĐA VÙNG / NHIỀU NĂM
| # | Câu hỏi | Trả lời | TT |
|---|---|---|---|
| 10.1 | Chuyển vật tư trại A→B | 2 move + `transfer_id`; giá 70% | 🔧 |
| 10.2 | Chuyển giống A→B qua cách ly | animal_transfers + intake_lot CHUYEN_TRAI | 🔧 |
| 10.3 | So KPI giữa trại khác vùng công bằng? | chuẩn hóa theo định mức vùng (norms) | 📅 |
| 10.4 | SOP phiên bản đẩy xuống 10 trại | sop_distributions | ✅ (UI 📅) |
| 10.5 | Người thuộc nhiều trại | staff.farm_ids | ✅ |
| 10.6 | Trại đóng cửa/bán | farms.status; dữ liệu giữ | ✅ |
| 10.7 | Năm N so N-1 cùng kỳ | explorer compare | ✅ |
| 10.8 | Báo cáo năm đóng băng (không đổi khi backfill sau) | REPORT_SNAPSHOT + period lock | 🔧 |
| 10.9 | Dữ liệu 5 năm trước lấy ra | partition archive vẫn query | 📅 |
| 10.10 | Xóa dữ liệu cá nhân khách sau 5 năm | ẩn danh job | 📅 |

## 11. NHÓM CHẤT LƯỢNG SỐ LIỆU
| # | Câu hỏi | Trả lời | TT |
|---|---|---|---|
| 11.1 | Trùng bản ghi khi sync 2 lần | client_ref unique | ✅ |
| 11.2 | Ghi nhầm con | supersede ≤72h | ✅ |
| 11.3 | Số âm/khổng lồ | Zod min/max; NORM sanity (kg/con/ngày ≤ 60) | 🔧 sanity rule |
| 11.4 | Đơn vị nhầm (kg↔g) | field unit cố định theo form | ✅ |
| 11.5 | Ghi hồi ký cuối ngày | histogram giờ; cờ >12h | ✅ |
| 11.6 | Sự kiện cho con đã CHET | trigger chặn trừ GHI_CHU | 🔧 |
| 11.7 | Nhóm head_count âm | greatest(0) + cảnh báo | ✅ |
| 11.8 | Tồn kho âm | cảnh báo (không chặn) | 🔧 alert |
| 11.9 | Sensor nhiễu | quality flag; median 5' | 📅 edge |
| 11.10 | KPI tính lại khi sửa dữ liệu | agg_daily refresh ngày bị ảnh hưởng | 🔧 |

## 12. DANH SÁCH SỬA ĐỢT NÀY (áp vào code ngay — migration 0009 + UI)
1. **Chỉ mục quy mô**: `(farm_id, animal_id, ts)`, `(farm_id, group_id, ts)`, `(farm_id, sku, ts)`, `(farm_id, created_by, ts)`, `(farm_id, plot_id, ts)`, trigram không dấu cho tìm kiếm animals/products/partners.
2. **Phân vùng**: `sensor_reads` theo tháng (tự tạo 12 tháng tới); bảng sự kiện lớn: kế hoạch chuyển sang partition theo năm khi >5M dòng (script sẵn), hiện tại chỉ mục đủ.
3. **`agg_daily`** (farm, day, metric, dim, value) + hàm `refresh_agg_daily(farm, day)`; explorer đọc agg khi bucket ≥ tuần và khoảng > 120 ngày; job đêm refresh hôm qua/hôm nay.
4. **`stock_daily`, `herd_daily`** snapshot cuối ngày (job) → hỏi tồn/đàn tại ngày bất kỳ.
5. **`cycles`** + `cycle_id` trên animal_groups/crop_logs/feed_logs/batch_logs; `cycle_summary` khi đóng.
6. **`period_locks`** + trigger chặn ghi lùi vào kỳ đã khóa (trừ adjustments).
7. **API phân trang/tìm kiếm**: `/api/data/animals?q&status&group&location&limit&offset` (server), tương tự products/partners; timeline con vật phân trang.
8. **UI theo tầng**: Đàn = tầng khu → đàn → cá thể (bộ lọc "cần chú ý" mặc định, tìm không dấu, 50/trang); Kho = kho → SKU tổng → lô; Việc = nhóm theo khu/mức; Cảnh báo gộp theo rule.
9. **Explorer**: ép bucket tự động; thẻ KPI có ▲▼ so kỳ trước; các dim thêm `dam_id`, `plot_id`, `cycle_id`.
10. Sanity rule: chặn sự kiện cho con đã CHET/XUAT (trừ GHI_CHU/CHUYEN hồ sơ), cảnh báo tồn âm.
