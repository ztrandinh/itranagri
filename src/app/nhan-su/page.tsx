import { Page } from "@/components/withSession"; import { NhanSuPanel } from "@/components/panels/Depts";
export default function P() { return <Page title="Nhân sự — đào tạo tuần · năng lực · thưởng gắn lương · hồ sơ · chấm công">{(s) => <NhanSuPanel sess={s} />}</Page>; }
