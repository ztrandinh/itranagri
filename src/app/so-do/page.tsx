import { Page } from "@/components/withSession"; import { SoDoPanel } from "@/components/panels/Extra";
export default function P() { return <Page title="Sơ đồ khu · chuồng · vị trí — trạng thái">{(s) => <SoDoPanel sess={s} />}</Page>; }
