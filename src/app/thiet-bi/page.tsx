import { Page } from "@/components/withSession"; import { ThietBiPanel } from "@/components/panels/Depts";
export default function P() { return <Page title="Thiết bị – máy móc – công nghệ">{(s) => <ThietBiPanel sess={s} />}</Page>; }
