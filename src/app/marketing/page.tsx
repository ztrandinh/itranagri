import { Page } from "@/components/withSession"; import Marketing from "@/components/panels/Marketing";
export default function P() { return <Page title="Marketing – Truyền thông — chiến dịch · lịch nội dung · thương hiệu · lắng nghe & khủng hoảng">{(s) => <Marketing sess={s} />}</Page>; }
