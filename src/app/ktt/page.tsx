import { Page } from "@/components/withSession"; import { KttPanel } from "@/components/panels/Dashboards";
export default function P() { return <Page title="Điều hành ca (Kỹ thuật trưởng) — duyệt · đối chiếu chéo · PO">{(s) => <KttPanel sess={s} />}</Page>; }
