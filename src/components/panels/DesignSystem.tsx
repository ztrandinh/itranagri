"use client";
/** HỆ THIẾT KẾ (tài liệu sống) — mở /design-system để xem toàn bộ token & primitive đang dùng.
 *  Mục đích: người sau không phải đoán, và giao diện không "trôi" lại thành mỗi trang một kiểu. */
import { useState } from "react";
import { Button } from "@/components/ui/Button";
import { Skeleton, SkeletonText, SkeletonTable } from "@/components/ui/Skeleton";
import { EmptyState } from "@/components/ui/EmptyState";
import { Sheet } from "@/components/ui/Sheet";
import { Field } from "@/components/ui/Field";
import { ThemeToggle } from "@/components/ui/ThemeToggle";
import { toast } from "@/components/ui/Toast";
import { useConfirm } from "@/components/ui/ConfirmDialog";
import { usePrompt } from "@/components/ui/PromptDialog";

const COLORS: [string, string][] = [
  ["--bg", "Nền trang"], ["--surface", "Mặt thẻ"], ["--surface-2", "Mặt phụ"], ["--line", "Viền"],
  ["--ink", "Chữ chính"], ["--muted", "Chữ phụ"], ["--brand", "Thương hiệu"],
  ["--success", "Đạt"], ["--warning", "Cảnh báo"], ["--danger", "Nguy hiểm"], ["--info", "Thông tin"],
];
const SPACES = ["--s1", "--s2", "--s3", "--s4", "--s5", "--s6", "--s7", "--s8"];
const RADII = ["--r-sm", "--r-md", "--r-lg", "--r-xl", "--r-full"];

function Sec({ t, hint, children }: { t: string; hint?: string; children: React.ReactNode }) {
  return <section className="card">
    <h2 className="font-bold text-lg">{t}</h2>
    {hint && <p className="text-sm mb-3" style={{ color: "var(--muted)" }}>{hint}</p>}
    {children}
  </section>;
}

