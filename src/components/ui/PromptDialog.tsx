"use client";
/** PromptDialog: thay window.prompt() native — ĐẶC BIỆT cho nhập TIỀN/SỐ (giá POS, đếm két, trả NCC…).
 *  Có input đúng kiểu (number/text), validate, chặn NaN/âm, format gợi ý, nhãn liên kết htmlFor.
 *  Dùng qua hook usePrompt(): const v = await prompt({ label, type:"number", min:0 }); (null nếu hủy). */
import { useCallback, useState } from "react";
import { Modal } from "./Modal";
import { Field } from "./Field";

type PromptOpts = {
  title: string;
  label: string;
  type?: "text" | "number";
  defaultValue?: string | number;
  placeholder?: string;
  min?: number;
  max?: number;
  unit?: string;
  required?: boolean;
  confirmText?: string;
};

export function usePrompt() {
  const [state, setState] = useState<(PromptOpts & { resolve: (v: string | null) => void }) | null>(null);
  const [value, setValue] = useState("");
  const [err, setErr] = useState<string | null>(null);

  const prompt = useCallback((opts: PromptOpts) => new Promise<string | null>((resolve) => {
    setValue(opts.defaultValue != null ? String(opts.defaultValue) : "");
    setErr(null);
    setState({ ...opts, resolve });
  }), []);

  const finish = useCallback((v: string | null) => {
    setState((s) => { s?.resolve(v); return null; });
  }, []);

  const validate = (s: PromptOpts, raw: string): string | null => {
    const v = raw.trim();
    if (s.required !== false && v === "") return "Chưa nhập giá trị.";
    if (s.type === "number") {
      const n = Number(v);
      if (v !== "" && Number.isNaN(n)) return "Phải là số hợp lệ.";
      if (s.min != null && n < s.min) return `Không nhỏ hơn ${s.min.toLocaleString("vi-VN")}.`;
      if (s.max != null && n > s.max) return `Không lớn hơn ${s.max.toLocaleString("vi-VN")}.`;
    }
    return null;
  };

  const submit = () => {
    if (!state) return;
    const e = validate(state, value);
    if (e) { setErr(e); return; }
    finish(value.trim());
  };

  const element = state ? (
    <Modal open onClose={() => finish(null)} title={state.title}>
      <form onSubmit={(e) => { e.preventDefault(); submit(); }}>
        <Field label={state.label} required={state.required !== false} error={err}>
          {(p) => (
            <div className="flex items-center gap-2">
              <input
                {...p}
                className="input"
                type={state.type === "number" ? "number" : "text"}
                inputMode={state.type === "number" ? "decimal" : undefined}
                autoFocus
                value={value}
                placeholder={state.placeholder}
                min={state.min}
                max={state.max}
                onChange={(e) => { setValue(e.target.value); if (err) setErr(null); }}
              />
              {state.unit && <span className="text-slate-600 whitespace-nowrap">{state.unit}</span>}
            </div>
          )}
        </Field>
        <div className="flex gap-2 justify-end mt-4">
          <button type="button" className="btn-secondary !py-2.5 !px-4 !text-base" onClick={() => finish(null)}>Hủy</button>
          <button type="submit" className="btn-primary !py-2.5 !px-4 !text-base">{state.confirmText ?? "Xong"}</button>
        </div>
      </form>
    </Modal>
  ) : null;

  return { prompt, promptElement: element };
}
