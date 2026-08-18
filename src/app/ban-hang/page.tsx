import { Page } from "@/components/withSession"; import { BanHangPanel } from "@/components/panels/Ops";
export default function P() { return <Page title="Bán hàng · 5 kênh · công nợ · giá sàn">{(s) => <BanHangPanel sess={s} />}</Page>; }
