import { Page } from "@/components/withSession"; import { AuditPanel } from "@/components/panels/Dashboards";
export default function P() { return <Page title="Kiểm toán · Xuất dữ liệu chuẩn">{(s) => <AuditPanel sess={s} />}</Page>; }
