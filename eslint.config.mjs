import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

const eslintConfig = defineConfig([
  ...nextVitals,
  ...nextTs,
  // Override default ignores of eslint-config-next.
  globalIgnores([
    // Default ignores of eslint-config-next:
    ".next/**",
    "out/**",
    "build/**",
    "next-env.d.ts",
    // .next/** không khớp .next lồng trong worktree phụ (vd .claude/worktrees/x/.next) —
    // loại cả dạng đệ quy và toàn bộ thư mục worktree phụ (mỗi worktree tự lint riêng).
    "**/.next/**",
    "**/out/**",
    "**/build/**",
    ".claude/worktrees/**",
  ]),
  {
    rules: {
      "react/no-unescaped-entities": "off",
      "@next/next/no-html-link-for-pages": "off",
      // Giữ "warn" (không "error"): codebase cũ có 181 vi phạm hiện hữu, ép "error" ngay sẽ đỏ CI
      // hàng loạt không kiểm soát được. Chặn TÁI DIỄN thay vì chặn tồn tại: `pnpm lint` có
      // `--max-warnings 181` (package.json) — số warning tăng thêm 1 là CI đỏ, chỉ giảm được, không tăng.
      "react-hooks/set-state-in-effect": "warn",
      "react-hooks/purity": "warn",
      "react-hooks/use-memo": "warn",
      "react-hooks/exhaustive-deps": "warn",
      // Chặn tận gốc bug "chữ chìm vào nền": class màu Tailwind cứng (text-slate-900, bg-emerald-50...)
      // không tự đổi theo dark mode trừ khi có ai nhớ vá thêm 1 lớp bù riêng (dễ quên — đã xảy ra thật,
      // gây chữ tối trên nền tối vô hình ở dark mode tự động). Dùng token ngữ nghĩa (var(--ink)/var(--brand)...)
      // hoặc class .btn-*/.b-*/.card/.kpi có sẵn — những class đó tự đổi đúng màu ở mọi theme, không cần vá gì thêm.
      // Mức "warn" vì codebase cũ còn nhiều chỗ dùng kiểu này — không chặn build, chỉ nhắc khi viết code MỚI.
      "no-restricted-syntax": [
        "warn",
        {
          selector: "JSXAttribute[name.name='className'] Literal[value=/\\b(text|bg|border|ring)-(slate|stone|gray|zinc|neutral|emerald|green|red|amber|yellow|blue|sky|cyan|teal|indigo|violet|purple|pink|rose)-(50|100|200|300|400|500|600|700|800|900)\\b/]",
          message: "Đừng hardcode class màu Tailwind (vd text-slate-900) — dùng token ngữ nghĩa (var(--ink)/var(--brand)/var(--muted)...) hoặc class .btn-*/.b-*/.card/.kpi có sẵn. Class cứng dễ vỡ dark mode (đã xảy ra thật — xem globals.css).",
        },
      ],
    },
  },
]);

export default eslintConfig;
