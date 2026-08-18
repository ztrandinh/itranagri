import { Page } from "@/components/withSession"; import { PrintCenter } from "@/components/panels/More";
export default function P() { return <Page title="In biểu mẫu — hóa đơn · phiếu cân · hợp đồng · nhãn/tem QR · biểu mẫu · báo cáo">{(s) => <PrintCenter sess={s} />}</Page>; }
