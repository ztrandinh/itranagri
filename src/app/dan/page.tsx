import { Page } from "@/components/withSession"; import DanPanel from "@/components/panels/DanPanel";
export default function P() { return <Page title="Chăn nuôi — Đàn: định danh 3 cấp · vòng theo dõi · lịch sinh sản · việc đàn">{(s) => <DanPanel sess={s} />}</Page>; }