export default function DesignSystem() {
  const [sheet, setSheet] = useState(false);
  const { confirm, confirmElement } = useConfirm();
  const { prompt, promptElement } = usePrompt();
  return (
    <div className="space-y-3 ui-enter">
      {confirmElement}{promptElement}

      <Sec t="Giao diện Sáng / Tối" hint="Mọi màu đi qua token nên chuyển theme không cần sửa component.">
        <ThemeToggle />
      </Sec>

      <Sec t="Màu ngữ nghĩa" hint="Dùng theo Ý NGHĨA (nguy hiểm/cảnh báo/đạt), không dùng theo tên màu.">
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
          {COLORS.map(([v, label]) => (
            <div key={v} style={{ border: "1px solid var(--line)", borderRadius: "var(--r-md)", overflow: "hidden" }}>
              <div style={{ background: `var(${v})`, height: 40 }} />
              <div className="px-2 py-1.5">
                <div className="text-sm font-semibold">{label}</div>
                <code className="text-xs" style={{ color: "var(--muted)" }}>{v}</code>
              </div>
            </div>
          ))}
        </div>
      </Sec>

      <Sec t="Khoảng cách (4pt) & Bo góc">
        <div className="flex flex-wrap items-end gap-3">
          {SPACES.map((s) => <div key={s} className="text-center"><div style={{ width: `var(${s})`, height: `var(${s})`, background: "var(--brand)", borderRadius: 3 }} /><code className="text-[11px]" style={{ color: "var(--muted)" }}>{s}</code></div>)}
        </div>
        <div className="flex flex-wrap items-center gap-3 mt-4">
          {RADII.map((r) => <div key={r} className="text-center"><div style={{ width: 52, height: 40, background: "var(--surface-2)", border: "1px solid var(--line)", borderRadius: `var(${r})` }} /><code className="text-[11px]" style={{ color: "var(--muted)" }}>{r}</code></div>)}
        </div>
      </Sec>

      <Sec t="Nút" hint="4 biến thể × 3 cỡ. Cỡ lg cho thao tác ngoài đồng (tay đeo găng).">
        <div className="flex flex-wrap gap-2 items-center">
          <Button variant="primary">Chính</Button>
          <Button variant="secondary">Phụ</Button>
          <Button variant="danger">Nguy hiểm</Button>
          <Button variant="ghost">Trong suốt</Button>
          <Button variant="primary" loading>Đang lưu</Button>
          <Button variant="primary" disabled>Khoá</Button>
        </div>
        <div className="flex flex-wrap gap-2 items-center mt-3">
          <Button size="sm">Nhỏ 36px</Button><Button size="md">Vừa 44px</Button><Button size="lg" variant="primary">Lớn 52px</Button>
        </div>
      </Sec>

      <Sec t="Phản hồi & hộp thoại" hint="Thay hoàn toàn alert/confirm/prompt của trình duyệt.">
        <div className="flex flex-wrap gap-2">
          <Button onClick={() => toast.ok("Đã lưu bản ghi")}>Toast thành công</Button>
          <Button onClick={() => toast.err("Không lưu được — thử lại")}>Toast lỗi</Button>
          <Button onClick={() => toast.info("Đang đồng bộ dữ liệu")}>Toast thông tin</Button>
          <Button onClick={async () => { if (await confirm({ title: "Gỡ bản ghi này?", message: "Vẫn giữ lịch sử, có thể khôi phục.", danger: true })) toast.ok("Đã gỡ"); }}>Hộp xác nhận</Button>
          <Button onClick={async () => { const v = await prompt({ title: "Nhập số tiền", label: "Số tiền thu", type: "number", min: 0, unit: "đ" }); if (v != null) toast.ok(`Đã nhập ${Number(v).toLocaleString("vi-VN")} đ`); }}>Hộp nhập số</Button>
          <Button onClick={() => setSheet(true)}>Tấm trượt (mobile)</Button>
        </div>
        <Sheet open={sheet} onClose={() => setSheet(false)} title="Ghi nhanh">
          <Field label="Số lượng" required>{(p) => <input {...p} className="input" type="number" inputMode="decimal" defaultValue={10} />}</Field>
          <div className="flex gap-2 justify-end mt-4"><Button onClick={() => setSheet(false)}>Hủy</Button><Button variant="primary" onClick={() => { setSheet(false); toast.ok("Đã ghi"); }}>Lưu</Button></div>
        </Sheet>
      </Sec>

      <Sec t="Trạng thái tải & rỗng" hint="Không bao giờ để màn trắng hoặc chữ cụt.">
        <div className="grid md:grid-cols-3 gap-3">
          <div><div className="text-xs font-bold uppercase mb-2" style={{ color: "var(--muted)" }}>Đang tải — chữ</div><SkeletonText lines={4} /></div>
          <div><div className="text-xs font-bold uppercase mb-2" style={{ color: "var(--muted)" }}>Đang tải — bảng</div><div style={{ border: "1px solid var(--line)", borderRadius: "var(--r-md)" }}><SkeletonTable rows={4} cols={3} /></div></div>
          <div><div className="text-xs font-bold uppercase mb-2" style={{ color: "var(--muted)" }}>Rỗng</div>
            <div style={{ border: "1px solid var(--line)", borderRadius: "var(--r-md)" }}>
              <EmptyState icon="🐄" title="Chưa có con nào trong chuồng này" hint="Nhập lô đàn hoặc thêm cá thể để bắt đầu theo dõi." action={<Button size="sm" variant="primary">Nhập lô đàn</Button>} />
            </div>
          </div>
        </div>
      </Sec>

      <Sec t="Thẻ số liệu & bảng">
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 mb-3">
          <div className="kpi"><div className="l">Tổng đàn</div><div className="v">403</div></div>
          <div className="kpi"><div className="l">Ngày-tồn ủ chua</div><div className="v" style={{ color: "var(--danger)" }}>28</div></div>
          <div className="kpi"><div className="l">Doanh thu tuần</div><div className="v">185tr</div></div>
          <div className="kpi"><div className="l">Việc quá hạn</div><div className="v" style={{ color: "var(--warning)" }}>12</div></div>
        </div>
        <div className="card p-0 overflow-auto"><table className="tbl"><thead><tr><th className="pl-3">Mã</th><th>Tên</th><th className="text-right">Tồn</th><th>Trạng thái</th></tr></thead><tbody>
          <tr><td className="pl-3 font-mono text-xs">NL-BA-BIA</td><td>Bã bia</td><td className="text-right">20.221 kg</td><td><span className="b-grn">Đủ</span></td></tr>
          <tr><td className="pl-3 font-mono text-xs">NL-RI-MAT</td><td>Rỉ mật</td><td className="text-right">5.640 kg</td><td><span className="b-yel">Sắp hết</span></td></tr>
          <tr><td className="pl-3 font-mono text-xs">TA-VIEN-GA</td><td>Viên D5 gà đẻ</td><td className="text-right">1.044 kg</td><td><span className="b-red">Cạn</span></td></tr>
        </tbody></table></div>
      </Sec>

      <Sec t="Quy tắc dùng" hint="Giữ 5 điều này thì giao diện không trôi lại.">
        <ol className="list-decimal ml-5 text-sm space-y-1" style={{ color: "var(--muted)" }}>
          <li>Không hardcode màu mới — dùng token ngữ nghĩa (<code>var(--danger)</code>, không phải <code>text-red-600</code>).</li>
          <li>Không dùng <code>alert/confirm/prompt</code> của trình duyệt — dùng toast / useConfirm / usePrompt.</li>
          <li>Danh sách phải có đủ 4 trạng thái: đang tải (skeleton) · rỗng (EmptyState) · lỗi (có nút thử lại) · có dữ liệu.</li>
          <li>Nút thao tác chính trên mobile ≥44px; ngoài đồng dùng cỡ <code>lg</code>.</li>
          <li>Chuyển động lấy từ token (<code>--dur</code>, <code>--ease</code>) và phải tắt khi người dùng bật giảm chuyển động.</li>
        </ol>
      </Sec>
    </div>
  );
}
