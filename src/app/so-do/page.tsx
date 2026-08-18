import { Page } from "@/components/withSession"; import { SoDoPanel } from "@/components/panels/Extra";
export default function P() { return <Page title="Sơ đồ trại — khu · vị trí · trạng thái">{(s) => <SoDoPanel sess={s} />}</Page>; }
