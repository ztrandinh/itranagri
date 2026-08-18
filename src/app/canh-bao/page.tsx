import { Page } from "@/components/withSession"; import { CanhBaoPanel } from "@/components/panels/Ops";
export default function P() { return <Page title="Cảnh báo">{(s) => <CanhBaoPanel sess={s} />}</Page>; }
