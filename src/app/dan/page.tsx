import { Page } from "@/components/withSession"; import DanPanel from "@/components/panels/DanPanel";
export default function P() { return <Page title="Đàn — định danh 3 cấp (cá thể · lô nhập · đàn)">{(s) => <DanPanel sess={s} />}</Page>; }
