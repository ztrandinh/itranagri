import { Page } from "@/components/withSession"; import TaiKhoan from "@/components/panels/TaiKhoan";
export default function P() { return <Page title="Tài khoản & thiết bị">{(s) => <TaiKhoan sess={s} />}</Page>; }
