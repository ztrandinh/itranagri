import { Page } from "@/components/withSession"; import { KttPanel } from "@/components/panels/Dashboards";
export default function P() { return <Page title="Kỹ thuật trưởng — duyệt · đối chiếu chéo">{(s) => <KttPanel sess={s} />}</Page>; }
