import { Page } from "@/components/withSession"; import { PrintCenter } from "@/components/panels/More";
export default function P() { return <Page title="In ấn — hóa đơn · phiếu cân · hợp đồng · nhãn QR · biểu mẫu · báo cáo">{(s) => <PrintCenter sess={s} />}</Page>; }
