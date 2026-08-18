import { Page } from "@/components/withSession"; import { BanHangPanel } from "@/components/panels/Ops";
export default function P() { return <Page title="Kinh doanh — bán 5 kênh · báo giá · hợp đồng · khách · điểm · công nợ · POS">{(s) => <BanHangPanel sess={s} />}</Page>; }
