import { Page } from "@/components/withSession"; import CheBien from "@/components/panels/CheBien";
export default function P() { return <Page title="Chế biến — kế hoạch SX · BOM/MRP · bao bì · nhãn · tem QR mẻ">{(s) => <CheBien sess={s} />}</Page>; }
