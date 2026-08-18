import { Page } from "@/components/withSession"; import CheBien from "@/components/panels/CheBien";
export default function P() { return <Page title="Xưởng thức ăn D5 & Chế biến — KHSX · MRP · BOM · mẻ · bao bì · nhãn · tem QR">{(s) => <CheBien sess={s} />}</Page>; }
