import { Page } from "@/components/withSession"; import { SucKhoePanel } from "@/components/panels/Ops";
export default function P() { return <Page title="Chất lượng dữ liệu & sức khỏe hệ thống — 7 bộ câu chất vấn">{(s) => <SucKhoePanel sess={s} />}</Page>; }
