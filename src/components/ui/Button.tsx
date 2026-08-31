"use client";
/** Button primitive — một nguồn sự thật cho nút. Dùng token (không hardcode màu).
 *  variant: primary | secondary | danger | ghost · size: sm | md | lg · loading (khoá + spinner). */
import { forwardRef } from "react";

type Variant = "primary" | "secondary" | "danger" | "ghost";
type Size = "sm" | "md" | "lg";

const SIZE: Record<Size, string> = {
  sm: "min-h-[36px] px-3 text-sm gap-1.5",
  md: "min-h-[44px] px-4 text-base gap-2",
  lg: "min-h-[52px] px-5 text-lg gap-2",
};

export const Button = forwardRef<HTMLButtonElement, React.ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: Variant; size?: Size; loading?: boolean; block?: boolean;
}>(function Button({ variant = "secondary", size = "md", loading, block, className = "", children, disabled, style, ...rest }, ref) {
  const base = "inline-flex items-center justify-center font-semibold select-none transition-[background-color,box-shadow,transform] active:scale-[.985] disabled:opacity-55 disabled:pointer-events-none";
  const v: React.CSSProperties =
    variant === "primary" ? { background: "var(--brand)", color: "var(--bg)", boxShadow: "var(--sh-1)" }
    : variant === "danger" ? { background: "var(--danger)", color: "var(--bg)", boxShadow: "var(--sh-1)" }
    : variant === "ghost" ? { background: "transparent", color: "var(--ink)" }
    : { background: "var(--surface)", color: "var(--ink)", border: "1px solid var(--line)", boxShadow: "var(--sh-1)" };
  return (
    <button
      ref={ref}
      disabled={disabled || loading}
      className={`${base} ${SIZE[size]} ${block ? "w-full" : ""} ${className}`}
      style={{ borderRadius: "var(--r-md)", transitionDuration: "var(--dur-fast)", transitionTimingFunction: "var(--ease)", ...v, ...style }}
      {...rest}
    >
      {loading && <span aria-hidden="true" className="inline-block h-4 w-4 rounded-full border-2 border-current border-r-transparent animate-spin" />}
      {children}
    </button>
  );
});
