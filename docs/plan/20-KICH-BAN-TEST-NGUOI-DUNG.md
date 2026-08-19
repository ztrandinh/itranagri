# 20 · KỊCH BẢN TEST VỚI NGƯỜI DÙNG THẬT

> Mục đích: tìm chỗ người thật **vấp**, không phải hỏi họ "thấy đẹp không".
> Nguyên tắc vàng: **không nhắc, không giải thích, không bênh sản phẩm**. Im lặng quan sát.
> Từ 8 lên 9+ điểm chỉ đạt được ở đây — không phải trong editor.

## Chuẩn bị

- [ ] 5–7 người: **4 công nhân (A1–A11)**, 1 tổ trưởng, 1 kỹ thuật trưởng, 1 kế toán
- [ ] Thiết bị THẬT của họ (điện thoại Android cũ, màn xước, tay bẩn/đeo găng)
- [ ] Địa điểm THẬT: chuồng/kho/ngoài nắng — không phải phòng họp máy lạnh
- [ ] Tài khoản thật của từng người, dữ liệu thật của trại
- [ ] Bật đo: hệ thống tự ghi `ux_events` (task_start/done/abandon/form_error)
- [ ] 1 người dẫn (chỉ đọc kịch bản) + 1 người ghi chép (không nói)

## 6 tác vụ lõi (mỗi người làm hết, KHÔNG hướng dẫn)

| # | Nói với người dùng đúng câu này | Đo cái gì | Đạt khi |
|---|---|---|---|
| 1 | "Anh/chị ghi giúp mẻ TMR vừa cho ăn sáng nay." | ghi_feed_logs | ≤20s · ≤3 chạm · không hỏi |
| 2 | "Con bò B012 vừa cân được 430 kg, ghi lại giúp." | ghi_animal_events | ≤20s · tìm đúng con |
| 3 | "Vừa nhập 2 tấn bã bia vào kho, ghi vào hệ thống." | ghi_inventory_moves | ≤30s · chọn đúng kho/lô |
| 4 | "Máy cắt cỏ bị hỏng, báo cho người phụ trách." | ghi_incidents | ≤30s · tìm được chỗ báo |
| 5 | "Hôm nay anh/chị có việc gì phải làm?" | xem việc | ≤10s · hiểu đúng việc |
| 6 | "Tờ phiếu giấy này, đưa vào hệ thống giúp." | paper_scans | ≤40s · chụp + gắn đúng |

## Cách quan sát (người ghi chép điền)

Mỗi tác vụ ghi:
- [ ] **Thời gian** (bấm giờ từ lúc bắt đầu tới lúc xong)
- [ ] **Số lần vấp**: dừng >3 giây / bấm nhầm / quay lại / cuộn tìm
- [ ] **Câu họ hỏi** (chép nguyên văn — đây là vàng, mỗi câu hỏi = một chỗ thiết kế chưa rõ)
- [ ] **Chỗ họ chạm nhầm** (nút nào tưởng bấm được mà không phải, ngược lại)
- [ ] **Từ họ không hiểu** (mã, viết tắt, nhãn) → bổ sung vào `lib/glossary.ts`
- [ ] **Bỏ cuộc?** (có/không · ở bước nào)

Thang mức vấp: `0` trôi chảy · `1` ngập ngừng · `2` phải thử lại · `3` phải hỏi · `4` bỏ cuộc.

## Câu hỏi sau buổi (mở, không dẫn dắt)

1. "Chỗ nào khó chịu nhất?"
2. "Có gì anh/chị tưởng nó sẽ làm mà nó không làm?"
3. "Nếu được xoá một thứ trên màn hình này, anh/chị xoá gì?"
4. "Ngoài nắng có đọc được không?" (bật/tắt Chế độ nắng cho thử)
5. "Một tay cầm điện thoại có với tới nút không?"

❌ KHÔNG hỏi: "Anh/chị thấy đẹp không?", "Có dễ dùng không?" — người Việt thường khen cho vừa lòng.

## Sau buổi test — biến quan sát thành việc

- [ ] Đối chiếu quan sát với số đo: `select * from v_ux_task_success` và `v_ux_friction`
- [ ] Xếp lỗi theo **số người vấp × mức vấp** (không phải theo cảm tính người sửa)
- [ ] Mọi câu hỏi họ hỏi ≥2 lần → sửa nhãn/thêm giải thích (`Term`)
- [ ] Mọi tác vụ có tỷ lệ hoàn tất <80% → thiết kế lại luồng, không phải "thêm hướng dẫn"
- [ ] Ghi kết quả vào `docs/plan/21-KET-QUA-TEST-VONG-1.md`, rồi lặp lại vòng 2 sau khi sửa

## Ngưỡng chấp nhận (vòng 1)

| Chỉ số | Ngưỡng |
|---|---|
| Tỷ lệ hoàn tất mỗi tác vụ | ≥ 80% |
| Thời gian trung vị ghi 1 bản ghi | ≤ 20 giây |
| Số câu hỏi trung bình / người | ≤ 3 |
| Bỏ cuộc | 0 |

Chưa đạt ngưỡng thì **sửa rồi test lại**, không đi tiếp tính năng mới.
