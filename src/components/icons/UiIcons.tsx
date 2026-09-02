/** Icon SVG đơn sắc cho ký hiệu UI thuần túy (mũi tên, dấu cộng, tick...) — khác với ZoneIcons.tsx
 *  (icon MÀU cho 16 khu vực, mang ý nghĩa ngành). Nhóm này KHÔNG mang ý nghĩa ngành, chỉ là chrome
 *  giao diện, nên vẽ đơn sắc dùng currentColor — tự động đúng màu theo chữ xung quanh (sidebar tối
 *  hay card sáng), không cần quản lý riêng như icon màu tự chứa nền.
 *  Quy ước: viewBox 24x24, stroke 2px, round cap/join — nhất quán 1 kiểu cho mọi icon trong bộ. */
type P = { size?: number; className?: string; strokeWidth?: number };
const base = { fill: "none" as const, stroke: "currentColor" as const, strokeLinecap: "round" as const, strokeLinejoin: "round" as const };

function Svg({ size = 18, className, strokeWidth = 2, children }: P & { children: React.ReactNode }) {
  return <svg width={size} height={size} viewBox="0 0 24 24" className={className} style={{ display: "inline-block", verticalAlign: "-3px" }} {...base} strokeWidth={strokeWidth}>{children}</svg>;
}

