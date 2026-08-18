import QRCode from "qrcode";
/** QR SVG nội bộ (không gọi dịch vụ ngoài — offline được, không lộ mã lô ra bên thứ ba) */
export async function qrSvg(text: string, size = 128): Promise<string> {
  const svg = await QRCode.toString(text, { type: "svg", errorCorrectionLevel: "M", margin: 1, width: size });
  return svg;
}
export const publicBase = () => process.env.PUBLIC_URL ?? "";
