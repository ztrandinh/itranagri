import { Page } from "@/components/withSession"; import { NhanSuPanel } from "@/components/panels/Depts";
export default function P() { return <Page title="Nhân sự — chứng chỉ SOP · sức khỏe · hoạt động">{(s) => <NhanSuPanel sess={s} />}</Page>; }
