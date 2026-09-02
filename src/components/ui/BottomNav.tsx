"use client";
/** BOTTOM NAV (mobile) — 4 việc công nhân làm nhiều nhất, đặt trong VÙNG NGÓN CÁI.
 *  Trước đây mọi điều hướng nằm ở menu ☰ góc trên → cầm một tay ngoài đồng phải với lên.
 *  Chỉ hiện trên mobile (<md) và cho vai thao tác hiện trường. */
import Link from "next/link";
import { usePathname } from "next/navigation";
import { IconClipboard, IconPencil, IconCamera, IconUser } from "@/components/icons/UiIcons";

const ITEMS: { href: string; Icon: (p: { size?: number }) => React.ReactNode; label: string }[] = [
  { href: "/ca", Icon: IconClipboard, label: "Việc" },
  { href: "/ca?tab=ghi", Icon: IconPencil, label: "Ghi" },
  { href: "/giay", Icon: IconCamera, label: "Phiếu" },
  { href: "/tai-khoan", Icon: IconUser, label: "Tôi" },
];

export function BottomNav({ role }: { role: string }) {
  const path = usePathname();
  // Vai hiện trường: công nhân, tổ trưởng, kỹ thuật trưởng
  if (!["worker", "team_lead", "tech_head"].includes(role)) return null;
  return (
    <>
      {/* chừa chỗ để nội dung không bị thanh che */}
      <div aria-hidden="true" className="md:hidden" style={{ height: "calc(60px + env(safe-area-inset-bottom))" }} />
      <nav
        aria-label="Điều hướng nhanh"
        className="md:hidden fixed bottom-0 left-0 right-0"
        style={{
          zIndex: "var(--z-header)", background: "var(--surface)", borderTop: "1px solid var(--line)",
          paddingBottom: "env(safe-area-inset-bottom)", boxShadow: "0 -2px 12px rgba(20,30,45,.06)",
        }}
      >
        <ul className="flex">
          {ITEMS.map((it) => {
            const base = it.href.split("?")[0];
            const active = path === base || (base !== "/ca" && path.startsWith(base + "/")) || (it.href === "/ca" && path === "/ca");
            return (
              <li key={it.href} className="flex-1">
                <Link
                  href={it.href}
                  aria-current={active ? "page" : undefined}
                  className="flex flex-col items-center justify-center gap-0.5"
                  style={{
                    minHeight: 60, fontSize: 12, fontWeight: 600,
                    color: active ? "var(--brand)" : "var(--muted)",
                    transition: `color var(--dur-fast) var(--ease)`,
                  }}
                >
                  <span aria-hidden="true" style={{ lineHeight: 1 }}><it.Icon size={20} /></span>
                  {it.label}
                </Link>
              </li>
            );
          })}
        </ul>
      </nav>
    </>
  );
}
