import { Page } from "@/components/withSession"; import MuaHang from "@/components/panels/MuaHang";
export default function P() { return <Page title="Mua hàng — vật tư · giống · thiết bị · công cụ · dịch vụ (PO → duyệt → nhận → nhập kho)">{(s) => <MuaHang sess={s} />}</Page>; }
