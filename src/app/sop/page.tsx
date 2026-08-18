import { Page } from "@/components/withSession"; import { SopPanel } from "@/components/panels/Ops";
export default function P() { return <Page title="Thư viện SOP">{() => <SopPanel />}</Page>; }