export const IconCheck = (p: P) => <Svg {...p}><path d="M4 12.5 L9.5 18 L20 6" /></Svg>;
export const IconX = (p: P) => <Svg {...p}><path d="M5 5 L19 19 M19 5 L5 19" /></Svg>;
export const IconArrowLeft = (p: P) => <Svg {...p}><path d="M19 12 H5 M11 6 L5 12 L11 18" /></Svg>;
export const IconArrowRight = (p: P) => <Svg {...p}><path d="M5 12 H19 M13 6 L19 12 L13 18" /></Svg>;
export const IconChevronDown = (p: P) => <Svg {...p}><path d="M5 9 L12 16 L19 9" /></Svg>;
export const IconChevronRight = (p: P) => <Svg {...p}><path d="M9 5 L16 12 L9 19" /></Svg>;
export const IconChevronsLeft = (p: P) => <Svg {...p}><path d="M13 5 L6 12 L13 19 M19 5 L12 12 L19 19" /></Svg>;
export const IconChevronsRight = (p: P) => <Svg {...p}><path d="M11 5 L18 12 L11 19 M5 5 L12 12 L5 19" /></Svg>;
export const IconMenu = (p: P) => <Svg {...p}><path d="M4 7 H20 M4 12 H20 M4 17 H20" /></Svg>;
export const IconPlus = (p: P) => <Svg {...p}><path d="M12 5 V19 M5 12 H19" /></Svg>;
export const IconMinus = (p: P) => <Svg {...p}><path d="M5 12 H19" /></Svg>;
export const IconHome = (p: P) => <Svg {...p}><path d="M4 11 L12 4 L20 11 V19.5 A0.5 0.5 0 0 1 19.5 20 H14.5 V14 H9.5 V20 H4.5 A0.5 0.5 0 0 1 4 19.5 Z" /></Svg>;
export const IconClipboard = (p: P) => <Svg {...p}><rect x="6" y="4.5" width="12" height="16" rx="1.5" /><rect x="9" y="3" width="6" height="3" rx="1" /><path d="M9 11 H15 M9 14.5 H15 M9 18 H12.5" /></Svg>;
export const IconCamera = (p: P) => <Svg {...p}><path d="M4 8.5 A1.5 1.5 0 0 1 5.5 7 H8 L9.3 5 H14.7 L16 7 H18.5 A1.5 1.5 0 0 1 20 8.5 V17.5 A1.5 1.5 0 0 1 18.5 19 H5.5 A1.5 1.5 0 0 1 4 17.5 Z" /><circle cx="12" cy="13" r="3.3" /></Svg>;
export const IconUser = (p: P) => <Svg {...p}><circle cx="12" cy="8" r="3.5" /><path d="M5 20 C5 15.5 8 13.5 12 13.5 C16 13.5 19 15.5 19 20" /></Svg>;
export const IconSearch = (p: P) => <Svg {...p}><circle cx="10.5" cy="10.5" r="6.5" /><path d="M19.5 19.5 L15.2 15.2" /></Svg>;
export const IconPencil = (p: P) => <Svg {...p}><path d="M4 20 L4.7 16.7 L15.5 5.9 A1.8 1.8 0 0 1 18 5.9 L18.1 6 A1.8 1.8 0 0 1 18.1 8.5 L7.3 19.3 Z M14 7.4 L16.6 10" /></Svg>;
export const IconBell = (p: P) => <Svg {...p}><path d="M6 10.5 C6 6.9 8.7 4.5 12 4.5 C15.3 4.5 18 6.9 18 10.5 C18 14 19 15.3 19.8 16.2 A0.8 0.8 0 0 1 19.2 17.5 H4.8 A0.8 0.8 0 0 1 4.2 16.2 C5 15.3 6 14 6 10.5 Z" /><path d="M9.5 20 A2.5 2.5 0 0 0 14.5 20" /></Svg>;
export const IconHourglass = (p: P) => <Svg {...p}><path d="M6 4 H18 M6 20 H18 M7 4 C7 8.5 11 10.5 12 11.5 C13 10.5 17 8.5 17 4 M7 20 C7 15.5 11 13.5 12 12.5 C13 13.5 17 15.5 17 20" /></Svg>;
export const IconCloudOff = (p: P) => <Svg {...p}><path d="M4 4 L20 20" /><path d="M8.5 16 H16.5 A3.5 3.5 0 0 0 17.2 9.1 A5.5 5.5 0 0 0 7 7.8" /><path d="M6.3 9.6 A3.5 3.5 0 0 0 6.5 16 H7" /></Svg>;
export const IconSun = (p: P) => <Svg {...p}><circle cx="12" cy="12" r="4" /><path d="M12 2.5 V5 M12 19 V21.5 M21.5 12 H19 M5 12 H2.5 M18.7 5.3 L17 7 M7 17 L5.3 18.7 M18.7 18.7 L17 17 M7 7 L5.3 5.3" /></Svg>;
export const IconMoon = (p: P) => <Svg {...p}><path d="M20 13.5 A8 8 0 1 1 10.5 4 A6.3 6.3 0 0 0 20 13.5 Z" /></Svg>;
export const IconMonitor = (p: P) => <Svg {...p}><rect x="3" y="4.5" width="18" height="12" rx="1.5" /><path d="M8 20 H16 M12 16.5 V20" /></Svg>;
export const IconSunCloud = (p: P) => <Svg {...p}><circle cx="9" cy="8" r="3" /><path d="M9 2.5 V3.5 M14.2 4.8 L13.5 5.5 M3.8 4.8 L4.5 5.5" /><path d="M8 15 H16.5 A3.5 3.5 0 0 0 17.1 8.1 A5.2 5.2 0 0 0 10.3 7.3" /></Svg>;
export const IconScale = (p: P) => <Svg {...p}><path d="M12 3 V21 M7 21 H17 M12 3 L5 8 M12 3 L19 8" /><path d="M2 8 H8 L5 13 A3 3 0 0 1 2 8 Z" /><path d="M16 8 H22 L19 13 A3 3 0 0 1 16 8 Z" /></Svg>;
export const IconRedo = (p: P) => <Svg {...p}><path d="M18 8 H9 A5 5 0 0 0 4 13 A5 5 0 0 0 9 18 H14" /><path d="M13 4 L18 8 L13 12" /></Svg>;
export const IconPaperclip = (p: P) => <Svg {...p}><path d="M17.5 8.5 L9.5 16.5 A3.2 3.2 0 0 1 5 12 L13 4 A2.2 2.2 0 0 1 16.1 7.1 L8.8 14.4 A1.2 1.2 0 0 1 7 12.6 L13 6.6" /></Svg>;
export const IconFile = (p: P) => <Svg {...p}><path d="M7 3.5 H14 L18 7.5 V19.5 A1 1 0 0 1 17 20.5 H7 A1 1 0 0 1 6 19.5 V4.5 A1 1 0 0 1 7 3.5 Z" /><path d="M14 3.5 V7.5 H18" /></Svg>;
