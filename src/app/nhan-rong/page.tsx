import { Page } from "@/components/withSession"; import { ModuleByKey } from "@/components/ModuleRegistry";
export default function P() { return <Page title="Nhân rộng · nhượng quyền — gói mẫu trại · điểm triển khai · checklist chuyển giao">{() => <ModuleByKey k="nhan-rong" />}</Page>; }
