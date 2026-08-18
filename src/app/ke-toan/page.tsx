import { Page } from "@/components/withSession"; import { KeToanPanel } from "@/components/panels/Depts";
export default function P() { return <Page title="Kế toán — bảng kê · khóa kỳ · chi · quỹ">{(s) => <KeToanPanel sess={s} />}</Page>; }
