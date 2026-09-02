/** Icon SVG màu cho 16 khu vực/phòng ban (ZONES ở Shell.tsx) — thay emoji thô (🐄🌾♻️...).
 *  Lý do đổi: emoji hiển thị KHÁC NHAU tùy hệ điều hành (Android công nhân dùng ra khác Windows/máy chủ đầu tư
 *  test) — không chuyên nghiệp và không nhất quán. Icon SVK tự vẽ, có nền màu riêng (giống Notion/iOS Settings),
 *  giữ hình tượng ngành (bò, lúa, tuần hoàn, nhà máy...) để công nhân vẫn nhận ra ngay không cần đọc chữ —
 *  không đổi sang bộ icon outline chung chung vì sẽ mất khả năng nhận diện đó.
 *  Mỗi icon tự chứa màu nền riêng (không dùng token) nên luôn hiển thị đúng bất kể đặt trên sidebar tối hay
 *  card sáng — không cần biết ngữ cảnh xung quanh. */
type Props = { size?: number };
const S = 40;

function Base({ bg, children }: { bg: string; children: React.ReactNode }) {
  return (
    <svg width={S} height={S} viewBox={`0 0 ${S} ${S}`} style={{ display: "block" }}>
      <rect width={S} height={S} rx="10" fill={bg} />
      {children}
    </svg>
  );
}

