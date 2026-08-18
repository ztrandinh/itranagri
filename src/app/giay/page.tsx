import { Page } from "@/components/withSession"; import GiayPanel from "@/components/panels/GiayPanel";
export default function P() { return <Page title="Phiếu giấy ↔ số">{(s) => <GiayPanel sess={s} />}</Page>; }
