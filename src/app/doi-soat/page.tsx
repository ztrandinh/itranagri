import { Page } from "@/components/withSession"; import { DoiSoatPanel } from "@/components/panels/Ops";
export default function P() { return <Page title="Đối soát đầu vào – đầu ra (RC)">{(s) => <DoiSoatPanel sess={s} />}</Page>; }