const ICONS: Record<string, (p: Props) => React.ReactNode> = {
  me: () => (
    <Base bg="#4b5563">
      <rect x="11" y="10" width="18" height="21" rx="2" fill="#fff" />
      <rect x="14" y="15" width="12" height="2" rx="1" fill="#4b5563" />
      <rect x="14" y="19" width="12" height="2" rx="1" fill="#4b5563" />
      <rect x="14" y="23" width="8" height="2" rx="1" fill="#4b5563" />
    </Base>
  ),
  dh: () => (
    <Base bg="#4338ca">
      <circle cx="20" cy="20" r="11" fill="none" stroke="#fff" strokeWidth="2.5" />
      <circle cx="20" cy="20" r="6.5" fill="none" stroke="#fff" strokeWidth="2.5" />
      <circle cx="20" cy="20" r="2" fill="#fff" />
    </Base>
  ),
  cn: () => (
    <Base bg="#92601c">
      <path d="M14 10 L16 15 M26 10 L24 15" stroke="#fff" strokeWidth="2.2" strokeLinecap="round" />
      <ellipse cx="11.5" cy="18" rx="3.2" ry="4" fill="#fff" transform="rotate(-15 11.5 18)" />
      <ellipse cx="28.5" cy="18" rx="3.2" ry="4" fill="#fff" transform="rotate(15 28.5 18)" />
      <rect x="11" y="15" width="18" height="16" rx="8" fill="#fff" />
      <rect x="15" y="23" width="10" height="7" rx="3.5" fill="#92601c" />
      <circle cx="18" cy="26.5" r="0.9" fill="#fff" />
      <circle cx="22" cy="26.5" r="0.9" fill="#fff" />
      <circle cx="16" cy="19" r="1.8" fill="#92601c" />
      <circle cx="24" cy="19" r="1.8" fill="#92601c" />
      <path d="M13 12 Q11 9 9 10" fill="none" stroke="#fff" strokeWidth="1.8" strokeLinecap="round" />
      <path d="M27 12 Q29 9 31 10" fill="none" stroke="#fff" strokeWidth="1.8" strokeLinecap="round" />
    </Base>
  ),
  tt: () => (
    <Base bg="#15803d">
      <path d="M20 30 V14" stroke="#fff" strokeWidth="2.5" strokeLinecap="round" />
      <path d="M20 14 C16 14 13 11 13 7 C17 7 20 10 20 14" fill="#fff" />
      <path d="M20 18 C24 18 27 15 27 11 C23 11 20 14 20 18" fill="#fff" />
      <path d="M20 22 C16 22 13 19 13 15 C17 15 20 18 20 22" fill="#fff" />
    </Base>
  ),
  sh: () => (
    <Base bg="#0d9488">
      <path d="M13 15 L20 11 L27 15 L23.5 17 L20 15 L16.5 17 Z" fill="#fff" />
      <path d="M27 17 L27 25 L23 28 L23 24 L25 22.5 L25 19 Z" fill="#fff" />
      <path d="M13 17 L13 25 L17 28 L17 24 L15 22.5 L15 19 Z" fill="#fff" />
    </Base>
  ),
  d5: () => (
    <Base bg="#c2410c">
      <rect x="10" y="18" width="20" height="12" fill="#fff" />
      <path d="M13 18 L13 12 L17 15 L17 10 L21 13 L21 18" fill="#fff" />
      <rect x="24" y="22" width="3" height="8" fill="#c2410c" />
    </Base>
  ),
  ccu: () => (
    <Base bg="#1d4ed8">
      <path d="M20 9 L30 14 V26 L20 31 L10 26 V14 Z" fill="none" stroke="#fff" strokeWidth="2" />
      <path d="M10 14 L20 19 L30 14" fill="none" stroke="#fff" strokeWidth="2" />
      <path d="M20 19 V31" stroke="#fff" strokeWidth="2" />
    </Base>
  ),
  kdm: () => (
    <Base bg="#be123c">
      <ellipse cx="20" cy="27" rx="9" ry="3.2" fill="#fff" opacity="0.55" />
      <ellipse cx="20" cy="23" rx="9" ry="3.2" fill="#fff" opacity="0.75" />
      <ellipse cx="20" cy="19" rx="9" ry="3.2" fill="#fff" />
      <path d="M17 17.6 V20.4 M20 17.2 V20.8 M23 17.6 V20.4" stroke="#be123c" strokeWidth="1.3" strokeLinecap="round" />
    </Base>
  ),
  dl: () => (
    <Base bg="#7e22ce">
      <rect x="11" y="19" width="18" height="10" rx="2" fill="#fff" />
      <rect x="14" y="14" width="12" height="6" rx="3" fill="#fff" />
      <rect x="17" y="23" width="6" height="6" rx="1" fill="#7e22ce" />
    </Base>
  ),
  xnk: () => (
    <Base bg="#0891b2">
      <circle cx="20" cy="20" r="11" fill="none" stroke="#fff" strokeWidth="2.2" />
      <ellipse cx="20" cy="20" rx="4.5" ry="11" fill="none" stroke="#fff" strokeWidth="2" />
      <path d="M9 20 H31" stroke="#fff" strokeWidth="2" />
      <path d="M11 14 H29" stroke="#fff" strokeWidth="1.6" />
      <path d="M11 26 H29" stroke="#fff" strokeWidth="1.6" />
    </Base>
  ),
  tckt: () => (
    <Base bg="#059669">
      <rect x="11" y="10" width="18" height="21" rx="2" fill="#fff" />
      <path d="M20 10 V31" stroke="#059669" strokeWidth="1.5" />
      <path d="M14 15 H18 M14 19 H18" stroke="#059669" strokeWidth="1.5" />
      <path d="M14 23 H18" stroke="#059669" strokeWidth="1.5" />
      <path d="M22 15 H26 M22 19 H26" stroke="#059669" strokeWidth="1.5" />
    </Base>
  ),
  hcns: () => (
    <Base bg="#0369a1">
      <circle cx="15" cy="15" r="4" fill="#fff" />
      <circle cx="25" cy="15" r="4" fill="#fff" />
      <path d="M8 30 C8 24 11 21 15 21 C19 21 22 24 22 30" fill="#fff" />
      <path d="M18 30 C18 24 21 21 25 21 C29 21 32 24 32 30" fill="#fff" opacity="0.75" />
    </Base>
  ),
  qa: () => (
    <Base bg="#166534">
      <path d="M20 9 L29 13 V21 C29 27 25 30 20 32 C15 30 11 27 11 21 V13 Z" fill="#fff" />
      <path d="M15.5 20 L18.5 23 L25 16" fill="none" stroke="#166534" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" />
    </Base>
  ),
  cntb: () => (
    <Base bg="#475569">
      <g fill="#fff">
        <rect x="18" y="7" width="4" height="5" rx="1" />
        <rect x="18" y="28" width="4" height="5" rx="1" />
        <rect x="7" y="18" width="5" height="4" rx="1" />
        <rect x="28" y="18" width="5" height="4" rx="1" />
        <rect x="10.3" y="10.3" width="4" height="5" rx="1" transform="rotate(-45 12.3 12.8)" />
        <rect x="25.7" y="10.3" width="4" height="5" rx="1" transform="rotate(45 27.7 12.8)" />
        <rect x="10.3" y="25.7" width="4" height="5" rx="1" transform="rotate(45 12.3 28.2)" />
        <rect x="25.7" y="25.7" width="4" height="5" rx="1" transform="rotate(-45 27.7 28.2)" />
      </g>
      <circle cx="20" cy="20" r="7.5" fill="#475569" stroke="#fff" strokeWidth="2.2" />
      <circle cx="20" cy="20" r="2.5" fill="#fff" />
    </Base>
  ),
  rd: () => (
    <Base bg="#7c3aed">
      <path d="M17 10 H23 V17 L28 28 C28.8 29.6 27.6 31 26 31 H14 C12.4 31 11.2 29.6 12 28 L17 17 Z" fill="none" stroke="#fff" strokeWidth="2.2" strokeLinejoin="round" />
      <path d="M14.5 24 H25.5" stroke="#fff" strokeWidth="2" />
    </Base>
  ),
  tc: () => (
    <Base bg="#334155">
      <rect x="17" y="9" width="6" height="6" rx="1.5" fill="#fff" />
      <rect x="9" y="25" width="6" height="6" rx="1.5" fill="#fff" />
      <rect x="25" y="25" width="6" height="6" rx="1.5" fill="#fff" />
      <path d="M20 15 V20 H12 V25 M20 20 H28 V25" fill="none" stroke="#fff" strokeWidth="2" />
    </Base>
  ),
};

/** key khớp với ZONES[].key trong Shell.tsx. size mặc định 40 (co giãn qua CSS width/height ở nơi gọi). */
export function ZoneIcon({ zoneKey, size = 22 }: { zoneKey: string; size?: number }) {
  const render = ICONS[zoneKey];
  if (!render) return null;
  return <span style={{ display: "inline-flex", width: size, height: size, verticalAlign: "middle" }}>{render({})}</span>;
}
