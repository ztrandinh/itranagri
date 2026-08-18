import { Page } from "@/components/withSession"; import { ModuleByKey } from "@/components/ModuleRegistry";
export default function P() { return <Page title="Xuất nhập khẩu — thị trường · HĐ ngoại · lô hàng · chứng từ · hải quan · thanh toán · landed cost">{() => <ModuleByKey k="xnk" />}</Page>; }
