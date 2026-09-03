"use client";
/** Field: bọc <label> liên kết tường minh với input qua htmlFor/id (WCAG 3.3.2, 1.3.1).
 *  Dùng thay cho pattern <label>text</label><input/> rời rạc (screen-reader không đọc được nhãn,
 *  chạm nhãn không focus ô). Tự sinh id ổn định bằng useId. */
import { useId } from "react";

export function Field({ label, required, hint, error, children, className }: {
  label: string;
  required?: boolean;
  hint?: string;
  error?: string | null;
  className?: string;
  children: (props: { id: string; "aria-invalid"?: boolean; "aria-describedby"?: string }) => React.ReactNode;
}) {
  const id = useId();
  const hintId = hint ? `${id}-hint` : undefined;
  const errId = error ? `${id}-err` : undefined;
  const describedBy = [hintId, errId].filter(Boolean).join(" ") || undefined;
  return (
    <div className={className}>
      <label htmlFor={id} className="block text-sm text-muted mb-1 font-semibold">
        {label}{required && <span className="text-danger-tok" aria-hidden="true"> *</span>}
      </label>
      {children({ id, "aria-invalid": error ? true : undefined, "aria-describedby": describedBy })}
      {hint && <p id={hintId} className="mt-1 text-xs text-muted">{hint}</p>}
      {error && <p id={errId} className="mt-1 text-xs text-danger-tok" role="alert">{error}</p>}
    </div>
  );
}
